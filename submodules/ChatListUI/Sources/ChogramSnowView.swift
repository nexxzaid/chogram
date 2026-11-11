import Foundation
import UIKit
import Display
import TelegramCore

final class ChogramSnowView: UIView {
    private let emitterLayer = CAEmitterLayer()
    private var validSize: CGSize?
    private var isDark: Bool?
    private var isPaused: Bool = false

    private static let flakeSide: CGFloat = 8.0

    // A soft round dot: opaque core fading to transparent at the edge.
    private static let flakeImage: UIImage? = generateImage(CGSize(width: flakeSide, height: flakeSide), contextGenerator: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        let colors: [CGColor] = [
            UIColor(white: 1.0, alpha: 1.0).cgColor,
            UIColor(white: 1.0, alpha: 0.85).cgColor,
            UIColor(white: 1.0, alpha: 0.0).cgColor
        ]
        guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0.0, 0.4, 1.0]) else {
            return
        }
        let center = CGPoint(x: size.width / 2.0, y: size.height / 2.0)
        context.drawRadialGradient(gradient, startCenter: center, startRadius: 0.0, endCenter: center, endRadius: size.width / 2.0, options: [])
    })

    override init(frame: CGRect) {
        super.init(frame: frame)

        self.isUserInteractionEnabled = false
        self.backgroundColor = nil
        self.isOpaque = false
        self.clipsToBounds = true

        self.emitterLayer.emitterShape = .line
        self.emitterLayer.renderMode = .unordered
        // Without this the layer "catches up" and dumps a burst of flakes on first display.
        self.emitterLayer.beginTime = CACurrentMediaTime()
        self.layer.addSublayer(self.emitterLayer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // Three depth layers: small far flakes drift slowly, bigger near flakes fall faster.
    private static func makeCells(isDark: Bool, height: CGFloat) -> [CAEmitterCell] {
        guard let image = ChogramSnowView.flakeImage, let cgImage = image.cgImage else {
            return []
        }
        // Pure white is invisible on a light list, so tint the flakes slightly grey-blue there.
        let tint = isDark ? UIColor(white: 1.0, alpha: 1.0) : UIColor(red: 0.60, green: 0.68, blue: 0.80, alpha: 1.0)

        let specs: [(scale: CGFloat, scaleRange: CGFloat, velocity: CGFloat, velocityRange: CGFloat, alpha: CGFloat, birthRate: Float)] = [
            (0.32, 0.08, 20.0, 6.0, 0.45, 1.6),
            (0.5, 0.12, 30.0, 8.0, 0.65, 1.2),
            (0.68, 0.08, 40.0, 10.0, 0.8, 0.5)
        ]

        var cells: [CAEmitterCell] = []
        for spec in specs {
            let cell = CAEmitterCell()
            cell.contents = cgImage
            // One unit of the image is one point, so scale 1.0 is a flakeSide-sized flake.
            cell.contentsScale = image.scale
            cell.birthRate = spec.birthRate
            // Long enough to reach the bottom at the slowest speed, with a margin.
            cell.lifetime = Float(ceil((height + 40.0) / max(1.0, spec.velocity - spec.velocityRange)))
            cell.velocity = spec.velocity
            cell.velocityRange = spec.velocityRange
            cell.emissionLongitude = CGFloat.pi / 2.0
            cell.emissionRange = CGFloat.pi / 14.0
            cell.scale = spec.scale
            cell.scaleRange = spec.scaleRange
            cell.alphaRange = 0.25
            cell.color = tint.withAlphaComponent(spec.alpha).cgColor
            cells.append(cell)
        }
        return cells
    }

    func update(size: CGSize, isDark: Bool) {
        if self.validSize == size && self.isDark == isDark {
            return
        }
        let heightChanged = self.validSize?.height != size.height
        self.validSize = size

        if self.isDark != isDark || heightChanged || self.emitterLayer.emitterCells == nil {
            self.isDark = isDark
            self.emitterLayer.emitterCells = ChogramSnowView.makeCells(isDark: isDark, height: size.height)
        }

        self.emitterLayer.frame = CGRect(origin: CGPoint(), size: size)
        self.emitterLayer.emitterPosition = CGPoint(x: size.width / 2.0, y: -ChogramSnowView.flakeSide)
        self.emitterLayer.emitterSize = CGSize(width: size.width, height: 1.0)
        // Keep the density per point of width constant across phones and tablets.
        self.emitterLayer.birthRate = Float(max(0.5, size.width / 390.0))
    }

    // Freezes the emitter in place while the list is offscreen and resumes without a gap.
    func setPaused(_ paused: Bool) {
        if self.isPaused == paused {
            return
        }
        self.isPaused = paused
        if paused {
            let pausedTime = self.emitterLayer.convertTime(CACurrentMediaTime(), from: nil)
            self.emitterLayer.speed = 0.0
            self.emitterLayer.timeOffset = pausedTime
        } else {
            let pausedTime = self.emitterLayer.timeOffset
            self.emitterLayer.speed = 1.0
            self.emitterLayer.timeOffset = 0.0
            self.emitterLayer.beginTime = 0.0
            let timeSincePause = self.emitterLayer.convertTime(CACurrentMediaTime(), from: nil) - pausedTime
            self.emitterLayer.beginTime = timeSincePause
        }
    }
}

extension ChatListControllerNode {
    // Called on every layout pass and when the settings change.
    func updateChogramSnow(size: CGSize? = nil) {
        let isEnabled = ChogramSettings.current.snow && !UIAccessibility.isReduceMotionEnabled && self.isChogramSnowAllowed
        if !isEnabled {
            if let snowView = self.chogramSnowView {
                snowView.removeFromSuperview()
                self.chogramSnowView = nil
            }
            return
        }

        let snowView: ChogramSnowView
        if let current = self.chogramSnowView {
            snowView = current
        } else {
            snowView = ChogramSnowView(frame: CGRect())
            self.chogramSnowView = snowView
        }
        // Above the chat rows, below search results, the header and the toolbar.
        if snowView.superview !== self.view {
            self.view.insertSubview(snowView, aboveSubview: self.mainContainerNode.view)
        }
        let size = size ?? self.currentContainerLayoutSize ?? self.bounds.size
        if size.width.isZero || size.height.isZero {
            return
        }
        snowView.frame = CGRect(origin: CGPoint(), size: size)
        snowView.update(size: size, isDark: self.chogramSnowIsDark)
    }
}
