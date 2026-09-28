import AppKit
import SwiftUI

private enum LauncherSettingsPage: String, CaseIterable {
    case general, launcher, dock, edges

    var title: String {
        switch self {
        case .general: return LaunchText.value("通用", "General")
        case .launcher: return LaunchText.value("启动台", "Launcher")
        case .dock: return LaunchText.value("Dock 预览", "Dock Previews")
        case .edges: return LaunchText.value("跨屏边缘", "Screen Edges")
        }
    }

    var symbol: String {
        switch self {
        case .general: return "gearshape"
        case .launcher: return "square.grid.3x3"
        case .dock: return "macwindow.on.rectangle"
        case .edges: return "display.2"
        }
    }

    var detail: String {
        switch self {
        case .general: return LaunchText.value("桌伴的启动方式与菜单栏。", "Startup and menu bar settings for 桌伴.")
        case .launcher: return LaunchText.value("管理应用、调整布局与触控板手势。", "Manage applications, layout and trackpad gestures.")
        case .dock: return LaunchText.value("悬停查看窗口，点击即可切换。", "Peek at windows on hover; click to switch.")
        case .edges: return LaunchText.value("看见扩展屏与通用控制的跨屏入口。", "Find passages to displays and Universal Control devices.")
        }
    }
}

private enum LauncherSettingsPane: String, CaseIterable {
    case layout, options, trackpad
    var title: String {
        switch self {
        case .layout: return LaunchText.value("布局", "Layout")
        case .options: return LaunchText.value("选项", "Options")
        case .trackpad: return LaunchText.value("触控板", "Trackpad")
        }
    }
}

struct LauncherSettingsContent: View {
    @ObservedObject var applicationModel: LauncherModel
    @ObservedObject var dockPreviews: DockPreviewController
    @ObservedObject var screenEdges: ScreenEdgeModel
    @Binding var preferences: LaunchPreferences

    @State private var showsApplicationManager = false
    @State private var selectedPage = LauncherSettingsPage.general
    @State private var launcherPane = LauncherSettingsPane.layout

