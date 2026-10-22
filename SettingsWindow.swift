import AppKit

@MainActor
final class SettingsWindow: NSWindowController {
    private let length = NSPopUpButton()
    private let width = NSPopUpButton()
    private let rate = NSPopUpButton()
    private let mainOnly = NSButton(checkboxWithTitle: "仅在主显示器触发", target: nil, action: nil)
    private let lengths = [180, 300, 450, 600]
    private let widths = [3, 5, 8, 12]
    private let changed: () -> Void

    init(changed: @escaping () -> Void) {
        self.changed = changed
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 440, height: 255),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "上一个应用切换器 · 设置"
        window.isReleasedWhenClosed = false
        super.init(window: window)
        length.addItems(withTitles: lengths.map { "\($0) 点" })
        width.addItems(withTitles: widths.map { "\($0) 点" })
        rate.addItems(withTitles: ["极速 · 每秒检查120次", "节能 · 每秒检查60次"])
        for control in [length, width, rate] {
            control.target = self
            control.action = #selector(update)
        }
        mainOnly.target = self
        mainOnly.action = #selector(update)
        let reset = NSButton(title: "重置区域与响应", target: self, action: #selector(reset))
        let grid = NSGridView(views: [
            [NSTextField(labelWithString: "区域长度"), length],
            [NSTextField(labelWithString: "区域宽度"), width],
            [NSTextField(labelWithString: "响应模式"), rate],
            [NSGridCell.emptyContentView, mainOnly]
        ])
        grid.rowSpacing = 10
        grid.columnSpacing = 16
        let note = NSTextField(wrappingLabelWithString: "触发区域位于屏幕左侧中段。共享边缘会自动跳过，停留不会重复触发。更改立即生效。")
        note.textColor = .secondaryLabelColor
        let stack = NSStackView(views: [grid, note, reset])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 15
        stack.translatesAutoresizingMaskIntoConstraints = false
        window.contentView!.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor, constant: 22),
            stack.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor, constant: -22),
            stack.topAnchor.constraint(equalTo: window.contentView!.topAnchor, constant: 22)
        ])
        reload()
        window.center()
    }

    required init?(coder: NSCoder) { nil }

    func present() {
        reload()
        showWindow(nil)
        NSApp.activate()
    }

    private func reload() {
        length.selectItem(at: lengths.firstIndex(of: Int(Preferences.length)) ?? 1)
        width.selectItem(at: widths.firstIndex(of: Int(Preferences.width)) ?? 1)
        rate.selectItem(at: Preferences.rate == 120 ? 0 : 1)
        mainOnly.state = Preferences.mainDisplayOnly ? .on : .off
    }

    @objc private func update() {
        Preferences.defaults.set(lengths[length.indexOfSelectedItem], forKey: "zoneLength")
        Preferences.defaults.set(widths[width.indexOfSelectedItem], forKey: "zoneWidth")
        Preferences.defaults.set(rate.indexOfSelectedItem == 0 ? 120 : 60, forKey: "pollingRate")
        Preferences.defaults.set(mainOnly.state == .on, forKey: "mainDisplayOnly")
        changed()
    }

    @objc private func reset() {
        Preferences.resetRegion()
        reload()
        changed()
    }
}
