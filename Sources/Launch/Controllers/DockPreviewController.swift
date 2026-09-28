import AppKit
import ApplicationServices
import Combine
import SwiftUI

@MainActor
final class DockPreviewController: ObservableObject {
    @Published private(set) var accessibilityGranted = false
    @Published private(set) var screenRecordingGranted = false

    var isSuspended: () -> Bool = { false }
    private let service = DockPreviewWindowService()
    private let presentation = DockPreviewPresentation()
    private var preferences = DockPreviewPreferences.default
    private var timer: Timer?
    private var observers: [NSObjectProtocol] = []
    private var keyboardMonitor: Any?
    private var globalDismissMonitor: Any?
    private var queryTask: Task<Void, Never>?
    private var captureTask: Task<Void, Never>?
    private var generation: UInt64 = 0
    private var target: DockHoverTarget?
    private var hoveredSince: TimeInterval = 0
    private var lastInside: TimeInterval = 0
    private var lastRefresh: TimeInterval = 0
    private var lastPermissionCheck: TimeInterval = 0
    private var suppressedIconFrame: CGRect?
    private var panel: DockPreviewPanel?
    private var iconFrame = CGRect.zero
    private var transitFrame = CGRect.zero
    private var activationInFlight = false

    func update(_ preferences: DockPreviewPreferences) {
        let normalized = preferences.normalized()
        guard self.preferences != normalized || (normalized.enabled && timer == nil) else { return }
        self.preferences = normalized
        dismiss()
        timer?.invalidate()
        timer = nil
        refreshPermissions()
        guard normalized.enabled else {
            removeObservers()
            return
        }
        let timer = Timer(timeInterval: 0.10, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        timer.tolerance = 0.025
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        installObservers()
    }

    func refreshPermissions() {
        let ax = AXIsProcessTrusted()
        let screen = CGPreflightScreenCaptureAccess()
        if accessibilityGranted != ax { accessibilityGranted = ax }
        if screenRecordingGranted != screen { screenRecordingGranted = screen }
        if !ax { dismiss() }
    }

    func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        openPrivacyPane("Privacy_Accessibility")
    }

    func requestScreenRecording() {
        _ = CGRequestScreenCaptureAccess()
        openPrivacyPane("Privacy_ScreenCapture")
    }

    private func openPrivacyPane(_ pane: String) {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") else { return }
        NSWorkspace.shared.open(url)
    }

    func stop() {
        preferences.enabled = false
        timer?.invalidate()
        timer = nil
        dismiss()
        removeObservers()
    }

    func dismiss() {
        if let globalDismissMonitor { NSEvent.removeMonitor(globalDismissMonitor) }
        globalDismissMonitor = nil
        generation &+= 1
        queryTask?.cancel()
        queryTask = nil
        captureTask?.cancel()
        captureTask = nil
        target = nil
        hoveredSince = 0
        panel?.orderOut(nil)
        presentation.windows = []
        presentation.isLoading = false
        Task { await service.clear() }
    }

