import Foundation
import UIKit

// Replaces the monospaced font of code and pre entities with the one chosen in the Chogram settings.
// An empty name keeps the font the caller passed in. Fonts that are not monospaced (the chat list
// preview passes its plain font) are left alone.
func chogramCodeFont(_ fixedFont: UIFont) -> UIFont {
    // Read straight from the defaults: this runs once per entity of every rendered message.
    let name = UserDefaults.standard.string(forKey: "chogram.monospaceFontName") ?? ""
    if name.isEmpty || !fixedFont.fontDescriptor.symbolicTraits.contains(.traitMonoSpace) {
        return fixedFont
    }
    if let font = UIFont(name: name, size: fixedFont.pointSize) {
        return font
    }
    return UIFont.monospacedSystemFont(ofSize: fixedFont.pointSize, weight: .regular)
}
