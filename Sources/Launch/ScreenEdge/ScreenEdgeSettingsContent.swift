import SwiftUI

private enum ScreenEdgeSettingsPage: String, CaseIterable, Identifiable {
    case display, style, channels, manual, lock
    var id: String { rawValue }
    var title: String {
        switch self {
        case .display: return "显示"
        case .style: return "样式"
        case .channels: return "通道"
        case .manual: return "手动标记"
        case .lock: return "锁屏"
        }
    }
}

struct ScreenEdgeSettingsContent: View {
    @ObservedObject var model: ScreenEdgeModel
    @State private var page = ScreenEdgeSettingsPage.display

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            SettingsCard(title: "跨屏边缘") {
                SettingsToggleRow(title: "启用边缘提示", detail: "标记扩展屏和通用控制入口；提示线穿透点击。", isOn: $model.preferences.enabled)
            }
            Picker("跨屏边缘选项", selection: $page) {
                ForEach(ScreenEdgeSettingsPage.allCases) { Text($0.title).tag($0) }
            }.pickerStyle(.segmented)
            Group {
                switch page {
                case .display: AppearanceSettings(model: model)
                case .style: StyleSettings(model: model)
                case .channels: ChannelSettings(model: model)
                case .manual: ManualSettings(model: model)
                case .lock: GeneralSettings(model: model)
                }
            }
            if let warning = model.configWarning {
                Text(warning).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