    let loginItemAvailable: Bool
    let loginItemEnabled: Bool
    let loginItemUnavailableReason: String?
    let loginItemRequiresApproval: Bool
    let loginItemError: String?
    let shortcutError: String?
    let iconProvider: (String) -> NSImage?
    let setLaunchAtLogin: (Bool) -> Void
    let openLoginItemsSettings: () -> Void
    let clearShortcutError: () -> Void
    let save: () -> Void
    let rescan: () -> Void
    let quit: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(selectedPage.title).font(.system(size: 24, weight: .semibold))
                        .accessibilityAddTraits(.isHeader)
                    Text(selectedPage.detail).font(.callout).foregroundStyle(.secondary)
                }

                if selectedPage == .launcher {
                    Picker(LaunchText.value("启动台选项", "Launcher options"), selection: $launcherPane) {
                        ForEach(LauncherSettingsPane.allCases, id: \.self) { pane in
                            Text(pane.title).tag(pane)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if selectedPage == .launcher && launcherPane == .layout {
                    launcherLayoutSection
                }
                if selectedPage == .general {
                    generalSection
                }
                if selectedPage == .launcher && launcherPane == .options {
                    launcherOptionsSection
                }
                if selectedPage == .launcher && launcherPane == .trackpad {
                    launcherTrackpadSection
                }

                if selectedPage == .dock {
                    dockPreviewSection
                }
                if selectedPage == .edges {
                    ScreenEdgeSettingsContent(model: screenEdges)
                }

            }
            .padding(.horizontal, 26)
            .padding(.vertical, 22)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
            }
            .id(selectedPage)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .toggleStyle(.switch)
        .navigationTitle(LaunchText.value("桌伴设置", "桌伴 Settings"))
        .onChange(of: preferences) { _, _ in
            save()
        }
        .sheet(isPresented: $showsApplicationManager) {
            LauncherApplicationManagerSheet(
                model: applicationModel,
                iconProvider: iconProvider
            )
        }
    }

    private var launcherLayoutSection: some View {
        LauncherSettingsSection(
            title: LaunchText.value("布局", "Layout"),
            systemImage: "square.grid.3x3"
        ) {
            LauncherSettingsRow(title: LaunchText.value("行数", "Rows")) {
                Stepper(value: $preferences.rows, in: 3...8) {
                    Text("\(preferences.rows)")
                        .monospacedDigit()
                        .frame(width: 24, alignment: .trailing)
                }
                .frame(width: 92)
                .accessibilityLabel(LaunchText.value("网格行数", "Grid rows"))
            }

            LauncherSettingsDivider()

            LauncherSettingsRow(title: LaunchText.value("列数", "Columns")) {
                Stepper(value: $preferences.columns, in: 4...12) {
                    Text("\(preferences.columns)")
                        .monospacedDigit()
                        .frame(width: 24, alignment: .trailing)
                }
                .frame(width: 92)
                .accessibilityLabel(LaunchText.value("网格列数", "Grid columns"))
            }

            LauncherSettingsDivider()

            LauncherSettingsRow(title: LaunchText.value("图标大小", "Icon size")) {
                HStack(spacing: 10) {
                    Slider(value: $preferences.iconSize, in: 48...112, step: 2)
                        .frame(width: 190)
                        .accessibilityLabel(LaunchText.value("应用图标大小", "Application icon size"))
                    Text("\(Int(preferences.iconSize)) pt")
                        .font(.callout)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: 54, alignment: .trailing)
                }
            }

            LauncherSettingsDivider()

            LauncherSettingsRow(
                title: LaunchText.value("显示应用名称", "Show application names")
            ) {
                Toggle(LaunchText.value("显示应用名称", "Show application names"), isOn: $preferences.showLabels)
                    .labelsHidden()
            }
        }
    }

    private var generalSection: some View {
        LauncherSettingsSection(
            title: LaunchText.value("通用", "General"),
            systemImage: "gearshape"
        ) {
            LauncherSettingsRow(
                title: LaunchText.value("登录时自动打开桌伴", "Open 桌伴 automatically at login"),
                subtitle: loginItemUnavailableReason
            ) {
                Toggle(
                    LaunchText.value("登录时自动打开桌伴", "Open 桌伴 automatically at login"),
                    isOn: Binding(
                        get: { loginItemEnabled },
                        set: setLaunchAtLogin
                    )
                )
                .labelsHidden()
                .disabled(!loginItemAvailable)
            }

            if loginItemRequiresApproval {
                LauncherSettingsDivider()
                LauncherSettingsNotice(
                    text: LaunchText.value(
                        "macOS 需要你在“登录项”中批准。",
                        "macOS needs your approval in Login Items."
                    ),
                    systemImage: "exclamationmark.triangle.fill",
                    tint: .orange,
                    actionTitle: LaunchText.value("打开系统设置", "Open Settings"),
                    action: openLoginItemsSettings
                )
            }

            if let loginItemError {
                LauncherSettingsDivider()
                LauncherSettingsNotice(
                    text: loginItemError,
                    systemImage: "exclamationmark.circle.fill",
                    tint: .red
                )
            }

            LauncherSettingsDivider()

            LauncherSettingsRow(
                title: LaunchText.value("显示菜单栏图标", "Show menu bar icon"),
                subtitle: LaunchText.value(
                    "关闭后仍可使用全局快捷键或从“应用程序”文件夹打开桌伴。",
                    "When off, use the global shortcut or open 桌伴 from Applications."
                )
            ) {
                Toggle(LaunchText.value("显示菜单栏图标", "Show menu bar icon"), isOn: $preferences.showMenuBarIcon)
                    .labelsHidden()
            }

            LauncherSettingsDivider()

            LauncherSettingsRow(
                title: LaunchText.value("退出桌伴", "Quit 桌伴"),
                subtitle: LaunchText.value("退出全部三个模块，设置会自动保存。", "Stop all three modules and save settings.")
            ) {
                Button(LaunchText.value("退出", "Quit"), action: quit)
            }
        }
    }

    private var launcherOptionsSection: some View {
        LauncherSettingsSection(
            title: LaunchText.value("应用与打开方式", "Applications and opening"),
            systemImage: "slider.horizontal.3"
        ) {
        LauncherSettingsRow(
            title: LaunchText.value("管理应用", "Manage applications"),
            subtitle: LaunchText.value(
                "在一个列表中选择哪些应用显示在启动台中。",
                "Choose which applications appear in the launcher from one list."
            )
        ) {
            HStack(spacing: 7) {
                Button(LaunchText.value("应用列表…", "Application List…")) {
                    showsApplicationManager = true
                }
                .disabled(applicationModel.managedApplications.isEmpty)

                Button(LaunchText.value("重新扫描", "Scan Again"), action: rescan)
            }
            .controlSize(.small)
        }
            LauncherSettingsDivider()
            LauncherGlobalShortcutEditor(shortcut: $preferences.globalShortcut)
            if let shortcutError {
                LauncherSettingsDivider()
                LauncherSettingsNotice(
                    text: shortcutError,
                    systemImage: "exclamationmark.triangle.fill",
                    tint: .red,
                    actionTitle: LaunchText.value("关闭", "Dismiss"),
                    action: clearShortcutError
                )
            }
        }
    }

    private var launcherTrackpadSection: some View {
        LauncherSettingsSection(
            title: LaunchText.value("触控板", "Trackpad"),
            systemImage: "hand.draw"
        ) {
            LauncherShortcutRow(
                keys: [LaunchText.value("五指", "5 fingers"), LaunchText.value("捏合", "Pinch")],
                action: LaunchText.value("显示启动台", "Show Launcher")
            )
            LauncherSettingsDivider()
            LauncherShortcutRow(
                keys: [LaunchText.value("五指", "5 fingers"), LaunchText.value("张开", "Spread")],
                action: LaunchText.value("隐藏启动台", "Hide Launcher")
            )
            LauncherSettingsDivider()
            LauncherShortcutRow(
                keys: [LaunchText.value("二指", "2 fingers"), LaunchText.value("横向滑动", "Swipe")],
                action: LaunchText.value("跟手切换页面", "Interactively change pages")
            )
            LauncherSettingsDivider()
            LauncherSettingsNotice(
                text: LaunchText.value(
                    "启动台打开时，二指横向滑动会让页面跟随手势移动；三指手势继续交给 macOS。五指手势暂不可用时，可使用你在“选项”中设置的全局快捷键。",
                    "While the launcher is open, a two-finger horizontal swipe moves pages with your gesture; three-finger gestures remain available to macOS. If five-finger gestures are unavailable, use the global shortcut configured in Options."
                ),
                systemImage: "info.circle",
                tint: .secondary
            )
            LauncherSettingsDivider()
            LauncherSettingsNotice(
                text: LaunchText.value(
                    "鼠标移到通用控制的另一台 Mac 或 iPad 后，本机五指手势不会打开启动台。移回本机或本机扩展屏后恢复；快捷键仍可使用。",
                    "Five-finger gestures do not open this launcher while the pointer is on another Mac or iPad through Universal Control. Move back to a local display to use gestures; keyboard shortcuts remain available."
                ),
                systemImage: "display.2",
                tint: .secondary
            )
            if !RawMultitouchCompatibility.current.isVerified {
                LauncherSettingsNotice(
                    text: LaunchText.value(
                        "当前系统版本尚未适配全局五指手势。请使用全局快捷键或菜单栏图标打开启动台。",
                        "Global five-finger gestures have not been verified for this system version. Open the launcher using the global shortcut or menu bar icon."
                    ),
                    systemImage: "exclamationmark.triangle",
                    tint: .orange
                )
            }
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("桌伴", systemImage: "desktopcomputer")
                .font(.system(size: 16, weight: .semibold))
                .padding(.horizontal, 12).padding(.top, 16).padding(.bottom, 20)
            ForEach(LauncherSettingsPage.allCases, id: \.self) { page in
                if page == .launcher {
                    Text(LaunchText.value("功能模块", "Modules"))
                        .font(.caption.weight(.medium)).foregroundStyle(.secondary)
                        .padding(.horizontal, 12).padding(.top, 16).padding(.bottom, 4)
                }
                Button { selectedPage = page } label: {
                    HStack(spacing: 10) {
                        Image(systemName: page.symbol).frame(width: 20).accessibilityHidden(true)
                        Text(page.title)
                        Spacer(minLength: 0)
                    }
                    .font(.system(size: 13, weight: selectedPage == page ? .semibold : .regular))
                    .foregroundStyle(selectedPage == page ? Color.accentColor : Color.primary)
                    .padding(.horizontal, 12).frame(height: 38)
                    .background(selectedPage == page ? Color.accentColor.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 8))
                    .contentShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selectedPage == page ? .isSelected : [])
            }
            Spacer()
            Button(action: quit) {
                Label(LaunchText.value("退出桌伴", "Quit 桌伴"), systemImage: "power")
                    .font(.callout).frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12).frame(height: 38)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(LaunchText.value("退出桌伴（⌘Q）", "Quit 桌伴 (⌘Q)"))
            Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")
                .font(.caption).foregroundStyle(.secondary).padding(12)
        }
        .padding(.horizontal, 10).padding(.bottom, 8)
        .frame(width: 150)
        .frame(maxHeight: .infinity)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.45))
    }

    private var dockPreviewSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            LauncherSettingsSection(title: LaunchText.value("窗口预览", "Window Previews"), systemImage: "macwindow") {
                LauncherSettingsRow(
                    title: LaunchText.value("启用 Dock 窗口预览", "Enable Dock window previews"),
                    subtitle: LaunchText.value("鼠标停在 Dock 的运行中应用上显示窗口。", "Hover over a running application in the Dock to see its windows.")
                ) {
                    Toggle(LaunchText.value("启用 Dock 窗口预览", "Enable Dock window previews"), isOn: $preferences.dockPreviews.enabled)
                        .labelsHidden()
                }
                LauncherSettingsDivider()
                LauncherSettingsRow(title: LaunchText.value("悬停等待", "Hover delay")) {
                    HStack(spacing: 8) {
                        Slider(value: $preferences.dockPreviews.hoverDelay, in: 0.15...1.2, step: 0.05)
                            .frame(width: 132)
                            .accessibilityLabel(LaunchText.value("悬停等待时间", "Hover delay"))
                        Text(String(format: "%.2f s", preferences.dockPreviews.hoverDelay))
                            .font(.callout.monospacedDigit()).foregroundStyle(.secondary).frame(width: 54)
                    }
                    .disabled(!preferences.dockPreviews.enabled)
                }
                LauncherSettingsDivider()
                LauncherSettingsRow(
                    title: LaunchText.value("预览大小", "Preview size"),
                    subtitle: LaunchText.value("宽高同步缩放，保持窗口画面比例。", "Scale both dimensions while preserving the window image's proportions.")
                ) {
                    HStack(spacing: 8) {
                        Slider(value: $preferences.dockPreviews.thumbnailWidth, in: 180...320, step: 20)
                            .frame(width: 132)
                            .accessibilityLabel(LaunchText.value("窗口预览大小", "Window preview size"))
                        Text("\(Int(preferences.dockPreviews.thumbnailWidth)) pt")
                            .font(.callout.monospacedDigit()).foregroundStyle(.secondary).frame(width: 54)
                    }
                    .disabled(!preferences.dockPreviews.enabled)
                }
            }
            LauncherSettingsSection(title: LaunchText.value("权限", "Permissions"), systemImage: "lock.shield") {
                LauncherSettingsRow(
                    title: LaunchText.value("辅助功能", "Accessibility"),
                    subtitle: dockPreviews.accessibilityGranted
                        ? LaunchText.value("已授权 · 识别 Dock 图标并切换窗口", "Allowed · Read Dock icons and switch windows")
                        : LaunchText.value("需要授权，用于识别 Dock 图标并切换窗口。", "Required to read Dock icons and switch windows.")
                ) {
                    if dockPreviews.accessibilityGranted {
                        Label(LaunchText.value("已授权", "Allowed"), systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green).font(.callout)
                    } else {
                        Button(LaunchText.value("去授权", "Allow"), action: dockPreviews.requestAccessibility)
                            .disabled(!preferences.dockPreviews.enabled)
                    }
                }
                LauncherSettingsDivider()
                LauncherSettingsRow(
                    title: LaunchText.value("屏幕录制", "Screen Recording"),
                    subtitle: dockPreviews.screenRecordingGranted
                        ? LaunchText.value("已授权 · 缩略图只保留在本机内存", "Allowed · Thumbnails stay in local memory")
                        : LaunchText.value("用于窗口缩略图；未授权时仍可显示窗口列表。", "Used for thumbnails; the window list works without it.")
                ) {
                    if dockPreviews.screenRecordingGranted {
                        Label(LaunchText.value("已授权", "Allowed"), systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green).font(.callout)
                    } else {
                        Button(LaunchText.value("去授权", "Allow"), action: dockPreviews.requestScreenRecording)
                            .disabled(!preferences.dockPreviews.enabled)
                    }
                }
            }
            Label(LaunchText.value("启用后按需授权；macOS 提示重新打开时，请退出并重新打开桌伴。", "Allow permissions after enabling; relaunch 桌伴 if macOS asks."),
                  systemImage: "info.circle")
                .font(.callout).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button(LaunchText.value("集成自 DockDoor · 开源许可与致谢", "Integrated from DockDoor · License and credits")) {
                if let notice = Bundle.main.url(forResource: "THIRD_PARTY_NOTICES", withExtension: "md") {
                    NSWorkspace.shared.open(notice)
                }
            }
                .buttonStyle(.link)
                .font(.caption)
        }
        .task {
            while !Task.isCancelled {
                dockPreviews.refreshPermissions()
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }
    }
}

