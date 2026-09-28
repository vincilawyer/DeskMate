#!/bin/zsh
set -euo pipefail
SCRIPT_DIRECTORY="${0:A:h}"
PROJECT_DIRECTORY="${SCRIPT_DIRECTORY:h}"
cd "${PROJECT_DIRECTORY}"
source "${SCRIPT_DIRECTORY}/build-paths.zsh"
configure_launch_build_paths "${PROJECT_DIRECTORY}"
source "${SCRIPT_DIRECTORY}/resolve-compatible-sdk.zsh"
export SDKROOT="$(resolve_compatible_macos_sdk "${PROJECT_DIRECTORY}" "${PROJECT_DIRECTORY}/Sources/Launch/Utilities/LaunchText.swift")"
APP_DIRECTORY="${PROJECT_DIRECTORY}/dist/桌伴预览验收.app"
mkdir -p "${APP_DIRECTORY}/Contents/MacOS"
xcrun swiftc -sdk "${SDKROOT}" -module-cache-path "${SWIFT_MODULECACHE_PATH}" \
    -swift-version 5 -parse-as-library \
    Sources/Launch/Models/LaunchPreferences.swift \
    Sources/Launch/Services/LocalPointerContext.swift \
    Sources/Launch/Services/DockPreviewGeometry.swift \
    Sources/Launch/Services/DockDoorAccessibility.swift \
    Sources/Launch/Services/DockPreviewWindowService.swift \
    Sources/Launch/Controllers/DockPreviewController.swift \
    Sources/Launch/Views/DockPreviewContent.swift \
    Sources/Launch/Utilities/LaunchText.swift \
    Tests/DockPreviewVisualFixture.swift \
    -o "${APP_DIRECTORY}/Contents/MacOS/DockPreviewFixture"
cat > "${APP_DIRECTORY}/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>com.vinci.Launch.DockPreviewFixture</string>
<key>CFBundleName</key><string>桌伴预览验收</string>
<key>CFBundleExecutable</key><string>DockPreviewFixture</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>LSUIElement</key><true/>
<key>LSMinimumSystemVersion</key><string>14.0</string>
</dict></plist>
PLIST
codesign --force --sign - "${APP_DIRECTORY}"
print -r -- "Built ${APP_DIRECTORY}"
