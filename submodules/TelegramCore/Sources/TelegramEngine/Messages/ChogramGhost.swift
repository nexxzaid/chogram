import Foundation
import Postbox
import SwiftSignalKit
internal import TelegramApi

// Account-aware ghost checks. A nil account falls back to the global switch.
private func chogramGhostActive(_ settings: ChogramSettings, _ accountPeerId: PeerId?) -> Bool {
    if let accountPeerId {
        return settings.isGhostModeActive(accountPeerId: accountPeerId.toInt64())
    }
    return settings.ghostMode
}

func chogramHidesOnline(accountPeerId: PeerId?) -> Bool {
    let settings = ChogramSettings.current
    return chogramGhostActive(settings, accountPeerId) && settings.ghostHideOnline
}

func chogramHidesReadReceipts(accountPeerId: PeerId?) -> Bool {
    let settings = ChogramSettings.current
    return chogramGhostActive(settings, accountPeerId) && settings.ghostHideRead
}

func chogramHidesStoryViews(accountPeerId: PeerId?) -> Bool {
    let settings = ChogramSettings.current
    return chogramGhostActive(settings, accountPeerId) && settings.ghostHideStoryViews
}

func chogramHidesTyping(accountPeerId: PeerId?) -> Bool {
    let settings = ChogramSettings.current
    return chogramGhostActive(settings, accountPeerId) && settings.ghostHideTyping
}

extension ChogramSettings {
    // Turns ghost mode on or off for one account. With "per account" off it is the global switch;
    // with it on, the global switch stays on and the account is added to or removed from the exceptions.
    public mutating func setGhostMode(_ value: Bool, accountPeerId: Int64) {
        if self.ghostPerAccount {
            if value {
                self.ghostMode = true
                self.ghostDisabledAccountIds.remove(accountPeerId)
            } else {
                self.ghostDisabledAccountIds.insert(accountPeerId)
            }
        } else {
            self.ghostMode = value
        }
    }
}

// Sending a message brings the account online. With ghost mode hiding online status, an ordinary
// message goes out as a scheduled one a few seconds ahead instead: scheduling does not touch presence,
// and the server publishes the message by itself. The server rejects a date that is too close to
// now, so the lead is kept a little above the usual 10 s limit.
private let chogramGhostScheduleLead: Int32 = 12

func chogramGhostScheduledMessages(account: Account, peerId: PeerId, messages: [EnqueueMessage]) -> [EnqueueMessage] {
    guard ChogramSettings.current.ghostSendScheduled && chogramHidesOnline(accountPeerId: account.peerId) else {
        return messages
    }
    guard peerId != account.peerId, peerId.namespace == Namespaces.Peer.CloudUser || peerId.namespace == Namespaces.Peer.CloudGroup || peerId.namespace == Namespaces.Peer.CloudChannel else {
        return messages
    }
    let scheduleTime = Int32(account.network.context.globalTime()) + chogramGhostScheduleLead
    return messages.map { message -> EnqueueMessage in
        guard case let .message(text, attributes, _, mediaReference, _, _, replyToStoryId, _, _, _) = message else {
            return message
        }
        if text.hasPrefix("/start") {
            return message
        }
        if replyToStoryId != nil {
            return message
        }
        if let media = mediaReference?.media, let map = media as? TelegramMediaMap, map.liveBroadcastingTimeout != nil {
            return message
        }
        for attribute in attributes {
            if attribute is OutgoingScheduleInfoMessageAttribute || attribute is OutgoingQuickReplyMessageAttribute || attribute is InlineBotMessageAttribute {
                return message
            }
        }
        return message.withUpdatedAttributes { attributes in
            return attributes + [OutgoingScheduleInfoMessageAttribute(scheduleTime: scheduleTime, repeatPeriod: nil)]
        }
    }
}