@MainActor
private struct LauncherApplicationManagerSheet: View {
    @StateObject private var managerState: LauncherApplicationManagerState
    let iconProvider: (String) -> NSImage?

    @Environment(\.dismiss) private var dismiss

    init(
        model: LauncherModel,
        iconProvider: @escaping (String) -> NSImage?
    ) {
        _managerState = StateObject(
            wrappedValue: LauncherApplicationManagerState(model: model)
        )
        self.iconProvider = iconProvider
    }

    private var filteredApplications: [ManagedApplication] {
        managerState.filteredRows
    }

    private var isSearching: Bool {
        !managerState.searchText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty
    }

    private var applicationCount: Int {
        managerState.applicationCount
    }

    private var visibleCount: Int {
        managerState.visibleCount
    }

    private var visibleApplications: [ManagedApplication] {
        managerState.visibleRows
    }

    private var hiddenApplications: [ManagedApplication] {
        managerState.hiddenRows
    }

    var body: some View {
        VStack(spacing: 0) {
            managerHeader

            Divider()

            if filteredApplications.isEmpty {
                ContentUnavailableView(
                    LaunchText.value("没有匹配的应用", "No Matching Applications"),
                    systemImage: "magnifyingglass",
                    description: Text(
                        LaunchText.value("请尝试其他名称。", "Try another name.")
                    )
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        if isSearching {
                            // Search results stay in one identity namespace.
                            // Toggling visibility cannot remove an active
                            // NSSwitch from one ForEach and recreate it in a
                            // different group during the same control action.
                            applicationGroup(
                                title: LaunchText.value("搜索结果", "Search Results"),
                                systemImage: "magnifyingglass",
                                applications: filteredApplications
                            )
                        } else {
                            applicationGroup(
                                title: LaunchText.value("可见", "Visible"),
                                systemImage: "eye",
                                applications: visibleApplications
                            )

                            applicationGroup(
                                title: LaunchText.value("已隐藏", "Hidden"),
                                systemImage: "eye.slash",
                                applications: hiddenApplications
                            )
                        }
                    }
                    .padding(14)
                }
            }

            Divider()

            HStack {
                Spacer()
                Button(LaunchText.value("完成", "Done")) {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
            .padding(18)
        }
        .frame(width: 620, height: 560)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var managerHeader: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(LaunchText.value("管理应用", "Manage Applications"))
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                    Text(
                        LaunchText.value(
                            "更改会立即生效，隐藏的应用随时可以重新显示。",
                            "Changes apply immediately, and hidden applications can be shown again at any time."
                        )
                    )
                    .font(.callout)
                    .foregroundStyle(.secondary)
                }
                Spacer()
                Text(
                    LaunchText.value(
                        "显示 \(visibleCount) / \(applicationCount)",
                        "\(visibleCount) of \(applicationCount) shown"
                    )
                )
                .font(.callout.weight(.medium))
                .foregroundStyle(.secondary)
                .contentTransition(.numericText())
            }

