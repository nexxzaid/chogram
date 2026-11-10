import Foundation

// Kept in UserDefaults because both the state replay and message rendering read it synchronously.
public struct ChogramSettings: Equatable {
    public enum DeletedMessageAppearance: Int {
        case gray = 0
        case faded = 1
        case labelOnly = 2
    }

    public enum DoubleTapAction: Int {
        case reaction = 0
        case reply = 1
        case copy = 2
        case forward = 3
        case edit = 4
        case nothing = 5
    }

    public enum RoundVideoCamera: Int {
        case front = 0
        case back = 1
        case last = 2
    }

    public enum ChatListTitle: Int {
        case standard = 0
        case chogram = 1
        case username = 2
        case name = 3
        case folder = 4
    }

    private static let keepDeletedMessagesKey = "chogram.keepDeletedMessages"
    private static let deletedMessageAppearanceKey = "chogram.deletedMessageAppearance"
    private static let deletedMessageOpacityKey = "chogram.deletedMessageOpacity"
    private static let deletedMessageIconKey = "chogram.deletedMessageIcon"
    private static let deletedMessageLabelKey = "chogram.deletedMessageLabel"
    private static let showDeletionTimeKey = "chogram.showDeletionTime"
    private static let hideAdsKey = "chogram.hideAds"
    private static let filterZalgoKey = "chogram.filterZalgo"
    private static let ghostModeKey = "chogram.ghostMode"
    private static let ghostHideOnlineKey = "chogram.ghostHideOnline"
    private static let ghostHideReadKey = "chogram.ghostHideRead"
    private static let ghostHideStoryViewsKey = "chogram.ghostHideStoryViews"
    private static let ghostHideTypingKey = "chogram.ghostHideTyping"
    private static let ghostReadOnSendKey = "chogram.ghostReadOnSend"
    private static let showProfileDetailsKey = "chogram.showProfileDetails"
    private static let shareChogramPresenceKey = "chogram.shareChogramPresence"
    private static let photoWithoutCompressionKey = "chogram.photoWithoutCompression"
    private static let videoWithoutCompressionKey = "chogram.videoWithoutCompression"
    private static let mintThemeKey = "chogram.mintTheme"
    private static let personalChatAsGroupKey = "chogram.personalChatAsGroup"
    private static let usernameInHeaderKey = "chogram.usernameInHeader"

    public var keepDeletedMessages: Bool
    public var deletedMessageAppearance: DeletedMessageAppearance
    public var deletedMessageOpacity: Int
    public var deletedMessageIcon: String
    public var deletedMessageLabel: String
    public var showDeletionTime: Bool
    public var hideAds: Bool
    public var filterZalgo: Bool
    public var ghostMode: Bool
    public var ghostHideOnline: Bool
    public var ghostHideRead: Bool
    public var ghostHideStoryViews: Bool
    public var ghostHideTyping: Bool
    public var ghostReadOnSend: Bool
    public var showProfileDetails: Bool
    public var shareChogramPresence: Bool
    public var photoWithoutCompression: Bool
    public var videoWithoutCompression: Bool
    public var mintTheme: Bool
    public var personalChatAsGroup: Bool
    public var usernameInHeader: Bool

    // Deleted and edited messages.
    public var keepEditHistory: Bool = true
    // Empty means Telegram's own "edited" label.
    public var editedLabel: String = ""
    public var keepDeletedMedia: Bool = true
    public var deletedMediaInPrivateChats: Bool = true
    public var deletedMediaInGroups: Bool = true
    public var deletedMediaInChannels: Bool = false
    public var keepDeletedInBotChats: Bool = false

    // Ghost mode.
    // Sends a message as scheduled a few seconds ahead, so sending does not bring the account online.
    public var ghostSendScheduled: Bool = true
    // When on, ghost mode is off for the accounts in ghostDisabledAccountIds.
    public var ghostPerAccount: Bool = false
    public var ghostDisabledAccountIds: Set<Int64> = Set()
    public var ghostAskBeforeStory: Bool = true

