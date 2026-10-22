import AppKit
import Darwin

@MainActor
final class Switcher: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var recentApps: [NSRunningApplication] = []
    private var observers: [NSObjectProtocol] = []
    private var pointerTimer: Timer?
    private var insideEdge = false
    private var sessionActive = true
    private var screenObserver: NSObjectProtocol?
    private var zones = TriggerZones(screens: [], length: 300, width: 5, mainOnly: false)
    private var statusItem: NSStatusItem!
    private var pauseItem: NSMenuItem!
    private var loginItem: NSMenuItem!
    private var menuOpen = false
    private var settingsWindow: SettingsWindow?
    private let service = "gui/\(getuid())/local.taixu.previous-app-switcher"
    private let showSettingsNotification = Notification.Name("local.taixu.previous-app-switcher.show-settings")
    private var instanceLock: Int32 = -1

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        guard acquireInstanceLock() else { return }
        DistributedNotificationCenter.default().addObserver(
            self, selector: #selector(receiveShowSettings(_:)), name: showSettingsNotification, object: nil
        )
        Preferences.register()
        createMenu()
        record(NSWorkspace.shared.frontmostApplication)
        updateConfiguration()
        let center = NSWorkspace.shared.notificationCenter
        observers.append(center.addObserver(forName: NSWorkspace.didActivateApplicationNotification,
                                             object: nil, queue: .main) { [weak self] event in
            let app = event.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            MainActor.assumeIsolated { self?.record(app) }
        })
        observers.append(center.addObserver(forName: NSWorkspace.sessionDidResignActiveNotification,
                                             object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.sessionActive = false }
        })
        for name in [NSWorkspace.sessionDidBecomeActiveNotification, NSWorkspace.didWakeNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.sessionActive = true
                    self?.updateConfiguration()
                    self?.record(NSWorkspace.shared.frontmostApplication)
                }
            })
        }
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.updateConfiguration() }
        }
    }

    private func acquireInstanceLock() -> Bool {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("local.taixu.previous-app-switcher.lock").path
        instanceLock = Darwin.open(path, O_CREAT | O_RDWR | O_CLOEXEC, S_IRUSR | S_IWUSR)
        guard instanceLock >= 0 else {
            Self.showStartupError()
            NSApp.terminate(nil)
            return false
        }
        if flock(instanceLock, LOCK_EX | LOCK_NB) != 0 {
            DistributedNotificationCenter.default().postNotificationName(
                showSettingsNotification, object: nil, userInfo: nil, deliverImmediately: true
            )
            NSApp.terminate(nil)
            return false
        }
        return true
    }

    private static func showStartupError() {
        let alert = NSAlert()
        alert.messageText = "未能建立单实例保护"
        alert.informativeText = "请检查当前用户临时目录是否可写，然后重新打开工具。"
        alert.runModal()
    }

    @objc private func receiveShowSettings(_ notification: Notification) { showSettings() }

    private func updateConfiguration() {
        pointerTimer?.invalidate()
        pointerTimer = nil
        zones = TriggerZones(screens: NSScreen.screens.map(\.frame), length: Preferences.length,
                             width: Preferences.width, mainOnly: Preferences.mainDisplayOnly)
        insideEdge = isInLeftZone(NSEvent.mouseLocation)
        pauseItem.title = Preferences.enabled ? "暂停切换" : "恢复切换"
        statusItem.button?.image = NSImage(systemSymbolName: Preferences.enabled ? "arrow.uturn.backward" : "pause.circle",
                                          accessibilityDescription: "上一个应用切换器")
        statusItem.button?.toolTip = Preferences.enabled ? "上一个应用切换器：运行中" : "上一个应用切换器：已暂停"
        guard Preferences.enabled else { return }
        // App-dispatched mouse events can be absent at a window/screen boundary.
        // Poll the pointer itself so triggering does not depend on the app underneath it.
        let timer = Timer(timeInterval: 1.0 / Double(Preferences.rate), repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.mouseMoved() }
        }
        timer.tolerance = 0.001
        RunLoop.main.add(timer, forMode: .common)
        pointerTimer = timer
    }

    private func record(_ app: NSRunningApplication?) {
        recentApps.removeAll { $0.isTerminated }
        guard let app, app.activationPolicy == .regular,
              app.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return }
        recentApps.removeAll { $0.processIdentifier == app.processIdentifier }
        recentApps.insert(app, at: 0)
        if recentApps.count > 20 { recentApps.removeLast() }
    }

    private func isInLeftZone(_ point: NSPoint) -> Bool {
        zones.contains(point)
    }

    private func mouseMoved() {
        let wasInside = insideEdge
        insideEdge = isInLeftZone(NSEvent.mouseLocation)
        guard sessionActive, !menuOpen, insideEdge, !wasInside,
              NSEvent.pressedMouseButtons == 0 else { return }
        switchToPreviousApp()
    }

    private func switchToPreviousApp() {
        let current = NSWorkspace.shared.frontmostApplication
        record(current)
        guard let previous = recentApps.first(where: {
            !$0.isTerminated && $0.processIdentifier != current?.processIdentifier
        }) else { return }
        if previous.isHidden { previous.unhide() }
        previous.activate(options: [])
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings()
        return false
    }

    private func createMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let menu = NSMenu()
        menu.delegate = self
        let title = NSMenuItem(title: "上一个应用切换器", action: nil, keyEquivalent: "")
        menu.addItem(title)
        menu.addItem(.separator())
        pauseItem = NSMenuItem(title: "暂停切换", action: #selector(togglePause), keyEquivalent: "")
        menu.addItem(pauseItem)
        menu.addItem(NSMenuItem(title: "设置…", action: #selector(showSettings), keyEquivalent: ""))
        loginItem = NSMenuItem(title: "登录后启动", action: #selector(toggleLogin), keyEquivalent: "")
        menu.addItem(loginItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "退出", action: #selector(quit), keyEquivalent: ""))
        for item in menu.items where item.action != nil { item.target = self }
        statusItem.menu = menu
    }

    func menuWillOpen(_ menu: NSMenu) {
        menuOpen = true
        loginItem.state = loginEnabled() ? .on : .off
    }

    func menuDidClose(_ menu: NSMenu) {
        menuOpen = false
        insideEdge = isInLeftZone(NSEvent.mouseLocation)
    }

    @objc private func togglePause() {
        Preferences.defaults.set(!Preferences.enabled, forKey: "enabled")
        updateConfiguration()
    }

    @objc private func showSettings() {
        if settingsWindow == nil {
            settingsWindow = SettingsWindow { [weak self] in self?.updateConfiguration() }
        }
        settingsWindow?.present()
    }

    private func launchctl(_ arguments: [String]) -> (Int32, String) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        task.arguments = arguments
        let output = Pipe()
        task.standardOutput = output
        task.standardError = FileHandle.nullDevice
        do {
            try task.run()
            let data = output.fileHandleForReading.readDataToEndOfFile()
            task.waitUntilExit()
            return (task.terminationStatus, String(decoding: data, as: UTF8.self))
        } catch { return (-1, "") }
    }

    private var agentExists: Bool {
        let agent = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/local.taixu.previous-app-switcher.plist")
        return FileManager.default.fileExists(atPath: agent.path)
    }

    private func loginEnabled() -> Bool {
        guard agentExists else { return false }
        let output = launchctl(["print-disabled", "gui/\(getuid())"]).1
        let line = output.split(separator: "\n").first { $0.contains("\"local.taixu.previous-app-switcher\"") }
        return !(line?.contains("disabled") == true || line?.contains("=> true") == true)
    }

    @objc private func toggleLogin() {
        if !agentExists || launchctl([loginEnabled() ? "disable" : "enable", service]).0 != 0 {
            let alert = NSAlert()
            alert.messageText = "未能更改登录启动设置"
            alert.informativeText = "请确认已通过安装脚本安装本工具。"
            alert.runModal()
        }
        loginItem.state = loginEnabled() ? .on : .off
    }

    @objc private func quit() {
        // Removing this login-session job prevents KeepAlive from immediately reopening us.
        if launchctl(["print", service]).0 == 0 {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/bin/launchctl")
            task.arguments = ["bootout", service]
            task.standardOutput = FileHandle.nullDevice
            task.standardError = FileHandle.nullDevice
            task.terminationHandler = { task in
                if task.terminationStatus != 0 {
                    DispatchQueue.main.async { Self.showQuitError() }
                }
            }
            do { try task.run() } catch { Self.showQuitError() }
        } else {
            NSApp.terminate(nil)
        }
    }

    private static func showQuitError() {
        let alert = NSAlert()
        alert.messageText = "未能停止后台服务"
        alert.informativeText = "请稍后重试，或通过卸载脚本停止本工具。"
        alert.runModal()
    }

    func applicationWillTerminate(_ notification: Notification) {
        DistributedNotificationCenter.default().removeObserver(self)
        if instanceLock >= 0 { Darwin.close(instanceLock) }
        pointerTimer?.invalidate()
        if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }
        for observer in observers { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
    }
}
