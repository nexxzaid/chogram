import Foundation
import TelegramCore
import TelegramPresentationData
import LocalizedPeerData
import GlobalControlPanelsContext

// "All chats" is only dropped from the tab strip when there is at least one other folder to show.
func chogramShouldHideAllChatsTab(items: [(ChatListFilter, Int, Bool)]) -> Bool {
    guard ChogramSettings.current.hideAllChatsTab else {
        return false
    }
    return items.contains(where: { item in
        if case .filter = item.0 {
            return true
        }
        return false
    })
}

func chogramChatListTitle(standard: String, accountPeer: EnginePeer?, folderTitle: String?, presentationData: PresentationData) -> String {
    switch ChogramSettings.current.chatListTitle {
    case .standard:
        return standard
    case .chogram:
        return "Чограм"
    case .username:
        if let accountPeer {
            if let addressName = accountPeer.addressName, !addressName.isEmpty {
                return "@" + addressName
            }
            return accountPeer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
        }
        return standard
    case .name:
        if let accountPeer {
            return accountPeer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
        }
        return standard
    case .folder:
        if let folderTitle, !folderTitle.isEmpty {
            return folderTitle
        }
        return standard
    }
}

func chogramHidesChatListNotice(_ notice: GlobalControlPanelsContext.ChatListNotice) -> Bool {
    guard ChogramSettings.current.hidePremiumUpsell else {
        return false
    }
    switch notice {
    case .premiumUpgrade, .premiumAnnualDiscount, .premiumRestore, .xmasPremiumGift:
        return true
    default:
        return false
    }
}
