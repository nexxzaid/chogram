import Foundation
import UIKit
import Display
import AccountContext
import TelegramCore
import PresentationDataUtils
import TelegramPresentationData

// Opening someone's story marks it seen. When ghost mode does not hide story views for this account,
// ask first. Returns true when the alert was shown and the caller must stop: `proceed` opens the story.
func chogramAskBeforeStory(context: AccountContext, peerId: EnginePeer.Id, parentController: ViewController, proceed: @escaping () -> Void) -> Bool {
    let settings = ChogramSettings.current
    guard settings.ghostAskBeforeStory, peerId != context.account.peerId else {
        return false
    }
    let accountPeerId = context.account.peerId.toInt64()
    if settings.isGhostModeActive(accountPeerId: accountPeerId) && settings.ghostHideStoryViews {
        return false
    }
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
    let alert = textAlertController(context: context, title: "Включить режим призрака?", text: "Сейчас автор увидит, что ты смотрел историю.", actions: [
        TextAlertAction(type: .defaultAction, title: "Включить и смотреть", action: {
            var settings = ChogramSettings.current
            settings.setGhostMode(true, accountPeerId: accountPeerId)
            settings.ghostHideStoryViews = true
            settings.save()
            proceed()
        }),
        TextAlertAction(type: .genericAction, title: "Смотреть так", action: {
            proceed()
        }),
        TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {})
    ], actionLayout: .vertical)
    parentController.present(alert, in: .window(.root))
    return true
}
