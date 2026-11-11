import AppKit

@MainActor
final class PetTouchBarController: NSObject, NSTouchBarDelegate {
    static let petIdentifier = NSTouchBarItem.Identifier("dev.commitpet.touchbar.pet")
    static let statsIdentifier = NSTouchBarItem.Identifier("dev.commitpet.touchbar.stats")
    static let activityIdentifier = NSTouchBarItem.Identifier("dev.commitpet.touchbar.activity")
    static let refreshIdentifier = NSTouchBarItem.Identifier("dev.commitpet.touchbar.refresh")

    private let model: PetModel
    private let ghostView = PixelGhostView(frame: NSRect(x: 0, y: 0, width: 110, height: 30))
    private let statsLabel = NSTextField(labelWithString: "")
    private let activityLabel = NSTextField(labelWithString: "")
    nonisolated(unsafe) private var observer: NSObjectProtocol?

    init(model: PetModel) {
        self.model = model
        super.init()
        ghostView.isCompact = true
        observer = NotificationCenter.default.addObserver(
            forName: .commitPetStatsDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.update() }
        }
        update()
    }

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
    }

    func makeTouchBar() -> NSTouchBar {
        let bar = NSTouchBar()
        bar.delegate = self
        bar.customizationIdentifier = NSTouchBar.CustomizationIdentifier("dev.commitpet.touchbar")
        bar.defaultItemIdentifiers = [Self.petIdentifier, Self.statsIdentifier, Self.activityIdentifier, .flexibleSpace, Self.refreshIdentifier]
        bar.customizationAllowedItemIdentifiers = bar.defaultItemIdentifiers
        bar.customizationRequiredItemIdentifiers = [Self.petIdentifier, Self.statsIdentifier]
        bar.principalItemIdentifier = Self.petIdentifier
        return bar
    }

    func touchBar(_ touchBar: NSTouchBar, makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        switch identifier {
        case Self.petIdentifier:
            let item = NSCustomTouchBarItem(identifier: identifier)
            let button = NSButton(title: "", target: self, action: #selector(petBoo))
            button.isBordered = false
            button.addSubview(ghostView)
            ghostView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                ghostView.leadingAnchor.constraint(equalTo: button.leadingAnchor),
                ghostView.trailingAnchor.constraint(equalTo: button.trailingAnchor),
                ghostView.topAnchor.constraint(equalTo: button.topAnchor),
                ghostView.bottomAnchor.constraint(equalTo: button.bottomAnchor),
                button.widthAnchor.constraint(equalToConstant: 110)
            ])
            item.view = button
            item.customizationLabel = "Boo"
            return item

        case Self.statsIdentifier:
            let item = NSCustomTouchBarItem(identifier: identifier)
            statsLabel.alignment = .center
            statsLabel.font = .monospacedSystemFont(ofSize: 12, weight: .medium)
            statsLabel.textColor = .labelColor
            item.view = statsLabel
            item.customizationLabel = "Commit Pet stats"
            return item

        case Self.activityIdentifier:
            let item = NSCustomTouchBarItem(identifier: identifier)
            activityLabel.alignment = .center
            activityLabel.font = .systemFont(ofSize: 11, weight: .medium)
            activityLabel.textColor = .secondaryLabelColor
            item.view = activityLabel
            item.customizationLabel = "Top GitHub repository"
            return item

        case Self.refreshIdentifier:
            let item = NSCustomTouchBarItem(identifier: identifier)
            item.view = NSButton(title: "↻", target: self, action: #selector(refresh))
            item.customizationLabel = "Refresh Commit Pet"
            return item

        default:
            return nil
        }
    }

    private func update() {
        ghostView.mood = model.stats.mood
        statsLabel.stringValue = "Lv\(model.stats.level)  🔥\(model.stats.streak)  🌱\(model.stats.todayCount)"
        activityLabel.stringValue = model.activity.compactText
    }

    @objc private func petBoo() {
        ghostView.celebrating = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in self?.ghostView.celebrating = false }
    }

    @objc private func refresh() {
        Task { await model.refresh() }
    }
}

