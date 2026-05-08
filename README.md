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

1. Download `CapNote-x.y.z.zip` from
   [GitHub Releases](https://github.com/lardissone/cap-note/releases/latest).
2. Unzip it — you'll get `CapNote.app`.
3. Drag `CapNote.app` into `/Applications`.
4. Because the build is ad-hoc-signed (not yet notarized), macOS
   Gatekeeper blocks it on first launch. Clear the quarantine
   attribute once:

   ```sh
   xattr -dr com.apple.quarantine /Applications/CapNote.app
   ```

5. Open **CapNote** from Launchpad or `/Applications`. The note icon
   shows up in the menu bar.

To quit: use the menu's "Quit CapNote" or run `pkill -x CapNote`.

> **Heads-up**: the build is ad-hoc-signed. Each release ships with a
> different signing identity, so macOS will re-prompt for Keychain
> access to the stored API token after each upgrade until the project
> is properly notarized.

## Building from source

Requires a Swift toolchain that can resolve recent SPM dependencies
(KeyboardShortcuts ≥ 2.4, Sparkle ≥ 2.9). On macOS use Xcode 16+.

For a quick development run as a bare CLI process:

```sh
git clone https://github.com/lardissone/cap-note.git
cd cap-note
swift run -c release
```

To produce a real `.app` bundle (matching what the release pipeline
ships), run:

```sh
bin/make-app.sh 0.0.0-dev      # → dist/CapNote.app, ad-hoc signed
open dist/CapNote.app
```

Pass `universal` as the second argument for a fat arm64 + x86_64 build.
Set `CODESIGN_IDENTITY` in the environment to sign with a real
Developer ID instead of the default ad-hoc identity.

To open the source in Xcode for editing/debugging:

```sh
xed .
```

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
