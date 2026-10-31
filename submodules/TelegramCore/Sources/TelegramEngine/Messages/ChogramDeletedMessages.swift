import Foundation
import Postbox

private struct ChogramDeletedMessagesState: Codable {
    struct Entry: Codable {
        var peerId: Int64
        var id: Int32
    }

    var entries: [Entry]

    var messageIds: [MessageId] {
        return self.entries.map { entry in
            return MessageId(peerId: PeerId(entry.peerId), namespace: Namespaces.Message.Cloud, id: entry.id)
        }
    }
}

private func chogramDeletedMessagesState(transaction: Transaction) -> ChogramDeletedMessagesState {
    return transaction.getPreferencesEntry(key: PreferencesKeys.chogramDeletedMessages)?.get(ChogramDeletedMessagesState.self) ?? ChogramDeletedMessagesState(entries: [])
}

private func setChogramDeletedMessagesState(transaction: Transaction, state: ChogramDeletedMessagesState) {
    transaction.setPreferencesEntry(key: PreferencesKeys.chogramDeletedMessages, value: PreferencesEntry(state))
}

func _internal_chogramIsDeletedMessage(transaction: Transaction, id: MessageId) -> Bool {
    guard let message = transaction.getMessage(id) else {
        return false
    }
    return message.attributes.contains(where: { $0 is ChogramDeletedMessageAttribute })
}

private func chogramCanRetainMessage(_ message: Message, accountPeerId: PeerId) -> Bool {
    guard message.id.namespace == Namespaces.Message.Cloud, message.id.peerId != accountPeerId else {
        return false
    }
    switch message.id.peerId.namespace {
    case Namespaces.Peer.CloudUser, Namespaces.Peer.CloudGroup, Namespaces.Peer.CloudChannel:
        break
    default:
        return false
    }
    // Self-destructing messages must stay gone: their senders never meant them to last.
    for attribute in message.attributes {
        if attribute is AutoremoveTimeoutMessageAttribute || attribute is AutoclearTimeoutMessageAttribute || attribute is EphemeralReplacementMessageAttribute {
            return false
        }
    }
    if message.media.contains(where: { $0 is TelegramMediaAction }) {
        return false
    }
    return true
}

// Marks the messages the server has deleted as retained instead of removing them, and returns the
// ids that must be left out of the deletion. Deleting from this device does not come through here.
func _internal_chogramRetainDeletedMessages(transaction: Transaction, accountPeerId: PeerId, ids: [MessageId]) -> Set<MessageId> {
    guard ChogramSettings.current.keepDeletedMessages else {
        return Set()
    }

    let timestamp = Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970)
    var retainedIds = Set<MessageId>()
    var addedEntries: [ChogramDeletedMessagesState.Entry] = []

    for id in ids {
        guard let message = transaction.getMessage(id) else {
            continue
        }
        if message.attributes.contains(where: { $0 is ChogramDeletedMessageAttribute }) {
            retainedIds.insert(id)
            continue
        }
        guard chogramCanRetainMessage(message, accountPeerId: accountPeerId) else {
            continue
        }

        transaction.updateMessage(id, update: { currentMessage in
            var storeForwardInfo: StoreMessageForwardInfo?
            if let forwardInfo = currentMessage.forwardInfo {
                storeForwardInfo = StoreMessageForwardInfo(authorId: forwardInfo.author?.id, sourceId: forwardInfo.source?.id, sourceMessageId: forwardInfo.sourceMessageId, date: forwardInfo.date, authorSignature: forwardInfo.authorSignature, psaType: forwardInfo.psaType, flags: forwardInfo.flags)
            }
            var attributes = currentMessage.attributes
            attributes.append(ChogramDeletedMessageAttribute(date: timestamp))
            return .update(StoreMessage(id: currentMessage.id, customStableId: nil, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, threadId: currentMessage.threadId, timestamp: currentMessage.timestamp, flags: StoreMessageFlags(currentMessage.flags), tags: currentMessage.tags, globalTags: currentMessage.globalTags, localTags: currentMessage.localTags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: currentMessage.text, attributes: attributes, media: currentMessage.media))
        })

        retainedIds.insert(id)
        addedEntries.append(ChogramDeletedMessagesState.Entry(peerId: id.peerId.toInt64(), id: id.id))
    }

    if !addedEntries.isEmpty {
        var state = chogramDeletedMessagesState(transaction: transaction)
        state.entries.append(contentsOf: addedEntries)
        setChogramDeletedMessagesState(transaction: transaction, state: state)
    }

    return retainedIds
}

func _internal_chogramRemoveDeletedMessages(transaction: Transaction, mediaBox: MediaBox, ids: [MessageId]) {
    let removedIds = ids.filter { _internal_chogramIsDeletedMessage(transaction: transaction, id: $0) }
    _internal_deleteMessages(transaction: transaction, mediaBox: mediaBox, ids: removedIds)

    var state = chogramDeletedMessagesState(transaction: transaction)
    let removedIdSet = Set(ids)
    state.entries.removeAll(where: { entry in
        return removedIdSet.contains(MessageId(peerId: PeerId(entry.peerId), namespace: Namespaces.Message.Cloud, id: entry.id))
    })
    setChogramDeletedMessagesState(transaction: transaction, state: state)
}

func _internal_chogramClearDeletedMessages(transaction: Transaction, mediaBox: MediaBox) {
    let ids = chogramDeletedMessagesState(transaction: transaction).messageIds
    _internal_chogramRemoveDeletedMessages(transaction: transaction, mediaBox: mediaBox, ids: ids)
}

func _internal_chogramDeletedMessagesCount(transaction: Transaction) -> Int {
    let ids = chogramDeletedMessagesState(transaction: transaction).messageIds
    return ids.filter({ _internal_chogramIsDeletedMessage(transaction: transaction, id: $0) }).count
}
