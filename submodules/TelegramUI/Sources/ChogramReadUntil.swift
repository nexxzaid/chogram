import Foundation
import UIKit
import Display
import TelegramCore
import Postbox
import SwiftSignalKit
import AccountContext
import ContextUI
import UndoUI
import AppBundle
import TelegramPresentationData
import ChatPresentationInterfaceState
import ChatControllerInteraction

// "Прочитать до сюда": with ghost mode hiding read receipts the chat is only read locally, so this
// sends the read mark to the server up to one message. Nothing else is read.
func chogramReadUntilMenuItem(context: AccountContext, chatPresentationInterfaceState: ChatPresentationInterfaceState, message: Message, controllerInteraction: ChatControllerInteraction) -> ContextMenuItem? {
    guard ChogramMessageMenuItem.isVisible(.readUntil) else {
        return nil
    }
    let settings = ChogramSettings.current
    guard settings.isGhostModeActive(accountPeerId: context.account.peerId.toInt64()) && settings.ghostHideRead else {
        return nil
    }
    let peerId = message.id.peerId
    guard peerId.namespace == Namespaces.Peer.CloudUser || peerId.namespace == Namespaces.Peer.CloudGroup || peerId.namespace == Namespaces.Peer.CloudChannel else {
        return nil
    }
    guard message.id.namespace == Namespaces.Message.Cloud, message.flags.contains(.Incoming), chatPresentationInterfaceState.chatLocation.threadId == nil else {
        return nil
    }
    let messageId = message.id
    return .action(ContextMenuActionItem(text: ChogramMessageMenuItem.readUntil.title, icon: { theme in
        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: theme.actionSheet.primaryTextColor)
    }, action: { [weak controllerInteraction] _, f in
        let _ = chogramReadHistoryUpTo(account: context.account, messageId: messageId).startStandalone()
        f(.dismissWithoutContent)
        controllerInteraction?.displayUndo(.succeed(text: "Прочитано до этого сообщения", timeout: 2.0, customUndoText: nil))
    }))
}
