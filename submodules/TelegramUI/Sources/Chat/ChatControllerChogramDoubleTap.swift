import Foundation
import UIKit
import TelegramCore
import Display
import Postbox
import UndoUI
import Pasteboard
import ChatPresentationInterfaceState

extension ChatControllerImpl {
    // Returns true when the double tap was handled here and the quick reaction must not be sent.
    func chogramHandleDoubleTap(message: Message) -> Bool {
        let isIncoming = message.flags.contains(.Incoming)
        let settings = ChogramSettings.current
        let action = isIncoming ? settings.doubleTapIncoming : settings.doubleTapOutgoing
        switch action {
        case .reaction:
            return false
        case .nothing:
            return true
        case .reply:
            self.interfaceInteraction?.setupReplyMessage(message.id, nil, { _, f in f() })
        case .copy:
            if message.text.isEmpty || self.presentationInterfaceState.copyProtectionEnabled || message.isCopyProtected() {
                return true
            }
            var entities: [MessageTextEntity]?
            for attribute in message.attributes {
                if let attribute = attribute as? TextEntitiesMessageAttribute {
                    entities = attribute.entities
                }
            }
            storeMessageTextInPasteboard(message.text, entities: entities)
            self.present(UndoOverlayController(presentationData: self.presentationData, content: .copy(text: "Скопировано"), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .current)
        case .forward:
            if self.presentationInterfaceState.copyProtectionEnabled || message.isCopyProtected() {
                return true
            }
            self.interfaceInteraction?.forwardMessages([message])
        case .edit:
            if !isIncoming && message.id.namespace == Namespaces.Message.Cloud {
                self.interfaceInteraction?.setupEditMessage(message.id, { _ in })
            }
        }
        return true
    }
}
