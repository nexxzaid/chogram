import Foundation
import UIKit
import TelegramCore
import Display
import ChatInterfaceState
import PresentationDataUtils

extension ChatControllerImpl {
    enum ChogramSendConfirmationKind {
        case sticker
        case gif
        case voice
        case roundVideo
        
        var isEnabled: Bool {
            let settings = ChogramSettings.current
            switch self {
            case .sticker:
                return settings.confirmSendStickers
            case .gif:
                return settings.confirmSendGifs
            case .voice:
                return settings.confirmSendVoice
            case .roundVideo:
                return settings.confirmSendRoundVideos
            }
        }
        
        var title: String {
            switch self {
            case .sticker:
                return "Отправить стикер?"
            case .gif:
                return "Отправить GIF?"
            case .voice:
                return "Отправить голосовое?"
            case .roundVideo:
                return "Отправить кружок?"
            }
        }
    }
    
    private func chogramPresentSendConfirmation(kind: ChogramSendConfirmationKind, send: @escaping () -> Void, cancel: (() -> Void)? = nil) {
        let presentationData = self.presentationData
        self.present(textAlertController(context: self.context, title: kind.title, text: "", actions: [
            TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {
                cancel?()
            }),
            TextAlertAction(type: .defaultAction, title: "Отправить", action: {
                send()
            })
        ]), in: .window(.root))
    }
    
    // Returns true when the confirmation is shown and the caller must stop. `perform` repeats the send once confirmed.
    func chogramConfirmSend(kind: ChogramSendConfirmationKind, perform: @escaping () -> Void) -> Bool {
        if !kind.isEnabled || self.chogramSendConfirmed {
            return false
        }
        self.chogramPresentSendConfirmation(kind: kind, send: { [weak self] in
            guard let self else {
                return
            }
            self.chogramSendConfirmed = true
            perform()
            self.chogramSendConfirmed = false
        })
        return true
    }
    
    // Returns true when a confirmation is shown; the draft stays in place if the user cancels.
    func chogramConfirmSendRecording(draft: ChatInterfaceMediaDraftState, send: @escaping () -> Void) -> Bool {
        guard case .audio = draft, ChogramSendConfirmationKind.voice.isEnabled else {
            return false
        }
        self.chogramPresentSendConfirmation(kind: .voice, send: send)
        return true
    }
    
    // The camera screen has already finished the recording, so cancelling discards it.
    func chogramConfirmSendRoundVideo(send: @escaping () -> Void, discard: @escaping () -> Void) {
        self.chogramPresentSendConfirmation(kind: .roundVideo, send: send, cancel: discard)
    }
}
