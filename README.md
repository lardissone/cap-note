# CapNote

A tiny menubar-only macOS app that posts quick notes to your [Capacities](https://capacities.io) Daily Note via a global keyboard shortcut.

> Inspired by a BetterTouchTool setup that did the same thing — rebuilt as a standalone app.

## Features

- Lives in the macOS menu bar (no Dock icon).
- Configurable global keyboard shortcut to summon a quick-note window from anywhere.
- `⌘+Enter` sends the note to your Capacities Daily Note and closes the window.
- Built-in settings (rotated in via a 3D flip from the same window):
  - API token (stored securely in the macOS Keychain).
  - Target space (loaded from your Capacities account).
  - Window position: centered on screen, or where the cursor is.
  - Optional separator prepended to each note (default `---\n\n`).
  - Optional timestamp inclusion in the daily note.

## Requirements

- macOS 14 (Sonoma) or later.
- A [Capacities](https://capacities.io) account with API access enabled (Settings → Capacities API).

## Building from source

Requires Xcode 15 (or the matching command-line tools) for Swift 5.9.

```sh
git clone https://github.com/<you>/cap-note.git
cd cap-note
swift build -c release
.build/release/CapNote
```

To open in Xcode and run from there:

```sh
xed .
```

A proper signed `.app` bundle is not yet provided — you run the binary directly. The menu bar icon appears as soon as the process starts; quitting from the menu (or `^C` in the terminal) terminates it.

## Usage

1. Launch the app — a small note icon appears in your menu bar.
2. Click the menu bar icon and choose **Settings…** — the note window opens with the settings face showing.
3. Paste your Capacities API token, click **Test & Load spaces**, then pick your space from the dropdown.
4. Set a **Global shortcut** (e.g. `⌘⌥N`). Optionally tweak window position, separator, and timestamp.
5. Tap the back arrow (or press `Esc`) to flip back to the note input.
6. From any app, press your shortcut → write a note → `⌘+Enter` → it lands in your Capacities Daily Note.

### Keyboard shortcuts inside the window

| Key | Action |
|---|---|
| `⌘+Enter` | Send the note and close the window |
| `Esc` | Close the note (or, when on the settings face, flip back to the note) |
| `⌘+,` | Toggle between note and settings face |

## License

MIT — see [LICENSE](./LICENSE).
