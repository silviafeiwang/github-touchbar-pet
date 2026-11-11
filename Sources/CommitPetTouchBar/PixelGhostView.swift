import AppKit

final class PixelGhostView: NSView {
    var mood: PetMood = .content { didSet { needsDisplay = true } }
    var isCompact = false { didSet { needsDisplay = true } }
    var celebrating = false

    private var phase: CGFloat = 0
    nonisolated(unsafe) private var animationTimer: Timer?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 12.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.phase += self.celebrating ? 0.34 : 0.16
                self.needsDisplay = true
            }
        }
    }

    required init?(coder: NSCoder) { nil }

    deinit { animationTimer?.invalidate() }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.setShouldAntialias(false)

        let bounce = sin(phase) * (celebrating ? 4 : 1.5)
        let targetSize = min(bounds.height * 0.78, bounds.width * (isCompact ? 0.52 : 0.7))
        let pixel = max(1, floor(targetSize / 12))
        let bodyWidth = pixel * 10
        let bodyHeight = pixel * 10
        let origin = CGPoint(
            x: bounds.midX - bodyWidth / 2,
            y: bounds.midY - bodyHeight / 2 + bounce
        )

        let bodyColor: NSColor = switch mood {
        case .happy: NSColor(calibratedRed: 0.72, green: 0.63, blue: 1.0, alpha: 1)
        case .content: NSColor(calibratedRed: 0.59, green: 0.50, blue: 0.92, alpha: 1)
        case .hungry: NSColor(calibratedRed: 0.48, green: 0.43, blue: 0.67, alpha: 1)
        case .sick: NSColor(calibratedRed: 0.52, green: 0.55, blue: 0.62, alpha: 1)
        }

        func block(_ x: Int, _ y: Int, _ width: Int = 1, _ height: Int = 1, color: NSColor) {
            color.setFill()
            NSRect(
                x: origin.x + CGFloat(x) * pixel,
                y: origin.y + CGFloat(y) * pixel,
                width: CGFloat(width) * pixel,
                height: CGFloat(height) * pixel
            ).fill()
        }

        block(2, 1, 6, 1, color: bodyColor)
        block(1, 2, 8, 1, color: bodyColor)
        block(0, 3, 10, 5, color: bodyColor)
        block(0, 8, 2, 1, color: bodyColor)
        block(3, 8, 2, 1, color: bodyColor)
        block(6, 8, 2, 1, color: bodyColor)
        block(9, 8, 1, 1, color: bodyColor)

        let eye = NSColor(calibratedWhite: 0.12, alpha: 1)
        switch mood {
        case .happy:
            block(2, 4, 2, 2, color: eye)
            block(6, 4, 2, 2, color: eye)
            block(3, 6, 4, 1, color: eye)
            block(1, 3, color: .white)
            block(8, 2, color: NSColor.systemPink)
        case .content:
            block(2, 4, 2, 2, color: eye)
            block(6, 4, 2, 2, color: eye)
            block(4, 6, 2, 1, color: eye)
        case .hungry:
            block(2, 5, 2, 1, color: eye)
            block(6, 5, 2, 1, color: eye)
            block(4, 7, 2, 1, color: eye)
            block(8, 4, color: NSColor.systemBlue)
        case .sick:
            for offset in 0..<2 {
                block(2 + offset, 4 + offset, color: eye)
                block(3 - offset, 4 + offset, color: eye)
                block(6 + offset, 4 + offset, color: eye)
                block(7 - offset, 4 + offset, color: eye)
            }
            block(3, 7, 2, 1, color: eye)
            block(5, 6, 2, 1, color: eye)
        }
    }
}
