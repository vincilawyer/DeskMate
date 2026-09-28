import SwiftUI

@MainActor
struct SettingsView: View {
    @ObservedObject var model: LauncherModel
    @ObservedObject var launchAtLoginManager: LaunchAtLoginManager
    @ObservedObject var dockPreviews: DockPreviewController
    @ObservedObject var screenEdges: ScreenEdgeModel
    let quit: () -> Void

    init(
        model: LauncherModel,
        launchAtLoginManager: LaunchAtLoginManager,
        dockPreviews: DockPreviewController,
        screenEdges: ScreenEdgeModel,
        quit: @escaping () -> Void
    ) {
        self.model = model
        self.launchAtLoginManager = launchAtLoginManager
        self.dockPreviews = dockPreviews
        self.screenEdges = screenEdges
        self.quit = quit
    }

    var body: some View {
        LauncherSettingsContent(
            applicationModel: model,
            dockPreviews: dockPreviews,
            screenEdges: screenEdges,
            preferences: $model.preferences,
            loginItemAvailable: launchAtLoginManager.isAvailable,
            loginItemEnabled: launchAtLoginManager.isEnabled,
            loginItemUnavailableReason: launchAtLoginManager.unavailableReason,
            loginItemRequiresApproval: launchAtLoginManager.requiresApproval,
            loginItemError: launchAtLoginManager.lastError,
            shortcutError: model.errorMessage,
            iconProvider: model.icon,
            setLaunchAtLogin: model.setLaunchAtLogin,
            openLoginItemsSettings: launchAtLoginManager.openLoginItemsSettings,
            clearShortcutError: model.clearError,
            save: model.savePreferences,
            rescan: model.rescan,
            quit: quit
        )
        .frame(minWidth: 680, minHeight: 480)
        .onAppear { model.refreshLaunchAtLoginStatus() }
    }
}
