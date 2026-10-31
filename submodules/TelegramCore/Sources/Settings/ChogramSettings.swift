import Foundation

// Kept in UserDefaults because both the state replay and message rendering read it synchronously.
public struct ChogramSettings: Equatable {
    public enum DeletedMessageAppearance: Int {
        case gray = 0
        case faded = 1
        case labelOnly = 2
    }

    private static let keepDeletedMessagesKey = "chogram.keepDeletedMessages"
    private static let deletedMessageAppearanceKey = "chogram.deletedMessageAppearance"
    private static let deletedMessageOpacityKey = "chogram.deletedMessageOpacity"
    private static let deletedMessageIconKey = "chogram.deletedMessageIcon"
    private static let deletedMessageLabelKey = "chogram.deletedMessageLabel"
    private static let showDeletionTimeKey = "chogram.showDeletionTime"

    public var keepDeletedMessages: Bool
    public var deletedMessageAppearance: DeletedMessageAppearance
    public var deletedMessageOpacity: Int
    public var deletedMessageIcon: String
    public var deletedMessageLabel: String
    public var showDeletionTime: Bool

    public static var current: ChogramSettings {
        let defaults = UserDefaults.standard
        return ChogramSettings(
            keepDeletedMessages: defaults.object(forKey: keepDeletedMessagesKey) as? Bool ?? true,
            deletedMessageAppearance: DeletedMessageAppearance(rawValue: defaults.integer(forKey: deletedMessageAppearanceKey)) ?? .gray,
            deletedMessageOpacity: defaults.object(forKey: deletedMessageOpacityKey) as? Int ?? 70,
            deletedMessageIcon: defaults.string(forKey: deletedMessageIconKey) ?? "🗑",
            deletedMessageLabel: defaults.string(forKey: deletedMessageLabelKey) ?? "удалено",
            showDeletionTime: defaults.object(forKey: showDeletionTimeKey) as? Bool ?? true
        )
    }

    public func save() {
        let defaults = UserDefaults.standard
        defaults.set(self.keepDeletedMessages, forKey: ChogramSettings.keepDeletedMessagesKey)
        defaults.set(self.deletedMessageAppearance.rawValue, forKey: ChogramSettings.deletedMessageAppearanceKey)
        defaults.set(self.deletedMessageOpacity, forKey: ChogramSettings.deletedMessageOpacityKey)
        defaults.set(self.deletedMessageIcon, forKey: ChogramSettings.deletedMessageIconKey)
        defaults.set(self.deletedMessageLabel, forKey: ChogramSettings.deletedMessageLabelKey)
        defaults.set(self.showDeletionTime, forKey: ChogramSettings.showDeletionTimeKey)
    }
}
