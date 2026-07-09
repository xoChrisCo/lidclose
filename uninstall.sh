#!/usr/bin/env bash
# Remove everything install.sh set up. Restores normal sleep behavior first.
set -euo pipefail

DIR="$(cd "$(dirname "$(readlink -f "$0" 2>/dev/null || echo "$0")")" && pwd)"
LABEL="com.lidclose.watcher"

# Restore normal sleep so we don't leave the Mac stuck awake.
sudo /usr/bin/pmset -a disablesleep 0 || true
echo "Sleep restored to normal."

# Unload and remove the LaunchAgent.
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
rm -f "$HOME/Library/LaunchAgents/$LABEL.plist"
echo "Watcher LaunchAgent removed."

# Remove the sudoers rule.
sudo rm -f /etc/sudoers.d/lidclose
echo "Sudoers rule removed (pmset needs a password again)."

# Remove the PATH entry.
for RC in "$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.config/fish/config.fish" "$HOME/.profile"; do
  if [ -f "$RC" ] && grep -Fq "$DIR/bin" "$RC"; then
    grep -Fv "$DIR/bin" "$RC" | grep -Fv "# lidclose: added by install.sh" > "$RC.tmp"
    mv "$RC.tmp" "$RC"
    echo "Removed PATH entry from $RC"
  fi
done

echo ""
echo "Uninstalled. Config kept at ~/.config/lidclose/ — delete it if you want."
