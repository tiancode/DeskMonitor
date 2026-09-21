import AppKit

/// 无边框窗口默认不能成为 key window，这里放开。
///
/// `mouseDown` 里的 `performDrag` 只是兜底：面板由 SwiftUI 承载，事件未必传得到
/// NSWindow，拖动主要靠 `isMovableByWindowBackground`。位置变化以 didMove 通知为准。
final class WidgetWindow: NSWindow {

    var contextMenu: NSMenu?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func mouseDown(with event: NSEvent) {
        performDrag(with: event)
    }

    override func rightMouseDown(with event: NSEvent) {
        guard let contextMenu, let contentView else { return }
        contextMenu.popUp(positioning: nil, at: event.locationInWindow, in: contentView)
    }
}

/// 悬浮层级：贴桌面（被其它窗口遮住）/ 普通 / 始终置顶
enum WindowLayer: Int, CaseIterable {

    case desktop = 0
    case normal = 1
    case floating = 2

    var title: String {
        switch self {
        case .desktop: return L("On Desktop")
        case .normal: return L("Normal Window")
        case .floating: return L("Always on Top")
        }
    }

    var level: NSWindow.Level {
        switch self {
        case .desktop: return NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
        case .normal: return .normal
        case .floating: return .floating
        }
    }
}

/// 吸附到屏幕四角；选定后换显示器、改分辨率都会重新贴回去。
enum WindowCorner: Int, CaseIterable {

    case topLeft = 0
    case topRight = 1
    case bottomLeft = 2
    case bottomRight = 3

    var title: String {
        switch self {
        case .topLeft: return L("Top Left")
        case .topRight: return L("Top Right")
        case .bottomLeft: return L("Bottom Left")
        case .bottomRight: return L("Bottom Right")
        }
    }

    func origin(for size: NSSize, in visible: NSRect, margin: CGFloat = 24) -> NSPoint {
        let left = visible.minX + margin
        let right = visible.maxX - size.width - margin
        let top = visible.maxY - size.height - margin
        let bottom = visible.minY + margin
        switch self {
        case .topLeft: return NSPoint(x: left, y: top)
        case .topRight: return NSPoint(x: right, y: top)
        case .bottomLeft: return NSPoint(x: left, y: bottom)
        case .bottomRight: return NSPoint(x: right, y: bottom)
        }
    }
}
