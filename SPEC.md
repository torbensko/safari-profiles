# Safari Profile Launcher — implementation and hand-off specification

## User goal

Build a personal-use native macOS utility that exports three or four independently coloured Dock launchers. Clicking a launcher must open a new window in its configured profile in the real Safari application.

The user does not want a paid third-party dependency, a browser wrapper, an embedded WebView, or a replacement browser.

## Repository location and current state

The requested location on the user's Mac is:

```text
~/repos/safari-profile-launcher
```

The current chat only has access to a separate Linux workspace. Its partial project is located at:

```text
/mnt/data/safari-profile-launcher
```

Nothing has been created in the user's Mac `~/repos` directory by this session. Do not confuse these two filesystems.

At the time this specification was written, the workspace contained `Package.swift`, core Swift source files under `Sources/LauncherCore`, and corresponding test files under `Tests/LauncherCoreTests`. Directories for the macOS components also exist. The full application, export workflow, and macOS end-to-end behaviour are not complete or verified. Inspect the actual files before continuing; do not infer implementation from directory names or earlier progress messages.

## Product requirements

### Configuration application

Provide a small native application with:

- A list of launcher definitions.
- Add, edit, and delete controls for definitions.
- An exact Safari profile name for each definition.
- A user-editable launcher display name, such as `Safari — Work`.
- A colour picker and preview for each launcher's icon.
- Export of a selected launcher, with batch export desirable.
- Clear setup and permission instructions.

Persist definitions locally. No accounts, server, telemetry, subscription, or third-party runtime service are required.

Do not silently treat deleting a definition as permission to delete an already exported application.

### Exported Dock launchers

Each exported launcher must be a real `.app` bundle with:

- Its own stable, unique bundle identifier.
- Its own display name and persistent coloured application icon.
- A bundled definition identifying the requested Safari profile.
- A copy of the common lightweight launcher executable.
- No dependency on the configuration application remaining open or installed.

The same executable should be reused across exports; this is one codebase, not separate implementations per profile.

The user can drag the exported applications into the Dock. The intended default export directory is `~/Applications`, subject to the user's selection and filesystem permissions. Do not change the Dock automatically in the first version.

### Launch behaviour

On launch:

1. Validate the bundled configuration.
2. Check the permissions needed by the automation implementation.
3. Start or activate the real Safari application.
4. Wait for Safari's relevant UI to become available, with a bounded timeout.
5. Locate the exact profile-specific new-window action.
6. Invoke that action once, then allow Safari to become frontmost.
7. Exit the launcher after success.

Every successful invocation should request a **new** window, rather than merely focus an existing one. Do not open an intermediate default-profile window as a substitute for selecting the intended profile. Safari's own startup/session-restoration behaviour may need separate handling and documentation.

Never silently fall back to another profile, Safari's generic new-window action, or a private window. A missing or ambiguous match must produce a useful error.

Do not close, repurpose, or alter existing Safari windows to achieve the requested launch.

### Icons and colour changes

Use a consistent, recognisable compass-style icon design with a different user-selected colour for each launcher. A bundled vector or programmatically rendered design is suitable; do not require image generation or network access at runtime.

The colour must be part of the exported application's persistent icon, not merely a temporary running-Dock-icon change. The icon must remain coloured while the launcher is not running.

Preserve launcher identity across edits and re-exports. Support changing a launcher's colour later. Verify actual Finder/Dock caching behaviour on macOS and document any necessary refresh or re-pin step honestly.

## Expected limitation

The coloured icons are launch buttons. Safari remains the owner of the browser windows. This project does not promise independently grouped Safari windows, separate Command–Tab identities per profile, or running indicators that reflect each profile's open windows.

Explain this in the README and configuration UI without presenting it as a defect in exporting the launchers.

## Proposed technical structure

Use Swift with a small native AppKit and/or SwiftUI interface. Prefer no third-party packages unless a concrete need is demonstrated.

Suggested module boundaries, matching the initial scaffold:

- `LauncherCore`: definition models, validation, deterministic identifiers, safe filenames, and pure menu-title matching logic.
- `MacSupport`: macOS automation, permission checks, icon generation, and bundle export support.
- `ProfileStudio`: the native configuration application.
- `ProfileLauncher`: the short-lived exported launcher executable.

Keep pure logic platform-independent where practical so it can be tested outside macOS. macOS integration still requires testing on a Mac.

### Safari automation

