import AppKit
import SwiftUI

@MainActor
final class DockPreviewPresentation: ObservableObject {
    @Published var name = ""
    @Published var icon: NSImage?
    @Published var windows: [DockPreviewWindow] = []
    @Published var isLoading = false
    @Published var captureUnavailable = false
    var activate: (CGWindowID) -> Void = { _ in }
    var dismiss: () -> Void = {}
}

struct DockPreviewContent: View {
    @ObservedObject var presentation: DockPreviewPresentation
    let width: Double
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private var layout: DockPreviewLayout { DockPreviewLayout(cardWidth: width) }

    var body: some View {
        VStack(alignment: .leading, spacing: DockPreviewLayout.spacing) {
            HStack(spacing: 8) {
                if let icon = presentation.icon {
                    Image(nsImage: icon).resizable().frame(width: 24, height: 24).accessibilityHidden(true)
                }
                Text(presentation.name).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                if !presentation.windows.isEmpty {
                    Text("\(presentation.windows.count)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(.quaternary, in: Capsule())
                }
                Spacer()
                Button(action: presentation.dismiss) {
                    Image(systemName: "xmark").font(.system(size: 11, weight: .semibold))
                        .frame(width: 24, height: 24).contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(LaunchText.value("关闭预览", "Dismiss preview"))
            }
            .frame(height: DockPreviewLayout.headerHeight)
            Group {
                if presentation.isLoading && presentation.windows.isEmpty {
                    VStack(spacing: 10) {
                        ProgressView().controlSize(.small)
                        Text(LaunchText.value("正在读取窗口…", "Loading windows…")).font(.callout).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if presentation.windows.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "macwindow").font(.system(size: 32)).foregroundStyle(.secondary)
                        Text(LaunchText.value("没有打开的窗口", "No open windows")).font(.callout)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView(.horizontal) {
                        HStack(spacing: DockPreviewLayout.spacing) {
                            ForEach(presentation.windows) { window in
                                DockWindowPreviewCard(window: window, width: width) {
                                    presentation.activate(window.id)
                                }
                            }
                        }
                        .padding(.vertical, DockPreviewLayout.scrollPadding)
                    }
                }
            }
            .frame(height: layout.scrollHeight)
            Text(presentation.captureUnavailable
                 ? LaunchText.value("授权屏幕录制后显示缩略图 · 点击切换窗口", "Allow Screen Recording for thumbnails · Click to switch")
                 : LaunchText.value("点击切换窗口 · Esc 关闭预览", "Click to switch windows · Esc to dismiss"))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .frame(height: DockPreviewLayout.footerHeight, alignment: .leading)
        }
        .padding(DockPreviewLayout.contentPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(reduceTransparency ? AnyShapeStyle(Color(nsColor: .windowBackgroundColor)) : AnyShapeStyle(.regularMaterial))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16).strokeBorder(Color(nsColor: .separatorColor).opacity(0.45), lineWidth: 1)
        }
    }
}

private struct DockWindowPreviewCard: View {
    let window: DockPreviewWindow
    let width: Double
    let action: () -> Void
    @State private var isHovered = false

    private var layout: DockPreviewLayout { DockPreviewLayout(cardWidth: width) }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: DockPreviewLayout.cardSpacing) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9).fill(Color(nsColor: .controlBackgroundColor))
                    if let image = window.image {
                        Image(decorative: image, scale: 1).resizable().scaledToFit().padding(3)
                    } else {
                        VStack(spacing: 6) {
                            Image(systemName: window.isMinimized ? "minus.rectangle" : "macwindow")
                                .font(.system(size: 28))
                            Text(window.isMinimized
                                 ? LaunchText.value("已最小化", "Minimized")
                                 : LaunchText.value("窗口预览不可用", "Preview unavailable"))
                                .font(.caption)
                        }
                        .foregroundStyle(.secondary)
                    }
                }
                .frame(width: layout.thumbnailSize.width, height: layout.thumbnailSize.height)
                Text(window.title).font(.system(size: 12, weight: .medium)).lineLimit(1)
                    .foregroundStyle(.primary)
                    .frame(height: DockPreviewLayout.titleHeight, alignment: .leading)
            }
            .padding(DockPreviewLayout.cardPadding)
            .frame(width: width)
            .background(isHovered ? Color.accentColor.opacity(0.13) : .clear, in: RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12).strokeBorder(
                    isHovered ? Color.accentColor.opacity(0.65) : Color(nsColor: .separatorColor).opacity(0.2), lineWidth: 1
                )
            }
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(window.title)
        .accessibilityLabel(window.title)
        .accessibilityHint(LaunchText.value("切换到这个窗口；已最小化的窗口会恢复。", "Switch to this window; minimized windows will be restored."))
    }
}
