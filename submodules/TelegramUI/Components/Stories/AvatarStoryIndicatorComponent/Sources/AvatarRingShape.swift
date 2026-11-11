import Foundation
import UIKit

/// Outline geometry shared by every ring drawn around an avatar (story indicator, progress, masks).
/// `cornerRadius` nil is a circle and keeps the upstream paths byte for byte; a value is a rounded square.
public enum AvatarRingShape {
    private static func clampedRadius(_ cornerRadius: CGFloat, rect: CGRect) -> CGFloat {
        return max(0.0, min(cornerRadius, min(rect.width, rect.height) * 0.5))
    }

    /// The closed outline of `rect`.
    public static func path(rect: CGRect, cornerRadius: CGFloat?) -> CGPath {
        if let cornerRadius {
            return UIBezierPath(roundedRect: rect, cornerRadius: self.clampedRadius(cornerRadius, rect: rect)).cgPath
        } else {
            return CGPath(ellipseIn: rect, transform: nil)
        }
    }

    /// The outline as a stroke for `strokeEnd` progress. A circle is rotated by its layer, so it starts anywhere;
    /// a rounded square cannot be rotated, so it starts at the top center and runs clockwise.
    public static func progressPath(rect: CGRect, cornerRadius: CGFloat?) -> CGPath {
        let path = CGMutablePath()
        if let cornerRadius {
            let radius = self.clampedRadius(cornerRadius, rect: rect)
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.minY), tangent2End: CGPoint(x: rect.maxX, y: rect.maxY), radius: radius)
            path.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.maxY), tangent2End: CGPoint(x: rect.minX, y: rect.maxY), radius: radius)
            path.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.maxY), tangent2End: CGPoint(x: rect.minX, y: rect.minY), radius: radius)
            path.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.minY), tangent2End: CGPoint(x: rect.maxX, y: rect.minY), radius: radius)
            path.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
        } else {
            path.addEllipse(in: rect)
        }
        return path
    }

    /// Length of the outline, for dash patterns that must tile it evenly.
    public static func perimeter(rect: CGRect, cornerRadius: CGFloat?) -> CGFloat {
        if let cornerRadius {
            let radius = self.clampedRadius(cornerRadius, rect: rect)
            return 2.0 * (rect.width + rect.height) - 8.0 * radius + 2.0 * CGFloat.pi * radius
        } else {
            return CGFloat.pi * (rect.width + rect.height) * 0.5
        }
    }
}
