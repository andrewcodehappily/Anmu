import Cocoa
import Carbon

final class Overlay: NSWindow {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

final class Dimmer: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let defaults = UserDefaults.standard
    var overlay: Overlay?
    var panel: NSWindow!
    var statusItem: NSStatusItem!
    let amount = NSSlider(value: 50, minValue: 0, maxValue: 95, target: nil, action: nil)
    let valueLabel = NSTextField(labelWithString: "")
    let stateLabel = NSTextField(labelWithString: localized("overlay.off"))
    let shortcutLabel = NSTextField(wrappingLabelWithString: "")
    let screens = NSPopUpButton(frame: .zero, pullsDown: false)
    let toggle = NSButton(checkboxWithTitle: localized("overlay.enable"), target: nil, action: nil)
    var enabled = false
    var applications: [NSRunningApplication] = []
    var selectedPID: pid_t?
    var trackingTimer: Timer?
    var hotkey: EventHotKeyRef?
    var handler: EventHandlerRef?
    var displayObserver: NSObjectProtocol?
    var wakeObserver: NSObjectProtocol?
    var activationObserver: NSObjectProtocol?
    var spaceObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        defaults.register(defaults: ["darkness": 50.0])
        amount.doubleValue = min(95, max(0, defaults.double(forKey: "darkness")))
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "◐"
        statusItem.button?.toolTip = localizedFormat("status.tooltip", localized("app.name"), localized("overlay.off"))
        let menu = NSMenu()
        menu.addItem(item(localized("menu.controls"), #selector(showPanel), ","))
        menu.addItem(item(localized("menu.toggle"), #selector(toggleMask), ""))
        menu.addItem(item(localized("brightness.restore"), #selector(disableMask), ""))
        menu.addItem(.separator())
        menu.addItem(item(localized("menu.quit"), #selector(quit), "q"))
        statusItem.menu = menu
        let main = NSMenu(); let root = NSMenuItem(); root.submenu = menu; main.addItem(root); NSApp.mainMenu = main
        buildPanel()
        refreshScreens()
        registerShortcut()
        displayObserver = NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            self?.disableMask(); self?.refreshScreens()
        }
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main) { [weak self] _ in self?.disableMask() }
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] _ in self?.trackTarget() }
        spaceObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main) { [weak self] _ in self?.trackTarget() }
        updateLabels(); showPanel()
    }
    func item(_ title: String, _ action: Selector, _ key: String) -> NSMenuItem {
        let result = NSMenuItem(title: title, action: action, keyEquivalent: key); result.target = self; return result
    }
    func buildPanel() {
        panel = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 500), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        panel.title = localized("app.name"); panel.isReleasedWhenClosed = false; panel.delegate = self
        panel.level = .normal
        let title = NSTextField(labelWithString: localized("panel.title"))
        title.font = .boldSystemFont(ofSize: 20)
        amount.target = self; amount.action = #selector(amountChanged)
        amount.isContinuous = true
        amount.setAccessibilityLabel(localized("dimming.label"))
        amount.widthAnchor.constraint(equalToConstant: 432).isActive = true
        screens.target = self; screens.action = #selector(screenChanged)
        screens.widthAnchor.constraint(equalToConstant: 432).isActive = true
        toggle.target = self; toggle.action = #selector(toggleMask)
        let restore = NSButton(title: localized("brightness.restore"), target: self, action: #selector(disableMask))
        let done = NSButton(title: localized("controls.hide"), target: self, action: #selector(hidePanel))
        let help = NSTextField(wrappingLabelWithString: localized("help"))
        help.widthAnchor.constraint(equalToConstant: 432).isActive = true
        shortcutLabel.widthAnchor.constraint(equalToConstant: 432).isActive = true
        let refresh = NSButton(title: localized("apps.refresh"), target: self, action: #selector(refreshApplications))
        let stack = NSStackView(views: [title, screens, refresh, valueLabel, amount, toggle, stateLabel, shortcutLabel, help, restore, done])
        stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 10; stack.translatesAutoresizingMaskIntoConstraints = false
        panel.contentView!.addSubview(stack)
        NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo: panel.contentView!.leadingAnchor, constant: 24), stack.trailingAnchor.constraint(equalTo: panel.contentView!.trailingAnchor, constant: -24), stack.topAnchor.constraint(equalTo: panel.contentView!.topAnchor, constant: 20), stack.bottomAnchor.constraint(lessThanOrEqualTo: panel.contentView!.bottomAnchor, constant: -20)])
        panel.center()
    }
    @objc func refreshApplications() { refreshScreens() }
    func refreshScreens() {
        disableMask()
        screens.removeAllItems()
        applications = NSWorkspace.shared.runningApplications.filter {
            $0.activationPolicy == .regular && $0.processIdentifier != ProcessInfo.processInfo.processIdentifier
        }.sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }
        for application in applications { screens.addItem(withTitle: application.localizedName ?? application.bundleIdentifier ?? localized("app.unnamed")) }
        let saved = defaults.string(forKey: "targetApp") ?? ""
        let index = applications.firstIndex(where: { $0.bundleIdentifier == saved }) ?? 0
        selectedPID = applications.indices.contains(index) ? applications[index].processIdentifier : nil
        if selectedPID != nil { screens.selectItem(at: index) }
        toggle.isEnabled = selectedPID != nil
    }
    @objc func screenChanged() {
        disableMask()
        guard applications.indices.contains(screens.indexOfSelectedItem) else { return }
        let application = applications[screens.indexOfSelectedItem]
        selectedPID = application.processIdentifier
        defaults.set(application.bundleIdentifier, forKey: "targetApp")
    }
    func targetRect() -> NSRect? {
        guard let pid = selectedPID,
              let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else { return nil }
        for window in windows {
            guard (window[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == pid,
                  (window[kCGWindowLayer as String] as? NSNumber)?.intValue == 0,
                  let dictionary = window[kCGWindowBounds as String] as? NSDictionary,
                  let rect = CGRect(dictionaryRepresentation: dictionary), rect.width > 40, rect.height > 40 else { continue }
            let top = NSScreen.screens.first?.frame.maxY ?? 0
            return NSRect(x: rect.minX, y: top - rect.maxY, width: rect.width, height: rect.height)
        }
        return nil
    }
    func trackTarget() {
        guard enabled, let overlay else { return }
        let front = NSWorkspace.shared.frontmostApplication?.processIdentifier
        guard front == selectedPID,
              let rect = targetRect() else { overlay.orderOut(nil); return }
        if overlay.frame != rect { overlay.setFrame(rect, display: true) }
        overlay.orderFrontRegardless()
    }
    @objc func amountChanged() {
        defaults.set(amount.doubleValue, forKey: "darkness")
        overlay?.alphaValue = amount.doubleValue / 100
        updateLabels()
    }
    func updateLabels() {
        valueLabel.stringValue = localizedFormat("dimming.value", Int(amount.doubleValue.rounded()))
        stateLabel.stringValue = enabled ? localized("overlay.on") : localized("overlay.off")
        toggle.state = enabled ? .on : .off
        statusItem.button?.title = enabled ? "●" : "◐"
        statusItem.button?.toolTip = localizedFormat("status.tooltip", localized("app.name"), stateLabel.stringValue)
    }
    @objc func toggleMask() {
        if enabled { disableMask(); return }
        guard selectedPID != nil else { return }
        let rect = targetRect() ?? .zero
        let window = Overlay(contentRect: rect, styleMask: [.borderless], backing: .buffered, defer: false)
        window.setFrame(rect, display: false)
        window.backgroundColor = .black; window.isOpaque = false; window.hasShadow = false
        window.ignoresMouseEvents = true
        window.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue - 1)
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        // 允許遮罩加入其他 App 的全螢幕 Space；控制台不套用此行為。
        if #available(macOS 13.0, *) { window.collectionBehavior.insert(.canJoinAllApplications) }
        window.alphaValue = amount.doubleValue / 100
        window.isReleasedWhenClosed = false
        overlay = window; enabled = true; trackTarget(); updateLabels()
        let timer = Timer(timeInterval: 0.15, repeats: true) { [weak self] _ in self?.trackTarget() }
        trackingTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }
    @objc func disableMask() { trackingTimer?.invalidate(); trackingTimer = nil; overlay?.orderOut(nil); overlay = nil; enabled = false; updateLabels() }
    @objc func showPanel() { panel.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true) }
    @objc func hidePanel() { panel.orderOut(nil); if let pid = selectedPID { NSRunningApplication(processIdentifier: pid)?.activate(options: []) } }
    @objc func quit() { disableMask(); NSApp.terminate(nil) }
    func windowShouldClose(_ sender: NSWindow) -> Bool { panel.orderOut(nil); return false }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showPanel(); return true }
    func registerShortcut() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let result = InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let context else { return OSStatus(eventNotHandledErr) }
            Unmanaged<Dimmer>.fromOpaque(context).takeUnretainedValue().toggleMask()
            return noErr
        }, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), &handler)
        let registered = result == noErr ? RegisterEventHotKey(UInt32(kVK_ANSI_D), UInt32(controlKey | optionKey | cmdKey), EventHotKeyID(signature: 0x44494D52, id: 1), GetApplicationEventTarget(), 0, &hotkey) : result
        shortcutLabel.stringValue = registered == noErr ? localized("shortcut.ready") : localizedFormat("shortcut.failed", registered)
    }
    func applicationWillTerminate(_ notification: Notification) {
        overlay?.orderOut(nil)
        if let hotkey { UnregisterEventHotKey(hotkey) }
        if let handler { RemoveEventHandler(handler) }
        if let displayObserver { NotificationCenter.default.removeObserver(displayObserver) }
        if let wakeObserver { NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver) }
        if let activationObserver { NSWorkspace.shared.notificationCenter.removeObserver(activationObserver) }
        if let spaceObserver { NSWorkspace.shared.notificationCenter.removeObserver(spaceObserver) }
    }
}
let app = NSApplication.shared
let delegate = Dimmer()
app.setActivationPolicy(.accessory)
app.delegate = delegate
app.run()
