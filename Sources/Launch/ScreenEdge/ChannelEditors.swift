// SPDX-License-Identifier: MIT
// Adapted from vincilawyer/ScreenEdge, commit 7e418d6352b5a839bd01f4b723f54f3f4d5d9e1c.
// Copyright (c) 2026 ScreenEdge contributors. See LICENSES/ScreenEdge-MIT.txt.
import SwiftUI

let settingsAccent = Color.accentColor

struct MarkerEditor: View {
    @Binding var marker: ManualMarker
    let displays: [DisplayInfo]
    let remove: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 12) {
                Toggle("启用标记", isOn: $marker.enabled).labelsHidden().help("显示或隐藏这段手动标记")
                TextField("目标设备名称", text: $marker.label).textFieldStyle(.roundedBorder)
                Text("手动").font(.caption2).foregroundStyle(.orange)
                Button(action: remove) { Image(systemName: "trash") }.buttonStyle(.borderless).help("删除这段标记")
                    .accessibilityLabel("删除标记")
            }
            HStack {
                Picker("本机屏幕", selection: $marker.displayID) {
                    ForEach(displays) { display in Text(display.name).tag(display.id) }
                    if !displays.contains(where: { $0.id == marker.displayID }) {
                        Text("原屏幕未连接").tag(marker.displayID)
                    }
                }
                Picker("边缘", selection: $marker.edge) {
                    ForEach(Edge.allCases) { edge in Text(edge.title).tag(edge) }
                }.frame(width: 155)
            }
            VStack(spacing: 10) {
                HStack(spacing: 12) {
                    Text("起点").font(.caption).frame(width: 32, alignment: .leading)
                    Slider(value: Binding(get: { marker.start * 100 }, set: { marker.start = min($0.rounded() / 100, marker.end - 0.01) }), in: 0...99)
                        .accessibilityLabel("标记起点")
                    Text("\(Int((marker.start * 100).rounded()))%").monospacedDigit().font(.caption).frame(width: 38, alignment: .trailing)
                }
                HStack(spacing: 12) {
                    Text("终点").font(.caption).frame(width: 32, alignment: .leading)
                    Slider(value: Binding(get: { marker.end * 100 }, set: { marker.end = max($0.rounded() / 100, marker.start + 0.01) }), in: 1...100)
                        .accessibilityLabel("标记终点")
                    Text("\(Int((marker.end * 100).rounded()))%").monospacedDigit().font(.caption).frame(width: 38, alignment: .trailing)
                }
            }
            Text(marker.edge.vertical ? "0% 是屏幕顶端，100% 是底端；边缘线会随调整实时更新。" : "0% 是屏幕左端，100% 是右端；边缘线会随调整实时更新。")
                .font(.caption2).foregroundStyle(.secondary)
        }.padding(16).background(Color.orange.opacity(0.055), in: RoundedRectangle(cornerRadius: 12))
    }
}

struct DisplayMap: View {
    let displays: [DisplayInfo]
    let portals: [Portal]
    let preferences: ScreenEdgePreferences
    private let remoteColor = Color.accentColor

    var body: some View {
        let hints = DisplayMapGeometry.remoteHints(displays: displays, portals: portals)
        GeometryReader { geometry in
            let union = (displays.map(\.frame) + hints.map(\.frame)).reduce(CGRect.null) { $0.union($1) }
            if !union.isNull && union.width > 0 && union.height > 0 {
                let scale = min((geometry.size.width - 56) / union.width, (geometry.size.height - 36) / union.height)
                let origin = CGPoint(x: (geometry.size.width - union.width * scale) / 2,
                                     y: (geometry.size.height - union.height * scale) / 2)
                let point: (CGPoint) -> CGPoint = { p in
                    CGPoint(x: origin.x + (p.x - union.minX) * scale, y: origin.y + (union.maxY - p.y) * scale)
                }
                ZStack(alignment: .topLeading) {
                    ForEach(hints) { hint in
                        Path { path in
                            path.move(to: point(hint.source)); path.addLine(to: point(hint.destination))
                        }.stroke(remoteColor.opacity(0.65), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.system(size: 10, weight: .bold)).foregroundStyle(remoteColor)
                            .rotationEffect(.degrees(hint.source.x == hint.destination.x ? 0 : 90))
                            .padding(3).background(Color(nsColor: .windowBackgroundColor), in: Circle())
                            .position(point(CGPoint(x: (hint.source.x + hint.destination.x) / 2,
                                                    y: (hint.source.y + hint.destination.y) / 2)))
                    }
                    ForEach(displays) { display in
                        let f = display.frame
                        RoundedRectangle(cornerRadius: 7).fill(Color(nsColor: .windowBackgroundColor))
                            .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.primary.opacity(0.25), lineWidth: 1))
                            .overlay(Text(display.name).font(.system(size: 11, weight: .medium)).lineLimit(2).minimumScaleFactor(0.7).padding(8))
                            .frame(width: f.width * scale, height: f.height * scale)
                            .position(point(CGPoint(x: f.midX, y: f.midY)))
                    }
                    ForEach(hints) { hint in
                        RoundedRectangle(cornerRadius: 7).fill(remoteColor.opacity(0.07))
                            .overlay(RoundedRectangle(cornerRadius: 7).stroke(remoteColor.opacity(0.65), style: StrokeStyle(lineWidth: 1.5, dash: [5, 3])))
                            .overlay(VStack(spacing: 4) {
                                Text("通用控制对端").font(.system(size: 11, weight: .semibold)).foregroundStyle(remoteColor)
                                Text("示意 · 非实际比例").font(.system(size: 9)).foregroundStyle(.secondary)
                            }.lineLimit(1).minimumScaleFactor(0.7).padding(6))
                            .frame(width: hint.frame.width * scale, height: hint.frame.height * scale)
                            .position(point(CGPoint(x: hint.frame.midX, y: hint.frame.midY)))
                            .help("这里表示该通道通向的另一台 Mac 或 iPad；远端屏幕尺寸和设备名称尚未读取。")
                    }
                    ForEach(portals) { portal in
                        if let display = displays.first(where: { $0.id == portal.displayID }) {
                            let rect = portal.rect(on: display, thickness: 4 / scale)
                            StyleStripSample(appearance: preferences.appearance(for: portal), vertical: portal.edge.vertical)
                                .frame(width: max(4, rect.width * scale), height: max(4, rect.height * scale))
                                .position(point(CGPoint(x: rect.midX, y: rect.midY)))
                                .help("\(portal.edge.title) → \(portal.label)")
                        }
                    }
                }
            } else {
                Text("等待系统显示器信息…").foregroundStyle(.secondary).frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }.accessibilityElement(children: .ignore)
            .accessibilityLabel("屏幕排列预览，\(displays.count) 块本机屏幕，\(hints.count) 处通用控制对端示意，\(portals.count) 段边缘标记")
    }
}
