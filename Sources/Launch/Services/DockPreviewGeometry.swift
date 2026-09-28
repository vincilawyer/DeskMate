import CoreGraphics

enum DockPreviewEdge: Equatable {
    case bottom, left, right
}

/// Shared dimensions keep the thumbnail, card and AppKit panel in agreement.
struct DockPreviewLayout {
    static let contentPadding: CGFloat = 14
    static let spacing: CGFloat = 12
    static let cardPadding: CGFloat = 6
    static let cardSpacing: CGFloat = 8
    static let headerHeight: CGFloat = 24
    static let titleHeight: CGFloat = 16
    static let footerHeight: CGFloat = 26
    static let scrollPadding: CGFloat = 3

    let cardWidth: CGFloat

    var thumbnailSize: CGSize {
        let width = cardWidth - Self.cardPadding * 2
        return CGSize(width: width, height: width * 10 / 16)
    }

    var scrollHeight: CGFloat {
        thumbnailSize.height + Self.titleHeight + Self.cardSpacing
            + Self.cardPadding * 2 + Self.scrollPadding * 2
    }

    func panelSize(windowCount: Int) -> CGSize {
        let count = CGFloat(max(1, min(3, windowCount)))
        return CGSize(
            width: cardWidth * count + Self.spacing * (count - 1) + Self.contentPadding * 2,
            height: Self.headerHeight + scrollHeight + Self.footerHeight
                + Self.spacing * 2 + Self.contentPadding * 2
        )
    }
}

enum DockPreviewGeometry {
    static func appKitRect(fromQuartz rect: CGRect, primaryScreenHeight: CGFloat) -> CGRect {
        CGRect(x: rect.minX, y: primaryScreenHeight - rect.maxY, width: rect.width, height: rect.height)
    }

    static func edge(iconFrame: CGRect, screenFrame: CGRect) -> DockPreviewEdge {
        let distances: [(DockPreviewEdge, CGFloat)] = [
            (.bottom, abs(iconFrame.midY - screenFrame.minY)),
            (.left, abs(iconFrame.midX - screenFrame.minX)),
            (.right, abs(iconFrame.midX - screenFrame.maxX))
        ]
        return distances.min { $0.1 < $1.1 }?.0 ?? .bottom
    }

    static func panelFrame(
        size: CGSize, iconFrame: CGRect, visibleFrame: CGRect, edge: DockPreviewEdge
    ) -> CGRect {
        let bounds = visibleFrame.insetBy(dx: 10, dy: 10)
        let width = min(size.width, bounds.width)
        let height = min(size.height, bounds.height)
        var origin: CGPoint
        switch edge {
        case .bottom:
            origin = CGPoint(x: iconFrame.midX - width / 2, y: max(iconFrame.maxY + 10, bounds.minY))
        case .left:
            origin = CGPoint(x: max(iconFrame.maxX + 10, bounds.minX), y: iconFrame.midY - height / 2)
        case .right:
            origin = CGPoint(x: min(iconFrame.minX - width - 10, bounds.maxX - width), y: iconFrame.midY - height / 2)
        }
        origin.x = min(max(origin.x, bounds.minX), bounds.maxX - width)
        origin.y = min(max(origin.y, bounds.minY), bounds.maxY - height)
        return CGRect(origin: origin, size: CGSize(width: width, height: height))
    }

    static func transitFrame(iconFrame: CGRect, panelFrame: CGRect, edge: DockPreviewEdge) -> CGRect {
        switch edge {
        case .bottom:
            return CGRect(
                x: min(iconFrame.minX, panelFrame.minX),
                y: iconFrame.maxY - 4,
                width: max(iconFrame.maxX, panelFrame.maxX) - min(iconFrame.minX, panelFrame.minX),
                height: max(0, panelFrame.minY - iconFrame.maxY) + 8
            )
        case .left:
            return CGRect(x: iconFrame.maxX - 4, y: panelFrame.minY,
                          width: max(0, panelFrame.minX - iconFrame.maxX) + 8, height: panelFrame.height)
        case .right:
            return CGRect(x: panelFrame.maxX - 4, y: panelFrame.minY,
                          width: max(0, iconFrame.minX - panelFrame.maxX) + 8, height: panelFrame.height)
        }
    }
}
