import Foundation
import UIKit
import Display
import TelegramCore
import Postbox
import SwiftSignalKit
import AccountContext
import ItemListUI
import PresentationDataUtils
import TelegramPresentationData
import TelegramStringFormatting
import TextFormat
import UndoUI
import ChatPresentationInterfaceState
import ChatControllerInteraction

private struct ChogramEditHistoryEntry: ItemListNodeEntry {
    let index: Int
    let isHeader: Bool
    let text: String

    var section: ItemListSectionId {
        return Int32(self.index + 1)
    }

    var stableId: Int {
        return self.index * 2 + (self.isHeader ? 0 : 1)
    }

    static func <(lhs: ChogramEditHistoryEntry, rhs: ChogramEditHistoryEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        if self.isHeader {
            return ItemListSectionHeaderItem(presentationData: presentationData, text: self.text, sectionId: self.section)
        } else {
            return ItemListMultilineTextItem(presentationData: presentationData, text: self.text, enabledEntityTypes: [], sectionId: self.section, style: .blocks)
        }
    }
}

func chogramHasEditHistory(message: Message) -> Bool {
    return !message.chogramEditVersions.isEmpty
}

func chogramEditHistoryController(context: AccountContext, message: Message) -> ViewController {
    let versions = message.chogramEditVersions
    let currentDate = message.editedTime ?? message.timestamp
    let currentText = message.text

    let signal = context.sharedContext.presentationData
    |> map { presentationData -> (ItemListControllerState, (ItemListNodeState, Any)) in
        var entries: [ChogramEditHistoryEntry] = []
        var index = 0
        let currentTitle = "Сейчас · " + stringForFullDate(timestamp: currentDate, strings: presentationData.strings, dateTimeFormat: presentationData.dateTimeFormat)
        entries.append(ChogramEditHistoryEntry(index: index, isHeader: true, text: currentTitle.uppercased()))
        entries.append(ChogramEditHistoryEntry(index: index, isHeader: false, text: currentText.isEmpty ? "—" : currentText))
        index += 1
        for version in versions.reversed() {
            let title = stringForFullDate(timestamp: version.date, strings: presentationData.strings, dateTimeFormat: presentationData.dateTimeFormat)
            entries.append(ChogramEditHistoryEntry(index: index, isHeader: true, text: title.uppercased()))
            entries.append(ChogramEditHistoryEntry(index: index, isHeader: false, text: version.text.isEmpty ? "—" : version.text))
            index += 1
        }
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text("История правок"), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: entries, style: .blocks, animateChanges: false)
        return (controllerState, (listState, ()))
    }
    return ItemListController(context: context, state: signal)
}

// A deleted message no longer exists on the server, so it is sent again as a new message.
func chogramForwardDeletedMessages(context: AccountContext, messages: [Message], controllerInteraction: ChatControllerInteraction) {
    let sortedMessages = messages.sorted(by: { $0.index < $1.index })
    let controller = context.sharedContext.makePeerSelectionController(PeerSelectionControllerParams(context: context, filter: [.onlyWriteable, .excludeDisabled, .doNotSearchMessages], hasContactSelector: false, selectForumThreads: true))
    controller.peerSelected = { [weak controller] peer, threadId in
        var enqueued: [EnqueueMessage] = []
        for message in sortedMessages {
            var attributes: [MessageAttribute] = []
            if let entities = message.textEntitiesAttribute, !entities.entities.isEmpty {
                attributes.append(entities)
            }
            var mediaReference: AnyMediaReference?
            for media in message.media {
                if media is TelegramMediaImage || media is TelegramMediaFile || media is TelegramMediaMap || media is TelegramMediaContact {
                    mediaReference = .standalone(media: media)
                    break
                }
            }
            if message.text.isEmpty && mediaReference == nil {
                continue
            }
            enqueued.append(.message(text: message.text, attributes: attributes, inlineStickers: [:], mediaReference: mediaReference, threadId: threadId, replyToMessageId: nil, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: []))
        }
        if !enqueued.isEmpty {
            let _ = enqueueMessages(account: context.account, peerId: peer.id, messages: enqueued).startStandalone()
        }
        controller?.dismiss()
        controllerInteraction.displayUndo(.succeed(text: "Отправлено", timeout: 2.0, customUndoText: nil))
    }
    controllerInteraction.navigationController()?.pushViewController(controller)
}

// The original is gone, so the reply is a quote of its text in the input field.
func chogramReplyToDeletedMessage(message: Message, interfaceInteraction: ChatPanelInterfaceInteraction) {
    let quote = NSMutableAttributedString(attributedString: chatInputStateStringWithAppliedEntities(message.text, entities: message.textEntitiesAttribute?.entities ?? []))
    quote.addAttribute(ChatTextInputAttributes.block, value: ChatTextInputTextQuoteAttribute(kind: .quote, isCollapsed: false), range: NSRange(location: 0, length: quote.length))
    interfaceInteraction.updateTextInputStateAndMode { state, mode in
        let text = NSMutableAttributedString(attributedString: state.inputText)
        text.append(quote)
        text.append(NSAttributedString(string: "\n"))
        return (ChatTextInputState(inputText: text), mode)
    }
}
