import AppKit
import TouchBarPrivate

@MainActor
final class PersistentTouchBarController: NSObject {
    static let trayIdentifier = NSTouchBarItem.Identifier("dev.commitpet.touchbar.tray")

    private let model: PetModel
    private var trayItem: NSCustomTouchBarItem?
    private var expandedBar: NSTouchBar?
    private var expandedController: PetTouchBarController?

    init(model: PetModel) {
        self.model = model
        super.init()
    }

    @discardableResult
    func install() -> Bool {
        uninstall()

        let item = NSCustomTouchBarItem(identifier: Self.trayIdentifier)
        item.customizationLabel = "Persistent Boo"
        let button = NSButton(title: "👻", target: self, action: #selector(showExpandedBar))
        button.isBordered = false
        button.font = .systemFont(ofSize: 18)
        button.toolTip = "Open Commit Pet"
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 42)
        ])

        item.view = button
        trayItem = item
        CPTouchBarSetCloseBoxVisible(false)
        let installed = CPTouchBarAddSystemTrayItem(item)
        CPTouchBarSetControlStripPresence(Self.trayIdentifier.rawValue, true)
        return installed
    }

    func uninstall() {
        if let expandedBar { CPTouchBarDismissSystemModal(expandedBar) }
        CPTouchBarSetControlStripPresence(Self.trayIdentifier.rawValue, false)
        if let trayItem { CPTouchBarRemoveSystemTrayItem(trayItem) }
        expandedBar = nil
        expandedController = nil
        trayItem = nil
    }

    @objc func showExpandedBar() {
        let controller = PetTouchBarController(model: model) { [weak self] in
            self?.collapseExpandedBar()
        }
        let bar = controller.makeTouchBar()
        expandedController = controller
        expandedBar = bar
        _ = CPTouchBarPresentSystemModal(bar, Self.trayIdentifier.rawValue)
    }

    /// Closes the expanded bar and puts the 👻 icon back. On recent macOS both
    /// minimizing and dismissing the system modal drop the Control Strip icon, so
    /// reinstall it the same way a fresh launch does once the animation finishes.
    func collapseExpandedBar() {
        if let expandedBar { CPTouchBarDismissSystemModal(expandedBar) }
        expandedBar = nil
        expandedController = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.install()
        }
    }

    /// macOS can also drop the icon when the frontmost app changes; re-assert it.
    func reassertPresence() {
        guard trayItem != nil, expandedBar == nil else { return }
        CPTouchBarSetControlStripPresence(Self.trayIdentifier.rawValue, true)
    }
}
