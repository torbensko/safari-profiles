# Publishing Safari Profile Studio

The public app lives at https://github.com/torbensko/safari-profiles. GitHub Releases supplies the downloads for the torbensko.com software entry. No separate download server or AWS credentials are needed for the app release.

## One release version

`VERSION` is the source of truth for the app version and release tag. Pushing a changed version to `main` starts the single **Build and release** workflow. Manual dispatch on `main` retries the same version after a failed build or missing-secret setup. Published versions are immutable: change `VERSION` to publish another release.

The workflow tests, builds a universal Apple Silicon/Intel app, signs the embedded executable and Studio with Developer ID and hardened runtime, submits them to Apple, staples the app ticket, packages a DMG, notarizes/staples the DMG, and only then publishes a GitHub Release. A draft holds the assets until every upload succeeds. The tag targets the commit that was built. Unsigned previews from the separate CI workflow are explicitly labelled and never uploaded as public releases.

Stable assets are `SafariProfileStudio.dmg`, `SafariProfileStudio.zip`, and `SHA256SUMS.txt`. The website download is:

https://github.com/torbensko/safari-profiles/releases/latest/download/SafariProfileStudio.dmg

Update `RELEASE_NOTES.md` along with `VERSION` for future releases. There is no in-app automatic updater in this version.

## Signing setup

Add these repository Actions secrets, using the same naming as Brainstorm:

| Secret | Value |
| --- | --- |
| `CERTIFICATE_P12` | Base64-encoded Developer ID Application certificate **with its private key**, exported as a password-protected `.p12` |
| `CERTIFICATE_PASSWORD` | Password for that `.p12` |
| `APPLE_ID` | Apple Developer account email |
| `APPLE_ID_PASSWORD` | App-specific password for notarization |
| `APPLE_TEAM_ID` | Developer team ID |

An Apple Development certificate is not sufficient for distribution outside the App Store. GitHub cannot reveal secrets already stored in another repo; add the original values to this one. Upload them directly through GitHub Settings → Secrets and variables → Actions, or use `gh secret set` with stdin from secure local files. Do not commit credentials or put their values in command-line arguments/chat.

The runner imports the certificate into an ephemeral keychain, deletes the P12 after import, and deletes the keychain on completion or failure. Signing/notarization fails closed if credentials are missing. Notarization result JSON is retained as a workflow artifact for diagnosis.

## Local verification

```sh
swift test
./scripts/package.sh --unsigned
```

This makes explicitly unsigned/ad-hoc preview DMG and ZIP files in `dist`. It does not install anything or modify existing launchers. For a signed local release, supply the same Apple credentials through environment variables and a locally installed `CODESIGN_IDENTITY` beginning with `Developer ID Application:`, then run `./scripts/package.sh`.

## Generated launcher identity

Only the distributed Studio and its bundled executable are Developer ID signed/notarized in CI. Studio creates independent local `.app` bundles, fills in each profile and colour, and ad-hoc signs each result. A customer does not receive the developer’s certificate or private key. Those generated apps therefore require their own Accessibility grant, and re-export may require removing and re-adding the current app in Settings even when its switch is enabled. The signed Studio release does not remove this limitation.

The site entry should go live after the first signed release exists. Site deployment remains separate from app releases, as in the reference projects.
