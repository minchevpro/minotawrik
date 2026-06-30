import Cocoa

/// Manages the menu-bar (status item) icon and its dropdown menu.
final class StatusBarController {
    private let statusItem: NSStatusItem

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "mic.circle", accessibilityDescription: "Vector Dictate")
        }
        statusItem.menu = buildMenu()
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        let dictateItem = NSMenuItem(title: "Начать диктовку", action: #selector(startDictation), keyEquivalent: "")
        dictateItem.target = self
        menu.addItem(dictateItem)

        menu.addItem(.separator())

        let historyItem = NSMenuItem(title: "История…", action: #selector(showHistory), keyEquivalent: "")
        historyItem.target = self
        menu.addItem(historyItem)

        let settingsItem = NSMenuItem(title: "Настройки…", action: #selector(showSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Выйти из Vector Dictate", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }

    @objc private func startDictation() {
        DictationPanelController.shared.toggleFromHotkey()
    }

    @objc private func showHistory() {
        HistoryWindowController.shared.show()
    }

    @objc private func showSettings() {
        SettingsWindowController.shared.show()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
