import Foundation
import Postbox
import SwiftSignalKit

private let chogramProxyInstalledSecretKey = "chogram.proxyInstalledSecret"

// The workflow adds the secret to Info.plist of the finished IPA, so it stays out of the source
// and the build cache. Applies once per secret: turning the proxy off then stays off.
public func chogramInstallDefaultProxy(accountManager: AccountManager<TelegramAccountManagerTypes>) {
    guard let secretString = Bundle.main.object(forInfoDictionaryKey: "ChogramProxySecret") as? String, let secret = Data(base64Encoded: secretString), !secret.isEmpty else {
        return
    }
    let defaults = UserDefaults.standard
    if defaults.string(forKey: chogramProxyInstalledSecretKey) == secretString {
        return
    }
    defaults.set(secretString, forKey: chogramProxyInstalledSecretKey)

    let server = ProxyServerSettings(host: "31.76.10.227", port: 8443, connection: .mtp(secret: secret))
    let _ = updateProxySettingsInteractively(accountManager: accountManager, { settings in
        var settings = settings
        settings.servers.removeAll(where: { $0.host == server.host && $0.port == server.port })
        settings.servers.insert(server, at: 0)
        settings.activeServer = server
        settings.enabled = true
        return settings
    }).start()
}
