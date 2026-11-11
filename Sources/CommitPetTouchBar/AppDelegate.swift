import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private let model = PetModel()
    private lazy var persistentTouchBar = PersistentTouchBarController(model: model)
    private lazy var desktopPet = DesktopPetController(model: model)
    private var window: NSWindow?
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        NSApp.isAutomaticCustomizeTouchBarMenuItemEnabled = true
        installMenuBarItem()
        _ = persistentTouchBar.install()
        model.start()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationWillTerminate(_ notification: Notification) {
        persistentTouchBar.uninstall()
    }

    @objc private func showWindow() {
        NSApp.setActivationPolicy(.regular)
        if window == nil {
            let controller = PetViewController(model: model)
            let newWindow = PetWindow(petViewController: controller)
            newWindow.title = "Commit Pet — Boo"
            newWindow.setContentSize(NSSize(width: 480, height: 280))
            newWindow.styleMask = [.titled, .closable, .miniaturizable]
            newWindow.isReleasedWhenClosed = false
            newWindow.delegate = self
            newWindow.center()
            window = newWindow
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        (window as? PetWindow)?.reinstallTouchBar()
    }

    func windowWillClose(_ notification: Notification) {
        DispatchQueue.main.async { NSApp.setActivationPolicy(.accessory) }
    }

    @objc private func toggleDesktopBoo() { desktopPet.toggle() }

    @objc private func refresh() { Task { await model.refresh() } }

    @objc private func reinstallTouchBar() {
        showWindow()
        (window as? PetWindow)?.reinstallTouchBar()
    }

    @objc private func restorePersistentBoo() {
        if persistentTouchBar.install() {
            persistentTouchBar.showExpandedBar()
        }
    }

    @objc private func hidePersistentBoo() { persistentTouchBar.uninstall() }

    @objc private func showActivityReport() {
        let alert = NSAlert()
        alert.messageText = "Boo’s GitHub report"
        alert.informativeText = model.activity.report
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc private func openProfile() {
        NSWorkspace.shared.open(URL(string: "https://github.com/\(model.username)")!)
    }

    @objc private func quit() { NSApp.terminate(nil) }

    private func installMenuBarItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "👻"
        let menu = NSMenu()
        menu.addItem(withTitle: "Show or hide desktop Boo", action: #selector(toggleDesktopBoo), keyEquivalent: "b")
        menu.addItem(withTitle: "Open dashboard", action: #selector(showWindow), keyEquivalent: "d")
        menu.addItem(withTitle: "Reinstall Touch Bar Boo", action: #selector(reinstallTouchBar), keyEquivalent: "t")
        menu.addItem(withTitle: "Restore persistent Boo", action: #selector(restorePersistentBoo), keyEquivalent: "p")
        menu.addItem(withTitle: "Hide persistent Boo", action: #selector(hidePersistentBoo), keyEquivalent: "")
        menu.addItem(withTitle: "Refresh GitHub activity", action: #selector(refresh), keyEquivalent: "r")
        menu.addItem(withTitle: "Show GitHub activity report", action: #selector(showActivityReport), keyEquivalent: "a")
        menu.addItem(withTitle: "Open GitHub profile", action: #selector(openProfile), keyEquivalent: "g")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Commit Pet", action: #selector(quit), keyEquivalent: "q")
        menu.items.forEach { $0.target = self }
        item.menu = menu
        statusItem = item
    }
}
