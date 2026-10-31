import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AccountContext

private let chogramDeletedMessageIcons: [(value: String, title: String)] = [
    ("🗑", "🗑 Корзина"),
    ("👻", "👻 Призрак"),
    ("👀", "👀 Глаза"),
    ("❌", "❌ Крестик"),
    ("", "Без значка")
]

private let chogramDeletedMessageOpacities: [Int] = [30, 50, 70, 100]

private final class ChogramSettingsControllerArguments {
    let updateKeepDeletedMessages: (Bool) -> Void
    let updateAppearance: (ChogramSettings.DeletedMessageAppearance) -> Void
    let updateOpacity: (Int) -> Void
    let updateIcon: (String) -> Void
    let updateLabel: (String) -> Void
    let updateShowDeletionTime: (Bool) -> Void
    let clearDeletedMessages: () -> Void

    init(
        updateKeepDeletedMessages: @escaping (Bool) -> Void,
        updateAppearance: @escaping (ChogramSettings.DeletedMessageAppearance) -> Void,
        updateOpacity: @escaping (Int) -> Void,
        updateIcon: @escaping (String) -> Void,
        updateLabel: @escaping (String) -> Void,
        updateShowDeletionTime: @escaping (Bool) -> Void,
        clearDeletedMessages: @escaping () -> Void
    ) {
        self.updateKeepDeletedMessages = updateKeepDeletedMessages
        self.updateAppearance = updateAppearance
        self.updateOpacity = updateOpacity
        self.updateIcon = updateIcon
        self.updateLabel = updateLabel
        self.updateShowDeletionTime = updateShowDeletionTime
        self.clearDeletedMessages = clearDeletedMessages
    }
}

private enum ChogramSettingsSection: Int32 {
    case keep
    case appearance
    case opacity
    case icon
    case label
    case clear
}

private enum ChogramSettingsControllerEntry: ItemListNodeEntry {
    case keepHeader
    case keepValue(Bool)
    case keepFooter

    case appearanceHeader
    case appearanceValue(Int32, String, ChogramSettings.DeletedMessageAppearance, Bool)

    case opacityHeader
    case opacityValue(Int32, Int, Bool)

    case iconHeader
    case iconValue(Int32, String, String, Bool)

    case labelHeader
    case labelValue(String)
    case showDeletionTime(Bool)
    case labelFooter(String)

    case clearAction(Int)
    case clearFooter

    var section: ItemListSectionId {
        switch self {
        case .keepHeader, .keepValue, .keepFooter:
            return ChogramSettingsSection.keep.rawValue
        case .appearanceHeader, .appearanceValue:
            return ChogramSettingsSection.appearance.rawValue
        case .opacityHeader, .opacityValue:
            return ChogramSettingsSection.opacity.rawValue
        case .iconHeader, .iconValue:
            return ChogramSettingsSection.icon.rawValue
        case .labelHeader, .labelValue, .showDeletionTime, .labelFooter:
            return ChogramSettingsSection.label.rawValue
        case .clearAction, .clearFooter:
            return ChogramSettingsSection.clear.rawValue
        }
    }

    var stableId: Int32 {
        switch self {
        case .keepHeader:
            return 0
        case .keepValue:
            return 1
        case .keepFooter:
            return 2
        case .appearanceHeader:
            return 10
        case let .appearanceValue(index, _, _, _):
            return 11 + index
        case .opacityHeader:
            return 20
        case let .opacityValue(index, _, _):
            return 21 + index
        case .iconHeader:
            return 30
        case let .iconValue(index, _, _, _):
            return 31 + index
        case .labelHeader:
            return 40
        case .labelValue:
            return 41
        case .showDeletionTime:
            return 42
        case .labelFooter:
            return 43
        case .clearAction:
            return 50
        case .clearFooter:
            return 51
        }
    }

    static func <(lhs: ChogramSettingsControllerEntry, rhs: ChogramSettingsControllerEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! ChogramSettingsControllerArguments
        switch self {
        case .keepHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "УДАЛЁННЫЕ СООБЩЕНИЯ", sectionId: self.section)
        case let .keepValue(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Сохранять удалённые", value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.updateKeepDeletedMessages(value)
            })
        case .keepFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain("Сообщение, удалённое собеседником, останется в чате, и увидишь его только ты. Секретные чаты и сообщения с таймером не сохраняются. Фото и файлы останутся, только если успели загрузиться."), sectionId: self.section)
        case .appearanceHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "КАК ВЫГЛЯДИТ В ЧАТЕ", sectionId: self.section)
        case let .appearanceValue(_, title, appearance, isSelected):
            return ItemListCheckboxItem(presentationData: presentationData, systemStyle: .glass, title: title, style: .left, checked: isSelected, zeroSeparatorInsets: false, sectionId: self.section, action: {
                arguments.updateAppearance(appearance)
            })
        case .opacityHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "НЕПРОЗРАЧНОСТЬ", sectionId: self.section)
        case let .opacityValue(_, value, isSelected):
            return ItemListCheckboxItem(presentationData: presentationData, systemStyle: .glass, title: "\(value)%", style: .left, checked: isSelected, zeroSeparatorInsets: false, sectionId: self.section, action: {
                arguments.updateOpacity(value)
            })
        case .iconHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "ЗНАЧОК", sectionId: self.section)
        case let .iconValue(_, value, title, isSelected):
            return ItemListCheckboxItem(presentationData: presentationData, systemStyle: .glass, title: title, style: .left, checked: isSelected, zeroSeparatorInsets: false, sectionId: self.section, action: {
                arguments.updateIcon(value)
            })
        case .labelHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "ПОДПИСЬ", sectionId: self.section)
        case let .labelValue(value):
            return ItemListSingleLineInputItem(presentationData: presentationData, systemStyle: .glass, title: NSAttributedString(string: "Текст", textColor: presentationData.theme.list.itemPrimaryTextColor), text: value, placeholder: "удалено", maxLength: 24, sectionId: self.section, textUpdated: { value in
                arguments.updateLabel(value)
            }, action: {
            })
        case let .showDeletionTime(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Время удаления", value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.updateShowDeletionTime(value)
            })
        case let .labelFooter(preview):
            return ItemListTextItem(presentationData: presentationData, text: .plain("В чате: \(preview). Новый вид появится, когда откроешь чат заново."), sectionId: self.section)
        case let .clearAction(count):
            return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: "Очистить сохранённые (\(count))", kind: count == 0 ? .disabled : .destructive, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                arguments.clearDeletedMessages()
            })
        case .clearFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain("Убирает удалённые сообщения из всех чатов на этом устройстве."), sectionId: self.section)
        }
    }
}

