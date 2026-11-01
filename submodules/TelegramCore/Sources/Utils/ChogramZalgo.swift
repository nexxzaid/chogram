import Foundation

private let chogramZalgoMarkThreshold = 3

private func chogramMarkCount(_ character: Character) -> Int {
    var count = 0
    for scalar in character.unicodeScalars {
        switch scalar.properties.generalCategory {
        case .nonspacingMark, .enclosingMark:
            count += 1
        default:
            break
        }
    }
    return count
}

// Returns the text without stacked combining marks, or nil when there is nothing to change.
// The check comes first because this runs for every message on screen.
public func chogramRemoveZalgo(_ text: String) -> String? {
    guard text.contains(where: { chogramMarkCount($0) >= chogramZalgoMarkThreshold }), ChogramSettings.current.filterZalgo else {
        return nil
    }
    var result = ""
    for character in text {
        if chogramMarkCount(character) >= chogramZalgoMarkThreshold, let base = character.unicodeScalars.first {
            result.unicodeScalars.append(base)
        } else {
            result.append(character)
        }
    }
    return result
}