            HStack(spacing: 9) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField(
                    LaunchText.value("搜索应用", "Search applications"),
                    text: $managerState.searchText
                )
                .textFieldStyle(.plain)
                if !managerState.searchText.isEmpty {
                    Button {
                        managerState.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(LaunchText.value("清除搜索", "Clear search"))
                }
            }
            .padding(.horizontal, 11)
            .frame(height: 36)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .padding(22)
    }

    @ViewBuilder
    private func applicationGroup(
        title: String,
        systemImage: String,
        applications: [ManagedApplication]
    ) -> some View {
        HStack(spacing: 7) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .semibold))
            Text(title)
            Text("\(applications.count)")
                .monospacedDigit()
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 10)
        .padding(.top, 10)
        .padding(.bottom, 3)
        .accessibilityElement(children: .combine)

        ForEach(applications) { item in
            LauncherManagedApplicationRow(
                managerState: managerState,
                applicationID: item.id,
                application: item.application,
                icon: iconProvider(item.id)
            )
        }
    }

}

@MainActor
private struct LauncherManagedApplicationRow: View {
    @ObservedObject var managerState: LauncherApplicationManagerState
    let applicationID: String
    let application: InstalledApplication
    let icon: NSImage?

    private var isVisible: Bool {
        managerState.visualVisibility(for: applicationID)
    }

