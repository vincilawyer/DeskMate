// SPDX-License-Identifier: MIT
// Adapted from vincilawyer/ScreenEdge, commit 7e418d6352b5a839bd01f4b723f54f3f4d5d9e1c.
// Copyright (c) 2026 ScreenEdge contributors. See LICENSES/ScreenEdge-MIT.txt.
import AppKit

enum PointerStateReader {
    static var isAvailable: Bool { LocalPointerContext.isCursorVisibilityAvailable }
    @MainActor static func read() -> PointerSnapshot {
        PointerSnapshot(location: NSEvent.mouseLocation, isVisible: LocalPointerContext.cursorIsVisible)
    }
}