@MainActor
final class PetViewController: NSViewController {
    private let model: PetModel
    private let touchBarController: PetTouchBarController
    private let ghostView = PixelGhostView(frame: .zero)
    private let titleLabel = NSTextField(labelWithString: "")
    private let statsLabel = NSTextField(labelWithString: "")
    private let statusLabel = NSTextField(labelWithString: "")
    private let activityLabel = NSTextField(wrappingLabelWithString: "")
    private var observers: [NSObjectProtocol] = []

    init(model: PetModel) {
        self.model = model
        self.touchBarController = PetTouchBarController(model: model)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { nil }

    override func loadView() {
        let root = NSView(frame: NSRect(x: 0, y: 0, width: 480, height: 280))
        root.wantsLayer = true
        root.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        ghostView.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 24, weight: .bold)
        statsLabel.font = .monospacedSystemFont(ofSize: 15, weight: .medium)
        statsLabel.textColor = .secondaryLabelColor
        statusLabel.font = .systemFont(ofSize: 12)
        statusLabel.textColor = .tertiaryLabelColor
        statusLabel.lineBreakMode = .byTruncatingTail
        activityLabel.font = .systemFont(ofSize: 13, weight: .medium)
        activityLabel.textColor = .secondaryLabelColor
        activityLabel.maximumNumberOfLines = 3

        let textStack = NSStackView(views: [titleLabel, statsLabel, activityLabel, statusLabel])
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 10
        textStack.translatesAutoresizingMaskIntoConstraints = false

        let refreshButton = NSButton(title: "Refresh now", target: self, action: #selector(refresh))
        refreshButton.bezelStyle = .rounded
        refreshButton.translatesAutoresizingMaskIntoConstraints = false

        root.addSubview(ghostView)
        root.addSubview(textStack)
        root.addSubview(refreshButton)

        NSLayoutConstraint.activate([
            ghostView.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 24),
            ghostView.topAnchor.constraint(equalTo: root.topAnchor, constant: 24),
            ghostView.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -24),
            ghostView.widthAnchor.constraint(equalToConstant: 190),

            textStack.leadingAnchor.constraint(equalTo: ghostView.trailingAnchor, constant: 22),
            textStack.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -24),
            textStack.centerYAnchor.constraint(equalTo: root.centerYAnchor, constant: -18),

            refreshButton.leadingAnchor.constraint(equalTo: textStack.leadingAnchor),
            refreshButton.topAnchor.constraint(equalTo: textStack.bottomAnchor, constant: 20)
        ])

        view = root
        update()

        observers.append(NotificationCenter.default.addObserver(
            forName: .commitPetStatsDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in Task { @MainActor in self?.update(celebrate: true) } })
    }

    override func makeTouchBar() -> NSTouchBar? { touchBarController.makeTouchBar() }

    private func update(celebrate: Bool = false) {
        let stats = model.stats
        ghostView.mood = stats.mood
        titleLabel.stringValue = "\(stats.name) · Lv \(stats.level) · \(stats.mood.symbol) \(stats.mood.displayName)"
        statsLabel.stringValue = "🔥 \(stats.streak) streak    🌱 \(stats.todayCount) today\n\(stats.total) contributions this year"
        activityLabel.stringValue = model.activity.report
        statusLabel.stringValue = model.statusMessage
        if celebrate {
            ghostView.celebrating = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in self?.ghostView.celebrating = false }
        }
    }

    @objc private func refresh() { Task { await model.refresh(); update() } }
}

/// Providing the bar from the key window is more reliable than relying on the
/// content view controller to become the first responder. AppKit checks the key
/// window near the beginning of its Touch Bar provider search.
@MainActor
final class PetWindow: NSWindow {
    private let petViewController: PetViewController

    init(petViewController: PetViewController) {
        self.petViewController = petViewController
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 280),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        contentViewController = petViewController
    }

    override func makeTouchBar() -> NSTouchBar? {
        petViewController.makeTouchBar()
    }

    func reinstallTouchBar() {
        touchBar = nil
        touchBar = makeTouchBar()
        makeFirstResponder(contentViewController?.view)
    }
}
