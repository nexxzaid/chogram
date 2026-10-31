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
    private static let hideAdsKey = "chogram.hideAds"
    private static let ghostModeKey = "chogram.ghostMode"
    private static let ghostHideOnlineKey = "chogram.ghostHideOnline"
    private static let ghostHideReadKey = "chogram.ghostHideRead"
    private static let ghostHideStoryViewsKey = "chogram.ghostHideStoryViews"
    private static let ghostHideTypingKey = "chogram.ghostHideTyping"

    public var keepDeletedMessages: Bool
    public var deletedMessageAppearance: DeletedMessageAppearance
    public var deletedMessageOpacity: Int
    public var deletedMessageIcon: String
    public var deletedMessageLabel: String
    public var showDeletionTime: Bool
    public var hideAds: Bool
    public var ghostMode: Bool
    public var ghostHideOnline: Bool
    public var ghostHideRead: Bool
    public var ghostHideStoryViews: Bool
    public var ghostHideTyping: Bool

    public var hidesOnline: Bool {
        return self.ghostMode && self.ghostHideOnline
    }

    public var hidesReadReceipts: Bool {
        return self.ghostMode && self.ghostHideRead
    }

    public var hidesStoryViews: Bool {
        return self.ghostMode && self.ghostHideStoryViews
    }

    public var hidesTyping: Bool {
        return self.ghostMode && self.ghostHideTyping
    }

    public static var current: ChogramSettings {
        let defaults = UserDefaults.standard
        return ChogramSettings(
            keepDeletedMessages: defaults.object(forKey: keepDeletedMessagesKey) as? Bool ?? true,
            deletedMessageAppearance: DeletedMessageAppearance(rawValue: defaults.integer(forKey: deletedMessageAppearanceKey)) ?? .gray,
            deletedMessageOpacity: defaults.object(forKey: deletedMessageOpacityKey) as? Int ?? 70,
            deletedMessageIcon: defaults.string(forKey: deletedMessageIconKey) ?? "🗑",
            deletedMessageLabel: defaults.string(forKey: deletedMessageLabelKey) ?? "удалено",
            showDeletionTime: defaults.object(forKey: showDeletionTimeKey) as? Bool ?? true,
            hideAds: defaults.object(forKey: hideAdsKey) as? Bool ?? true,
            ghostMode: defaults.object(forKey: ghostModeKey) as? Bool ?? false,
            ghostHideOnline: defaults.object(forKey: ghostHideOnlineKey) as? Bool ?? true,
            ghostHideRead: defaults.object(forKey: ghostHideReadKey) as? Bool ?? true,
            ghostHideStoryViews: defaults.object(forKey: ghostHideStoryViewsKey) as? Bool ?? true,
            ghostHideTyping: defaults.object(forKey: ghostHideTypingKey) as? Bool ?? true
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
        defaults.set(self.hideAds, forKey: ChogramSettings.hideAdsKey)
        defaults.set(self.ghostMode, forKey: ChogramSettings.ghostModeKey)
        defaults.set(self.ghostHideOnline, forKey: ChogramSettings.ghostHideOnlineKey)
        defaults.set(self.ghostHideRead, forKey: ChogramSettings.ghostHideReadKey)
        defaults.set(self.ghostHideStoryViews, forKey: ChogramSettings.ghostHideStoryViewsKey)
        defaults.set(self.ghostHideTyping, forKey: ChogramSettings.ghostHideTypingKey)
    }
}
