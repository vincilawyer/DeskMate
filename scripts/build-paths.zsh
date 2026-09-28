#!/bin/zsh

# Persistent compiler caches live outside the repository and its worktrees.
configure_launch_build_paths() {
    emulate -L zsh
    local project_directory="$1"
    local workspace_key
    workspace_key="$(print -rn -- "${project_directory:A}" | /usr/bin/shasum -a 256 | /usr/bin/cut -c 1-12)"
    export LAUNCH_BUILD_ROOT="${LAUNCH_BUILD_ROOT:-${HOME}/.local/share/codex-build/envs/launch/macos-arm64}"
    export LAUNCH_SCRATCH_DIRECTORY="${LAUNCH_BUILD_ROOT}/workspaces/${workspace_key}"
    export SWIFT_MODULECACHE_PATH="${LAUNCH_BUILD_ROOT}/ModuleCache"
    export CLANG_MODULE_CACHE_PATH="${SWIFT_MODULECACHE_PATH}"
    mkdir -p "${LAUNCH_SCRATCH_DIRECTORY}" "${SWIFT_MODULECACHE_PATH}"
}
