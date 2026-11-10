import Foundation
import Postbox
import SwiftSignalKit

func chogramIsBotChat(peers: SimpleDictionary<PeerId, Peer>, peerId: PeerId) -> Bool {
    if let user = peers[peerId] as? TelegramUser, user.botInfo != nil {
        return true
    }
    return false
}

// Edit history for the edit that replaces `previous` with `updated`.
func chogramEditHistoryAttributes(previous: Message, updated: StoreMessage, attributes: [MessageAttribute]) -> [MessageAttribute] {
    var versions = previous.chogramEditVersions
    let settings = ChogramSettings.current
    if settings.keepEditHistory, previous.id.namespace == Namespaces.Message.Cloud, settings.keepDeletedInBotChats || !chogramIsBotChat(peers: previous.peers, peerId: previous.id.peerId) {
        let previousEntities = previous.textEntitiesAttribute?.entities ?? []
        let updatedEntities = (updated.attributes.first(where: { $0 is TextEntitiesMessageAttribute }) as? TextEntitiesMessageAttribute)?.entities ?? []
        if previous.text != updated.text || previousEntities != updatedEntities {
            var date = previous.timestamp
            if let edited = previous.attributes.first(where: { $0 is EditedMessageAttribute }) as? EditedMessageAttribute {
                date = edited.date
            }
            versions.append(ChogramEditHistoryAttribute.Version(text: previous.text, entities: previousEntities, date: date))
            if versions.count > 30 {
                versions.removeFirst(versions.count - 30)
            }
        }
    }
    if versions.isEmpty {
        return attributes
    }
    var result = attributes.filter { !($0 is ChogramEditHistoryAttribute) }
    result.append(ChogramEditHistoryAttribute(versions: versions))
    return result
}

private let chogramPendingRetainedMessages = Atomic<[(accountPeerId: PeerId, id: MessageId)]>(value: [])

func chogramNoteRetainedMessages(accountPeerId: PeerId, ids: [MessageId]) {
    if ids.isEmpty || !ChogramSettings.current.keepDeletedMedia {
        return
    }
    let _ = chogramPendingRetainedMessages.modify { current in
        return current + ids.map { (accountPeerId: accountPeerId, id: $0) }
    }
}

private let chogramMediaSizeLimit: Int64 = 20 * 1024 * 1024

private func chogramShouldKeepMedia(message: Message) -> Bool {
    let settings = ChogramSettings.current
    guard settings.keepDeletedMedia, message.id.namespace == Namespaces.Message.Cloud else {
        return false
    }
    if !settings.keepDeletedInBotChats && chogramIsBotChat(peers: message.peers, peerId: message.id.peerId) {
        return false
    }
    switch message.id.peerId.namespace {
    case Namespaces.Peer.CloudUser:
        return settings.deletedMediaInPrivateChats
    case Namespaces.Peer.CloudGroup:
        return settings.deletedMediaInGroups
    case Namespaces.Peer.CloudChannel:
        if let channel = message.peers[message.id.peerId] as? TelegramChannel, case .broadcast = channel.info {
            return settings.deletedMediaInChannels
        } else {
            return settings.deletedMediaInGroups
        }
    default:
        return false
    }
}

private func chogramFetchMedia(mediaBox: MediaBox, message: Message) {
    for media in message.media {
        var resource: MediaResource?
        var contentType: MediaResourceUserContentType = .other
        if let image = media as? TelegramMediaImage {
            if let representation = largestImageRepresentation(image.representations) {
                resource = representation.resource
                contentType = .image
            }
        } else if let file = media as? TelegramMediaFile {
            if !file.isSticker && !file.isAnimatedSticker, let size = file.size, size <= chogramMediaSizeLimit {
                resource = file.resource
                contentType = MediaResourceUserContentType(file: file)
            }
        }
        guard let resource = resource else {
            continue
        }
        if let size = resource.size, size > chogramMediaSizeLimit {
            continue
        }
        let reference = MediaResourceReference.media(media: AnyMediaReference.message(message: MessageReference(message), media: media), resource: resource)
        let peerId = message.id.peerId
        let _ = (mediaBox.resourceStatus(resource)
        |> take(1)).startStandalone(next: { status in
            if case .Local = status {
                return
            }
            let _ = fetchedMediaResource(mediaBox: mediaBox, userLocation: .peer(peerId), userContentType: contentType, reference: reference).startStandalone()
        })
    }
}

// Downloads the photos, small videos and files of new incoming messages, so they survive a later
// deletion, and of messages that were just retained as deleted.
func chogramKeepMedia(postbox: Postbox, accountPeerId: PeerId, incomingIds: [MessageId]) {
    var retainedIds: [MessageId] = []
    let _ = chogramPendingRetainedMessages.modify { current in
        var others: [(accountPeerId: PeerId, id: MessageId)] = []
        for item in current {
            if item.accountPeerId == accountPeerId {
                retainedIds.append(item.id)
            } else {
                others.append(item)
            }
        }
        return others
    }
    if !ChogramSettings.current.keepDeletedMedia {
        return
    }
    let ids = incomingIds + retainedIds
    if ids.isEmpty {
        return
    }
    let mediaBox = postbox.mediaBox
    let _ = (postbox.transaction { transaction -> [Message] in
        return ids.compactMap { transaction.getMessage($0) }
    }).startStandalone(next: { messages in
        for message in messages {
            if message.flags.contains(.Incoming) && chogramShouldKeepMedia(message: message) {
                chogramFetchMedia(mediaBox: mediaBox, message: message)
            }
        }
    })
}
