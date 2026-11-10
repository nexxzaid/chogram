import Foundation
import UIKit
import TelegramCore

final class ChogramSnowView: UIView {
    private let emitterLayer = CAEmitterLayer()
    private static let flakeImage: CGImage? = {
        let size = CGSize(width: 10.0, height: 10.0)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            let colors = [UIColor(white: 1.0, alpha: 1.0).cgColor, UIColor(white: 1.0, alpha: 0.0).cgColor] as CFArray
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0.0, 1.0]) {
                let center = CGPoint(x: size.width / 2.0, y: size.height / 2.0)
                context.cgContext.drawRadialGradient(gradient, startCenter: center, startRadius: 0.0, endCenter: center, endRadius: size.width / 2.0, options: [])
            }
        }
        return image.cgImage
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        self.isUserInteractionEnabled = false
        self.clipsToBounds = true
        
        let cell = CAEmitterCell()
        cell.contents = ChogramSnowView.flakeImage
        cell.birthRate = 3.0
        cell.lifetime = 7.0
        cell.velocity = 20.0
        cell.velocityRange = 8.0
        cell.emissionLongitude = CGFloat.pi / 2.0
        cell.emissionRange = CGFloat.pi / 8.0
        cell.scale = 0.7
        cell.scaleRange = 0.4
        cell.alphaSpeed = -0.08
        cell.color = UIColor(red: 0.78, green: 0.88, blue: 1.0, alpha: 0.75).cgColor
        
        self.emitterLayer.emitterShape = .line
        self.emitterLayer.emitterCells = [cell]
        self.layer.addSublayer(self.emitterLayer)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func updateLayout(size: CGSize) {
        self.emitterLayer.frame = CGRect(origin: CGPoint(), size: size)
        self.emitterLayer.emitterPosition = CGPoint(x: size.width / 2.0, y: -4.0)
        self.emitterLayer.emitterSize = CGSize(width: size.width, height: 1.0)
    }
}

extension ChatListControllerNode {
    // Called on every layout of the header and when the settings change.
    func updateChogramSnow(headerSize: CGSize? = nil) {
        let isEnabled = ChogramSettings.current.snow && !UIAccessibility.isReduceMotionEnabled
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
        guard let navigationBarView = self.navigationBarView.view else {
            return
        }
        let size = headerSize ?? navigationBarView.bounds.size
        if snowView.superview !== self.view {
            self.view.insertSubview(snowView, aboveSubview: navigationBarView)
        }
        snowView.frame = CGRect(origin: CGPoint(), size: size)
        snowView.updateLayout(size: size)
    }
}
