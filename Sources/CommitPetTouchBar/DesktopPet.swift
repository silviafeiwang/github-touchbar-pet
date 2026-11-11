import AppKit

@MainActor
final class DesktopPetView: NSView {
    private let ghost = PixelGhostView(frame: .zero)
    private let bubble = NSVisualEffectView(frame: .zero)
    private let messageLabel = NSTextField(wrappingLabelWithString: "")
    private var hideWorkItem: DispatchWorkItem?
    var onPet: (() -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor

        bubble.material = .popover
        bubble.blendingMode = .withinWindow
        bubble.state = .active
        bubble.wantsLayer = true
        bubble.layer?.cornerRadius = 13
        bubble.layer?.borderWidth = 1
        bubble.layer?.borderColor = NSColor.separatorColor.cgColor
        bubble.translatesAutoresizingMaskIntoConstraints = false

        messageLabel.font = .systemFont(ofSize: 12.5, weight: .medium)
        messageLabel.textColor = .labelColor
        messageLabel.alignment = .center
        messageLabel.maximumNumberOfLines = 4
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        bubble.addSubview(messageLabel)

        ghost.translatesAutoresizingMaskIntoConstraints = false
        let click = NSClickGestureRecognizer(target: self, action: #selector(petClicked))
        ghost.addGestureRecognizer(click)

        addSubview(bubble)
        addSubview(ghost)
        NSLayoutConstraint.activate([
            bubble.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            bubble.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            bubble.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            bubble.heightAnchor.constraint(greaterThanOrEqualToConstant: 62),

            messageLabel.leadingAnchor.constraint(equalTo: bubble.leadingAnchor, constant: 10),
            messageLabel.trailingAnchor.constraint(equalTo: bubble.trailingAnchor, constant: -10),
            messageLabel.topAnchor.constraint(equalTo: bubble.topAnchor, constant: 8),
            messageLabel.bottomAnchor.constraint(equalTo: bubble.bottomAnchor, constant: -8),

            ghost.centerXAnchor.constraint(equalTo: centerXAnchor),
            ghost.topAnchor.constraint(equalTo: bubble.bottomAnchor, constant: 4),
            ghost.bottomAnchor.constraint(equalTo: bottomAnchor),
            ghost.widthAnchor.constraint(equalToConstant: 135)
        ])
    }

    required init?(coder: NSCoder) { nil }

    func update(mood: PetMood) {
        ghost.mood = mood
    }

    func celebrate() {
        ghost.celebrating = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            self?.ghost.celebrating = false
        }
    }

    func showMessage(_ message: String, duration: TimeInterval = 12) {
        hideWorkItem?.cancel()
        messageLabel.stringValue = message
        bubble.isHidden = false
        bubble.alphaValue = 1

        let workItem = DispatchWorkItem { [weak self] in
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.35
                self?.bubble.animator().alphaValue = 0
            } completionHandler: { [weak self] in
                Task { @MainActor in self?.bubble.isHidden = true }
            }
        }
        hideWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: workItem)
    }

    @objc private func petClicked() {
        celebrate()
        onPet?()
    }
}

@MainActor
final class DesktopPetController {
    private let model: PetModel
    private let window: NSPanel
    private let petView: DesktopPetView
    nonisolated(unsafe) private var observers: [NSObjectProtocol] = []

    init(model: PetModel) {
        self.model = model
        petView = DesktopPetView(frame: NSRect(x: 0, y: 0, width: 250, height: 210))
        window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 250, height: 210),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        window.contentView = petView
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .floating
        window.hidesOnDeactivate = false
        window.isMovableByWindowBackground = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

        petView.onPet = { [weak self] in
            guard let self else { return }
            let message = self.model.activity.latestDescription
                ?? "Boo is watching your GitHub streak! 🔥\(self.model.stats.streak)"
            self.petView.showMessage(message)
        }

        observers.append(NotificationCenter.default.addObserver(
            forName: .commitPetStatsDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.petView.update(mood: self?.model.stats.mood ?? .content) }
        })
        observers.append(NotificationCenter.default.addObserver(
            forName: .commitPetMessage,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let message = note.object as? String else { return }
            Task { @MainActor in
                self?.petView.celebrate()
                self?.petView.showMessage(message)
            }
        })

        positionInitially()
        petView.update(mood: model.stats.mood)
    }

    deinit {
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
    }

    var isVisible: Bool { window.isVisible }

    func toggle() {
        isVisible ? hide() : show()
    }

    func show() {
        window.orderFrontRegardless()
        petView.showMessage(model.activity.report)
    }

    func hide() {
        window.orderOut(nil)
    }

    private func positionInitially() {
        guard let frame = NSScreen.main?.visibleFrame else { return }
        window.setFrameOrigin(NSPoint(x: frame.maxX - 280, y: frame.minY + 32))
    }
}
