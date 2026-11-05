import Foundation
import UIKit
import SafariServices
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AccountContext

// Notifications through the Chogram web app: the web app lives on the Home Screen, receives the
// pushes Telegram sends through Firebase and hands its token to Chogram with a chogram:// link.
// The app only opens the web app's page and can turn notifications off again.
let chogramPushWebAppURL = "https://selfhamer.tech/chogram/push/"
private let chogramPushTokenKey = "chogram.pushToken"

private final class ChogramNotificationsArguments {
    let enable: () -> Void
    let disable: () -> Void

    init(enable: @escaping () -> Void, disable: @escaping () -> Void) {
        self.enable = enable
        self.disable = disable
    }
}

private enum ChogramNotificationsEntry: ItemListNodeEntry {
    case status(Bool)
    case enable(Bool)
    case disable
    case steps
    case footer

    var section: ItemListSectionId {
        switch self {
        case .status, .enable, .disable:
            return 0
        case .steps, .footer:
            return 1
        }
    }

    var stableId: Int32 {
        switch self {
        case .status:
            return 0
        case .enable:
            return 1
        case .disable:
            return 2
        case .steps:
            return 3
        case .footer:
            return 4
        }
    }

    static func <(lhs: ChogramNotificationsEntry, rhs: ChogramNotificationsEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! ChogramNotificationsArguments
        switch self {
        case let .status(isConnected):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: "Уведомления", label: isConnected ? "Подключены" : "Выключены", sectionId: self.section, style: .blocks, disclosureStyle: .none, action: nil)
        case let .enable(isConnected):
            return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: isConnected ? "Подключить заново" : "Включить уведомления", kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                arguments.enable()
            })
        case .disable:
            return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: "Отключить", kind: .destructive, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                arguments.disable()
            })
        case .steps:
            return ItemListTextItem(presentationData: presentationData, text: .plain("Как включить:\n1. Нажми «Включить уведомления», откроется страница Чограма.\n2. Внизу нажми «Поделиться» → «На экран „Домой“» → «Добавить».\n3. Открой новую иконку «Чограм» с экрана «Домой» и нажми «Разрешить».\n4. Нажми «Подключить к Чограму» — откроется Чограм и покажет «Уведомления подключены»."), sectionId: self.section)
        case .footer:
            return ItemListTextItem(presentationData: presentationData, text: .plain("Уведомления присылает сам Telegram, наш сервер к аккаунту не подключается. Иконку на экране «Домой» не удаляй, иначе уведомления перестанут приходить; её можно убрать в папку. Нужна iOS 16.4 или новее."), sectionId: self.section)
        }
    }
}

public func chogramNotificationsController(context: AccountContext) -> ViewController {
    let statePromise = ValuePromise<Bool>(UserDefaults.standard.string(forKey: chogramPushTokenKey) != nil, ignoreRepeated: true)
    var presentControllerImpl: ((ViewController) -> Void)?

    let arguments = ChogramNotificationsArguments(enable: {
        guard let url = URL(string: chogramPushWebAppURL) else {
            return
        }
        // Safari View Controller has "Add to Home Screen" since iOS 17; older systems open Safari.
        if #available(iOS 17.0, *) {
            context.sharedContext.applicationBindings.presentNativeController(SFSafariViewController(url: url))
        } else {
            context.sharedContext.applicationBindings.openUrl(chogramPushWebAppURL)
        }
    }, disable: {
        guard let token = UserDefaults.standard.string(forKey: chogramPushTokenKey) else {
            return
        }
        let _ = (context.sharedContext.activeAccountContexts
        |> take(1)
        |> mapToSignal { _, accounts, _ -> Signal<Never, NoError> in
            let userIds = accounts.map { $0.1.account.peerId.id }
            let signals = accounts.map { _, accountContext, _ -> Signal<Never, NoError> in
                let others = userIds.filter { $0 != accountContext.account.peerId.id }
                return accountContext.engine.accountData.chogramUnregisterFirebasePush(token: token, otherAccountUserIds: others)
            }
            return combineLatest(signals) |> ignoreValues
        }
        |> deliverOnMainQueue).startStandalone(completed: {
            UserDefaults.standard.removeObject(forKey: chogramPushTokenKey)
            statePromise.set(false)
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            presentControllerImpl?(textAlertController(context: context, title: nil, text: "Уведомления отключены. Иконку Чограма на экране «Домой» теперь можно удалить.", actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]))
        })
    })

    let signal = combineLatest(queue: .mainQueue(),
        context.sharedContext.presentationData,
        statePromise.get()
    )
    |> map { presentationData, isConnected -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text("Уведомления"), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        var entries: [ChogramNotificationsEntry] = [.status(isConnected), .enable(isConnected)]
        if isConnected {
            entries.append(.disable)
        }
        entries.append(.steps)
        entries.append(.footer)
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: entries, style: .blocks, animateChanges: true)
        return (controllerState, (listState, arguments))
    }

    // The status changes while the page that connects notifications covers this screen, so it is
    // refreshed when Chogram reports the change, not only when the screen reappears.
    let observer = NotificationCenter.default.addObserver(forName: NSNotification.Name("ChogramPushStateDidChange"), object: nil, queue: .main, using: { _ in
        statePromise.set(UserDefaults.standard.string(forKey: chogramPushTokenKey) != nil)
    })
    let controller = ItemListController(context: context, state: signal |> afterDisposed {
        NotificationCenter.default.removeObserver(observer)
    })
    controller.didAppear = { _ in
        statePromise.set(UserDefaults.standard.string(forKey: chogramPushTokenKey) != nil)
    }
    presentControllerImpl = { [weak controller] c in
        controller?.present(c, in: .window(.root))
    }
    return controller
}