    private func tick() {
        let now = ProcessInfo.processInfo.systemUptime
        if now - lastPermissionCheck >= 2 {
            lastPermissionCheck = now
            refreshPermissions()
        }
        guard preferences.enabled, accessibilityGranted, !isSuspended(),
              LocalPointerContext.allowsGlobalGesture else {
            if target != nil || panel?.isVisible == true { dismiss() }
            return
        }
        guard !activationInFlight else { return }
        let pointer = NSEvent.mouseLocation
        if let suppressedIconFrame, !suppressedIconFrame.contains(pointer) {
            self.suppressedIconFrame = nil
        }
        if let panel, panel.isVisible,
           panel.frame.insetBy(dx: -3, dy: -3).contains(pointer) || transitFrame.contains(pointer) {
            lastInside = now
            if NSEvent.pressedMouseButtons == 0 { refreshIfNeeded(now: now) }
            return
        }
        if NSEvent.pressedMouseButtons != 0 {
            if target != nil {
                suppressedIconFrame = iconFrame.insetBy(dx: -5, dy: -5)
                dismiss()
            }
            return
        }
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(pointer) }),
              nearDockEdge(pointer, frame: screen.frame) else {
            if target != nil, now - lastInside > 0.22 { dismiss() }
            return
        }
        if queryTask == nil { queryDock(at: pointer) }
        if let target, iconFrame.insetBy(dx: -5, dy: -5).contains(pointer) {
            lastInside = now
            if panel?.isVisible != true, now - hoveredSince >= preferences.hoverDelay {
                present(target)
            }
            refreshIfNeeded(now: now)
        } else if target != nil, now - lastInside > 0.22 {
            dismiss()
        }
    }

    private func nearDockEdge(_ pointer: CGPoint, frame: CGRect) -> Bool {
        pointer.y < frame.minY + 180 || pointer.x < frame.minX + 180 || pointer.x > frame.maxX - 180
    }

    private func queryDock(at point: CGPoint) {
        guard let dock = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first,
              let primaryHeight = NSScreen.screens.first?.frame.height else { return }
        let apps = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
            .map { DockRunningApplication(pid: $0.processIdentifier, bundleIdentifier: $0.bundleIdentifier,
                                          bundleURL: $0.bundleURL, name: $0.localizedName ?? "") }
        let expected = generation
        let dockPID = dock.processIdentifier
        queryTask = Task { [weak self, service] in
            let found = await service.hoveredApplication(
                dockPID: dockPID,
                quartzPoint: CGPoint(x: point.x, y: primaryHeight - point.y),
                applications: apps
            )
            guard !Task.isCancelled, let self, self.generation == expected else { return }
            self.queryTask = nil
            guard let found else {
                if self.target != nil, ProcessInfo.processInfo.systemUptime - self.lastInside > 0.22 {
                    self.dismiss()
                }
                return
            }
            let frame = DockPreviewGeometry.appKitRect(fromQuartz: found.iconFrame, primaryScreenHeight: primaryHeight)
            guard frame.insetBy(dx: -3, dy: -3).contains(NSEvent.mouseLocation),
                  self.suppressedIconFrame == nil, LocalPointerContext.allowsGlobalGesture,
                  !self.isSuspended(), NSEvent.pressedMouseButtons == 0 else { return }
            if self.target?.pid != found.pid {
                self.dismiss()
                self.target = found
                self.hoveredSince = ProcessInfo.processInfo.systemUptime
            } else {
                self.target = found
            }
            self.iconFrame = frame
            self.lastInside = ProcessInfo.processInfo.systemUptime
        }
    }

    private func present(_ target: DockHoverTarget) {
        guard !isSuspended(), LocalPointerContext.allowsGlobalGesture else { return }
        presentation.name = target.name
        presentation.icon = NSWorkspace.shared.icon(forFile: target.bundleURL.path)
        presentation.isLoading = true
        presentation.captureUnavailable = !screenRecordingGranted
        presentation.activate = { [weak self] id in self?.activate(windowID: id) }
        presentation.dismiss = { [weak self] in self?.dismissForUserIntent() }
        if panel == nil {
            let panel = DockPreviewPanel()
            panel.contentView = NSHostingView(rootView: DockPreviewContent(presentation: presentation, width: preferences.thumbnailWidth))
            self.panel = panel
        } else {
            panel?.contentView = NSHostingView(rootView: DockPreviewContent(presentation: presentation, width: preferences.thumbnailWidth))
        }
        positionPanel()
        NSApp.unhideWithoutActivation()
        panel?.orderFrontRegardless()
        // Key monitoring is only installed while a preview is visible and the
        // already-required Accessibility permission is available. No key text
        // is collected or stored, and no input events are consumed globally.
        globalDismissMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 {
                Task { @MainActor in self?.dismissForUserIntent() }
            }
        }
        lastRefresh = 0
        refreshIfNeeded(now: ProcessInfo.processInfo.systemUptime)
    }

    private func positionPanel() {
        guard let panel,
              let screen = NSScreen.screens.first(where: { $0.frame.contains(CGPoint(x: iconFrame.midX, y: iconFrame.midY)) }) else {
            dismiss()
            return
        }
        let edge = DockPreviewGeometry.edge(iconFrame: iconFrame, screenFrame: screen.frame)
        let size = DockPreviewLayout(cardWidth: preferences.thumbnailWidth)
            .panelSize(windowCount: presentation.windows.count)
        let frame = DockPreviewGeometry.panelFrame(
            size: size, iconFrame: iconFrame, visibleFrame: screen.visibleFrame, edge: edge
        )
        panel.setFrame(frame, display: true)
        transitFrame = DockPreviewGeometry.transitFrame(iconFrame: iconFrame, panelFrame: frame, edge: edge)
    }

    private func refreshIfNeeded(now: TimeInterval) {
        guard panel?.isVisible == true, let target, captureTask == nil, now - lastRefresh >= 1.5 else { return }
        lastRefresh = now
        let expected = generation
        let width = preferences.thumbnailWidth
        captureTask = Task { [weak self, service] in
            let snapshot = await service.snapshot(for: target, thumbnailWidth: width)
            guard !Task.isCancelled, let self, self.generation == expected, self.target?.pid == target.pid else { return }
            self.captureTask = nil
            self.presentation.windows = snapshot.windows
            self.presentation.isLoading = false
            self.presentation.captureUnavailable = snapshot.captureUnavailable
            self.positionPanel()
        }
    }

    private func activate(windowID: CGWindowID) {
        guard let target,
              let app = NSRunningApplication(processIdentifier: target.pid), !app.isTerminated else {
            dismiss()
            return
        }
        // Keep the AX references until the action finishes. A stale snapshot
        // must never redirect a click to a different application's window.
        let service = service
        activationInFlight = true
        captureTask?.cancel()
        captureTask = nil
        suppressedIconFrame = iconFrame.insetBy(dx: -5, dy: -5)
        generation &+= 1
        if let globalDismissMonitor { NSEvent.removeMonitor(globalDismissMonitor) }
        globalDismissMonitor = nil
        queryTask?.cancel()
        queryTask = nil
        panel?.orderOut(nil)
        self.target = nil
        presentation.windows = []
        Task { [weak self] in
            defer { self?.activationInFlight = false }
            _ = await service.restoreAndRaise(windowID: windowID, pid: target.pid)
            app.unhide()
            app.activate(options: [])
            _ = await service.restoreAndRaise(windowID: windowID, pid: target.pid)
            await service.clear()
        }
    }

    private func installObservers() {
        guard observers.isEmpty else { return }
        for name in [NSWorkspace.activeSpaceDidChangeNotification, NSWorkspace.willSleepNotification] {
            observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.dismiss() }
            })
        }
        observers.append(NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in Task { @MainActor in self?.dismiss() } })
        keyboardMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53, self?.panel?.isVisible == true {
                self?.dismissForUserIntent()
                return nil
            }
            return event
        }
    }

    private func dismissForUserIntent() {
        if target != nil { suppressedIconFrame = iconFrame.insetBy(dx: -5, dy: -5) }
        dismiss()
    }

    private func removeObservers() {
        for observer in observers {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            NotificationCenter.default.removeObserver(observer)
        }
        observers.removeAll()
        if let keyboardMonitor { NSEvent.removeMonitor(keyboardMonitor) }
        keyboardMonitor = nil
    }
}

final class DockPreviewPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        title = LaunchText.value("Dock 窗口预览", "Dock Window Preview")
        level = .statusBar
        isFloatingPanel = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        animationBehavior = .none
    }
}
