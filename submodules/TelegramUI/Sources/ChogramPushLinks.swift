import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import AccountContext
import UndoUI

// chogram:// links come from the Chogram web app that delivers notifications:
//   chogram://push?token=<Firebase token>&key=<base64url, 256 bytes>  connects notifications
//   chogram://open?user=<id> | chat=<id> | channel=<id> [&msg=<id>]   opens the chat of a notification
let chogramPushTokenKey = "chogram.pushToken"

func chogramHandleUrl(_ url: URL, context: AccountContext, navigationController: NavigationController) -> Bool {
    guard url.scheme?.lowercased() == "chogram" else {
        return false
    }
    let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
    func value(_ name: String) -> String? {
        return items.first(where: { $0.name == name })?.value
    }

    switch url.host?.lowercased() {
    case "push":
        if let token = value("token"), !token.isEmpty, let key = value("key").flatMap(chogramBase64UrlData), key.count == 256 {
            chogramConnectPush(context: context, token: token, secret: key)
        } else {
            chogramToast(context: context, text: "Не получилось подключить уведомления: ссылка неполная. Открой веб-приложение Чограма и попробуй ещё раз.")
        }
    case "open":
        chogramOpenChat(context: context, navigationController: navigationController, value: value)
    default:
        break
    }
    return true
}

private func chogramBase64UrlData(_ string: String) -> Data? {
    var base64 = string.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
    while base64.count % 4 != 0 {
        base64.append("=")
    }
    return Data(base64Encoded: base64)
}

private func chogramToast(context: AccountContext, text: String) {
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
    context.sharedContext.presentGlobalController(UndoOverlayController(presentationData: presentationData, content: .info(title: nil, text: text, timeout: nil, customUndoText: nil), elevatedLayout: false, action: { _ in return false }), nil)
}

// Every signed-in account registers the same token, each listing the others, so one web app
// receives the notifications of all of them.
private func chogramConnectPush(context: AccountContext, token: String, secret: Data) {
    let _ = (context.sharedContext.activeAccountContexts
    |> take(1)
    |> mapToSignal { _, accounts, _ -> Signal<[Bool], NoError> in
        let userIds = accounts.map { $0.1.account.peerId.id }
        let signals = accounts.map { _, accountContext, _ -> Signal<Bool, NoError> in
            let others = userIds.filter { $0 != accountContext.account.peerId.id }
            return accountContext.engine.accountData.chogramRegisterFirebasePush(token: token, secret: secret, otherAccountUserIds: others)
        }
        return combineLatest(signals)
    }
    |> deliverOnMainQueue).startStandalone(next: { results in
        if !results.isEmpty && results.allSatisfy({ $0 }) {
            UserDefaults.standard.set(token, forKey: chogramPushTokenKey)
            chogramToast(context: context, text: "Уведомления подключены")
        } else {
            chogramToast(context: context, text: "Telegram не принял подключение уведомлений. Попробуй ещё раз позже.")
        }
    })
}

private func chogramOpenChat(context: AccountContext, navigationController: NavigationController, value: (String) -> String?) {
    let peerId: EnginePeer.Id
    if let id = value("user").flatMap(Int64.init) {
        peerId = EnginePeer.Id(namespace: Namespaces.Peer.CloudUser, id: EnginePeer.Id.Id._internalFromInt64Value(id))
    } else if let id = value("chat").flatMap(Int64.init) {
        peerId = EnginePeer.Id(namespace: Namespaces.Peer.CloudGroup, id: EnginePeer.Id.Id._internalFromInt64Value(id))
    } else if let id = value("channel").flatMap(Int64.init) {
        peerId = EnginePeer.Id(namespace: Namespaces.Peer.CloudChannel, id: EnginePeer.Id.Id._internalFromInt64Value(id))
    } else {
        return
    }
    let messageId = value("msg").flatMap(Int32.init)
    let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
    |> deliverOnMainQueue).startStandalone(next: { peer in
        guard let peer else {
            return
        }
        var subject: ChatControllerSubject?
        if let messageId {
            subject = .message(id: .id(EngineMessage.Id(peerId: peerId, namespace: Namespaces.Message.Cloud, id: messageId)), highlight: nil, timecode: nil, setupReply: false)
        }
        context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: context, chatLocation: .peer(peer), subject: subject))
    })
}