    private var visibilityBinding: Binding<Bool> {
        Binding(
            get: {
                managerState.visualVisibility(for: applicationID)
            },
            set: { desiredVisibility in
                managerState.requestVisibility(
                    applicationID,
                    isVisible: desiredVisibility
                )
            }
        )
    }

    var body: some View {
        HStack(spacing: 12) {
            LauncherAppIcon(
                image: icon,
                fallbackName: application.name,
                size: 38
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(application.name)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(
                    isVisible
                        ? LaunchText.value("在启动台中显示", "Shown in Launcher")
                        : LaunchText.value("已隐藏", "Hidden")
                )
                .font(.caption)
                .foregroundStyle(isVisible ? Color.secondary : Color.orange)
                .lineLimit(1)
            }

            Spacer()

            Toggle(
                "",
                isOn: visibilityBinding
            )
            .labelsHidden()
            .toggleStyle(.switch)
            .accessibilityLabel(
                LaunchText.value(
                    "在启动台中显示 \(application.name)",
                    "Show \(application.name) in Launcher"
                )
            )
        }
        .padding(.horizontal, 12)
        .frame(height: 58)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isVisible ? Color.clear : Color.orange.opacity(0.055))
        }
    }
}

private struct LauncherSettingsSection<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Color(nsColor: .controlBackgroundColor),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.42), lineWidth: 1)
            }
        }
    }
}

