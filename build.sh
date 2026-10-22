#!/bin/bash
set -euo pipefail
source_dir="$(cd "$(dirname "$0")" && pwd)"
build_app="$source_dir/.build/切回上一个应用.app"
sdk="${SDKROOT:-$(xcrun --show-sdk-path)}"
mkdir -p "$build_app/Contents/MacOS"
swiftc -sdk "$sdk" -target "$(uname -m)-apple-macos14.0" -O \
    "$source_dir/Preferences.swift" "$source_dir/SettingsWindow.swift" \
    "$source_dir/TriggerZones.swift" "$source_dir/PreviousAppSwitcher.swift" "$source_dir/main.swift" \
    -o "$build_app/Contents/MacOS/PreviousAppSwitcher"
python3 - "$build_app" <<'PY'
import plistlib, sys
from pathlib import Path
info = {
    'CFBundleExecutable': 'PreviousAppSwitcher',
    'CFBundleIdentifier': 'local.taixu.previous-app-switcher',
    'CFBundleName': '切回上一个应用',
    'CFBundlePackageType': 'APPL',
    'CFBundleShortVersionString': '2.1',
    'CFBundleVersion': '3',
    'LSMinimumSystemVersion': '14.0',
    'LSUIElement': True,
    'NSHighResolutionCapable': True,
}
with (Path(sys.argv[1]) / 'Contents/Info.plist').open('wb') as output:
    plistlib.dump(info, output)
PY
codesign --force --sign - "$build_app"
codesign --verify --strict "$build_app"

echo "构建完成：$build_app"
