import AppKit
import Darwin

enum LocalPointerContext {
    private typealias CursorVisibility = @convention(c) () -> UInt32
    private static let cursorVisibility: CursorVisibility? = {
        // The C entry point is still exported on the verified systems, but is
        // unavailable to Swift in current SDKs. Never assume visibility if it
        // disappears; raw gestures must fail closed during a remote handoff.
        guard let address = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "CGCursorIsVisible") else { return nil }
        return unsafeBitCast(address, to: CursorVisibility.self)
    }()
    static var isCursorVisibilityAvailable: Bool { cursorVisibility != nil }
    static var cursorIsVisible: Bool? { cursorVisibility.map { $0() != 0 } }
    static func allowsGlobalGesture(
        pointer: CGPoint,
        cursorIsVisible: Bool,
        screenFrames: [CGRect]
    ) -> Bool {
        guard cursorIsVisible, pointer.x.isFinite, pointer.y.isFinite else { return false }
        return screenFrames.contains { frame in
            !frame.isEmpty && pointer.x >= frame.minX && pointer.x < frame.maxX
                && pointer.y > frame.minY && pointer.y <= frame.maxY
        }
    }

    @MainActor
    static var allowsGlobalGesture: Bool {
        // Universal Control can leave a stale, in-bounds mouse position on the
        // source Mac. Visibility must be checked as well as local geometry.
        allowsGlobalGesture(
            pointer: NSEvent.mouseLocation,
            cursorIsVisible: cursorIsVisible == true,
            screenFrames: NSScreen.screens.map(\.frame)
        )
    }
}
