import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private let model = PetModel()
    private let oauthClient = GitHubOAuthClient()
    private lazy var persistentTouchBar = PersistentTouchBarController(model: model)
    private lazy var desktopPet = DesktopPetController(model: model)
    private var window: NSWindow?
    private var statusItem: NSStatusItem?
    private var githubAccountItem: NSMenuItem?
    private var authenticationTask: Task<Void, Never>?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        NSApp.isAutomaticCustomizeTouchBarMenuItemEnabled = true
        installMenuBarItem()
        _ = persistentTouchBar.install()
        model.start()
        restoreGitHubLogin()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationWillTerminate(_ notification: Notification) {
        authenticationTask?.cancel()
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
        let inboxText = model.inbox.unreadCount > 0
            ? "\n\nGitHub inbox: \(model.inbox.unreadCount) unread\n\(model.inbox.latestDescription ?? "")"
            : GitHubCredentialStore.loadToken() != nil ? "\n\nGitHub inbox: clear" : ""
        alert.informativeText = model.activity.report + inboxText
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc private func openProfile() {
        NSWorkspace.shared.open(URL(string: "https://github.com/\(model.username)")!)
    }

    @objc private func manageGitHubAccount() {
        if GitHubCredentialStore.loadToken() != nil {
            let login = UserDefaults.standard.string(forKey: "githubAuthenticatedLogin") ?? "GitHub"
            let alert = NSAlert()
            alert.messageText = "Connected as @\(login)"
            alert.informativeText = "Boo can read your GitHub notification inbox. The token is stored in macOS Keychain."
            alert.addButton(withTitle: "Keep Connected")
            alert.addButton(withTitle: "Disconnect")
            if alert.runModal() == .alertSecondButtonReturn {
                disconnectGitHub()
            }
            return
        }

        guard let clientID = configuredClientID() else { return }
        authenticationTask?.cancel()
        authenticationTask = Task { [weak self] in
            await self?.connectGitHub(clientID: clientID)
        }
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
        let accountItem = menu.addItem(
            withTitle: "Connect GitHub…",
            action: #selector(manageGitHubAccount),
            keyEquivalent: ""
        )
        githubAccountItem = accountItem
        menu.addItem(withTitle: "Open GitHub profile", action: #selector(openProfile), keyEquivalent: "g")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Commit Pet", action: #selector(quit), keyEquivalent: "q")
        menu.items.forEach { $0.target = self }
        item.menu = menu
        statusItem = item
    }

    private func restoreGitHubLogin() {
        guard GitHubCredentialStore.loadToken() != nil else {
            updateGitHubMenu()
            offerGitHubLoginIfNeeded()
            return
        }
        authenticationTask = Task { [weak self] in
            guard let self else { return }
            do {
                if let login = try await self.oauthClient.validateStoredToken() {
                    UserDefaults.standard.set(login, forKey: "githubAuthenticatedLogin")
                }
            } catch {
                GitHubCredentialStore.deleteToken()
                UserDefaults.standard.removeObject(forKey: "githubAuthenticatedLogin")
            }
            self.updateGitHubMenu()
        }
    }

    private func offerGitHubLoginIfNeeded() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: "hasOfferedGitHubLogin") else { return }
        defaults.set(true, forKey: "hasOfferedGitHubLogin")
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            NSApp.activate(ignoringOtherApps: true)
            let alert = NSAlert()
            alert.messageText = "Let Boo watch your GitHub inbox?"
            alert.informativeText = "Connect GitHub to receive Boo messages for mentions, comments, review requests, and assignments. Commit Pet will not mark notifications as read."
            alert.addButton(withTitle: "Connect GitHub")
            alert.addButton(withTitle: "Not Now")
            if alert.runModal() == .alertFirstButtonReturn {
                self.manageGitHubAccount()
            }
        }
    }

    private func configuredClientID() -> String? {
        if let saved = UserDefaults.standard.string(forKey: "githubOAuthClientID"),
           !saved.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return saved
        }

        let alert = NSAlert()
        alert.messageText = "Set up GitHub sign-in once"
        alert.informativeText = """
        Commit Pet needs the public Client ID from an OAuth App you own.

        Create an OAuth App, enable “Device Flow” in its settings, then paste its Client ID below. No client secret is needed.
        """
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 360, height: 24))
        field.placeholderString = "GitHub OAuth Client ID"
        alert.accessoryView = field
        alert.addButton(withTitle: "Continue")
        alert.addButton(withTitle: "Create OAuth App")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        if response == .alertSecondButtonReturn {
            NSWorkspace.shared.open(URL(string: "https://github.com/settings/applications/new")!)
            return promptForClientID()
        }
        guard response == .alertFirstButtonReturn else { return nil }
        return saveClientID(field.stringValue)
    }

    private func promptForClientID() -> String? {
        let alert = NSAlert()
        alert.messageText = "Paste the OAuth App Client ID"
        alert.informativeText = """
        Use any Homepage URL and callback URL (for example, https://github.com). After creating the app, enable Device Flow on its settings page.
        """
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 360, height: 24))
        field.placeholderString = "GitHub OAuth Client ID"
        alert.accessoryView = field
        alert.addButton(withTitle: "Connect")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        return saveClientID(field.stringValue)
    }

    private func saveClientID(_ rawValue: String) -> String? {
        let clientID = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clientID.isEmpty else {
            showError("The Client ID cannot be empty.")
            return nil
        }
        UserDefaults.standard.set(clientID, forKey: "githubOAuthClientID")
        return clientID
    }

    private func connectGitHub(clientID: String) async {
        githubAccountItem?.title = "GitHub: Requesting code…"
        githubAccountItem?.isEnabled = false
        defer { githubAccountItem?.isEnabled = true }

        do {
            let authorization = try await oauthClient.begin(clientID: clientID)
            guard showDeviceCode(authorization) else {
                throw GitHubAuthenticationError.cancelled
            }
            githubAccountItem?.title = "GitHub: Waiting for approval…"
            let login = try await oauthClient.finish(clientID: clientID, authorization: authorization)
            updateGitHubMenu()
            NotificationCenter.default.post(name: .githubAuthenticationDidChange, object: login)
            await model.refresh()

            let alert = NSAlert()
            alert.messageText = "Boo is connected to GitHub"
            alert.informativeText = "Signed in as @\(login). Boo can now read your unread GitHub notifications."
            alert.addButton(withTitle: "Done")
            alert.runModal()
        } catch GitHubAuthenticationError.cancelled {
            updateGitHubMenu()
        } catch {
            updateGitHubMenu()
            showAuthenticationError(error.localizedDescription)
        }
    }

    private func showDeviceCode(_ authorization: GitHubDeviceAuthorization) -> Bool {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(authorization.userCode, forType: .string)

        let alert = NSAlert()
        alert.messageText = "Your GitHub code is \(authorization.userCode)"
        alert.informativeText = "The code has been copied. GitHub will open in your browser; paste the code there and approve Commit Pet."
        alert.addButton(withTitle: "Open GitHub")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return false }
        NSWorkspace.shared.open(authorization.verificationURL)
        return true
    }

    private func disconnectGitHub() {
        GitHubCredentialStore.deleteToken()
        UserDefaults.standard.removeObject(forKey: "githubAuthenticatedLogin")
        updateGitHubMenu()
        NotificationCenter.default.post(name: .githubAuthenticationDidChange, object: nil)
        Task { await model.refresh() }
    }

    private func updateGitHubMenu() {
        if GitHubCredentialStore.loadToken() != nil {
            let login = UserDefaults.standard.string(forKey: "githubAuthenticatedLogin")
            githubAccountItem?.title = login.map { "GitHub: @\($0) ✓" } ?? "GitHub: Connected ✓"
        } else {
            githubAccountItem?.title = "Connect GitHub…"
        }
    }

    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "GitHub sign-in failed"
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func showAuthenticationError(_ message: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "GitHub sign-in failed"
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Change Client ID")
        if alert.runModal() == .alertSecondButtonReturn {
            UserDefaults.standard.removeObject(forKey: "githubOAuthClientID")
            manageGitHubAccount()
        }
    }
}
