import AppKit
import TouchBarPrivate

@MainActor
final class PersistentTouchBarController: NSObject {
    static let trayIdentifier = NSTouchBarItem.Identifier("dev.commitpet.touchbar.tray")

    private let model: PetModel
    private var trayItem: NSCustomTouchBarItem?
    private var expandedBar: NSTouchBar?
    private var expandedController: PetTouchBarController?
    private var trayGhost: PixelGhostView?
    nonisolated(unsafe) private var observer: NSObjectProtocol?

    init(model: PetModel) {
        self.model = model
        super.init()
        observer = NotificationCenter.default.addObserver(
            forName: .commitPetStatsDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.update() }
        }
    }

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
    }

    @discardableResult
    func install() -> Bool {
        uninstall()

        let item = NSCustomTouchBarItem(identifier: Self.trayIdentifier)
        item.customizationLabel = "Persistent Boo"
        let button = NSButton(title: "", target: self, action: #selector(showExpandedBar))
        button.isBordered = false
        button.toolTip = "Open Commit Pet"

        let ghost = PixelGhostView(frame: NSRect(x: 0, y: 0, width: 42, height: 30))
        ghost.isCompact = true
        ghost.mood = model.stats.mood
        ghost.translatesAutoresizingMaskIntoConstraints = false
        button.addSubview(ghost)
        NSLayoutConstraint.activate([
            ghost.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            ghost.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            ghost.topAnchor.constraint(equalTo: button.topAnchor),
            ghost.bottomAnchor.constraint(equalTo: button.bottomAnchor),
            button.widthAnchor.constraint(equalToConstant: 42)
        ])

        item.view = button
        trayItem = item
        trayGhost = ghost
        CPTouchBarSetCloseBoxVisible(false)
        return CPTouchBarAddSystemTrayItem(item)
    }

    func uninstall() {
        if let expandedBar { CPTouchBarDismissSystemModal(expandedBar) }
        if let trayItem { CPTouchBarRemoveSystemTrayItem(trayItem) }
        expandedBar = nil
        expandedController = nil
        trayItem = nil
        trayGhost = nil
    }

    @objc func showExpandedBar() {
        let controller = PetTouchBarController(model: model)
        let bar = controller.makeTouchBar()
        expandedController = controller
        expandedBar = bar
        _ = CPTouchBarPresentSystemModal(bar, Self.trayIdentifier.rawValue)
    }

    private func update() {
        trayGhost?.mood = model.stats.mood
    }
}
