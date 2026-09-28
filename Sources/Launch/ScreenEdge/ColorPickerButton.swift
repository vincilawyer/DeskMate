// SPDX-License-Identifier: MIT
// Adapted from vincilawyer/ScreenEdge, commit 7e418d6352b5a839bd01f4b723f54f3f4d5d9e1c.
// Copyright (c) 2026 ScreenEdge contributors. See LICENSES/ScreenEdge-MIT.txt.
import AppKit

/// A quiet swatch button backed by the system color panel. The color well handles
/// panel ownership and change notifications, without drawing its heavy bezel.
final class ColorPickerButton: NSButton {
    let well = NSColorWell(style: .minimal)
    override init(frame: NSRect) {
        super.init(frame: frame)
        title = ""
        isBordered = false
        setButtonType(.momentaryPushIn)
        imagePosition = .imageOnly
        target = self
        action = #selector(showColorPanel)
        if #available(macOS 14.0, *) { well.supportsAlpha = false }
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
    @objc private func showColorPanel() {
        NSColorPanel.shared.showsAlpha = false
        well.activate(true)
        NSColorPanel.shared.makeKeyAndOrderFront(nil)
    }
    func updateSwatch(_ color: NSColor) {
        well.color = color
        image = NSImage(size: NSSize(width: 30, height: 26), flipped: false) { bounds in
            let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 2, dy: 2), xRadius: 5, yRadius: 5)
            color.setFill(); path.fill()
            NSColor.labelColor.withAlphaComponent(0.18).setStroke()
            path.lineWidth = 0.7; path.stroke()
            return true
        }
    }
}
