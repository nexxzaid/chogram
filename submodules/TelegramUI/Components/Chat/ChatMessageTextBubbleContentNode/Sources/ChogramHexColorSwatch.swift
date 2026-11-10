import Foundation
import UIKit
import Display
import TelegramCore
import TextFormat

private let chogramHexColorRegex = try? NSRegularExpression(pattern: "(?<![\\p{L}\\p{N}_&])#([0-9A-Fa-f]{6}|[0-9A-Fa-f]{3})(?![\\p{L}\\p{N}_])", options: [])

// Adds a small square in the colour after every #RRGGBB / #RGB in the displayed text. The square
// carries an empty OriginalTextAttribute, so copying and quoting treat it as absent.
func chogramApplyHexColorSwatches(_ string: NSAttributedString) -> NSAttributedString {
    guard ChogramSettings.current.hexColorSwatches, let regex = chogramHexColorRegex, string.length != 0 else {
        return string
    }
    let nsString = string.string as NSString
    let matches = regex.matches(in: string.string, options: [], range: NSRange(location: 0, length: nsString.length))
    if matches.isEmpty {
        return string
    }
    let result = NSMutableAttributedString(attributedString: string)
    for match in matches.reversed() {
        var hex = nsString.substring(with: match.range(at: 1))
        if hex.count == 3 {
            hex = hex.map { "\($0)\($0)" }.joined()
        }
        guard let value = UInt32(hex, radix: 16) else {
            continue
        }
        let upperBound = match.range.location + match.range.length
        var attributes: [NSAttributedString.Key: Any] = [:]
        if let font = string.attribute(.font, at: upperBound - 1, effectiveRange: nil) {
            attributes[.font] = font
        }
        attributes[.foregroundColor] = UIColor(rgb: value)
        attributes[originalTextAttributeKey] = OriginalTextAttribute(id: 0, string: "")
        result.insert(NSAttributedString(string: "\u{2009}\u{25A0}", attributes: attributes), at: upperBound)
    }
    return result
}
