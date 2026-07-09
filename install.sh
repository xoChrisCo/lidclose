#!/usr/bin/env bash
# lidclose installer:
#   1. passwordless sudo for the two pmset commands (prompts for your password once)
#   2. adds bin/ to PATH in your shell rc
#   3. seeds ~/.config/lidclose/config
#   4. installs + loads the lid-close watcher LaunchAgent
#   5. removes the old lidawake()/lidsleep() functions from ~/.zshrc if present
set -euo pipefail

DIR="$(cd "$(dirname "$(readlink -f "$0" 2>/dev/null || echo "$0")")" && pwd)"
LABEL="com.lidclose.watcher"

chmod +x "$DIR"/bin/* "$DIR"/watcher/lidclose-watcher "$DIR"/install.sh "$DIR"/uninstall.sh 2>/dev/null || true

# --- 1. sudoers rule (validated with visudo before installing) -------------
SUDOERS_DST="/etc/sudoers.d/lidclose"
RULE="$USER ALL=(ALL) NOPASSWD: /usr/bin/pmset -a disablesleep 1, /usr/bin/pmset -a disablesleep 0"

if sudo -n true 2>/dev/null && sudo test -f "$SUDOERS_DST" && [ "$(sudo cat "$SUDOERS_DST")" = "$RULE" ]; then
  echo "sudoers rule already installed — skipping."
else
  echo "Installing sudoers rule (you may be asked for your password):"
  echo "  $RULE"
  TMP="$(mktemp)"
  echo "$RULE" > "$TMP"
  sudo visudo -cf "$TMP"
  sudo install -m 440 -o root -g wheel "$TMP" "$SUDOERS_DST"
  rm -f "$TMP"
  echo "Installed $SUDOERS_DST"
fi

# --- 2. PATH entry ----------------------------------------------------------
SHELL_NAME="$(basename "${SHELL:-/bin/zsh}")"
case "$SHELL_NAME" in
  zsh)  RC="$HOME/.zshrc" ;;
  bash) RC="$HOME/.bashrc" ;;
  fish) RC="$HOME/.config/fish/config.fish" ;;
  *)    RC="$HOME/.profile" ;;
esac
mkdir -p "$(dirname "$RC")"
touch "$RC"
if grep -Fq "$DIR/bin" "$RC"; then
  echo "PATH entry already present in $RC — skipping."
else
  {
    echo ""
    echo "# lidclose: added by install.sh"
    if [ "$SHELL_NAME" = "fish" ]; then
      echo "set -gx PATH $DIR/bin \$PATH"
    else
      echo "export PATH=\"$DIR/bin:\$PATH\""
    fi
  } >> "$RC"
  echo "Added PATH entry to $RC"
fi

# --- 3. config --------------------------------------------------------------
CONFIG_DIR="$HOME/.config/lidclose"
CONFIG="$CONFIG_DIR/config"
if [ ! -f "$CONFIG" ]; then
  mkdir -p "$CONFIG_DIR"
  cat > "$CONFIG" <<'EOF'
# lidclose watcher config — re-read on every poll, no restart needed.

# Sound played when the lid closes while sleep is disabled.
CHIME_SOUND=/System/Library/Sounds/Glass.aiff

# How loud/insistent the alert is. The system volume is temporarily raised
# to at least MIN_VOLUME during the alert (and restored afterwards).
CHIME_REPEATS=3   # plays per alert, 1s apart
CHIME_GAIN=3      # afplay -v multiplier (>1 amplifies)
MIN_VOLUME=60     # floor for system output volume during the alert

# 0 = chime once per lid close. N > 0 = also repeat every N minutes
# for as long as the lid stays closed with sleep disabled.
REPEAT_MINUTES=0
EOF
  echo "Created $CONFIG"
else
  echo "$CONFIG already exists — leaving it alone."
fi

# --- 4. LaunchAgent ---------------------------------------------------------
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
mkdir -p "$HOME/Library/LaunchAgents" "$HOME/Library/Logs"
sed -e "s|__DIR__|$DIR|g" -e "s|__HOME__|$HOME|g" \
  "$DIR/launchd/$LABEL.plist.template" > "$PLIST"
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"
echo "Watcher LaunchAgent loaded ($LABEL)"

# --- 5. remove old zshrc functions -----------------------------------------
ZSHRC="$HOME/.zshrc"
if [ -f "$ZSHRC" ] && grep -Eq '^\s*(lidawake|lidsleep)\(\)' "$ZSHRC"; then
  cp "$ZSHRC" "$ZSHRC.bak.lidclose"
  grep -Ev '^\s*(lidawake|lidsleep)\(\)' "$ZSHRC" > "$ZSHRC.tmp"
  mv "$ZSHRC.tmp" "$ZSHRC"
  echo "Removed old lidawake()/lidsleep() functions from $ZSHRC (backup: $ZSHRC.bak.lidclose)"
fi

# --- summary ----------------------------------------------------------------
echo ""
echo "Done. Open a new shell (or 'source $RC'), then: lidawake / lidsleep / lidstatus"
echo ""
"$DIR/bin/lidstatus"
