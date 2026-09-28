#!/bin/zsh
set -euo pipefail

SCRIPT_DIRECTORY="${0:A:h}"
PROJECT_DIRECTORY="${SCRIPT_DIRECTORY:h}"
cd "${PROJECT_DIRECTORY}"

source "${SCRIPT_DIRECTORY}/build-paths.zsh"
configure_launch_build_paths "${PROJECT_DIRECTORY}"

source "${SCRIPT_DIRECTORY}/resolve-compatible-sdk.zsh"
export SDKROOT="$(resolve_compatible_macos_sdk \
    "${PROJECT_DIRECTORY}" \
    "${PROJECT_DIRECTORY}/Sources/Launch/Utilities/LaunchText.swift")"

swift build --scratch-path "${LAUNCH_SCRATCH_DIRECTORY}" --disable-sandbox

xcrun swiftc \
    -sdk "${SDKROOT}" \
    -swift-version 5 \
    -parse-as-library \
    Sources/Launch/Models/LaunchPreferences.swift \
    Sources/Launch/Services/ShellIntegrationPolicy.swift \
    Tests/ShellIntegrationChecks.swift \
    -o "${LAUNCH_SCRATCH_DIRECTORY}/ShellIntegrationChecks"

"${LAUNCH_SCRATCH_DIRECTORY}/ShellIntegrationChecks"

xcrun swiftc \
    -sdk "${SDKROOT}" \
    -swift-version 5 \
    -parse-as-library \
    Sources/Launch/Services/LaunchAtLoginManager.swift \
    Sources/Launch/Utilities/LaunchText.swift \
    Tests/LoginItemChecks.swift \
    -o "${LAUNCH_SCRATCH_DIRECTORY}/LoginItemChecks"

"${LAUNCH_SCRATCH_DIRECTORY}/LoginItemChecks"

xcrun swiftc \
    -sdk "${SDKROOT}" \
    -swift-version 5 \
    -parse-as-library \
    Sources/Launch/Services/StableTouchIdentityKey.swift \
    Tests/TouchIdentityChecks.swift \
    -o "${LAUNCH_SCRATCH_DIRECTORY}/TouchIdentityChecks"

"${LAUNCH_SCRATCH_DIRECTORY}/TouchIdentityChecks"

CORE_SOURCES=(
    Sources/Launch/Models/InstalledApplication.swift
    Sources/Launch/Models/LaunchEntry.swift
    Sources/Launch/Models/LaunchFolder.swift
    Sources/Launch/Models/LaunchLayout.swift
    Sources/Launch/Models/LaunchPreferences.swift
    Sources/Launch/Models/LauncherPageInteraction.swift
    Sources/Launch/Models/WeChatCompanionRefresh.swift
    Sources/Launch/Services/AppScanner.swift
    Sources/Launch/Services/ApplicationDirectoryMonitor.swift
    Sources/Launch/Services/LaunchAtLoginManager.swift
    Sources/Launch/Services/LayoutStore.swift
    Sources/Launch/Services/ShellIntegrationPolicy.swift
    Sources/Launch/Services/WeChatDualLaunchService.swift
    Sources/Launch/Services/WeChatCompanionRefreshService.swift
    Sources/Launch/Utilities/LaunchText.swift
    Sources/Launch/Controllers/LauncherModel.swift
)

xcrun swiftc \
    -sdk "${SDKROOT}" \
    -swift-version 5 \
    -parse-as-library \
    "${CORE_SOURCES[@]}" \
    Tests/CoreChecks.swift \
    -o "${LAUNCH_SCRATCH_DIRECTORY}/CoreChecks"

"${LAUNCH_SCRATCH_DIRECTORY}/CoreChecks"

xcrun swiftc \
    -sdk "${SDKROOT}" \
    -swift-version 5 \
    -parse-as-library \
    Sources/Launch/Services/TrackpadGestureManager.swift \
    Sources/Launch/Services/LocalPointerContext.swift \
    Tests/GestureChecks.swift \
    -o "${LAUNCH_SCRATCH_DIRECTORY}/GestureChecks"

"${LAUNCH_SCRATCH_DIRECTORY}/GestureChecks"

xcrun swiftc \
    -sdk "${SDKROOT}" \
    -swift-version 5 \
    -parse-as-library \
    Sources/Launch/Services/MenuBarCoverGeometry.swift \
    Tests/MenuBarCoverChecks.swift \
    -o "${LAUNCH_SCRATCH_DIRECTORY}/MenuBarCoverChecks"

"${LAUNCH_SCRATCH_DIRECTORY}/MenuBarCoverChecks"

xcrun swiftc \
    -sdk "$SDKROOT" \
    -swift-version 5 \
    -parse-as-library \
    Sources/Launch/Models/LaunchPreferences.swift \
    Sources/Launch/Services/LocalPointerContext.swift \
    Sources/Launch/Services/DockPreviewGeometry.swift \
    Tests/DockPreviewChecks.swift \
    -o "${LAUNCH_SCRATCH_DIRECTORY}/DockPreviewChecks"

"${LAUNCH_SCRATCH_DIRECTORY}/DockPreviewChecks"

xcrun swiftc \
    -sdk "$SDKROOT" \
    -swift-version 5 \
    -module-cache-path "$SWIFT_MODULECACHE_PATH" \
    Sources/Launch/ScreenEdge/Geometry.swift \
    Sources/Launch/ScreenEdge/UCGeometry.swift \
    Sources/Launch/ScreenEdge/DisplayMapGeometry.swift \
    Sources/Launch/ScreenEdge/OverlayVisibility.swift \
    Sources/Launch/ScreenEdge/EdgeAppearance.swift \
    Sources/Launch/ScreenEdge/Preferences.swift \
    Tests/ScreenEdgeGeometryChecks.swift \
    -o "${LAUNCH_SCRATCH_DIRECTORY}/ScreenEdgeGeometryChecks"

"${LAUNCH_SCRATCH_DIRECTORY}/ScreenEdgeGeometryChecks"
