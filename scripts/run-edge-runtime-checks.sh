#!/bin/zsh
set -euo pipefail
SCRIPT_DIRECTORY="${0:A:h}"
PROJECT_DIRECTORY="${SCRIPT_DIRECTORY:h}"
cd "$PROJECT_DIRECTORY"
source "$SCRIPT_DIRECTORY/build-paths.zsh"
configure_launch_build_paths "$PROJECT_DIRECTORY"
source "$SCRIPT_DIRECTORY/resolve-compatible-sdk.zsh"
export SDKROOT="$(resolve_compatible_macos_sdk "$PROJECT_DIRECTORY" "$PROJECT_DIRECTORY/Sources/Launch/Utilities/LaunchText.swift")"
BRIDGE_INCLUDE="$PROJECT_DIRECTORY/Sources/ScreenEdgeBridge/include"
xcrun clang -fobjc-arc -isysroot "$SDKROOT" -target arm64-apple-macosx14.0 \
    -I "$BRIDGE_INCLUDE" -c Sources/ScreenEdgeBridge/UCBridge.m -o "$LAUNCH_SCRATCH_DIRECTORY/EdgeRuntimeBridge.o"
xcrun swiftc -sdk "$SDKROOT" -swift-version 5 -parse-as-library \
    -module-cache-path "$SWIFT_MODULECACHE_PATH" -I "$BRIDGE_INCLUDE" \
    Sources/Launch/ScreenEdge/*.swift Sources/Launch/Services/LocalPointerContext.swift \
    Tests/ScreenEdgeRuntimeChecks.swift "$LAUNCH_SCRATCH_DIRECTORY/EdgeRuntimeBridge.o" \
    -o "$LAUNCH_SCRATCH_DIRECTORY/ScreenEdgeRuntimeChecks"
"$LAUNCH_SCRATCH_DIRECTORY/ScreenEdgeRuntimeChecks"
