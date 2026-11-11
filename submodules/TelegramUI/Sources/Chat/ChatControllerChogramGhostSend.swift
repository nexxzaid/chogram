import Foundation
import UIKit
import TelegramCore
import Display
import UndoUI

// Ghost send turns a message into a scheduled one a few seconds ahead, so it leaves the history until
// the server publishes it. Without a notice that reads as a send that did nothing.
extension ChatControllerImpl {
    func chogramObserveGhostSend() {
        if self.chogramGhostSendObserver != nil {
            return
        }
        self.chogramGhostSendObserver = NotificationCenter.default.addObserver(forName: chogramGhostSendDivertedNotification, object: nil, queue: .main, using: { [weak self] notification in
            guard let self else {
                return
            }
            guard let peerIdValue = notification.userInfo?["peerId"] as? Int64, let peerId = self.chatLocation.peerId, peerId.toInt64() == peerIdValue else {
                return
            }
            if case .scheduledMessages = self.presentationInterfaceState.subject {
                return
            }
            guard self.isNodeLoaded, self.view.window != nil else {
                return
            }
            let delay = notification.userInfo?["delay"] as? Int32 ?? 12
            self.chogramGhostSendToast?.dismiss()
            let toast = UndoOverlayController(presentationData: self.presentationData, content: .info(title: nil, text: "Режим призрака: сообщение появится в чате через \(delay) с. Пока оно в отложенных.", timeout: Double(delay), customUndoText: "Открыть"), elevatedLayout: false, action: { [weak self] action in
                if case .undo = action {
                    self?.openScheduledMessages()
                }
                return false
            })
            self.chogramGhostSendToast = toast
            self.present(toast, in: .current)
        })
    }
}
