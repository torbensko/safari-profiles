# Verification record

Target: macOS 27.2 (26B5112a), Safari 27.2, Apple Silicon, Swift 6.4. Tested on 16 October 2026 (Australia/Sydney).

## Verified

- Debug and release macOS targets compile; Studio and exported launchers are ad-hoc signed.
- Native Studio opens with the four requested definitions and visibly distinct compass icons.
- Exported Personal, VPT, Blint, and Accelevate apps exist in `~/Applications`; all final signatures verified. Native batch export/replacement was exercised successfully for all four.
- Finder visibly displays all four persistent coloured icons while the launchers are closed.
- Safari’s live File → New Window menu contains exact profile actions, including the four requested profiles.
- Installed Safari scripting dictionary contains no profile-specific command.
- Six automated tests pass, including staged export/replacement, colour resource changes, collision handling, failure cleanup preserving the prior app, and store corruption handling.
- Core tests cover stable IDs, encoding, exact matching, missing/ambiguous matches, punctuation, Unicode, case, invalid values, traversal-safe filenames, and sanitisation collisions.
- First launch without Accessibility access shows actionable guidance and an Open Permission Settings button without sending a Safari action.

## Manual acceptance checklist

Only checked entries are verified end-to-end. Pending entries are not implied by successful compilation or unit tests.

- [x] Create four definitions and export four signed bundles with distinct persistent ICNS resources.
- [x] Open Studio and inspect icon previews, names, exact profile entry, colour picker, and export controls.
- [x] Inspect real Safari profile menu hierarchy, including nesting.
- [x] Missing permission produces a useful error rather than a crash/retry loop.
- [x] Each exported app has its own enabled Device Control and Data Access entry. Personal initially still failed despite the enabled switch; removing its old entry and adding the current app fixed it after Touch ID authentication. VPT, Blint, and Accelevate already had working grants and did not need replacement.
- [x] Launch all four with Safari running and observe the matching Start Page title and toolbar Profile identifier: Personal, VPT, Blint, Accelevate.
- [ ] Repeat the full matrix with Studio closed.
- [x] Repeat Personal and VPT launches: both produced distinct new Safari window UUIDs in the correct profile.
- [ ] Verify exact window-count increments and repeat launches for Blint/Accelevate.
- [ ] Pin all four exports and inspect icons while the launchers are not running.
- [ ] Change a colour, re-export to the same path, verify identity and Dock/Finder appearance; if stale, remove/re-pin and record the observed result.
- [x] Permission reapproval limitation observed: an enabled Personal entry did not suffice after re-export; remove/re-add repaired it. No app bundles were rebuilt or re-signed after this repair.
- [ ] With Safari safely quit by the user, launch each and record Safari's own restoration/startup behaviour separately from the requested profile window.
- [ ] Revoke/deny permission and retry; restore access and retry.
- [ ] Configure a nonexistent profile: error, no other-profile fallback.
- [ ] On a disposable Safari setup, test Work/Workshop, apostrophes, Unicode, duplicate/renamed/deleted profiles.
- [ ] Click different launchers concurrently and the same launcher rapidly; verify no wrong-profile action. macOS may coalesce repeated open events.
- [ ] Test a blocking Safari dialog and a startup timeout.
- [ ] Confirm existing Safari windows remain intact throughout.

No Safari profiles or browser data were changed to run these tests. Safari was not forcibly quit and the Dock was not restarted or programmatically rewritten.