// Marks a chat read on the server up to one message, even while ghost mode hides read receipts.
// Used by the "read up to here" menu action; only this one call bypasses the hiding.
public func chogramReadHistoryUpTo(account: Account, messageId: MessageId) -> Signal<Never, NoError> {
    let network = account.network
    let stateManager = account.stateManager
    let peerId = messageId.peerId
    return account.postbox.transaction { transaction -> Api.InputPeer? in
        guard let peer = transaction.getPeer(peerId) else {
            return nil
        }
        return apiInputPeer(peer)
    }
    |> mapToSignal { inputPeer -> Signal<Never, NoError> in
        guard let inputPeer else {
            return .complete()
        }
        switch inputPeer {
        case let .inputPeerChannel(channelData):
            return network.request(Api.functions.channels.readHistory(channel: Api.InputChannel.inputChannel(.init(channelId: channelData.channelId, accessHash: channelData.accessHash)), maxId: messageId.id))
            |> `catch` { _ -> Signal<Api.Bool, NoError> in
                return .complete()
            }
            |> ignoreValues
        default:
            return network.request(Api.functions.messages.readHistory(peer: inputPeer, maxId: messageId.id))
            |> map(Optional.init)
            |> `catch` { _ -> Signal<Api.messages.AffectedMessages?, NoError> in
                return .single(nil)
            }
            |> mapToSignal { result -> Signal<Never, NoError> in
                if let result {
                    switch result {
                    case let .affectedMessages(affectedMessagesData):
                        stateManager?.addUpdateGroups([.updatePts(pts: affectedMessagesData.pts, ptsCount: affectedMessagesData.ptsCount)])
                    }
                }
                return .complete()
            }
        }
    }
}

// With ghost mode hiding read receipts, replying in a chat still marks that chat read on the
// server: an answer next to unread messages looks odd to the other side. Only the chat the user
// writes to is read; every other chat keeps its receipts hidden.
func chogramReadOnSendIfNeeded(account: Account, peerId: PeerId) {
    let settings = ChogramSettings.current
    guard chogramHidesReadReceipts(accountPeerId: account.peerId) && settings.ghostReadOnSend else {
        return
    }
    guard peerId.namespace == Namespaces.Peer.CloudUser || peerId.namespace == Namespaces.Peer.CloudGroup || peerId.namespace == Namespaces.Peer.CloudChannel else {
        return
    }
    let network = account.network
    let stateManager = account.stateManager
    let _ = (account.postbox.transaction { transaction -> (Api.InputPeer, Int32)? in
        guard let peer = transaction.getPeer(peerId), let inputPeer = apiInputPeer(peer) else {
            return nil
        }
        guard let topId = transaction.getTopPeerMessageId(peerId: peerId, namespace: Namespaces.Message.Cloud) else {
            return nil
        }
        return (inputPeer, topId.id)
    }
    |> mapToSignal { value -> Signal<Never, NoError> in
        guard let value else {
            return .complete()
        }
        let (inputPeer, maxId) = value
        switch inputPeer {
        case let .inputPeerChannel(channelData):
            return network.request(Api.functions.channels.readHistory(channel: Api.InputChannel.inputChannel(.init(channelId: channelData.channelId, accessHash: channelData.accessHash)), maxId: maxId))
            |> `catch` { _ -> Signal<Api.Bool, NoError> in
                return .complete()
            }
            |> ignoreValues
        default:
            return network.request(Api.functions.messages.readHistory(peer: inputPeer, maxId: maxId))
            |> map(Optional.init)
            |> `catch` { _ -> Signal<Api.messages.AffectedMessages?, NoError> in
                return .single(nil)
            }
            |> mapToSignal { result -> Signal<Never, NoError> in
                if let result {
                    switch result {
                    case let .affectedMessages(affectedMessagesData):
                        stateManager?.addUpdateGroups([.updatePts(pts: affectedMessagesData.pts, ptsCount: affectedMessagesData.ptsCount)])
                    }
                }
                return .complete()
            }
        }
    }).start()
}