    // Protected content.
    public var allowScreenshots: Bool = false
    public var saveViewOnceMedia: Bool = false
    public var bypassCopyProtection: Bool = false

    // Chats.
    public var confirmCalls: Bool = true
    public var confirmSendStickers: Bool = false
    public var confirmSendGifs: Bool = false
    public var confirmSendVoice: Bool = false
    public var confirmSendRoundVideos: Bool = false
    public var doubleTapIncoming: DoubleTapAction = .reaction
    public var doubleTapOutgoing: DoubleTapAction = .reaction
    // Keys of the message context menu items the user turned off (ChogramMessageMenuItem raw values).
    public var hiddenMessageMenuItems: Set<String> = Set()
    public var showSecondsInTime: Bool = false
    public var showServiceMessageTime: Bool = false
    public var showForwardOriginalDate: Bool = true
    public var disableNextChannelSwipe: Bool = false
    public var convertCurrency: Bool = true

    // Privacy.
    public var hidePhoneNumber: Bool = false
    public var hideBlockedInGroups: Bool = false

    // Media.
    public var stickerSizePercent: Int = 100
    public var roundVideoCamera: RoundVideoCamera = .front
    public var lastRoundVideoCameraIsBack: Bool = false
    public var onlyMyStickerPacks: Bool = false
    public var fasterTransfers: Bool = false

    // Looks.
    // 100 is a circle, 0 a square with slightly rounded corners.
    public var avatarRoundnessPercent: Int = 100
    public var hideBubbleTails: Bool = false
    public var chatListTitle: ChatListTitle = .standard
    public var hideAllChatsTab: Bool = false
    public var snow: Bool = false
    public var hexColorSwatches: Bool = true
    public var disableVideoAvatars: Bool = false
    public var disableChatThemes: Bool = false
    public var hideShareButton: Bool = false
    public var hideSendAsChannel: Bool = false
    public var hideGreetingSticker: Bool = false
    public var hideChannelMuteButton: Bool = false
    public var hidePremiumUpsell: Bool = false
    public var hideSimilarChannels: Bool = false
    // Empty means the system monospaced font.
    public var monospaceFontName: String = ""

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

    // Ghost mode for one account: with "per account" on, an account in ghostDisabledAccountIds is visible.
    public func isGhostModeActive(accountPeerId: Int64) -> Bool {
        if !self.ghostMode {
            return false
        }
        if self.ghostPerAccount && self.ghostDisabledAccountIds.contains(accountPeerId) {
            return false
        }
        return true
    }

    // Message layout reads the settings many times per frame, so they are cached and dropped whenever
    // UserDefaults changes (save() writes there, and so does code that sets a chogram.* key directly).
    private static let cacheLock = NSLock()
    private static var cachedSettings: ChogramSettings?
    private static var cacheObserver: NSObjectProtocol?

