import Foundation
import ServiceManagement

@MainActor
private final class MockLoginService: LaunchAtLoginService {
    var status = SMAppService.Status.notFound
    var registeredStatus = SMAppService.Status.enabled
    var registrationError: Error?
    var unregistrationError: Error?
    var registerCalls = 0
    var unregisterCalls = 0

    func register() throws {
        registerCalls += 1
        if let registrationError { throw registrationError }
        status = registeredStatus
    }
    func unregister() throws {
        unregisterCalls += 1
        if let unregistrationError { throw unregistrationError }
        status = .notRegistered
    }
}

@main
private enum LoginItemChecks {
    @MainActor static func main() throws {
        func check(_ value: Bool, _ message: String) throws {
            if !value { throw NSError(domain: message, code: 1) }
        }

        let fresh = MockLoginService()
        let manager = LaunchAtLoginManager(service: fresh, isBundled: true)
        try check(manager.isAvailable && !manager.isEnabled, "A fresh .notFound item must be selectable")
        try check(manager.setEnabled(true) && fresh.registerCalls == 1, "First enable must register")
        try check(manager.setEnabled(true) && fresh.registerCalls == 1, "Repeated enable must not reregister")
        try check(!manager.setEnabled(false) && fresh.unregisterCalls == 1, "Disable must unregister")
        _ = manager.setEnabled(false)
        try check(fresh.unregisterCalls == 1, "Repeated disable must not unregister")

        fresh.registrationError = NSError(domain: "Registration denied", code: 1)
        try check(!manager.setEnabled(true) && manager.lastError != nil && manager.isAvailable,
                  "A registration failure must roll back and allow retry")
        fresh.registrationError = nil
        try check(manager.setEnabled(true) && manager.lastError == nil, "Retry must recover")
        fresh.unregistrationError = NSError(domain: "Unregistration failed", code: 2)
        try check(manager.setEnabled(false) && manager.lastError != nil,
                  "An unregister failure must retain the actual on state")
        fresh.unregistrationError = nil
        _ = manager.setEnabled(false)

        fresh.registeredStatus = .requiresApproval
        try check(manager.setEnabled(true) && manager.requiresApproval, "Pending approval must stay registered")
        try check(!manager.setEnabled(false) && !manager.requiresApproval, "Pending approval must be cancellable")

        fresh.status = .enabled
        manager.refresh()
        try check(manager.isEnabled, "Refresh must reflect system enable")
        fresh.status = .notRegistered
        manager.refresh()
        try check(!manager.isEnabled, "Refresh must reflect system disable")

        let raw = MockLoginService()
        let unbundled = LaunchAtLoginManager(service: raw, isBundled: false)
        try check(!unbundled.isAvailable && unbundled.unavailableReason != nil,
                  "A raw executable must explain why login startup is unavailable")
        try check(!unbundled.setEnabled(true) && raw.registerCalls == 0,
                  "Unbundled executables must not mutate login items")
        print("LoginItemChecks: 14 checks passed")
    }
}
