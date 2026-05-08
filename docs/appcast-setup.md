# Sparkle appcast setup

Once-per-project setup so the in-app **Check for updates now** finds a real
appcast feed and auto-updates work end-to-end.

## What is already in the repo

- `bin/make-app.sh` embeds the public Ed25519 key (`SUPublicEDKey`) in
  `Info.plist`. Only the matching private key (held in your local Keychain
  and as a GitHub secret) can sign updates that Sparkle will accept.
- `.github/workflows/release.yml` now:
  - downloads Sparkle's CLI tools (`sign_update`, etc.),
  - signs each release zip with `sign_update`,
  - updates `appcast.xml` on the `gh-pages` branch via
    `bin/update-appcast.py`,
  - leaves the rest of the notarized build pipeline untouched.

## What you need to do once

### 1. Generate the Ed25519 keypair (already done)

You already ran:

```sh
~/Downloads/Sparkle-2.9.1/bin/generate_keys
```

That stored the private key in your **login keychain** ("Private key for
signing Sparkle updates") and printed the public key. The public key is
already hardcoded in `bin/make-app.sh`:

```
SrfAn540iTdY174yQhMIyqSoAkCwh66UDziuy8EPwxQ=
```

### 2. Export and add the private key as a GitHub secret

The private key was exported to `~/Downloads/sparkle-private-key.txt`
(44 bytes, chmod 600). Open that file, copy its contents (a single
base64 line ending in `=`), and add it as a repository secret:

- <https://github.com/lardissone/cap-note/settings/secrets/actions>
- Name: `SPARKLE_ED_PRIVATE_KEY`
- Value: full contents of the file

After saving the secret, **delete the local file**:

```sh
rm ~/Downloads/sparkle-private-key.txt
```

The private key still lives in your macOS login keychain and can be
re-exported with `generate_keys -x` if you ever need it again.

### 3. Enable GitHub Pages on the repo

The release workflow pushes the appcast to a `gh-pages` branch on every
release. Enable Pages so it is served at the URL the app expects.

- <https://github.com/lardissone/cap-note/settings/pages>
- **Source**: *Deploy from a branch*
- **Branch**: `gh-pages` / `(root)`
- Click **Save**

The first release tag after this setup creates the branch automatically.
After that, GitHub Pages serves:

```
https://lardissone.github.io/cap-note/appcast.xml
```

This URL is the `SUFeedURL` already baked into the bundled `Info.plist`.

## Releasing after setup

Same as before — push a tag matching `v*`:

```sh
git tag -a v0.2.4 -m "v0.2.4"
git push origin v0.2.4
```

The release workflow:

1. Builds, signs, and notarizes `CapNote.app`.
2. Publishes the zipped `.app` as a GitHub Release asset.
3. Signs the zip with `sign_update` and produces an `sparkle:edSignature`.
4. Pulls (or initializes) `gh-pages`, runs `bin/update-appcast.py` to add a
   new `<item>` for this version, commits, and pushes.

A user running an older CapNote will see the new release the next time the
app polls the appcast (`SUEnableAutomaticChecks` is on) — or immediately
when they hit **Check for updates now** in *Settings → Updates*.

## Local testing without publishing

To test that signatures verify locally:

```sh
~/Downloads/Sparkle-2.9.1/bin/sign_update CapNote-x.y.z.zip
# prints: sparkle:edSignature="..." length="..."
```

Sparkle's update verification uses the same public key whether the
signature was made on your laptop or in CI; if the local signature line
matches the one published in the appcast, you're good.