    public static var current: ChogramSettings {
        ChogramSettings.cacheLock.lock()
        defer {
            ChogramSettings.cacheLock.unlock()
        }
        if ChogramSettings.cacheObserver == nil {
            ChogramSettings.cacheObserver = NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: nil, using: { _ in
                ChogramSettings.invalidateCache()
            })
        }
        if let cachedSettings = ChogramSettings.cachedSettings {
            return cachedSettings
        }
        let settings = ChogramSettings.load()
        ChogramSettings.cachedSettings = settings
        return settings
    }

    private static func invalidateCache() {
        ChogramSettings.cacheLock.lock()
        ChogramSettings.cachedSettings = nil
        ChogramSettings.cacheLock.unlock()
    }

    private static func load() -> ChogramSettings {
        let defaults = UserDefaults.standard
        var settings = ChogramSettings(
            keepDeletedMessages: defaults.object(forKey: keepDeletedMessagesKey) as? Bool ?? true,
            deletedMessageAppearance: DeletedMessageAppearance(rawValue: defaults.integer(forKey: deletedMessageAppearanceKey)) ?? .gray,
            deletedMessageOpacity: defaults.object(forKey: deletedMessageOpacityKey) as? Int ?? 70,
            deletedMessageIcon: defaults.string(forKey: deletedMessageIconKey) ?? "🗑",
            deletedMessageLabel: defaults.string(forKey: deletedMessageLabelKey) ?? "удалено",
            showDeletionTime: defaults.object(forKey: showDeletionTimeKey) as? Bool ?? true,
            hideAds: defaults.object(forKey: hideAdsKey) as? Bool ?? true,
            filterZalgo: defaults.object(forKey: filterZalgoKey) as? Bool ?? true,
            ghostMode: defaults.object(forKey: ghostModeKey) as? Bool ?? false,
            ghostHideOnline: defaults.object(forKey: ghostHideOnlineKey) as? Bool ?? true,
            ghostHideRead: defaults.object(forKey: ghostHideReadKey) as? Bool ?? true,
            ghostHideStoryViews: defaults.object(forKey: ghostHideStoryViewsKey) as? Bool ?? true,
            ghostHideTyping: defaults.object(forKey: ghostHideTypingKey) as? Bool ?? true,
            ghostReadOnSend: defaults.object(forKey: ghostReadOnSendKey) as? Bool ?? true,
            showProfileDetails: defaults.object(forKey: showProfileDetailsKey) as? Bool ?? true,
            shareChogramPresence: defaults.object(forKey: shareChogramPresenceKey) as? Bool ?? true,
            photoWithoutCompression: defaults.object(forKey: photoWithoutCompressionKey) as? Bool ?? false,
            videoWithoutCompression: defaults.object(forKey: videoWithoutCompressionKey) as? Bool ?? false,
            mintTheme: defaults.object(forKey: mintThemeKey) as? Bool ?? false,
            personalChatAsGroup: defaults.object(forKey: personalChatAsGroupKey) as? Bool ?? false,
            usernameInHeader: defaults.object(forKey: usernameInHeaderKey) as? Bool ?? false
        )
        settings.loadExtended(from: defaults)
        return settings
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
        defaults.set(self.filterZalgo, forKey: ChogramSettings.filterZalgoKey)
        defaults.set(self.ghostMode, forKey: ChogramSettings.ghostModeKey)
        defaults.set(self.ghostHideOnline, forKey: ChogramSettings.ghostHideOnlineKey)
        defaults.set(self.ghostHideRead, forKey: ChogramSettings.ghostHideReadKey)
        defaults.set(self.ghostHideStoryViews, forKey: ChogramSettings.ghostHideStoryViewsKey)
        defaults.set(self.ghostHideTyping, forKey: ChogramSettings.ghostHideTypingKey)
        defaults.set(self.ghostReadOnSend, forKey: ChogramSettings.ghostReadOnSendKey)
        defaults.set(self.showProfileDetails, forKey: ChogramSettings.showProfileDetailsKey)
        defaults.set(self.shareChogramPresence, forKey: ChogramSettings.shareChogramPresenceKey)
        defaults.set(self.photoWithoutCompression, forKey: ChogramSettings.photoWithoutCompressionKey)
        defaults.set(self.videoWithoutCompression, forKey: ChogramSettings.videoWithoutCompressionKey)
        defaults.set(self.mintTheme, forKey: ChogramSettings.mintThemeKey)
        defaults.set(self.personalChatAsGroup, forKey: ChogramSettings.personalChatAsGroupKey)
        defaults.set(self.usernameInHeader, forKey: ChogramSettings.usernameInHeaderKey)
        self.saveExtended(to: defaults)
        ChogramSettings.invalidateCache()
        NotificationCenter.default.post(name: ChogramSettings.didChangeNotification, object: nil)
    }

    // Posted after every save, so screens that render from the settings can redraw.
    public static let didChangeNotification = Notification.Name("ChogramSettingsDidChange")

    private static func extendedKey(_ name: String) -> String {
        return "chogram." + name
    }

    private mutating func loadExtended(from defaults: UserDefaults) {
        func bool(_ name: String, _ fallback: Bool) -> Bool {
            return defaults.object(forKey: ChogramSettings.extendedKey(name)) as? Bool ?? fallback
        }
        func int(_ name: String, _ fallback: Int) -> Int {
            return defaults.object(forKey: ChogramSettings.extendedKey(name)) as? Int ?? fallback
        }
        func string(_ name: String, _ fallback: String) -> String {
            return defaults.string(forKey: ChogramSettings.extendedKey(name)) ?? fallback
        }

        self.keepEditHistory = bool("keepEditHistory", true)
        self.editedLabel = string("editedLabel", "")
        self.keepDeletedMedia = bool("keepDeletedMedia", true)
        self.deletedMediaInPrivateChats = bool("deletedMediaInPrivateChats", true)
        self.deletedMediaInGroups = bool("deletedMediaInGroups", true)
        self.deletedMediaInChannels = bool("deletedMediaInChannels", false)
        self.keepDeletedInBotChats = bool("keepDeletedInBotChats", false)

        self.ghostSendScheduled = bool("ghostSendScheduled", true)
        self.ghostPerAccount = bool("ghostPerAccount", false)
        self.ghostDisabledAccountIds = Set((defaults.array(forKey: ChogramSettings.extendedKey("ghostDisabledAccountIds")) as? [NSNumber] ?? []).map { $0.int64Value })
        self.ghostAskBeforeStory = bool("ghostAskBeforeStory", true)

        self.allowScreenshots = bool("allowScreenshots", false)
        self.saveViewOnceMedia = bool("saveViewOnceMedia", false)
        self.bypassCopyProtection = bool("bypassCopyProtection", false)

        self.confirmCalls = bool("confirmCalls", true)
        self.confirmSendStickers = bool("confirmSendStickers", false)
        self.confirmSendGifs = bool("confirmSendGifs", false)
        self.confirmSendVoice = bool("confirmSendVoice", false)
        self.confirmSendRoundVideos = bool("confirmSendRoundVideos", false)
        self.doubleTapIncoming = DoubleTapAction(rawValue: int("doubleTapIncoming", DoubleTapAction.reaction.rawValue)) ?? .reaction
        self.doubleTapOutgoing = DoubleTapAction(rawValue: int("doubleTapOutgoing", DoubleTapAction.reaction.rawValue)) ?? .reaction
        self.hiddenMessageMenuItems = Set(defaults.stringArray(forKey: ChogramSettings.extendedKey("hiddenMessageMenuItems")) ?? [])
        self.showSecondsInTime = bool("showSecondsInTime", false)
        self.showServiceMessageTime = bool("showServiceMessageTime", false)
        self.showForwardOriginalDate = bool("showForwardOriginalDate", true)
        self.disableNextChannelSwipe = bool("disableNextChannelSwipe", false)
        self.convertCurrency = bool("convertCurrency", true)

        self.hidePhoneNumber = bool("hidePhoneNumber", false)
        self.hideBlockedInGroups = bool("hideBlockedInGroups", false)

        self.stickerSizePercent = max(50, min(150, int("stickerSizePercent", 100)))
        self.roundVideoCamera = RoundVideoCamera(rawValue: int("roundVideoCamera", RoundVideoCamera.front.rawValue)) ?? .front
        self.lastRoundVideoCameraIsBack = bool("lastRoundVideoCameraIsBack", false)
        self.onlyMyStickerPacks = bool("onlyMyStickerPacks", false)
        self.fasterTransfers = bool("fasterTransfers", false)

        self.avatarRoundnessPercent = max(0, min(100, int("avatarRoundnessPercent", 100)))
        self.hideBubbleTails = bool("hideBubbleTails", false)
        self.chatListTitle = ChatListTitle(rawValue: int("chatListTitle", ChatListTitle.standard.rawValue)) ?? .standard
        self.hideAllChatsTab = bool("hideAllChatsTab", false)
        self.snow = bool("snow", false)
        self.hexColorSwatches = bool("hexColorSwatches", true)
        self.disableVideoAvatars = bool("disableVideoAvatars", false)
        self.disableChatThemes = bool("disableChatThemes", false)
        self.hideShareButton = bool("hideShareButton", false)
        self.hideSendAsChannel = bool("hideSendAsChannel", false)
        self.hideGreetingSticker = bool("hideGreetingSticker", false)
        self.hideChannelMuteButton = bool("hideChannelMuteButton", false)
        self.hidePremiumUpsell = bool("hidePremiumUpsell", false)
        self.hideSimilarChannels = bool("hideSimilarChannels", false)
        self.monospaceFontName = string("monospaceFontName", "")
    }

    private func saveExtended(to defaults: UserDefaults) {
        func set(_ value: Any, _ name: String) {
            defaults.set(value, forKey: ChogramSettings.extendedKey(name))
        }

        set(self.keepEditHistory, "keepEditHistory")
        set(self.editedLabel, "editedLabel")
        set(self.keepDeletedMedia, "keepDeletedMedia")
        set(self.deletedMediaInPrivateChats, "deletedMediaInPrivateChats")
        set(self.deletedMediaInGroups, "deletedMediaInGroups")
        set(self.deletedMediaInChannels, "deletedMediaInChannels")
        set(self.keepDeletedInBotChats, "keepDeletedInBotChats")

        set(self.ghostSendScheduled, "ghostSendScheduled")
        set(self.ghostPerAccount, "ghostPerAccount")
        set(self.ghostDisabledAccountIds.map { NSNumber(value: $0) }, "ghostDisabledAccountIds")
        set(self.ghostAskBeforeStory, "ghostAskBeforeStory")

        set(self.allowScreenshots, "allowScreenshots")
        set(self.saveViewOnceMedia, "saveViewOnceMedia")
        set(self.bypassCopyProtection, "bypassCopyProtection")

        set(self.confirmCalls, "confirmCalls")
        set(self.confirmSendStickers, "confirmSendStickers")
        set(self.confirmSendGifs, "confirmSendGifs")
        set(self.confirmSendVoice, "confirmSendVoice")
        set(self.confirmSendRoundVideos, "confirmSendRoundVideos")
        set(self.doubleTapIncoming.rawValue, "doubleTapIncoming")
        set(self.doubleTapOutgoing.rawValue, "doubleTapOutgoing")
        set(Array(self.hiddenMessageMenuItems).sorted(), "hiddenMessageMenuItems")
        set(self.showSecondsInTime, "showSecondsInTime")
        set(self.showServiceMessageTime, "showServiceMessageTime")
        set(self.showForwardOriginalDate, "showForwardOriginalDate")
        set(self.disableNextChannelSwipe, "disableNextChannelSwipe")
        set(self.convertCurrency, "convertCurrency")

        set(self.hidePhoneNumber, "hidePhoneNumber")
        set(self.hideBlockedInGroups, "hideBlockedInGroups")

        set(self.stickerSizePercent, "stickerSizePercent")
        set(self.roundVideoCamera.rawValue, "roundVideoCamera")
        set(self.lastRoundVideoCameraIsBack, "lastRoundVideoCameraIsBack")
        set(self.onlyMyStickerPacks, "onlyMyStickerPacks")
        set(self.fasterTransfers, "fasterTransfers")

        set(self.avatarRoundnessPercent, "avatarRoundnessPercent")
        set(self.hideBubbleTails, "hideBubbleTails")
        set(self.chatListTitle.rawValue, "chatListTitle")
        set(self.hideAllChatsTab, "hideAllChatsTab")
        set(self.snow, "snow")
        set(self.hexColorSwatches, "hexColorSwatches")
        set(self.disableVideoAvatars, "disableVideoAvatars")
        set(self.disableChatThemes, "disableChatThemes")
        set(self.hideShareButton, "hideShareButton")
        set(self.hideSendAsChannel, "hideSendAsChannel")
        set(self.hideGreetingSticker, "hideGreetingSticker")
        set(self.hideChannelMuteButton, "hideChannelMuteButton")
        set(self.hidePremiumUpsell, "hidePremiumUpsell")
        set(self.hideSimilarChannels, "hideSimilarChannels")
        set(self.monospaceFontName, "monospaceFontName")
    }
}
