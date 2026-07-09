# lidclose

Keep a MacBook awake with the lid closed — without typing your password every
time, and without forgetting you did it.

macOS has no supported way to keep a laptop awake in clamshell mode on battery.
`sudo pmset -a disablesleep 1` works, but it's global, it needs sudo, and if
you forget to turn it back off your Mac sits hot in your bag all day. This
repo wraps that in three commands, makes them passwordless, and adds a chime
so a closed lid with sleep disabled never goes unnoticed.

## Commands

| Command | What it does |
|---|---|
| `lidawake` | Disable sleep — the Mac stays awake when you close the lid |
| `lidsleep` | Back to normal — lid close sleeps the Mac |
| `lidstatus` | Show sleep state, lid state, and whether the watcher is running |

## The chime

A tiny watcher runs as a LaunchAgent and polls the lid sensor every 5 seconds.
When you close the lid while sleep is disabled, it plays a chime so you know
the Mac is staying awake. A closed lid muffles the speakers badly, so the
alert is amplified, repeated with 1-second gaps, and the system volume is
temporarily raised to a floor (then restored) — it fires even on a muted Mac.

Configure it in `~/.config/lidclose/config` (changes apply immediately, no
restart needed):

```sh
CHIME_SOUND=/System/Library/Sounds/Glass.aiff  # any .aiff in /System/Library/Sounds
CHIME_REPEATS=3    # plays per alert, 1s apart
CHIME_GAIN=3       # afplay -v multiplier (>1 amplifies)
MIN_VOLUME=60      # floor for system output volume during the alert
REPEAT_MINUTES=0   # 0 = chime once per lid close; 10 = also nag every 10 minutes
```

Logs go to `~/Library/Logs/lidclose-watcher.log`.

## Install

```sh
git clone https://github.com/xoChrisCo/lidclose.git ~/src/lidclose
cd ~/src/lidclose && ./install.sh
```

The installer asks for your password once, to install the sudoers rule. It
then adds `bin/` to your PATH, seeds the config, loads the watcher
LaunchAgent, and removes any old `lidawake()`/`lidsleep()` functions from your
`.zshrc` (backed up to `.zshrc.bak.lidclose` first). It's idempotent — safe to
re-run.

## Security note

Passwordless sudo is scoped to exactly two commands, nothing else:

```
you ALL=(ALL) NOPASSWD: /usr/bin/pmset -a disablesleep 1, /usr/bin/pmset -a disablesleep 0
```

The rule is written to `/etc/sudoers.d/lidclose` at install time (your
username is filled in then — nothing user-specific lives in the repo) and is
validated with `visudo -c` before it's put in place.

## Uninstall

```sh
./uninstall.sh
```

Restores normal sleep, unloads the watcher, removes the sudoers rule and the
PATH entry. Your config in `~/.config/lidclose/` is kept.

## Requirements

macOS. Tested on macOS 26 (Tahoe) on Apple silicon. Everything used —
`pmset`, `ioreg`, `afplay`, `launchd` — ships with the OS.
