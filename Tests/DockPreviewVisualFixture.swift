import AppKit
import ApplicationServices
import SwiftUI

/// Synthetic windows let visual QA exercise the real panel and card UI without
/// reading the user's windows or granting Screen Recording to a test bundle.
@MainActor
private final class DockPreviewFixtureDelegate: NSObject, NSApplicationDelegate {
    private var panel: DockPreviewPanel?
    private let presentation = DockPreviewPresentation()
    private var targetWindows: [NSWindow] = []
    private let service = DockPreviewWindowService()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        guard let screen = NSScreen.screens.dropFirst().first ?? NSScreen.main else { return }
        if let value = ProcessInfo.processInfo.environment["LAUNCH_FIXTURE_TARGET_PID"], let pid = Int32(value) {
            showRemotePreview(on: screen, pid: pid)
            return
        }
        if ProcessInfo.processInfo.environment["LAUNCH_FIXTURE_CAPTURE_TARGET"] == "1" {
            showIntegrationTargets(on: screen)
            return
        }
        let width = ProcessInfo.processInfo.environment["LAUNCH_FIXTURE_WIDTH"].flatMap(Double.init) ?? 240
        presentation.name = "启动台 · 窗口预览示例"
        presentation.icon = NSImage(systemSymbolName: "square.grid.3x3.fill", accessibilityDescription: nil)
        presentation.windows = [
            DockPreviewWindow(id: 101, title: "项目看板", isMinimized: false, image: Self.image(accent: .systemBlue)),
            DockPreviewWindow(id: 102, title: "设计草稿", isMinimized: false, image: Self.image(accent: .systemOrange)),
            DockPreviewWindow(id: 103, title: "已最小化的窗口", isMinimized: true, image: nil),
            DockPreviewWindow(id: 104, title: "其他窗口", isMinimized: false, image: Self.image(accent: .systemGreen))
        ]
        let count = ProcessInfo.processInfo.environment["LAUNCH_FIXTURE_WINDOW_COUNT"].flatMap(Int.init) ?? 4
        presentation.windows = Array(presentation.windows.prefix(max(1, count)))
        presentation.dismiss = { NSApp.terminate(nil) }
        let panel = DockPreviewPanel()
        panel.contentView = NSHostingView(rootView: DockPreviewContent(presentation: presentation, width: width))
        let icon = CGRect(x: screen.frame.midX - 30, y: screen.frame.minY + 10, width: 60, height: 60)
        let frame = DockPreviewGeometry.panelFrame(
            size: DockPreviewLayout(cardWidth: width).panelSize(windowCount: presentation.windows.count),
            iconFrame: icon, visibleFrame: screen.visibleFrame, edge: .bottom
        )
        panel.setFrame(frame, display: true)
        presentation.activate = { [weak panel] id in
            FileHandle.standardError.write(Data("Fixture window selected: \(id)\n".utf8))
            panel?.orderOut(nil)
            NSApp.terminate(nil)
        }
        self.panel = panel
        panel.orderFrontRegardless()
        let external = NSScreen.screens.count > 1 && panel.screen != NSScreen.screens.first
        FileHandle.standardError.write(Data("Launch fixture: on-external=\(external ? 1 : 0) width=\(width) frame=\(panel.frame)\n".utf8))
    }

    private func showIntegrationTargets(on screen: NSScreen) {
        NSApp.setActivationPolicy(.regular)
        for (index, title) in ["项目看板", "设计草稿"].enumerated() {
            let window = NSWindow(
                contentRect: CGRect(x: screen.visibleFrame.minX + 100 + CGFloat(index * 100),
                                    y: screen.visibleFrame.minY + 280 + CGFloat(index * 80),
                                    width: 600, height: 400),
                styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false
            )
            window.title = title
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView:
                VStack(alignment: .leading, spacing: 18) {
                    Text(title).font(.largeTitle.bold())
                    Text("Dock 预览集成验收 · 此窗口仅包含合成数据").font(.callout).foregroundStyle(.secondary)
                    Image(nsImage: NSImage(cgImage: Self.image(accent: index == 0 ? .systemBlue : .systemOrange)!,
                                          size: CGSize(width: 720, height: 430)))
                        .resizable().scaledToFit()
                }.padding(24).frame(maxWidth: .infinity, maxHeight: .infinity)
            )
            window.makeKeyAndOrderFront(nil)
            targetWindows.append(window)
        }
        NSApp.activate(ignoringOtherApps: true)
        if ProcessInfo.processInfo.environment["LAUNCH_FIXTURE_TARGET_ONLY"] == "1" {
            FileHandle.standardError.write(Data("Fixture target: pid=\(ProcessInfo.processInfo.processIdentifier) on-external=\(targetWindows.allSatisfy { $0.screen != NSScreen.screens.first } ? 1 : 0)\n".utf8))
            return
        }
        Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: 350_000_000)
            let axRoot = AXUIElementCreateApplication(ProcessInfo.processInfo.processIdentifier)
            let axWindows: [AXUIElement] = DockDoorAccessibility.attribute(axRoot, kAXWindowsAttribute) ?? []
            FileHandle.standardError.write(Data("Integration permissions: ax=\(AXIsProcessTrusted()) screen=\(CGPreflightScreenCaptureAccess()) raw-windows=\(axWindows.count)\n".utf8))
            for element in axWindows {
                let subrole: String = DockDoorAccessibility.attribute(element, kAXSubroleAttribute) ?? "nil"
                FileHandle.standardError.write(Data("Integration AX: subrole=\(subrole) id=\(DockDoorAccessibility.windowID(element) ?? 0) frame=\(DockDoorAccessibility.frame(element) != nil)\n".utf8))
            }
            let target = DockHoverTarget(pid: ProcessInfo.processInfo.processIdentifier,
                                         name: "窗口预览集成验收", bundleURL: Bundle.main.bundleURL, iconFrame: .zero)
            let initial = await self.service.snapshot(for: target, thumbnailWidth: 240)
            FileHandle.standardError.write(Data("Integration capture: windows=\(initial.windows.count) images=\(initial.windows.filter { $0.image != nil }.count)\n".utf8))
            self.targetWindows.last?.miniaturize(nil)
            let minimized = await self.service.snapshot(for: target, thumbnailWidth: 240)
            FileHandle.standardError.write(Data("Integration minimized: windows=\(minimized.windows.count) minimized=\(minimized.windows.filter(\.isMinimized).count)\n".utf8))
            self.presentation.name = target.name
            self.presentation.windows = minimized.windows
            let panel = DockPreviewPanel()
            panel.contentView = NSHostingView(rootView: DockPreviewContent(presentation: self.presentation, width: 240))
            let icon = CGRect(x: screen.frame.midX - 30, y: screen.frame.minY + 10, width: 60, height: 60)
            panel.setFrame(DockPreviewGeometry.panelFrame(size: DockPreviewLayout(cardWidth: 240).panelSize(windowCount: self.presentation.windows.count),
                           iconFrame: icon, visibleFrame: screen.visibleFrame, edge: .bottom), display: true)
            self.panel = panel
            self.presentation.activate = { [weak self] id in
                guard let self else { return }
                self.panel?.orderOut(nil)
                Task {
                    let raised = await self.service.restoreAndRaise(windowID: id, pid: target.pid)
                    let restored = self.targetWindows.last?.isMiniaturized == false
                    FileHandle.standardError.write(Data("Integration selection: raised=\(raised ? 1 : 0) restored-minimized=\(restored ? 1 : 0)\n".utf8))
                }
            }
            self.presentation.dismiss = { NSApp.terminate(nil) }
            panel.makeKeyAndOrderFront(nil)
            let external = NSScreen.screens.count > 1 && panel.screen != NSScreen.screens.first
            FileHandle.standardError.write(Data("Integration preview: on-external=\(external ? 1 : 0)\n".utf8))
        }
    }

    private func showRemotePreview(on screen: NSScreen, pid: pid_t) {
        Task {
            let target = DockHoverTarget(pid: pid, name: "窗口预览集成验收", bundleURL: Bundle.main.bundleURL, iconFrame: .zero)
            let snapshot = await service.snapshot(for: target, thumbnailWidth: 240)
            presentation.name = target.name
            presentation.windows = snapshot.windows
            FileHandle.standardError.write(Data("Remote capture: windows=\(snapshot.windows.count) images=\(snapshot.windows.filter { $0.image != nil }.count) minimized=\(snapshot.windows.filter(\.isMinimized).count)\n".utf8))
            let panel = DockPreviewPanel()
            panel.contentView = NSHostingView(rootView: DockPreviewContent(presentation: presentation, width: 240))
            let icon = CGRect(x: screen.frame.midX - 30, y: screen.frame.minY + 10, width: 60, height: 60)
            panel.setFrame(DockPreviewGeometry.panelFrame(size: DockPreviewLayout(cardWidth: 240).panelSize(windowCount: presentation.windows.count), iconFrame: icon,
                           visibleFrame: screen.visibleFrame, edge: .bottom), display: true)
            self.panel = panel
            presentation.activate = { [weak self] id in
                guard let self else { return }
                self.panel?.orderOut(nil)
                Task {
                    _ = await self.service.restoreAndRaise(windowID: id, pid: pid)
                    NSRunningApplication(processIdentifier: pid)?.activate(options: [])
                    let raised = await self.service.restoreAndRaise(windowID: id, pid: pid)
                    let root = AXUIElementCreateApplication(pid)
                    let windows: [AXUIElement] = DockDoorAccessibility.attribute(root, kAXWindowsAttribute) ?? []
                    let selected = windows.first { DockDoorAccessibility.windowID($0) == id }
                    let minimized: Bool? = selected.flatMap { DockDoorAccessibility.attribute($0, kAXMinimizedAttribute) }
                    FileHandle.standardError.write(Data("Remote selection: raised=\(raised ? 1 : 0) restored-minimized=\(minimized == false ? 1 : 0)\n".utf8))
                    NSApp.terminate(nil)
                }
            }
            presentation.dismiss = { NSApp.terminate(nil) }
            panel.orderFrontRegardless()
            FileHandle.standardError.write(Data("Remote preview: on-external=\(panel.screen != NSScreen.screens.first ? 1 : 0)\n".utf8))
        }
    }

    private static func image(accent: NSColor) -> CGImage? {
        let image = NSImage(size: CGSize(width: 720, height: 430))
        image.lockFocus()
        NSColor.windowBackgroundColor.setFill()
        NSBezierPath(rect: CGRect(x: 0, y: 0, width: 720, height: 430)).fill()
        NSColor.controlBackgroundColor.setFill()
        NSBezierPath(rect: CGRect(x: 0, y: 0, width: 150, height: 430)).fill()
        for row in 0..<5 {
            accent.withAlphaComponent(row == 0 ? 0.7 : 0.12).setFill()
            NSBezierPath(roundedRect: CGRect(x: 16, y: CGFloat(340 - row * 45), width: 115, height: 26), xRadius: 5, yRadius: 5).fill()
        }
        for row in 0..<2 {
            for column in 0..<3 {
                accent.withAlphaComponent(0.15).setFill()
                NSBezierPath(roundedRect: CGRect(x: CGFloat(176 + column * 175), y: CGFloat(64 + row * 145), width: 152, height: 115), xRadius: 9, yRadius: 9).fill()
            }
        }
        ("窗口预览" as NSString).draw(at: CGPoint(x: 176, y: 355), withAttributes: [
            .font: NSFont.systemFont(ofSize: 24, weight: .semibold),
            .foregroundColor: NSColor.labelColor
        ])
        image.unlockFocus()
        var rect = CGRect(origin: .zero, size: image.size)
        return image.cgImage(forProposedRect: &rect, context: nil, hints: nil)
    }
}

@main
private enum DockPreviewVisualFixture {
    @MainActor
    static func main() {
        let app = NSApplication.shared
        let delegate = DockPreviewFixtureDelegate()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}
