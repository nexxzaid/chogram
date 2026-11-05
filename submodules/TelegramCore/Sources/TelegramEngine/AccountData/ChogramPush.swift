import Foundation
import SwiftSignalKit
import Postbox
internal import TelegramApi

// Chogram has no Apple push entitlement, so notifications come through the Chogram web app on the
// Home Screen: Telegram sends them to Firebase (token type 2), Firebase delivers them to the web
// app. The web app makes the token and the 256-byte key Telegram encrypts each push with, and hands
// both to Chogram, which registers them for every signed-in account.
func _internal_chogramRegisterFirebasePush(account: Account, token: String, secret: Data, otherAccountUserIds: [PeerId.Id]) -> Signal<Bool, NoError> {
    return account.network.request(Api.functions.account.registerDevice(flags: 0, tokenType: 2, token: token, appSandbox: .boolFalse, secret: Buffer(data: secret), otherUids: otherAccountUserIds.map({ $0._internalGetInt64Value() })))
    |> map { _ -> Bool in
        return true
    }
    |> `catch` { _ -> Signal<Bool, NoError> in
        return .single(false)
    }
}

func _internal_chogramUnregisterFirebasePush(account: Account, token: String, otherAccountUserIds: [PeerId.Id]) -> Signal<Never, NoError> {
    return account.network.request(Api.functions.account.unregisterDevice(tokenType: 2, token: token, otherUids: otherAccountUserIds.map({ $0._internalGetInt64Value() })))
    |> `catch` { _ -> Signal<Api.Bool, NoError> in
        return .complete()
    }
    |> ignoreValues
}
