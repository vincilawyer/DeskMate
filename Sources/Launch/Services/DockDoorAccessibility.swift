// SPDX-License-Identifier: GPL-3.0-or-later
// Adapted from DockDoor, Copyright (C) 2024 ejbills and contributors.
// Upstream: 48483a7704a2430dceabd9465b65434dfbb3bff0
// Changes: bounded AX calls, validated icon geometry, no Dock mutations,
// dependency-free types, and runtime resolution of the window-ID bridge.

import AppKit
import ApplicationServices
import Darwin

struct DockRunningApplication: Sendable {
    let pid: pid_t
    let bundleIdentifier: String?
    let bundleURL: URL?
    let name: String
}

struct DockHoverTarget: Equatable, Sendable {
    let pid: pid_t
    let name: String
    let bundleURL: URL
    let iconFrame: CGRect
}

enum DockDoorAccessibility {
    static func attribute<T>(_ element: AXUIElement, _ key: String, as: T.Type = T.self) -> T? {
        var pid = pid_t(0)
        if !Thread.isMainThread,
           AXUIElementGetPid(element, &pid) == .success,
           pid == ProcessInfo.processInfo.processIdentifier {
            return DispatchQueue.main.sync { attribute(element, key, as: T.self) }
        }
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, key as CFString, &value) == .success else {
            return nil
        }
        return value as? T
    }

    static func frame(_ element: AXUIElement) -> CGRect? {
        guard let position: AXValue = attribute(element, kAXPositionAttribute),
              let size: AXValue = attribute(element, kAXSizeAttribute) else { return nil }
        var origin = CGPoint.zero
        var dimensions = CGSize.zero
        guard AXValueGetValue(position, .cgPoint, &origin),
              AXValueGetValue(size, .cgSize, &dimensions),
              origin.x.isFinite, origin.y.isFinite,
              dimensions.width.isFinite, dimensions.height.isFinite else { return nil }
        return CGRect(origin: origin, size: dimensions)
    }

    static func hoveredApplication(
        dockPID: pid_t,
        quartzPoint: CGPoint,
        applications: [DockRunningApplication]
    ) -> DockHoverTarget? {
        let dock = AXUIElementCreateApplication(dockPID)
        AXUIElementSetMessagingTimeout(dock, 0.12)
        guard let children: [AXUIElement] = attribute(dock, kAXChildrenAttribute),
              let list = children.first(where: {
                  attribute($0, kAXRoleAttribute, as: String.self) == kAXListRole
              }),
              let selected: [AXUIElement] = attribute(list, kAXSelectedChildrenAttribute),
              let item = selected.first,
              attribute(item, kAXSubroleAttribute, as: String.self) == "AXApplicationDockItem",
              let iconFrame = frame(item), !iconFrame.isEmpty,
              iconFrame.insetBy(dx: -2, dy: -2).contains(quartzPoint),
              let nsURL: NSURL = attribute(item, kAXURLAttribute),
              let url = nsURL.absoluteURL else { return nil }

        let bundleID = Bundle(url: url)?.bundleIdentifier
        let matches = applications.filter {
            $0.bundleURL?.standardizedFileURL == url.standardizedFileURL
                || (bundleID != nil && $0.bundleIdentifier == bundleID)
        }
        guard !matches.isEmpty else { return nil }
        var instanceIndex = 0
        if matches.count > 1,
           let items: [AXUIElement] = attribute(list, kAXChildrenAttribute) {
            let matchingItems = items.filter { candidate in
                guard attribute(candidate, kAXSubroleAttribute, as: String.self) == "AXApplicationDockItem",
                      let candidateURL: NSURL = attribute(candidate, kAXURLAttribute),
                      let absoluteURL = candidateURL.absoluteURL else { return false }
                return absoluteURL.standardizedFileURL == url.standardizedFileURL
            }
            instanceIndex = matchingItems.firstIndex(where: { CFEqual($0, item) }) ?? 0
        }
        guard instanceIndex < matches.count else { return nil }
        let app = matches[instanceIndex]
        return DockHoverTarget(pid: app.pid, name: app.name, bundleURL: url, iconFrame: iconFrame)
    }

    private typealias GetWindowID = @convention(c) (AXUIElement, UnsafeMutablePointer<CGWindowID>) -> Int32
    private static let getWindowID: GetWindowID? = {
        guard let address = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "_AXUIElementGetWindow") else {
            return nil
        }
        return unsafeBitCast(address, to: GetWindowID.self)
    }()

    static func windowID(_ element: AXUIElement) -> CGWindowID? {
        guard let getWindowID else { return nil }
        var id = CGWindowID(0)
        guard getWindowID(element, &id) == AXError.success.rawValue, id != 0 else { return nil }
        return id
    }
}
