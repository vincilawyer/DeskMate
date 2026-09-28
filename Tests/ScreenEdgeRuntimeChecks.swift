import AppKit
import ScreenEdgeBridge

@MainActor
private final class EdgeRuntimeDelegate: NSObject, NSApplicationDelegate {
    private let feature = ScreenEdgeFeatureController(ephemeral: true)

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let model = feature.model
        let overlays = feature.overlays
        guard let screen = model.displays.dropFirst().first ?? model.displays.first else {
            fputs("FAIL: no local display\n", stderr); exit(1)
        }
        precondition(!model.preferences.enabled && overlays.entries.isEmpty, "First launch must be opt-in")
        model.preferences.automatic = false
        model.preferences.automaticUniversalControl = false
        model.preferences.markers = [ManualMarker(displayID: screen.id, edge: .right)]
        model.preferences.enabled = true
        precondition(overlays.entries.count == 1)
        let entry = overlays.entries[0]
        precondition(entry.window.frame == entry.frame && screen.frame.contains(entry.frame))
        precondition(entry.window.screen != NSScreen.screens.first || NSScreen.screens.count == 1,
                     "Acceptance overlay must be on external display")
        precondition(entry.window.ignoresMouseEvents && !entry.window.canBecomeKey && !entry.window.canBecomeMain)
        precondition(entry.window.collectionBehavior.contains(.canJoinAllSpaces) && entry.window.collectionBehavior.contains(.fullScreenAuxiliary))
        model.preferences.displayMode = .pointerScreen
        let point = CGPoint(x: screen.frame.midX, y: screen.frame.midY)
        overlays.updateVisibility(pointer: PointerSnapshot(location: point, isVisible: true))
        precondition(overlays.entries.allSatisfy { $0.window.alphaValue == 1 })
        overlays.updateVisibility(pointer: PointerSnapshot(location: point, isVisible: false))
        precondition(overlays.entries.allSatisfy { $0.window.alphaValue == 0 })
        overlays.updateVisibility(pointer: PointerSnapshot(location: point, isVisible: nil))
        precondition(overlays.entries.allSatisfy { $0.window.alphaValue == 0 })
        model.preferences.displayMode = .nearEdges
        overlays.updateProximity(at: point)
        precondition(overlays.entries.allSatisfy { $0.window.alphaValue == 0 })
        model.setScreenLocked(true)
        precondition(overlays.usesLockScreenSpace, "Temporary edge-only lock space must attach")
        precondition(overlays.entries.allSatisfy { $0.window.canBecomeVisibleWithoutLogin })
        overlays.updateProximity(at: point)
        precondition(overlays.entries.allSatisfy { $0.window.alphaValue == 1 })
        model.preferences.showWhenLocked = false
        precondition(overlays.entries.isEmpty && !overlays.usesLockScreenSpace)
        model.setScreenLocked(false)
        precondition(overlays.entries.count == 1 && !overlays.usesLockScreenSpace)
        model.preferences.enabled = false
        precondition(overlays.entries.isEmpty)
        print("PASS: opt-in, external overlay bounds, click-through, nonactivation, Spaces, pointer visibility, lock simulation, disable teardown")

        // Read the real service, but never print device identities or change system state.
        SEReadUniversalControlEdges { [weak self] values, error in
            Task { @MainActor in
                guard let self else { return }
                model.applyUniversalControlResponse(values, error: error)
                print("UC query: raw=\(values?.count ?? 0) mapped=\(model.universalControlPortals.count) error=\(error != nil)")
                model.preferences.markers = []
                model.preferences.enabled = true
                model.preferences.automaticUniversalControl = true
                guard let q = screen.quartzFrame else { preconditionFailure("Missing Quartz geometry") }
                let fixture: [[AnyHashable: Any]] = [["id": ["display": screen.id, "device": "synthetic-fixture"],
                    "edge": "right", "rect": [q.maxX - 1, q.minY + q.height * 0.25, 1, q.height * 0.5]]]
                model.applyUniversalControlResponse(fixture, error: nil)
                precondition(overlays.entries.count == 1 && overlays.entries[0].portal.universalControl)
                model.applyUniversalControlResponse([], error: nil)
                precondition(model.universalControlPortals.isEmpty && overlays.entries.isEmpty)
                model.applyUniversalControlResponse(fixture, error: nil)
                model.applyUniversalControlResponse(nil, error: "fixture failure")
                precondition(model.universalControlPortals.isEmpty && overlays.entries.isEmpty)
                model.applyUniversalControlResponse(fixture, error: nil)
                model.preferences.automaticUniversalControl = false
                precondition(model.universalControlPortals.isEmpty && overlays.entries.isEmpty)
                self.feature.stop()
                precondition(overlays.entries.isEmpty)
                print("PASS: UC empty/error response clears automatic edges; feature stop removes owned windows")
                NSApp.terminate(nil)
            }
        }
    }
}

@main
private enum ScreenEdgeRuntimeChecks {
    @MainActor static func main() {
        let app = NSApplication.shared
        let delegate = EdgeRuntimeDelegate()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}
