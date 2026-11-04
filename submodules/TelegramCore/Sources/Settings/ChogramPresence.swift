import Foundation
import Postbox
import SwiftSignalKit

// Lets Chogram users see each other: a client adds its own account ID to the server while
// "Показывать, что я в Чограме" is on, and asks about one profile at a time. Nothing else is sent.
public final class ChogramPresence {
    public static let shared = ChogramPresence()

    private static let base = "https://selfhamer.tech/api/chogram/users"
    private static let reportedKey = "chogram.presenceReported"
    private static let cacheKey = "chogram.presenceCache"
    private static let cacheLifetime: TimeInterval = 6.0 * 60.0 * 60.0

    private let cache: Atomic<[Int64: (uses: Bool, date: Double)]>

    private init() {
        var cache: [Int64: (uses: Bool, date: Double)] = [:]
        if let stored = UserDefaults.standard.dictionary(forKey: ChogramPresence.cacheKey) as? [String: [Double]] {
            for (key, value) in stored {
                if let id = Int64(key), value.count == 2 {
                    cache[id] = (value[0] != 0.0, value[1])
                }
            }
        }
        self.cache = Atomic(value: cache)
    }

    // Brings the server in line with the setting for this account. Called on launch and when the
    // setting changes; it only makes a request when the reported state differs.
    public func syncOwnPresence(accountPeerId: PeerId) {
        let id = accountPeerId.id._internalGetInt64Value()
        let enabled = ChogramSettings.current.shareChogramPresence
        let defaults = UserDefaults.standard
        let reported = defaults.dictionary(forKey: ChogramPresence.reportedKey) as? [String: Bool] ?? [:]
        if reported["\(id)"] == enabled {
            return
        }
        var request: URLRequest
        if enabled {
            guard let url = URL(string: ChogramPresence.base) else {
                return
            }
            request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = "{\"userId\":\"\(id)\"}".data(using: .utf8)
        } else {
            guard let url = URL(string: "\(ChogramPresence.base)/\(id)") else {
                return
            }
            request = URLRequest(url: url)
            request.httpMethod = "DELETE"
        }
        request.timeoutInterval = 20.0
        URLSession.shared.dataTask(with: request, completionHandler: { _, response, _ in
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                return
            }
            var updated = defaults.dictionary(forKey: ChogramPresence.reportedKey) as? [String: Bool] ?? [:]
            updated["\(id)"] = enabled
            defaults.set(updated, forKey: ChogramPresence.reportedKey)
        }).resume()
    }

    public func usesChogram(peerId: PeerId) -> Signal<Bool, NoError> {
        guard peerId.namespace == Namespaces.Peer.CloudUser else {
            return .single(false)
        }
        let id = peerId.id._internalGetInt64Value()
        let now = Date().timeIntervalSince1970
        let cached = self.cache.with { $0[id] }
        let cachedSignal: Signal<Bool, NoError> = .single(cached?.uses ?? false)
        if let cached, now - cached.date < ChogramPresence.cacheLifetime {
            return cachedSignal
        }
        let remote = Signal<Bool, NoError> { [weak self] subscriber in
            guard let url = URL(string: "\(ChogramPresence.base)/\(id)") else {
                subscriber.putCompletion()
                return EmptyDisposable
            }
            var request = URLRequest(url: url)
            request.timeoutInterval = 20.0
            let task = URLSession.shared.dataTask(with: request, completionHandler: { data, response, _ in
                if let data, (response as? HTTPURLResponse)?.statusCode == 200, let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let uses = object["uses"] as? Bool {
                    self?.store(id: id, uses: uses, date: now)
                    subscriber.putNext(uses)
                }
                subscriber.putCompletion()
            })
            task.resume()
            return ActionDisposable {
                task.cancel()
            }
        }
        return cachedSignal |> then(remote)
    }

    private func store(id: Int64, uses: Bool, date: Double) {
        let updated = self.cache.modify { current in
            var current = current
            current[id] = (uses, date)
            return current
        }
        var stored: [String: [Double]] = [:]
        for (key, value) in updated {
            stored["\(key)"] = [value.uses ? 1.0 : 0.0, value.date]
        }
        UserDefaults.standard.set(stored, forKey: ChogramPresence.cacheKey)
    }
}