Investigate and verify Safari's current public automation surface on the target Mac before finalising the implementation. Do not assume a documented profile-specific command-line flag or AppleScript API exists.

The proposed initial implementation uses macOS Accessibility to inspect Safari's menu hierarchy and invoke its own profile-specific new-window action. Prefer semantic menu traversal and action invocation over coordinate clicks, simulated typing, or arbitrary fixed sleeps.

Read the actual menu hierarchy on supported Safari versions. Profile commands may be nested; do not assume a particular menu path without verifying it. Treat localisation explicitly: either support tested languages or clearly declare the initial language limitation.

Use exact profile-name matching. `Work` must not match `Workshop`. Handle spaces, punctuation, apostrophes, Unicode, and similarly named profiles without interpolation into executable shell or script text.

Automatic profile discovery is optional for the first version. Manual exact-name entry is acceptable, provided runtime validation is clear. Do not modify Safari profile storage or rely on undocumented database schemas as a prerequisite.

### Permissions, identity, and distribution

Use the minimum permissions required by the chosen implementation. Document which exported app needs permission and how to grant or repair it. Avoid repeatedly prompting after an explicit denial.

Because the launchers are independently exported applications, verify permission attribution and persistence on macOS. Do not promise that granting permission to the builder automatically covers exported apps.

Account for signing and identity before declaring re-export reliable. If configuration or icons change inside a signed bundle, signing must be performed after the final bundle contents are written. Document personal-use signing and any permission reapproval limitations. Do not claim ad-hoc signing guarantees permission persistence across rebuilds.

No always-running helper, login item, browser extension, or background service is required for the first version.

## Failure handling and safety

Provide actionable errors for invalid configuration, Safari not being available, missing Accessibility permission, unavailable menus, missing/ambiguous profile commands, launch timeouts, and export failures.

Use bounded retries and distinguish transient startup state from a missing profile. Avoid duplicate menu invocation when an operation times out after an action may already have been dispatched.

Export into a staging location and replace the destination only after validation. Confirm before overwriting an existing application. Clean up failed staging bundles without deleting unrelated files.

Sanitise generated filenames, preserve the original profile name separately, and prevent path traversal. Do not use profile or launcher names as shell commands or bundle identifiers without safe transformation.

Do not kill Safari or restart the Dock automatically. Do not modify Safari's application bundle, preferences, profile databases, or browser data.

## Acceptance criteria

1. The user can create four definitions with different names and colours and export four valid applications.
2. All four apps can be pinned to the Dock and retain their distinct icons while closed.
3. A launcher invokes exactly its configured profile's new-window command while Safari is already running.
4. Launching while Safari is closed works or reports a useful error without selecting an unintended profile; separately document any session restoration windows Safari opens itself.
5. Repeated sequential clicks request additional windows in the intended profile.
6. `Work` and `Workshop` remain distinct; punctuation and Unicode names are handled safely.
7. A renamed or deleted profile causes an error, not a wrong-profile fallback.
8. Missing or revoked permission produces usable guidance without a crash or endless retry.
9. Exported launchers work while the builder is closed and do not require a permanently running helper.
10. Changing an icon colour and re-exporting has a tested, documented path to updating its Dock appearance.
11. Existing Safari windows and data are left intact.
12. The project includes reproducible build instructions and clearly identifies what has and has not been tested on macOS.

## Testing and delivery

Extend the core unit tests for definition validation, identifier stability, safe filenames, exact matching, Unicode, and collision cases.

On a Mac, build the actual application bundles and test both Safari-running and Safari-closed paths, permission grant/denial/revocation, multiple profiles, similar names, missing profiles, and colour changes. Test rapid/repeated invocations and handle or explicitly document overlapping launch attempts.

Deliver the source project, build/export scripts, a README, this specification, and a manual macOS test checklist. Record the tested macOS and Safari versions.

A successful Linux unit-test run is not evidence that the macOS targets compile or that Safari automation works. State the verification boundary explicitly.

## Instructions for the next coding session

Continue in `~/repos/safari-profile-launcher` on the user's Mac. If that directory already exists, inspect it before making changes and do not overwrite unrelated work. If starting from this hand-off file alone, create the project there and implement the requirements above.

First inspect the scaffold and establish a working macOS build. Next verify the Safari profile command and permissions on the installed Safari version, then complete the builder, persistent icons, and self-contained export workflow. Keep the first version focused on reliable one-click launch behaviour rather than optional browser-management features.
