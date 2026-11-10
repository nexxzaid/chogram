import Foundation
import UIKit
import Display
import TelegramCore
import SwiftSignalKit
import AccountContext
import ContextUI
import UndoUI
import AppBundle
import TelegramPresentationData
import ChatPresentationInterfaceState
import ChatControllerInteraction

// Messages hidden on this device only. Stored as "peerId_namespace_id" strings in UserDefaults.
final class ChogramHiddenMessages {
    static let defaultsKey = "chogram.hiddenMessages"
    static let didChangeNotification = Notification.Name("chogram.hiddenMessages.didChange")

    private static let lock = NSLock()
    private static var cache: Set<String>?

    private static func load() -> Set<String> {
        if let cache = self.cache {
            return cache
        }
        let value = Set(UserDefaults.standard.stringArray(forKey: self.defaultsKey) ?? [])
        self.cache = value
        return value
    }

    private static func store(_ value: Set<String>) {
        self.cache = value
        UserDefaults.standard.set(Array(value).sorted(), forKey: self.defaultsKey)
    }

    private static func key(_ id: EngineMessage.Id) -> String {
        return "\(id.peerId.toInt64())_\(id.namespace)_\(id.id)"
    }

    static func isHidden(_ id: EngineMessage.Id) -> Bool {
        self.lock.lock()
        defer { self.lock.unlock() }
        let value = self.load()
        if value.isEmpty {
            return false
        }
        return value.contains(self.key(id))
    }

    static func hasHidden(peerId: EnginePeer.Id) -> Bool {
        self.lock.lock()
        defer { self.lock.unlock() }
        let prefix = "\(peerId.toInt64())_"
        return self.load().contains(where: { $0.hasPrefix(prefix) })
    }

    static func hide(ids: [EngineMessage.Id]) {
        self.lock.lock()
        var value = self.load()
        for id in ids {
            value.insert(self.key(id))
        }
        self.store(value)
        self.lock.unlock()
        NotificationCenter.default.post(name: self.didChangeNotification, object: nil)
    }

    static func unhideAll(peerId: EnginePeer.Id) {
        self.lock.lock()
        let prefix = "\(peerId.toInt64())_"
        var value = self.load()
        value = value.filter { !$0.hasPrefix(prefix) }
        self.store(value)
        self.lock.unlock()
        NotificationCenter.default.post(name: self.didChangeNotification, object: nil)
    }
}

// The id of a peer as bots and the Bot API see it.
private func chogramBotApiId(_ peerId: EnginePeer.Id) -> String {
    let raw = peerId.id._internalGetInt64Value()
    switch peerId.namespace {
    case Namespaces.Peer.CloudChannel:
        return "-100\(raw)"
    case Namespaces.Peer.CloudGroup:
        return "-\(raw)"
    default:
        return "\(raw)"
    }
}

private func chogramDateString(_ timestamp: Int32) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "dd.MM.yyyy HH:mm:ss"
    return formatter.string(from: Date(timeIntervalSince1970: Double(timestamp)))
}

private func chogramDataCenter(_ message: EngineRawMessage) -> Int? {
    for media in message.media {
        if let file = media as? TelegramMediaFile {
            if let resource = file.resource as? CloudDocumentMediaResource {
                return resource.datacenterId
            }
        } else if let image = media as? TelegramMediaImage {
            if let resource = image.representations.last?.resource as? CloudPhotoSizeMediaResource {
                return resource.datacenterId
            }
        }
    }
    return nil
}

private func chogramDetailRows(message: EngineRawMessage) -> [(String, String)] {
    var rows: [(String, String)] = []
    rows.append(("Отправлено", chogramDateString(message.timestamp)))
    for attribute in message.attributes {
        if let attribute = attribute as? EditedMessageAttribute, !attribute.isHidden, attribute.date != 0 {
            rows.append(("Изменено", chogramDateString(attribute.date)))
            break
        }
    }
    rows.append(("ID сообщения", "\(message.id.id)"))
    rows.append(("ID чата", chogramBotApiId(message.id.peerId)))
    if let author = message.author {
        rows.append(("ID отправителя", chogramBotApiId(author.id)))
    }
    if let dc = chogramDataCenter(message) {
        rows.append(("Дата-центр файла", "DC\(dc)"))
    }
    if let forwardInfo = message.forwardInfo {
        if let author = forwardInfo.author {
            rows.append(("Переслано от", author.debugDisplayTitle))
            rows.append(("ID автора", chogramBotApiId(author.id)))
        } else if let signature = forwardInfo.authorSignature {
            rows.append(("Переслано от", signature))
        }
        if let source = forwardInfo.source {
            rows.append(("Из чата", source.debugDisplayTitle))
            rows.append(("ID источника", chogramBotApiId(source.id)))
        }
        if let sourceMessageId = forwardInfo.sourceMessageId {
            rows.append(("ID исходного сообщения", "\(sourceMessageId.id)"))
        }
        rows.append(("Исходная дата", chogramDateString(forwardInfo.date)))
    }
    return rows
}

