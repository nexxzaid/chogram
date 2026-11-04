import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi

// With ghost mode hiding read receipts, replying in a chat still marks that chat read on the
// server: an answer next to unread messages looks odd to the other side. Only the chat the user
// writes to is read; every other chat keeps its receipts hidden.
func chogramReadOnSendIfNeeded(account: Account, peerId: PeerId) {
    let settings = ChogramSettings.current
    guard settings.hidesReadReceipts && settings.ghostReadOnSend else {
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
