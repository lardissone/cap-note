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

## Install

Grab the latest pre-built binary from
[GitHub Releases](https://github.com/lardissone/cap-note/releases/latest).

```sh
# Download and unzip (replace 0.1.0 with the latest version tag)
curl -L -o CapNote.zip \
  https://github.com/lardissone/cap-note/releases/latest/download/CapNote-0.1.0.zip
unzip CapNote.zip

# The binary is not yet code-signed/notarized — clear the macOS
# quarantine attribute so Gatekeeper lets it run.
xattr -dr com.apple.quarantine CapNote

# Move it somewhere stable (or run in place) and launch.
mv CapNote /usr/local/bin/
CapNote &
```

The note icon shows up in the menu bar. Quit from the menu or via
`pkill -x CapNote`.

> **Note**: while the project still ships as a bare executable, every
> rebuild changes its code-signing identity, which means macOS will
> ask you to re-authorize Keychain access for the saved API token on
> each upgrade. A signed `.app` bundle (planned) will fix this.

## Building from source

Requires Xcode 15 (or the matching command-line tools) for Swift 5.9.

```sh
git clone https://github.com/lardissone/cap-note.git
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

## Releases

Pushing a Git tag matching `v*` (for example `v0.1.0`) triggers
`.github/workflows/release.yml`, which builds the release binary on a
`macos-14` runner, zips it, and publishes a GitHub Release with the
zip + SHA-256 checksum attached.

```sh
git tag v0.1.0
git push origin v0.1.0
```

## Auto-update (Sparkle)

The app links Sparkle and exposes both a "Check for Updates…" item in
the menu bar and the matching toggles in *Settings → Updates*. For the
update flow to actually fetch anything, the bundled `Info.plist` of the
shipped `.app` needs:

- `SUFeedURL` — public URL of the appcast XML feed.
- `SUPublicEDKey` — base64-encoded EdDSA public key matching the
  private key used to sign each release zip.

The first proper bundled release will also need the `appcast.xml` to be
hosted somewhere stable (GitHub Pages on this repo is the typical
choice) and to be regenerated for every published release using
Sparkle's `generate_appcast` tool.

Until that bundled build is in place, `Updater` and the Sparkle UI are
wired correctly but updates will fail to fetch — the wiring stays the
same.

## License

MIT — see [LICENSE](./LICENSE).
