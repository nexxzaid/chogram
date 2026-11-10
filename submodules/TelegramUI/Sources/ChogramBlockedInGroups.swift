import Foundation
import Postbox
import TelegramCore
import SwiftSignalKit
import AccountContext

// Synchronous set of blocked peer ids per account, filled from BlockedPeersContext and refreshed at most every 30 seconds.
final class ChogramBlockedPeers {
    static let shared = ChogramBlockedPeers()
    
    private let lock = NSLock()
    private var peerIds: [PeerId: Set<PeerId>] = [:]
    private var lastRefresh: [PeerId: Double] = [:]
    
    // Touched on the main queue only.
    private var contexts: [PeerId: BlockedPeersContext] = [:]
    private var disposables: [PeerId: Disposable] = [:]
    
    func isBlocked(context: AccountContext, peerId: PeerId) -> Bool {
        let accountPeerId = context.account.peerId
        let now = CFAbsoluteTimeGetCurrent()
        
        self.lock.lock()
        let blocked = self.peerIds[accountPeerId]?.contains(peerId) ?? false
        let needsRefresh = now - (self.lastRefresh[accountPeerId] ?? 0.0) > 30.0
        if needsRefresh {
            self.lastRefresh[accountPeerId] = now
        }
        self.lock.unlock()
        
        if needsRefresh {
            Queue.mainQueue().async {
                self.refresh(context: context)
            }
        }
        return blocked
    }
    
    private func refresh(context: AccountContext) {
        let accountPeerId = context.account.peerId
        self.disposables[accountPeerId]?.dispose()
        
        let blockedContext = BlockedPeersContext(account: context.account, subject: .blocked)
        self.contexts[accountPeerId] = blockedContext
        self.disposables[accountPeerId] = (blockedContext.state
        |> deliverOnMainQueue).start(next: { [weak self, weak blockedContext] state in
            guard let self else {
                return
            }
            let ids = Set(state.peers.map { $0.peerId })
            self.lock.lock()
            self.peerIds[accountPeerId] = ids
            self.lock.unlock()
            if state.canLoadMore && !state.isLoadingMore {
                blockedContext?.loadMore()
            }
        })
    }
}

private func chogramIsGroupLikePeerId(_ peerId: PeerId) -> Bool {
    return peerId.namespace != Namespaces.Peer.CloudUser && peerId.namespace != Namespaces.Peer.SecretChat
}

func chogramShouldHideBlockedMessage(context: AccountContext, message: Message) -> Bool {
    if !ChogramSettings.current.hideBlockedInGroups {
        return false
    }
    if !chogramIsGroupLikePeerId(message.id.peerId) {
        return false
    }
    guard let authorId = message.author?.id, authorId != context.account.peerId else {
        return false
    }
    return ChogramBlockedPeers.shared.isBlocked(context: context, peerId: authorId)
}

func chogramShouldHideBlockedActivity(context: AccountContext, chatPeerId: PeerId, senderId: PeerId) -> Bool {
    if !ChogramSettings.current.hideBlockedInGroups {
        return false
    }
    if !chogramIsGroupLikePeerId(chatPeerId) || senderId == context.account.peerId {
        return false
    }
    return ChogramBlockedPeers.shared.isBlocked(context: context, peerId: senderId)
}
