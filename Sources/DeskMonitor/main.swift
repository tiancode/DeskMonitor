import AppKit
import ServiceManagement
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {

    private let engine = MetricsEngine()
    private var window: WidgetWindow!
    private var statusItem: NSStatusItem?
    private var isAdjustingFrame = false
    private var pendingOriginSave: DispatchWorkItem?
    private let defaults = UserDefaults.standard

    private var layer: WindowLayer {
        get { WindowLayer(rawValue: defaults.integer(forKey: "windowLayer")) ?? .desktop }
        set { defaults.set(newValue.rawValue, forKey: "windowLayer"); applyLayer() }
    }

    /// nil = 自由摆放（用户手动拖过）
    private var corner: WindowCorner? {
        get { WindowCorner(rawValue: defaults.object(forKey: "snapCorner") as? Int ?? -1) }
        set {
            defaults.set(newValue?.rawValue ?? -1, forKey: "snapCorner")
            if newValue != nil { snapToCorner() }
        }
    }

    private var opacity: Double {
        get { defaults.object(forKey: "opacity") as? Double ?? 1.0 }
        set { defaults.set(newValue, forKey: "opacity"); window.alphaValue = newValue }
    }

    /// 默认不占菜单栏；面板上右键就是同一个菜单
    private var showsStatusItem: Bool {
        get { defaults.bool(forKey: "showsStatusItem") }
        set { defaults.set(newValue, forKey: "showsStatusItem"); refreshStatusItem() }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildWindow()
        attachContextMenu()
        refreshStatusItem()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }

    func applicationWillTerminate(_ notification: Notification) {
        guard let pending = pendingOriginSave else { return }
        pending.cancel()
        savePosition()
    }

    // MARK: - 窗口

    private func buildWindow() {
        let content = DashboardView(engine: engine)
        let hosting = NSHostingView(rootView: content)
        hosting.frame.size = hosting.fittingSize

        window = WidgetWindow(contentRect: NSRect(origin: .zero, size: hosting.fittingSize),
                              styleMask: [.borderless, .fullSizeContentView],
                              backing: .buffered,
                              defer: false)
        window.contentView = hosting
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.isMovableByWindowBackground = true
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenNone]
        window.alphaValue = opacity

        restorePosition()
        applyLayer()
        window.orderFrontRegardless()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil)

        // didMove 不管窗口被谁移动都会发，是唯一可靠的拖动信号（见 WidgetWindow）
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidMove),
            name: NSWindow.didMoveNotification,
            object: window)
    }

    /// 程序自己挪窗口期间要屏蔽 didMove，否则吸附动作会被当成用户拖拽
    private func moveWindow(to origin: NSPoint) {
        isAdjustingFrame = true
        window.setFrameOrigin(origin)
        isAdjustingFrame = false
    }

    @objc private func windowDidMove() {
        guard !isAdjustingFrame else { return }

        // 用户拖过，解除吸附。只在还吸附着时写，免得一次拖动反复写同一个值
        if defaults.integer(forKey: "snapCorner") != -1 {
            defaults.set(-1, forKey: "snapCorner")
        }

        // 一次拖动会连发上百次 didMove，位置攒到停手之后写一次
        pendingOriginSave?.cancel()
        let save = DispatchWorkItem { [weak self] in self?.savePosition() }
        pendingOriginSave = save
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: save)
    }

    private func savePosition() {
        pendingOriginSave = nil
        savedOrigin = window.frame.origin
    }

    /// 只持久化位置，不持久化尺寸——面板高度由内容决定，会随布局改动而变。
    private var savedOrigin: NSPoint? {
        get {
            guard let values = defaults.array(forKey: "panelOrigin") as? [Double],
                  values.count == 2 else { return nil }
            return NSPoint(x: values[0], y: values[1])
        }
        set {
            guard let newValue else { return defaults.removeObject(forKey: "panelOrigin") }
            defaults.set([newValue.x, newValue.y], forKey: "panelOrigin")
        }
    }

    /// 吸附模式下把窗口贴回选定的角；自由摆放时什么也不做。
    private func snapToCorner() {
        guard let corner, let screen = window.screen ?? NSScreen.main else { return }
        moveWindow(to: corner.origin(for: window.frame.size, in: screen.visibleFrame))
    }

    private func restorePosition() {
        guard corner == nil else { return snapToCorner() }
        guard let savedOrigin else { return corner = .topRight }
        moveWindow(to: savedOrigin)
        ensureOnScreen()
    }

    /// 拔掉显示器后存下的坐标可能整个落在屏幕外，那就拉回右上角
    private func ensureOnScreen() {
        guard !NSScreen.screens.contains(where: { $0.visibleFrame.intersects(window.frame) }) else { return }
        corner = .topRight
    }

    @objc private func screensChanged() {
        corner == nil ? ensureOnScreen() : snapToCorner()
    }

    private func applyLayer() {
        window.level = layer.level
    }

    // MARK: - 菜单栏

    /// 面板右键菜单——菜单栏图标关掉时，这是唯一入口
    private func attachContextMenu() {
        let menu = NSMenu()
        menu.delegate = self
        window.contextMenu = menu
    }

    private func refreshStatusItem() {
        guard showsStatusItem else {
            if let statusItem { NSStatusBar.system.removeStatusItem(statusItem) }
            statusItem = nil
            // 面板右键成了唯一入口，绝不能让它同时是隐藏的，否则只能重启应用
            if !window.isVisible { window.orderFrontRegardless() }
            return
        }
        guard statusItem == nil else { return }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "gauge.with.dots.needle.bottom.50percent",
                                     accessibilityDescription: L("System Monitor"))
            ?? NSImage(systemSymbolName: "gauge", accessibilityDescription: L("System Monitor"))
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        statusItem = item
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        // 没有菜单栏图标时不提供“隐藏面板”——藏了就再也叫不出来了
        if showsStatusItem {
            let toggle = NSMenuItem(title: window.isVisible ? L("Hide Panel") : L("Show Panel"),
                                    action: #selector(toggleWindow), keyEquivalent: "")
            toggle.target = self
            menu.addItem(toggle)
            menu.addItem(.separator())
        }

        let layerMenu = NSMenu()
        for option in WindowLayer.allCases {
            let item = NSMenuItem(title: option.title, action: #selector(selectLayer(_:)), keyEquivalent: "")
            item.target = self
            item.tag = option.rawValue
            item.state = option == layer ? .on : .off
            layerMenu.addItem(item)
        }
        let layerRoot = NSMenuItem(title: L("Window Level"), action: nil, keyEquivalent: "")
        layerRoot.submenu = layerMenu
        menu.addItem(layerRoot)

        let intervalMenu = NSMenu()
        for value in [0.5, 1.0, 2.0, 5.0] {
            let item = NSMenuItem(title: L("%@ s", String(format: "%.1f", value)),
                                  action: #selector(selectInterval(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = value
            item.state = abs(engine.interval - value) < 0.01 ? .on : .off
            intervalMenu.addItem(item)
        }
        let intervalRoot = NSMenuItem(title: L("Refresh Interval"), action: nil, keyEquivalent: "")
        intervalRoot.submenu = intervalMenu
        menu.addItem(intervalRoot)

        let opacityMenu = NSMenu()
        for value in [0.5, 0.7, 0.85, 1.0] {
            let item = NSMenuItem(title: "\(Int(value * 100))%",
                                  action: #selector(selectOpacity(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = value
            item.state = abs(opacity - value) < 0.01 ? .on : .off
            opacityMenu.addItem(item)
        }
        let opacityRoot = NSMenuItem(title: L("Opacity"), action: nil, keyEquivalent: "")
        opacityRoot.submenu = opacityMenu
        menu.addItem(opacityRoot)

        menu.addItem(.separator())

        let cornerMenu = NSMenu()
        for option in WindowCorner.allCases {
            let item = NSMenuItem(title: option.title, action: #selector(selectCorner(_:)), keyEquivalent: "")
            item.target = self
            item.tag = option.rawValue
            item.state = option == corner ? .on : .off
            cornerMenu.addItem(item)
        }
        cornerMenu.addItem(.separator())
        let free = NSMenuItem(title: L("Free Placement"), action: #selector(clearCorner), keyEquivalent: "")
        free.target = self
        free.state = corner == nil ? .on : .off
        cornerMenu.addItem(free)

        let cornerRoot = NSMenuItem(title: L("Snap Position"), action: nil, keyEquivalent: "")
        cornerRoot.submenu = cornerMenu
        menu.addItem(cornerRoot)

        let statusToggle = NSMenuItem(title: L("Show Menu Bar Icon"),
                                      action: #selector(toggleStatusItem), keyEquivalent: "")
        statusToggle.target = self
        statusToggle.state = showsStatusItem ? .on : .off
        menu.addItem(statusToggle)

        let login = NSMenuItem(title: L("Launch at Login"), action: #selector(toggleLoginItem), keyEquivalent: "")
        login.target = self
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)

        menu.addItem(.separator())
        let quit = NSMenuItem(title: L("Quit"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
    }

    // MARK: - 菜单动作

    @objc private func toggleWindow() {
        if window.isVisible {
            window.orderOut(nil)
        } else {
            window.orderFrontRegardless()
        }
    }

    @objc private func selectLayer(_ sender: NSMenuItem) {
        guard let option = WindowLayer(rawValue: sender.tag) else { return }
        layer = option
    }

    @objc private func selectInterval(_ sender: NSMenuItem) {
        guard let value = sender.representedObject as? Double else { return }
        engine.interval = value
    }

    @objc private func selectOpacity(_ sender: NSMenuItem) {
        guard let value = sender.representedObject as? Double else { return }
        opacity = value
    }

    @objc private func selectCorner(_ sender: NSMenuItem) {
        corner = WindowCorner(rawValue: sender.tag)
        window.orderFrontRegardless()
    }

    @objc private func toggleStatusItem() {
        showsStatusItem.toggle()
    }

    @objc private func clearCorner() {
        corner = nil
    }

    @objc private func toggleLoginItem() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSLog("Login item toggle failed: \(error.localizedDescription)")
        }
    }
}

if CommandLine.arguments.contains("--probe") {
    Probe.run()
    exit(0)
}

let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.setActivationPolicy(.accessory)
application.run()
