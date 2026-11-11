import AppKit

private final class SpeechBubbleView: NSView {
    override var isOpaque: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let tailHeight: CGFloat = 9
        let bodyRect = NSRect(
            x: 1.5,
            y: tailHeight + 1.5,
            width: bounds.width - 3,
            height: bounds.height - tailHeight - 3
        )
        let path = NSBezierPath(roundedRect: bodyRect, xRadius: 14, yRadius: 14)
        path.move(to: NSPoint(x: bounds.midX - 8, y: bodyRect.minY + 1))
        path.line(to: NSPoint(x: bounds.midX, y: 1.5))
        path.line(to: NSPoint(x: bounds.midX + 8, y: bodyRect.minY + 1))
        path.close()

        let dark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let fill = dark
            ? NSColor(calibratedWhite: 0.12, alpha: 0.96)
            : NSColor(calibratedWhite: 1, alpha: 0.96)

        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.18)
        shadow.shadowBlurRadius = 10
        shadow.shadowOffset = NSSize(width: 0, height: -3)
        shadow.set()
        fill.setFill()
        path.fill()

        NSGraphicsContext.current?.saveGraphicsState()
        NSShadow().set()
        NSColor.separatorColor.withAlphaComponent(0.55).setStroke()
        path.lineWidth = 1
        path.stroke()
        NSGraphicsContext.current?.restoreGraphicsState()
    }
}

@MainActor
final class DesktopPetView: NSView {
    private enum Layout {
        static let petOnlySize = NSSize(width: 154, height: 126)
        static let maximumTextWidth: CGFloat = 238
        static let bubbleHorizontalPadding: CGFloat = 28
        static let bubbleVerticalPadding: CGFloat = 27
        static let bubbleToPetSpacing: CGFloat = 2
    }

    private let ghost = PixelGhostView(frame: .zero)
    private let bubble = SpeechBubbleView(frame: .zero)
    private let messageLabel = NSTextField(wrappingLabelWithString: "")
    private var hideWorkItem: DispatchWorkItem?
    private var bubbleSize = NSSize.zero
    private var bubbleRevision = 0
    var onPet: (() -> Void)?
    var onPreferredSizeChange: ((NSSize, Bool) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor

        bubble.wantsLayer = true
        bubble.isHidden = true

        messageLabel.font = .systemFont(ofSize: 13, weight: .medium)
        messageLabel.textColor = .labelColor
        messageLabel.alignment = .center
        messageLabel.maximumNumberOfLines = 0
        messageLabel.lineBreakMode = .byWordWrapping
        bubble.addSubview(messageLabel)

        let click = NSClickGestureRecognizer(target: self, action: #selector(petClicked))
        ghost.addGestureRecognizer(click)
        addSubview(bubble)
        addSubview(ghost)
    }

    required init?(coder: NSCoder) { nil }

    override func layout() {
        super.layout()
        let ghostSize = NSSize(width: 135, height: 118)
        ghost.frame = NSRect(
            x: (bounds.width - ghostSize.width) / 2,
            y: 2,
            width: ghostSize.width,
            height: ghostSize.height
        )

        guard !bubble.isHidden else { return }
        bubble.frame = NSRect(
            x: (bounds.width - bubbleSize.width) / 2,
            y: ghost.frame.maxY + Layout.bubbleToPetSpacing,
            width: bubbleSize.width,
            height: bubbleSize.height
        )
        messageLabel.frame = NSRect(
            x: Layout.bubbleHorizontalPadding / 2,
            y: 9 + Layout.bubbleVerticalPadding / 2,
            width: bubbleSize.width - Layout.bubbleHorizontalPadding,
            height: bubbleSize.height - Layout.bubbleVerticalPadding
        )
    }

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
        bubbleRevision += 1
        let revision = bubbleRevision
        messageLabel.stringValue = message
        bubbleSize = measuredBubbleSize(for: message)
        bubble.isHidden = false
        bubble.alphaValue = 1
        let size = NSSize(
            width: max(Layout.petOnlySize.width, bubbleSize.width + 18),
            height: Layout.petOnlySize.height + bubbleSize.height
        )
        onPreferredSizeChange?(size, true)
        needsLayout = true

        let workItem = DispatchWorkItem { [weak self] in
            self?.dismissMessage(ifRevision: revision)
        }
        hideWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: workItem)
    }

    func dismissMessage() {
        hideWorkItem?.cancel()
        bubbleRevision += 1
        dismissMessage(ifRevision: bubbleRevision)
    }

    private func dismissMessage(ifRevision revision: Int) {
        guard !bubble.isHidden, revision == bubbleRevision else { return }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.22
            bubble.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            Task { @MainActor in
                guard let self, revision == self.bubbleRevision else { return }
                self.bubble.isHidden = true
                self.onPreferredSizeChange?(Layout.petOnlySize, true)
            }
        }
    }

    private func measuredBubbleSize(for message: String) -> NSSize {
        let attributes: [NSAttributedString.Key: Any] = [.font: messageLabel.font!]
        let attributed = NSAttributedString(string: message, attributes: attributes)
        let measured = attributed.boundingRect(
            with: NSSize(width: Layout.maximumTextWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        ).integral.size
        let textWidth = min(Layout.maximumTextWidth, max(76, measured.width))
        return NSSize(
            width: ceil(textWidth + Layout.bubbleHorizontalPadding),
            height: ceil(max(47, measured.height + Layout.bubbleVerticalPadding))
        )
    }

    @objc private func petClicked() {
        if !bubble.isHidden {
            dismissMessage()
            return
        }
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
        let initialSize = NSSize(width: 154, height: 126)
        petView = DesktopPetView(frame: NSRect(origin: .zero, size: initialSize))
        window = NSPanel(
            contentRect: NSRect(origin: .zero, size: initialSize),
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

        petView.onPreferredSizeChange = { [weak self] size, animate in
            self?.resizeWindow(to: size, animate: animate)
        }
        petView.onPet = { [weak self] in
            guard let self else { return }
            let message = self.model.activity.latestDescription
                ?? "Boo is guarding your 🔥\(self.model.stats.streak) day streak."
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

        observers.append(NotificationCenter.default.addObserver(
            forName: .commitPetStreakReminder,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let message = note.object as? String else { return }
            Task { @MainActor in
                guard let self else { return }
                // Pop up even if desktop Boo was hidden; the bubble stays until clicked or ~5 minutes.
                self.window.orderFrontRegardless()
                self.petView.update(mood: .hungry)
                self.petView.showMessage(message, duration: 300)
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

    private func resizeWindow(to size: NSSize, animate: Bool) {
        let oldFrame = window.frame
        var newFrame = NSRect(
            x: oldFrame.midX - size.width / 2,
            y: oldFrame.minY,
            width: size.width,
            height: size.height
        )
        if let visibleFrame = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame {
            newFrame.origin.x = min(max(newFrame.minX, visibleFrame.minX), visibleFrame.maxX - newFrame.width)
            newFrame.origin.y = min(max(newFrame.minY, visibleFrame.minY), visibleFrame.maxY - newFrame.height)
        }
        window.setFrame(newFrame, display: true, animate: animate)
    }

    private func positionInitially() {
        guard let frame = NSScreen.main?.visibleFrame else { return }
        window.setFrameOrigin(NSPoint(x: frame.maxX - window.frame.width - 28, y: frame.minY + 32))
    }
}