private func chogramDeletedMessagePreview(settings: ChogramSettings) -> String {
    var components: [String] = []
    if !settings.deletedMessageIcon.isEmpty {
        components.append(settings.deletedMessageIcon)
    }
    if !settings.deletedMessageLabel.isEmpty {
        components.append(settings.deletedMessageLabel)
    }
    if settings.showDeletionTime {
        components.append("12:34")
    }
    if components.isEmpty {
        return "12:20"
    }
    return "\(components.joined(separator: " ")) · 12:20"
}

private func chogramSettingsControllerEntries(settings: ChogramSettings, deletedMessagesCount: Int) -> [ChogramSettingsControllerEntry] {
    var entries: [ChogramSettingsControllerEntry] = []

    entries.append(.keepHeader)
    entries.append(.keepValue(settings.keepDeletedMessages))
    entries.append(.keepFooter)

    entries.append(.appearanceHeader)
    entries.append(.appearanceValue(0, "Серое", .gray, settings.deletedMessageAppearance == .gray))
    entries.append(.appearanceValue(1, "Полупрозрачное", .faded, settings.deletedMessageAppearance == .faded))
    entries.append(.appearanceValue(2, "Обычное, только подпись", .labelOnly, settings.deletedMessageAppearance == .labelOnly))

    if settings.deletedMessageAppearance != .labelOnly {
        entries.append(.opacityHeader)
        for (index, value) in chogramDeletedMessageOpacities.enumerated() {
            entries.append(.opacityValue(Int32(index), value, settings.deletedMessageOpacity == value))
        }
    }

    entries.append(.iconHeader)
    for (index, icon) in chogramDeletedMessageIcons.enumerated() {
        entries.append(.iconValue(Int32(index), icon.value, icon.title, settings.deletedMessageIcon == icon.value))
    }

    entries.append(.labelHeader)
    entries.append(.labelValue(settings.deletedMessageLabel))
    entries.append(.showDeletionTime(settings.showDeletionTime))
    entries.append(.labelFooter(chogramDeletedMessagePreview(settings: settings)))

    entries.append(.clearAction(deletedMessagesCount))
    entries.append(.clearFooter)

    return entries
}

public func chogramSettingsController(context: AccountContext) -> ViewController {
    let initialSettings = ChogramSettings.current
    let settingsValue = Atomic<ChogramSettings>(value: initialSettings)
    let settingsPromise = ValuePromise<ChogramSettings>(initialSettings, ignoreRepeated: true)

    let updateSettings: (@escaping (inout ChogramSettings) -> Void) -> Void = { f in
        let updatedSettings = settingsValue.modify { current in
            var current = current
            f(&current)
            return current
        }
        updatedSettings.save()
        settingsPromise.set(updatedSettings)
    }

    let deletedMessagesCountPromise = Promise<Int>()
    deletedMessagesCountPromise.set(context.engine.messages.chogramDeletedMessagesCount())

    var presentControllerImpl: ((ViewController) -> Void)?

    let arguments = ChogramSettingsControllerArguments(
        updateKeepDeletedMessages: { value in
            updateSettings { $0.keepDeletedMessages = value }
        },
        updateAppearance: { value in
            updateSettings { $0.deletedMessageAppearance = value }
        },
        updateOpacity: { value in
            updateSettings { $0.deletedMessageOpacity = value }
        },
        updateIcon: { value in
            updateSettings { $0.deletedMessageIcon = value }
        },
        updateLabel: { value in
            updateSettings { $0.deletedMessageLabel = value }
        },
        updateShowDeletionTime: { value in
            updateSettings { $0.showDeletionTime = value }
        },
        clearDeletedMessages: {
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            presentControllerImpl?(textAlertController(context: context, title: nil, text: "Удалить все сохранённые сообщения с этого устройства?", actions: [
                TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {}),
                TextAlertAction(type: .destructiveAction, title: presentationData.strings.Common_Delete, action: {
                    let _ = (context.engine.messages.chogramClearDeletedMessages()
                    |> deliverOnMainQueue).startStandalone(completed: {
                        deletedMessagesCountPromise.set(context.engine.messages.chogramDeletedMessagesCount())
                    })
                })
            ]))
        }
    )

    let signal = combineLatest(queue: .mainQueue(),
        context.sharedContext.presentationData,
        settingsPromise.get(),
        deletedMessagesCountPromise.get()
    )
    |> map { presentationData, settings, deletedMessagesCount -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text("Чограм"), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: chogramSettingsControllerEntries(settings: settings, deletedMessagesCount: deletedMessagesCount), style: .blocks, animateChanges: true)

        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)
    presentControllerImpl = { [weak controller] c in
        controller?.present(c, in: .window(.root))
    }
    return controller
}
