#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION="$(tr -d '\n' < VERSION)"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo 'VERSION must be major.minor.patch' >&2; exit 1; }
SIGNING_IDENTITY="${CODESIGN_IDENTITY:--}"
BUILD_ARGS=(-c release)
if [[ "${UNIVERSAL:-0}" == 1 ]]; then
  BUILD_ARGS+=(--arch arm64 --arch x86_64)
fi
swift build "${BUILD_ARGS[@]}"
BIN="$(swift build "${BUILD_ARGS[@]}" --show-bin-path)"
APP="$PWD/dist/Safari Profile Studio.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN/ProfileStudio" "$APP/Contents/MacOS/ProfileStudio"
cp "$BIN/ProfileLauncher" "$APP/Contents/Resources/ProfileLauncher"
export APP VERSION
python3 - <<'PY'
import os, plistlib
from pathlib import Path
plist = dict(CFBundleIdentifier='local.safari-profile-launcher.studio',
    CFBundleName='Safari Profile Studio', CFBundleDisplayName='Safari Profile Studio',
    CFBundleExecutable='ProfileStudio', CFBundlePackageType='APPL',
    CFBundleVersion=os.environ['VERSION'], CFBundleShortVersionString=os.environ['VERSION'],
    CFBundleIconFile='Studio', LSMinimumSystemVersion='13.0', NSHighResolutionCapable=True)
with (Path(os.environ['APP'])/'Contents/Info.plist').open('wb') as f:
    plistlib.dump(plist, f)
PY
"$BIN/ProfileStudio" --write-studio-icon "$APP/Contents/Resources/Studio.icns"
SIGN_ARGS=(--force --sign "$SIGNING_IDENTITY")
if [[ "$SIGNING_IDENTITY" != '-' ]]; then SIGN_ARGS+=(--options runtime --timestamp); fi
codesign "${SIGN_ARGS[@]}" "$APP/Contents/Resources/ProfileLauncher"
codesign "${SIGN_ARGS[@]}" "$APP"
codesign --verify --deep --strict "$APP"
echo "$APP"
