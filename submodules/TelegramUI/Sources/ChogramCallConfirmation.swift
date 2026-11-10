import Foundation
import UIKit
import SwiftSignalKit
import TelegramCore
import Display
import AccountContext
import PresentationDataUtils

extension AccountContextImpl {
    func chogramConfirmCall(peerId: EnginePeer.Id, isVideo: Bool, completion: @escaping () -> Void) {
        let _ = (self.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
        |> deliverOnMainQueue).startStandalone(next: { [weak self] peer in
            guard let self else {
                return
            }
            let presentationData = self.sharedContext.currentPresentationData.with { $0 }
            let name = peer?.compactDisplayTitle ?? ""
            let title = name.isEmpty ? "Позвонить?" : "Позвонить \(name)?"
            self.sharedContext.mainWindow?.present(textAlertController(context: self, title: title, text: isVideo ? "Будет видеозвонок." : "Будет голосовой звонок.", actions: [
                TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {}),
                TextAlertAction(type: .defaultAction, title: "Позвонить", action: { [weak self] in
                    self?.performRequestCall(peerId: peerId, isVideo: isVideo, completion: completion)
                })
            ]), on: .root)
        })
    }
}
