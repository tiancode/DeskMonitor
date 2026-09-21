import AppKit
import SwiftUI

/// 毛玻璃背景。SwiftUI 自带的 `Material` 在无边框透明窗口里拿不到 behindWindow 模糊，
/// 所以这里直接包一层 `NSVisualEffectView`。
struct VisualEffectView: NSViewRepresentable {

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        view.isEmphasized = false
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
