import AppKit
import Foundation

private struct DockCheckFailure: Error, CustomStringConvertible { let description: String }

private func requireDock(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() { throw DockCheckFailure(description: message) }
}

@main
private enum DockPreviewChecks {
    static func main() throws {
        try pointerLocalityUsesVisibilityAndAllLocalDisplays()
        try previewsFitEveryDockEdgeAndSmallDisplay()
        try previewSizeScalesThumbnailsAndPanelTogether()
        try quartzConversionHandlesDisplaysAboveAndLeft()
        try preferencesRemainAtomicAndOptIn()
        print("Launch dock-preview checks passed (5/5)")
    }

    private static func previewSizeScalesThumbnailsAndPanelTogether() throws {
        let small = DockPreviewLayout(cardWidth: 180)
        let large = DockPreviewLayout(cardWidth: 320)
        try requireDock(large.thumbnailSize.width > small.thumbnailSize.width
                        && large.thumbnailSize.height > small.thumbnailSize.height,
                        "The size setting must enlarge both thumbnail dimensions")
        let widthScale = large.thumbnailSize.width / small.thumbnailSize.width
        let heightScale = large.thumbnailSize.height / small.thumbnailSize.height
        try requireDock(abs(widthScale - heightScale) < 0.0001,
                        "Thumbnail proportions changed while resizing")
        try requireDock(large.panelSize(windowCount: 1).height > small.panelSize(windowCount: 1).height,
                        "The panel retained a fixed height and clipped a larger thumbnail")
        try requireDock(large.panelSize(windowCount: 4) == large.panelSize(windowCount: 3),
                        "Additional windows must scroll instead of expanding past three cards")
        let bounds = CGRect(x: -480, y: 100, width: 480, height: 420)
        for edge in [DockPreviewEdge.bottom, .left, .right] {
            let frame = DockPreviewGeometry.panelFrame(size: large.panelSize(windowCount: 4),
                iconFrame: CGRect(x: -270, y: 105, width: 60, height: 60), visibleFrame: bounds, edge: edge)
            try requireDock(bounds.contains(frame) && frame.height == large.panelSize(windowCount: 4).height,
                            "The largest preview escaped a small display or lost thumbnail height")
        }
    }

    private static func pointerLocalityUsesVisibilityAndAllLocalDisplays() throws {
        let frames = [
            CGRect(x: 0, y: 0, width: 1440, height: 900),
            CGRect(x: -1920, y: 0, width: 1920, height: 1080),
            CGRect(x: 0, y: 900, width: 1440, height: 900)
        ]
        for point in [CGPoint(x: 700, y: 400), CGPoint(x: -1200, y: 400), CGPoint(x: 700, y: 1200), CGPoint(x: 0, y: 1800)] {
            try requireDock(LocalPointerContext.allowsGlobalGesture(pointer: point, cursorIsVisible: true, screenFrames: frames),
                            "A real local display was treated as a remote Mac")
        }
        try requireDock(!LocalPointerContext.allowsGlobalGesture(pointer: CGPoint(x: 700, y: 400),
                           cursorIsVisible: false, screenFrames: frames),
                        "A stale in-bounds pointer while Universal Control hides the local cursor was allowed")
        for point in [CGPoint(x: 1500, y: 400), CGPoint(x: -2000, y: 400), CGPoint(x: 700, y: -1), CGPoint(x: CGFloat.nan, y: 10)] {
            try requireDock(!LocalPointerContext.allowsGlobalGesture(pointer: point, cursorIsVisible: true, screenFrames: frames),
                            "An out-of-bounds or invalid pointer was allowed")
        }
        try requireDock(!LocalPointerContext.allowsGlobalGesture(pointer: .zero, cursorIsVisible: true, screenFrames: []),
                        "Missing display geometry did not fail closed")
    }

    private static func previewsFitEveryDockEdgeAndSmallDisplay() throws {
        let screen = CGRect(x: -1280, y: 150, width: 1280, height: 800)
        let visible = screen.insetBy(dx: 70, dy: 40)
        let cases: [(DockPreviewEdge, CGRect)] = [
            (.bottom, CGRect(x: -1200, y: 150, width: 60, height: 60)),
            (.left, CGRect(x: -1280, y: 800, width: 60, height: 60)),
            (.right, CGRect(x: -60, y: 190, width: 60, height: 60))
        ]
        for (edge, icon) in cases {
            try requireDock(DockPreviewGeometry.edge(iconFrame: icon, screenFrame: screen) == edge,
                            "Wrong Dock orientation on the secondary display")
            let panel = DockPreviewGeometry.panelFrame(size: CGSize(width: 1800, height: 246),
                                                        iconFrame: icon, visibleFrame: visible, edge: edge)
            try requireDock(visible.contains(panel) && panel.width > 0 && panel.height == 246,
                            "A preview was clipped or escaped a small display")
        }
        let icon = CGRect(x: 500, y: 0, width: 60, height: 60)
        let panel = DockPreviewGeometry.panelFrame(size: CGSize(width: 600, height: 246), iconFrame: icon,
                                                    visibleFrame: CGRect(x: 0, y: 70, width: 1440, height: 800), edge: .bottom)
        let transit = DockPreviewGeometry.transitFrame(iconFrame: icon, panelFrame: panel, edge: .bottom)
        try requireDock(transit.contains(CGPoint(x: icon.midX, y: 65)), "The pointer cannot cross the gap into a bottom-Dock preview")
    }

    private static func quartzConversionHandlesDisplaysAboveAndLeft() throws {
        let rect = DockPreviewGeometry.appKitRect(
            fromQuartz: CGRect(x: -1920, y: -600, width: 60, height: 50), primaryScreenHeight: 900
        )
        try requireDock(rect == CGRect(x: -1920, y: 1450, width: 60, height: 50),
                        "Quartz conversion used the hovered screen height instead of the primary screen")
    }

    private static func preferencesRemainAtomicAndOptIn() throws {
        let legacy = try JSONDecoder().decode(LaunchPreferences.self, from: Data(#"{"rows":6,"columns":8,"showMenuBarIcon":false}"#.utf8))
        try requireDock(!legacy.dockPreviews.enabled && legacy.rows == 6 && !legacy.showMenuBarIcon,
                        "Loading older preferences prompted for permissions or changed existing settings")
        var customized = legacy
        customized.dockPreviews = DockPreviewPreferences(enabled: true, hoverDelay: 0.6, thumbnailWidth: 300)
        let restored = try JSONDecoder().decode(LaunchPreferences.self, from: JSONEncoder().encode(customized))
        try requireDock(restored == customized, "Dock settings did not round-trip with existing launcher preferences")
        let damaged = DockPreviewPreferences(enabled: true, hoverDelay: .nan, thumbnailWidth: .infinity).normalized()
        try requireDock(damaged.enabled && damaged.hoverDelay == 0.35 && damaged.thumbnailWidth == 240,
                        "Invalid sizes or delays reached native panel geometry")
    }
}
