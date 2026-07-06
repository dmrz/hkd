# hkd

A minimal macOS hotkey daemon that launches applications in response to global keyboard shortcuts. Configure your shortcuts in a simple JSON file and run `hkd` in the background. The daemon watches your config for changes and reloads automatically.

## Features

- Global hotkeys (Cmd/Shift/Alt/Ctrl + letters, numbers, arrows, F-keys)
- Launch apps by bundle identifier or name
- Auto-reload on config changes
- Lightweight, no dependencies (Swift + CoreGraphics)

## Requirements

- macOS 13+
- Accessibility permission (System Settings → Privacy & Security → Accessibility)

## Install (Homebrew)

```sh
brew tap dmrz/hkd
brew install dmrz/hkd/hkd
```

### Autolaunch

```sh
brew services start hkd
```

> [!NOTE]
> On first launch, grant Accessibility permission in System Settings → Privacy & Security → Accessibility.

### Setup config

```sh
mkdir -p ~/.config/hkd
cp "$(brew --prefix hkd)/share/hkd/config-example.json" ~/.config/hkd/config.json
```

## Configure

Create or edit ~/.config/hkd/config.json.

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

- Modifiers: cmd, shift, alt/option, ctrl/control
- Application: bundle ID (e.g. com.apple.Terminal) or app name (e.g. Safari)
- Keys: letters, numbers, space, return, tab, escape, arrows, f1–f12
- Config auto-reloads on save

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
