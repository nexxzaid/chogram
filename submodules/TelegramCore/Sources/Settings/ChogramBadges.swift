import Foundation
import Postbox
import SwiftSignalKit

public struct ChogramBadge: Codable, Equatable {
    public let userId: Int64
    public let title: String
    public let description: String?
}

// The list lives on the server, so badges change without a new build. The last list is kept
// on the device, which keeps badges visible while the server is unreachable.
public final class ChogramBadges {
    public static let shared = ChogramBadges()
    
    private static let url = URL(string: "https://selfhamer.tech/api/badges")!
    private static let cacheKey = "chogram.badges"
    private static let lastUpdateKey = "chogram.badgesLastUpdate"
    private static let updateInterval: TimeInterval = 6.0 * 60.0 * 60.0
    
    private let badges: Atomic<[Int64: ChogramBadge]>
    
    private init() {
        var badges: [Int64: ChogramBadge] = [:]
        if let data = UserDefaults.standard.data(forKey: ChogramBadges.cacheKey), let list = try? JSONDecoder().decode([ChogramBadge].self, from: data) {
            for badge in list {
                badges[badge.userId] = badge
            }
        }
        self.badges = Atomic(value: badges)
    }
    
    public func badge(peerId: PeerId) -> ChogramBadge? {
        guard peerId.namespace == Namespaces.Peer.CloudUser else {
            return nil
        }
        return self.badges.with { $0[peerId.id._internalGetInt64Value()] }
    }
    
    public func refreshIfNeeded() {
        let defaults = UserDefaults.standard
        let now = Date().timeIntervalSince1970
        if now - defaults.double(forKey: ChogramBadges.lastUpdateKey) < ChogramBadges.updateInterval {
            return
        }
        var request = URLRequest(url: ChogramBadges.url)
        request.timeoutInterval = 20.0
        URLSession.shared.dataTask(with: request, completionHandler: { [weak self] data, response, _ in
            guard let self, let data, (response as? HTTPURLResponse)?.statusCode == 200, let list = try? JSONDecoder().decode([ChogramBadge].self, from: data) else {
                return
            }
            defaults.set(data, forKey: ChogramBadges.cacheKey)
            defaults.set(now, forKey: ChogramBadges.lastUpdateKey)
            var badges: [Int64: ChogramBadge] = [:]
            for badge in list {
                badges[badge.userId] = badge
            }
            let _ = self.badges.swap(badges)
        }).resume()
    }
}
