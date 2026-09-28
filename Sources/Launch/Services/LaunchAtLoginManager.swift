import AppKit
import Combine
import ServiceManagement

@MainActor
protocol LaunchAtLoginService {
    var status: SMAppService.Status { get }
    func register() throws
    func unregister() throws
}

@MainActor
private struct SystemLaunchAtLoginService: LaunchAtLoginService {
    var status: SMAppService.Status { SMAppService.mainApp.status }
    func register() throws { try SMAppService.mainApp.register() }
    func unregister() throws { try SMAppService.mainApp.unregister() }
}

/// The system registration is the source of truth; saved preferences mirror it.
@MainActor
final class LaunchAtLoginManager: ObservableObject {
    @Published private(set) var isEnabled = false
    @Published private(set) var requiresApproval = false
    @Published private(set) var isAvailable = true
    @Published private(set) var lastError: String?
    @Published private(set) var unavailableReason: String?

    private let service: any LaunchAtLoginService
    private let isBundled: Bool

    init(service: (any LaunchAtLoginService)? = nil, isBundled: Bool? = nil) {
        self.service = service ?? SystemLaunchAtLoginService()
        self.isBundled = isBundled ?? (Bundle.main.bundleURL.pathExtension.lowercased() == "app")
        refresh()
    }

    func refresh() {
        guard isBundled else {
            isAvailable = false
            isEnabled = false
            requiresApproval = false
            unavailableReason = LaunchText.value(
                "请从“应用程序”中的桌伴打开此功能。",
                "Open the packaged app in Applications to manage login startup."
            )
            return
        }
        apply(service.status)
    }

    @discardableResult
    func setEnabled(_ enabled: Bool) -> Bool {
        lastError = nil
        refresh()
        guard isAvailable else { return isEnabled }

        do {
            switch (enabled, service.status) {
            // A new main-app login item can report .notFound before its first
            // registration. This is an off, registerable state on macOS.
            case (true, .notRegistered), (true, .notFound):
                try service.register()
            case (false, .enabled), (false, .requiresApproval):
                try service.unregister()
            default:
                break
            }
        } catch {
            lastError = LaunchText.value(
                "登录项设置未能更新：\(error.localizedDescription)",
                "Could not update the login item: \(error.localizedDescription)"
            )
        }
        refresh()
        return isEnabled
    }

    func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    private func apply(_ status: SMAppService.Status) {
        unavailableReason = nil
        isAvailable = true
        requiresApproval = status == .requiresApproval
        isEnabled = status == .enabled || requiresApproval
        switch status {
        case .notRegistered, .notFound, .enabled, .requiresApproval:
            break
        @unknown default:
            isAvailable = false
            unavailableReason = LaunchText.value(
                "macOS 返回了暂不支持的登录项状态，请在系统设置中查看。",
                "macOS returned an unsupported login-item status. Check System Settings."
            )
        }
    }
}
