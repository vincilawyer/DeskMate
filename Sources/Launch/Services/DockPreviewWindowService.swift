import AppKit
import ApplicationServices
import ScreenCaptureKit

struct DockPreviewWindow: Identifiable {
    let id: CGWindowID
    let title: String
    let isMinimized: Bool
    let image: CGImage?
}

struct DockPreviewSnapshot {
    let windows: [DockPreviewWindow]
    let captureUnavailable: Bool
}

/// AX work and window capture never run on the launcher's UI actor.
actor DockPreviewWindowService {
    private var elements: [CGWindowID: AXUIElement] = [:]
    private var elementPID: pid_t?

    func hoveredApplication(
        dockPID: pid_t, quartzPoint: CGPoint, applications: [DockRunningApplication]
    ) -> DockHoverTarget? {
        DockDoorAccessibility.hoveredApplication(
            dockPID: dockPID, quartzPoint: quartzPoint, applications: applications
        )
    }

    func snapshot(for target: DockHoverTarget, thumbnailWidth: Double) async -> DockPreviewSnapshot {
        let appElement = AXUIElementCreateApplication(target.pid)
        AXUIElementSetMessagingTimeout(appElement, 0.15)
        guard AXIsProcessTrusted(),
              let axWindows: [AXUIElement] = DockDoorAccessibility.attribute(appElement, kAXWindowsAttribute) else {
            return DockPreviewSnapshot(windows: [], captureUnavailable: false)
        }
        var metadata: [(CGWindowID, String, Bool)] = []
        var nextElements: [CGWindowID: AXUIElement] = [:]
        for element in axWindows {
            guard !Task.isCancelled else { break }
            AXUIElementSetMessagingTimeout(element, 0.15)
            let subrole: String? = DockDoorAccessibility.attribute(element, kAXSubroleAttribute)
            guard subrole == kAXStandardWindowSubrole || subrole == kAXDialogSubrole,
                  let rect = DockDoorAccessibility.frame(element), rect.width >= 80, rect.height >= 60,
                  let id = DockDoorAccessibility.windowID(element), nextElements[id] == nil else { continue }
            let title: String = DockDoorAccessibility.attribute(element, kAXTitleAttribute) ?? target.name
            let minimized: Bool = DockDoorAccessibility.attribute(element, kAXMinimizedAttribute) ?? false
            metadata.append((id, title.isEmpty ? target.name : title, minimized))
            nextElements[id] = element
        }
        elements = nextElements
        elementPID = target.pid

        // Minimized and protected windows stay selectable even when macOS does
        // not expose an image. Images exist only in memory for the current app.
        let mayCapture = CGPreflightScreenCaptureAccess() && !Task.isCancelled
        let content = mayCapture && !metadata.isEmpty ? await shareableContent() : nil
        let shareable = Dictionary((content?.windows ?? []).map { ($0.windowID, $0) }, uniquingKeysWith: { a, _ in a })
        let candidates = metadata.compactMap { id, _, minimized -> SCWindow? in
            guard !minimized, let window = shareable[id],
                  window.owningApplication?.processID == target.pid else { return nil }
            return window
        }
        let images = await withTaskGroup(of: (CGWindowID, CGImage?).self) { group in
            var iterator = candidates.makeIterator()
            var captured: [CGWindowID: CGImage] = [:]
            func enqueue(_ window: SCWindow) {
                group.addTask { [self] in
                    guard !Task.isCancelled else { return (window.windowID, nil) }
                    return (window.windowID, await capture(window, width: thumbnailWidth))
                }
            }
            for _ in 0..<4 { if let window = iterator.next() { enqueue(window) } }
            for await (id, image) in group {
                if let image { captured[id] = image }
                if !Task.isCancelled, let window = iterator.next() { enqueue(window) }
            }
            return captured
        }
        let windows = metadata.map {
            DockPreviewWindow(id: $0.0, title: $0.1, isMinimized: $0.2, image: images[$0.0])
        }
        return DockPreviewSnapshot(windows: windows, captureUnavailable: !mayCapture || (content == nil && !metadata.isEmpty))
    }

    func restoreAndRaise(windowID: CGWindowID, pid: pid_t) -> Bool {
        guard AXIsProcessTrusted(), pid == elementPID, let element = elements[windowID] else { return false }
        return Self.restoreAndRaise(element, pid: pid)
    }

    private static func restoreAndRaise(_ element: AXUIElement, pid: pid_t) -> Bool {
        if pid == ProcessInfo.processInfo.processIdentifier && !Thread.isMainThread {
            return DispatchQueue.main.sync { restoreAndRaise(element, pid: pid) }
        }
        AXUIElementSetAttributeValue(element, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
        AXUIElementSetAttributeValue(element, kAXMainAttribute as CFString, kCFBooleanTrue)
        AXUIElementSetAttributeValue(
            AXUIElementCreateApplication(pid), kAXFocusedWindowAttribute as CFString, element
        )
        return AXUIElementPerformAction(element, kAXRaiseAction as CFString) == .success
    }

    func clear() {
        elements.removeAll()
        elementPID = nil
    }

    private func shareableContent() async -> SCShareableContent? {
        await withCheckedContinuation { continuation in
            let completion = DockCaptureCompletion<SCShareableContent>(continuation)
            SCShareableContent.getExcludingDesktopWindows(true, onScreenWindowsOnly: false) { content, _ in
                completion.finish(content)
            }
            completion.expire(after: 2)
        }
    }

    private func capture(_ window: SCWindow, width: Double) async -> CGImage? {
        let configuration = SCStreamConfiguration()
        configuration.width = Int(width * 2)
        configuration.height = Int(width * 2 * min(1.2, max(0.25, window.frame.height / max(1, window.frame.width))))
        configuration.showsCursor = false
        configuration.scalesToFit = true
        configuration.captureResolution = .nominal
        return await withCheckedContinuation { continuation in
            let completion = DockCaptureCompletion<CGImage>(continuation)
            SCScreenshotManager.captureImage(
                contentFilter: SCContentFilter(desktopIndependentWindow: window),
                configuration: configuration
            ) { image, _ in completion.finish(image) }
            completion.expire(after: 1)
        }
    }
}

/// Framework callbacks are not necessarily cancellation-aware. Late callbacks
/// may resolve once, but cannot stall a hover task or resume it twice.
private final class DockCaptureCompletion<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Value?, Never>?

    init(_ continuation: CheckedContinuation<Value?, Never>) { self.continuation = continuation }

    func finish(_ value: Value?) {
        lock.lock()
        let pending = continuation
        continuation = nil
        lock.unlock()
        pending?.resume(returning: value)
    }

    func expire(after interval: TimeInterval) {
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + interval) { [self] in
            finish(nil)
        }
    }
}
