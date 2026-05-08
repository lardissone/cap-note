# Release signing & notarization setup

This document walks through the one-time setup required to make
`.github/workflows/release.yml` produce a signed and notarized
`CapNote.app`. After this is done, every `git push origin v*` triggers a
fully signed, stapled release without further intervention.

## What you need

A paid Apple Developer Program account ($99/year) and a Mac with Xcode
installed. The App Store is **not** required — we ship outside it.

## 1. Create the Developer ID Application certificate

1. Open **Xcode → Settings → Accounts**.
2. Sign in with your Apple ID.
3. Select your team and click **Manage Certificates…**.
4. Click the **+** button → **Developer ID Application**.
5. Xcode generates the certificate and adds it to your login keychain.

Alternative path via the web console:
[developer.apple.com/account/resources/certificates](https://developer.apple.com/account/resources/certificates)
→ create a *Developer ID Application* certificate, download the `.cer`
file, double-click to install in **Keychain Access**.

## 2. Export the certificate as a `.p12`

1. Open **Keychain Access**.
2. Switch to the **login** keychain, **My Certificates** category.
3. Find *Developer ID Application: <Your Name> (TEAMID)*.
4. Right-click → **Export…** → save as `developerID.p12`.
5. Set a password when prompted — keep it, you'll need it for the
   GitHub secret.

## 3. Base64-encode the `.p12`

```sh
base64 -i developerID.p12 -o developerID.p12.b64
```

Open the resulting file in any text editor and copy its full contents
to your clipboard.

## 4. Create an app-specific password for `notarytool`

1. Open [appleid.apple.com](https://appleid.apple.com) and sign in.
2. **Sign-In and Security** → **App-Specific Passwords** → **+**.
3. Name it something like `cap-note CI notarization`.
4. Copy the generated password (one-shot — Apple won't show it again).

## 5. Note your Team ID

Visible at the top right of
[developer.apple.com/account](https://developer.apple.com/account)
(10-character alphanumeric). Or run:

```sh
security find-identity -v -p codesigning \
  | awk -F'"' '/Developer ID Application/ { print $2 }'
# → "Developer ID Application: Your Name (ABCDE12345)"
#                                          ^^^^^^^^^^ this part
```

## 6. Add the secrets to GitHub

Go to <https://github.com/lardissone/cap-note/settings/secrets/actions>
and add:

| Name | Value |
|---|---|
| `MACOS_CERTIFICATE_P12_BASE64` | The base64 string from step 3 (the whole content of `developerID.p12.b64`). |
| `MACOS_CERTIFICATE_P12_PASSWORD` | The password you set when exporting the `.p12` (step 2). |
| `APPLE_ID` | Your Apple ID email. |
| `APPLE_ID_PASSWORD` | The app-specific password from step 4. |
| `APPLE_TEAM_ID` | The 10-character Team ID from step 5. |

That's it. The next time you push a tag matching `v*`, the workflow:

1. Imports the certificate into a temporary keychain.
2. Builds `CapNote.app` and signs every nested component (Sparkle XPC
   services, Updater.app, Autoupdate, the framework, the app) with
   your Developer ID and hardened runtime.
3. Submits the bundle to Apple's notary service (`xcrun notarytool
   submit … --wait`).
4. Staples the notarization ticket onto the bundle.
5. Zips the stapled `.app` and publishes it as a GitHub Release with a
   SHA-256 sidecar.

The downloaded zip opens with a single, normal "downloaded from the
internet" prompt — no quarantine workaround needed.

## Releasing locally with the same identity

If you'd rather sign and notarize from your laptop:

```sh
CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
  bin/make-app.sh 0.2.0

# Notarize
ditto -c -k --keepParent dist/CapNote.app /tmp/CapNote-notarize.zip
xcrun notarytool submit /tmp/CapNote-notarize.zip \
  --apple-id you@example.com \
  --team-id TEAMID \
  --password APP_SPECIFIC_PASSWORD \
  --wait

# Staple and ship
xcrun stapler staple dist/CapNote.app
ditto -c -k --keepParent dist/CapNote.app CapNote-0.2.0.zip
```

You can save the notarytool credentials once with
`xcrun notarytool store-credentials` and skip the `--apple-id`/
`--team-id`/`--password` flags on subsequent runs.
