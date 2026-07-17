# hkd

A minimal macOS hotkey daemon that launches applications in response to global keyboard shortcuts. Configure your shortcuts in a simple JSON file and run `hkd` in the background. The daemon watches your config for changes and reloads automatically.

## Features

- Global hotkeys (Cmd/Shift/Alt/Ctrl + letters, numbers, arrows, F-keys)
- **No permissions required** when every hotkey includes a modifier (uses the Carbon hotkey API)
- Launch apps by bundle identifier or name
- Auto-reload on config changes
- Lightweight, no dependencies (Swift + Carbon/CoreGraphics)

## Requirements

- macOS 13+
- Accessibility permission — **only** if you declare a hotkey without any modifiers (e.g. a bare `f5`). In that case hkd falls back to a CGEvent tap, which macOS gates behind System Settings → Privacy & Security → Accessibility. As long as every hotkey has at least one modifier, no permission is needed.

## Install (Homebrew)

```sh
brew tap dmrz/hkd
brew install dmrz/hkd/hkd
```

### Autolaunch

```sh
brew services start hkd
```

### Setup config

```sh
mkdir -p ~/.config/hkd
cp "$(brew --prefix hkd)/share/hkd/config-example.json" ~/.config/hkd/config.json
```

## Configure

Create or edit `~/.config/hkd/config.json`.

Example:

```json
{
  "hotkeys": [
    { "key": "space", "modifiers": ["ctrl", "alt"], "application": "Terminal" },
    { "key": "b", "modifiers": ["cmd", "shift"], "application": "Safari" },
    { "key": "t", "modifiers": ["cmd", "alt"], "application": "TextEdit" }
  ]
}
```

Notes:

- Modifiers: `cmd`/`command`, `shift`, `alt`/`opt`/`option`, `ctrl`/`control`
- Application: bundle ID (e.g. `com.apple.Terminal`) or app name (e.g. `Safari`)
- Keys: letters, numbers, `space`, `return`/`enter`, `tab`, `escape`/`esc`, `delete`/`backspace`, arrows (`left`, `right`, `up`, `down`), `f1`–`f12`
- Config auto-reloads on save; invalid configs are rejected with an error and the previous hotkeys stay active

## Usage

```
hkd [options]

OPTIONS:
  -c, --config <path>   Path to the config file
                        (default: ~/.config/hkd/config.json)
  -v, --version         Print the version and exit
  -h, --help            Show this help and exit
```

## Build from source

### Prerequisites

```sh
xcode-select --install  # if not already installed
```

### Build

```sh
swift build -c release --disable-sandbox
codesign -fs - .build/release/hkd
```

### Test

Tests require a full Xcode toolchain (the Command Line Tools alone don't ship the Testing framework):

```sh
swift test
```