private func chogramCanRepeat(message: EngineRawMessage, chatPresentationInterfaceState: ChatPresentationInterfaceState, isCopyProtected: Bool) -> Bool {
    if isCopyProtected || message.id.namespace != Namespaces.Message.Cloud {
        return false
    }
    if message.id.peerId.namespace == Namespaces.Peer.SecretChat {
        return false
    }
    if !canSendMessagesToChat(chatPresentationInterfaceState) {
        return false
    }
    for media in message.media {
        if media is TelegramMediaAction || media is TelegramMediaExpiredContent || media is TelegramMediaGiveaway {
            return false
        }
    }
    if message.text.isEmpty && message.media.isEmpty {
        return false
    }
    return true
}

private func chogramRepeatMessage(context: AccountContext, message: EngineRawMessage, chatPresentationInterfaceState: ChatPresentationInterfaceState) {
    guard let peerId = chatPresentationInterfaceState.chatLocation.peerId else {
        return
    }
    let threadId = chatPresentationInterfaceState.chatLocation.threadId
    var hasMedia = false
    for media in message.media {
        if !(media is TelegramMediaWebpage) {
            hasMedia = true
        }
    }
    let enqueued: EnqueueMessage
    if hasMedia {
        // Forwarding with a hidden author keeps the media without uploading it again.
        enqueued = .forward(source: message.id, threadId: threadId, grouping: .none, attributes: [ForwardOptionsMessageAttribute(hideNames: true, hideCaptions: false)], correlationId: nil)
    } else {
        var attributes: [EngineMessage.Attribute] = []
        for attribute in message.attributes {
            if let attribute = attribute as? TextEntitiesMessageAttribute {
                attributes.append(attribute)
            }
        }
        enqueued = .message(text: message.text, attributes: attributes, inlineStickers: [:], mediaReference: nil, threadId: threadId, replyToMessageId: nil, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: [])
    }
    let _ = enqueueMessages(account: context.account, peerId: peerId, messages: [enqueued]).startStandalone()
}

// Items Чограм adds to the message context menu.
func chogramMessageContextMenuActions(context: AccountContext, chatPresentationInterfaceState: ChatPresentationInterfaceState, message: EngineRawMessage, messages: [EngineRawMessage], isCopyProtected: Bool, controllerInteraction: ChatControllerInteraction) -> [ContextMenuItem] {
    var items: [ContextMenuItem] = []
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }

    if ChogramMessageMenuItem.isVisible(.details) {
        items.append(.action(ContextMenuActionItem(text: ChogramMessageMenuItem.details.title, icon: { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Info"), color: theme.actionSheet.primaryTextColor)
        }, action: { [weak controllerInteraction] c, _ in
            var subItems: [ContextMenuItem] = []
            subItems.append(.action(ContextMenuActionItem(text: presentationData.strings.Common_Back, textColor: .primary, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Back"), color: theme.actionSheet.primaryTextColor)
            }, iconSource: nil, iconPosition: .left, action: { c, _ in
                c?.popItems()
            })))
            subItems.append(.separator)
            for (title, value) in chogramDetailRows(message: message) {
                subItems.append(.action(ContextMenuActionItem(text: "\(title): \(value)", textColor: .primary, textLayout: .multiline, icon: { _ in
                    return nil
                }, iconSource: nil, action: { c, _ in
                    c?.dismiss(completion: {
                        UIPasteboard.general.string = value
                        controllerInteraction?.displayUndo(.copy(text: "Скопировано"))
                    })
                })))
            }
            c?.pushItems(items: .single(ContextController.Items(content: .list(subItems))))
        })))
    }

    if ChogramMessageMenuItem.isVisible(.repeatMessage), chogramCanRepeat(message: message, chatPresentationInterfaceState: chatPresentationInterfaceState, isCopyProtected: isCopyProtected) {
        items.append(.action(ContextMenuActionItem(text: ChogramMessageMenuItem.repeatMessage.title, icon: { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Resend"), color: theme.actionSheet.primaryTextColor)
        }, action: { _, f in
            chogramRepeatMessage(context: context, message: message, chatPresentationInterfaceState: chatPresentationInterfaceState)
            f(.dismissWithoutContent)
        })))
    }

    if ChogramMessageMenuItem.isVisible(.hideLocally) {
        items.append(.action(ContextMenuActionItem(text: ChogramMessageMenuItem.hideLocally.title, icon: { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Eye"), color: theme.actionSheet.primaryTextColor)
        }, action: { _, f in
            var ids: [EngineMessage.Id] = [message.id]
            if let groupingKey = message.groupingKey {
                for other in messages where other.groupingKey == groupingKey {
                    ids.append(other.id)
                }
            }
            ChogramHiddenMessages.hide(ids: ids)
            f(.dismissWithoutContent)
        })))
    }

    if let item = chogramReadUntilMenuItem(context: context, chatPresentationInterfaceState: chatPresentationInterfaceState, message: message, controllerInteraction: controllerInteraction) {
        items.append(item)
    }

    return items
}

// «Показать скрытые» for the chat's menu; nil while nothing is hidden in the chat.
func chogramShowHiddenMenuItem(peerId: EnginePeer.Id) -> ContextMenuItem? {
    if !ChogramHiddenMessages.hasHidden(peerId: peerId) {
        return nil
    }
    return .action(ContextMenuActionItem(text: "Показать скрытые", icon: { theme in
        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Eye"), color: theme.actionSheet.primaryTextColor)
    }, action: { _, f in
        ChogramHiddenMessages.unhideAll(peerId: peerId)
        f(.dismissWithoutContent)
    }))
}