private struct LauncherSettingsRow<Control: View>: View {
    let title: String
    let subtitle: String?
    @ViewBuilder let control: () -> Control

    init(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder control: @escaping () -> Control
    ) {
        self.title = title
        self.subtitle = subtitle
        self.control = control
    }

    var body: some View {
        HStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .foregroundStyle(.primary)

                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 12)

            control()
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: subtitle == nil ? 48 : 58)
    }
}

private struct LauncherSettingsDivider: View {
    var body: some View {
        Divider()
            .padding(.leading, 14)
    }
}

private struct LauncherSettingsNotice: View {
    let text: String
    let systemImage: String
    let tint: Color
    var actionTitle: String?
    var action: (() -> Void)?

    init(
        text: String,
        systemImage: String,
        tint: Color,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.text = text
        self.systemImage = systemImage
        self.tint = tint
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
                .frame(width: 18)

            Text(text)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)

            Spacer(minLength: 8)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .controlSize(.small)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(minHeight: 44)
    }
}

private struct LauncherShortcutRow: View {
    let keys: [String]
    let action: String

    var body: some View {
        HStack {
            Text(action)
            Spacer()
            HStack(spacing: 5) {
                ForEach(keys, id: \.self) { key in
                    Text(key)
                        .font(.system(.callout, design: .rounded, weight: .medium))
                        .padding(.horizontal, 7)
                        .frame(minWidth: 27, minHeight: 24)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 5))
                }
            }
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 48)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            LaunchText.value(
                "\(action)：\(keys.joined(separator: " 加 "))",
                "\(action): \(keys.joined(separator: " plus "))"
            )
        )
    }
}
