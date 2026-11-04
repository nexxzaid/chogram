import Foundation
import SwiftSignalKit

// Builds and their notes come from the same source file SideStore reads, so the update banner and
// "Что нового" always agree with what SideStore offers.
struct ChogramBuildInfo: Equatable {
    let build: Int
    let date: String
    let notes: String
    let downloadURL: String
}

struct ChogramUpdatesState: Equatable {
    let currentBuild: Int
    let builds: [ChogramBuildInfo]

    var latest: ChogramBuildInfo? {
        return self.builds.first
    }

    var current: ChogramBuildInfo? {
        return self.builds.first(where: { $0.build == self.currentBuild })
    }

    var hasUpdate: Bool {
        guard let latest = self.latest else {
            return false
        }
        return latest.build > self.currentBuild
    }
}

let chogramSourceURL = "https://selfhamer.tech/chogram/source.json"

func chogramCurrentBuild() -> Int {
    return Int(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "") ?? 0
}

private func chogramShortDate(_ value: String) -> String {
    let parser = ISO8601DateFormatter()
    guard let date = parser.date(from: value) else {
        return ""
    }
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ru_RU")
    formatter.dateFormat = "d MMMM yyyy"
    return formatter.string(from: date)
}

func chogramUpdatesState() -> Signal<ChogramUpdatesState?, NoError> {
    return Signal { subscriber in
        guard let url = URL(string: chogramSourceURL) else {
            subscriber.putNext(nil)
            subscriber.putCompletion()
            return EmptyDisposable
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 15.0
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let task = URLSession.shared.dataTask(with: request, completionHandler: { data, response, _ in
            var result: ChogramUpdatesState?
            if let data, (response as? HTTPURLResponse)?.statusCode == 200, let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let apps = object["apps"] as? [[String: Any]], let app = apps.first, let versions = app["versions"] as? [[String: Any]] {
                var builds: [ChogramBuildInfo] = []
                for version in versions {
                    guard let buildString = version["buildVersion"] as? String, let build = Int(buildString) else {
                        continue
                    }
                    builds.append(ChogramBuildInfo(
                        build: build,
                        date: chogramShortDate(version["date"] as? String ?? ""),
                        notes: version["localizedDescription"] as? String ?? "",
                        downloadURL: version["downloadURL"] as? String ?? ""
                    ))
                }
                builds.sort(by: { $0.build > $1.build })
                result = ChogramUpdatesState(currentBuild: chogramCurrentBuild(), builds: builds)
            }
            subscriber.putNext(result)
            subscriber.putCompletion()
        })
        task.resume()
        return ActionDisposable {
            task.cancel()
        }
    }
}

// SideStore installs straight from the build's download link.
func chogramSideStoreInstallURL(for build: ChogramBuildInfo) -> String {
    let allowed = CharacterSet.urlQueryAllowed.subtracting(CharacterSet(charactersIn: "&=?"))
    let encoded = build.downloadURL.addingPercentEncoding(withAllowedCharacters: allowed) ?? build.downloadURL
    return "sidestore://install?url=\(encoded)"
}
