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

private let chogramDeletedMessageAppearances: [(value: ChogramSettings.DeletedMessageAppearance, title: String)] = [
    (.gray, "Серое"),
    (.faded, "Полупрозрачное"),
    (.labelOnly, "Обычное")
]

private func chogramAppearanceTitle(_ appearance: ChogramSettings.DeletedMessageAppearance) -> String {
    return chogramDeletedMessageAppearances.first(where: { $0.value == appearance })?.title ?? ""
}

private func chogramAppearanceSummary(settings: ChogramSettings) -> String {
    let title = chogramAppearanceTitle(settings.deletedMessageAppearance)
    if settings.deletedMessageAppearance == .labelOnly {
        return title
    }
    return "\(title), \(settings.deletedMessageOpacity)%"
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

private final class ChogramSettingsStore {
    private let value: Atomic<ChogramSettings>
    private let promise: ValuePromise<ChogramSettings>

    var settings: Signal<ChogramSettings, NoError> {
        return self.promise.get()
    }

    init() {
        let settings = ChogramSettings.current
        self.value = Atomic<ChogramSettings>(value: settings)
        self.promise = ValuePromise<ChogramSettings>(settings, ignoreRepeated: true)
    }

    func update(_ f: (inout ChogramSettings) -> Void) {
        let updatedSettings = self.value.modify { current in
            var current = current
            f(&current)
            return current
        }
        updatedSettings.save()
        self.promise.set(updatedSettings)
    }
}

private func presentChogramOptions(context: AccountContext, title: String, options: [(title: String, action: () -> Void)], present: (ViewController) -> Void) {
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
    let actionSheet = ActionSheetController(presentationData: presentationData)
    var items: [ActionSheetItem] = [ActionSheetTextItem(title: title)]
    for option in options {
        items.append(ActionSheetButtonItem(title: option.title, color: .accent, action: { [weak actionSheet] in
            actionSheet?.dismissAnimated()
            option.action()
        }))
    }
    actionSheet.setItemGroups([
        ActionSheetItemGroup(items: items),
        ActionSheetItemGroup(items: [
            ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                actionSheet?.dismissAnimated()
            })
        ])
    ])
    present(actionSheet)
}

// MARK: - Main screen

private final class ChogramSettingsControllerArguments {
    let store: ChogramSettingsStore
    let openGhostMode: () -> Void
    let openDeletedMessageAppearance: () -> Void
    let clearDeletedMessages: () -> Void

    init(store: ChogramSettingsStore, openGhostMode: @escaping () -> Void, openDeletedMessageAppearance: @escaping () -> Void, clearDeletedMessages: @escaping () -> Void) {
        self.store = store
        self.openGhostMode = openGhostMode
        self.openDeletedMessageAppearance = openDeletedMessageAppearance
        self.clearDeletedMessages = clearDeletedMessages
    }
}

private enum ChogramSettingsSection: Int32 {
    case general
    case deleted
}

private enum ChogramSettingsControllerEntry: ItemListNodeEntry {
    case ghostMode(Bool)
    case hideAds(Bool)

    case deletedHeader
    case keepDeletedMessages(Bool)
    case deletedMessageAppearance(String)
    case clearDeletedMessages(Int)
    case deletedFooter

    var section: ItemListSectionId {
        switch self {
        case .ghostMode, .hideAds:
            return ChogramSettingsSection.general.rawValue
        case .deletedHeader, .keepDeletedMessages, .deletedMessageAppearance, .clearDeletedMessages, .deletedFooter:
            return ChogramSettingsSection.deleted.rawValue
        }
    }

    var stableId: Int32 {
        switch self {
        case .ghostMode:
            return 0
        case .hideAds:
            return 1
        case .deletedHeader:
            return 2
        case .keepDeletedMessages:
            return 3
        case .deletedMessageAppearance:
            return 4
        case .clearDeletedMessages:
            return 5
        case .deletedFooter:
            return 6
        }
    }

    static func <(lhs: ChogramSettingsControllerEntry, rhs: ChogramSettingsControllerEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! ChogramSettingsControllerArguments
        switch self {
        case let .ghostMode(value):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: "Режим призрака", label: value ? "Вкл." : "Выкл.", sectionId: self.section, style: .blocks, action: {
                arguments.openGhostMode()
            })
        case let .hideAds(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Без рекламы", value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.store.update { $0.hideAds = value }
            })
        case .deletedHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "УДАЛЁННЫЕ СООБЩЕНИЯ", sectionId: self.section)
        case let .keepDeletedMessages(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Сохранять удалённые", value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.store.update { $0.keepDeletedMessages = value }
            })
        case let .deletedMessageAppearance(summary):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: "Внешний вид", label: summary, sectionId: self.section, style: .blocks, action: {
                arguments.openDeletedMessageAppearance()
            })
        case let .clearDeletedMessages(count):
            return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: "Очистить сохранённые (\(count))", kind: count == 0 ? .disabled : .destructive, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                arguments.clearDeletedMessages()
            })
        case .deletedFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain("Видны только тебе. Секретные чаты и сообщения с таймером не сохраняются."), sectionId: self.section)
        }
    }
}

private func chogramSettingsControllerEntries(settings: ChogramSettings, deletedMessagesCount: Int) -> [ChogramSettingsControllerEntry] {
    return [
        .ghostMode(settings.ghostMode),
        .hideAds(settings.hideAds),
        .deletedHeader,
        .keepDeletedMessages(settings.keepDeletedMessages),
        .deletedMessageAppearance(chogramAppearanceSummary(settings: settings)),
        .clearDeletedMessages(deletedMessagesCount),
        .deletedFooter
    ]
}

public func chogramSettingsController(context: AccountContext) -> ViewController {
    let store = ChogramSettingsStore()

    let deletedMessagesCountPromise = Promise<Int>()
    deletedMessagesCountPromise.set(context.engine.messages.chogramDeletedMessagesCount())

    var pushControllerImpl: ((ViewController) -> Void)?
    var presentControllerImpl: ((ViewController) -> Void)?

    let arguments = ChogramSettingsControllerArguments(
        store: store,
        openGhostMode: {
            pushControllerImpl?(chogramGhostModeController(context: context, store: store))
        },
        openDeletedMessageAppearance: {
            pushControllerImpl?(chogramDeletedMessageAppearanceController(context: context, store: store))
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
        store.settings,
        deletedMessagesCountPromise.get()
    )
    |> map { presentationData, settings, deletedMessagesCount -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text("Чограм"), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: chogramSettingsControllerEntries(settings: settings, deletedMessagesCount: deletedMessagesCount), style: .blocks, animateChanges: true)

        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)
    pushControllerImpl = { [weak controller] c in
        controller?.push(c)
    }
    presentControllerImpl = { [weak controller] c in
        controller?.present(c, in: .window(.root))
    }
    return controller
}

// MARK: - Ghost mode

private final class ChogramGhostModeControllerArguments {
    let store: ChogramSettingsStore

    init(store: ChogramSettingsStore) {
        self.store = store
    }
}

private enum ChogramGhostModeEntry: ItemListNodeEntry {
    case enabled(Bool)
    case hideOnline(Bool)
    case hideRead(Bool)
    case hideStoryViews(Bool)
    case hideTyping(Bool)
    case footer

    var section: ItemListSectionId {
        return 0
    }

    var stableId: Int32 {
        switch self {
        case .enabled:
            return 0
        case .hideOnline:
            return 1
        case .hideRead:
            return 2
        case .hideStoryViews:
            return 3
        case .hideTyping:
            return 4
        case .footer:
            return 5
        }
    }

    static func <(lhs: ChogramGhostModeEntry, rhs: ChogramGhostModeEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! ChogramGhostModeControllerArguments
        switch self {
        case let .enabled(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Режим призрака", value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.store.update { $0.ghostMode = value }
            })
        case let .hideOnline(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Не показывать онлайн", value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.store.update { $0.ghostHideOnline = value }
            })
        case let .hideRead(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Не читать сообщения", value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.store.update { $0.ghostHideRead = value }
            })
        case let .hideStoryViews(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Не читать истории", value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.store.update { $0.ghostHideStoryViews = value }
            })
        case let .hideTyping(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Не показывать набор", value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.store.update { $0.ghostHideTyping = value }
            })
        case .footer:
            return ItemListTextItem(presentationData: presentationData, text: .plain("Отправка сообщения всё равно покажет тебя в сети. Чаты позже могут снова стать непрочитанными. Секретные чаты не затрагиваются."), sectionId: self.section)
        }
    }
}

private func chogramGhostModeEntries(settings: ChogramSettings) -> [ChogramGhostModeEntry] {
    var entries: [ChogramGhostModeEntry] = [.enabled(settings.ghostMode)]
    if settings.ghostMode {
        entries.append(.hideOnline(settings.ghostHideOnline))
        entries.append(.hideRead(settings.ghostHideRead))
        entries.append(.hideStoryViews(settings.ghostHideStoryViews))
        entries.append(.hideTyping(settings.ghostHideTyping))
    }
    entries.append(.footer)
    return entries
}

private func chogramGhostModeController(context: AccountContext, store: ChogramSettingsStore) -> ViewController {
    let arguments = ChogramGhostModeControllerArguments(store: store)

    let signal = combineLatest(queue: .mainQueue(),
        context.sharedContext.presentationData,
        store.settings
    )
    |> map { presentationData, settings -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text("Режим призрака"), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: chogramGhostModeEntries(settings: settings), style: .blocks, animateChanges: true)

        return (controllerState, (listState, arguments))
    }

    return ItemListController(context: context, state: signal)
}

// MARK: - Deleted message appearance

private final class ChogramDeletedMessageAppearanceArguments {
    let store: ChogramSettingsStore
    let chooseStyle: () -> Void
    let chooseOpacity: () -> Void
    let chooseIcon: () -> Void

    init(store: ChogramSettingsStore, chooseStyle: @escaping () -> Void, chooseOpacity: @escaping () -> Void, chooseIcon: @escaping () -> Void) {
        self.store = store
        self.chooseStyle = chooseStyle
        self.chooseOpacity = chooseOpacity
        self.chooseIcon = chooseIcon
    }
}

private enum ChogramDeletedMessageAppearanceEntry: ItemListNodeEntry {
    case style(String)
    case opacity(String)
    case icon(String)
    case label(String)
    case showDeletionTime(Bool)
    case preview(String)

    var section: ItemListSectionId {
        return 0
    }

    var stableId: Int32 {
        switch self {
        case .style:
            return 0
        case .opacity:
            return 1
        case .icon:
            return 2
        case .label:
            return 3
        case .showDeletionTime:
            return 4
        case .preview:
            return 5
        }
    }

    static func <(lhs: ChogramDeletedMessageAppearanceEntry, rhs: ChogramDeletedMessageAppearanceEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! ChogramDeletedMessageAppearanceArguments
        switch self {
        case let .style(value):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: "Стиль", label: value, sectionId: self.section, style: .blocks, action: {
                arguments.chooseStyle()
            })
        case let .opacity(value):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: "Непрозрачность", label: value, sectionId: self.section, style: .blocks, action: {
                arguments.chooseOpacity()
            })
        case let .icon(value):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: "Значок", label: value, sectionId: self.section, style: .blocks, action: {
                arguments.chooseIcon()
            })
        case let .label(value):
            return ItemListSingleLineInputItem(presentationData: presentationData, systemStyle: .glass, title: NSAttributedString(string: "Подпись", textColor: presentationData.theme.list.itemPrimaryTextColor), text: value, placeholder: "удалено", spacing: 12.0, maxLength: 24, sectionId: self.section, textUpdated: { value in
                arguments.store.update { $0.deletedMessageLabel = value }
            }, action: {
            })
        case let .showDeletionTime(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Время удаления", value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.store.update { $0.showDeletionTime = value }
            })
        case let .preview(value):
            return ItemListTextItem(presentationData: presentationData, text: .plain("В чате: \(value). Новый вид появится, когда откроешь чат заново."), sectionId: self.section)
        }
    }
}

private func chogramDeletedMessageAppearanceEntries(settings: ChogramSettings) -> [ChogramDeletedMessageAppearanceEntry] {
    var entries: [ChogramDeletedMessageAppearanceEntry] = [.style(chogramAppearanceTitle(settings.deletedMessageAppearance))]
    if settings.deletedMessageAppearance != .labelOnly {
        entries.append(.opacity("\(settings.deletedMessageOpacity)%"))
    }
    entries.append(.icon(settings.deletedMessageIcon.isEmpty ? "Нет" : settings.deletedMessageIcon))
    entries.append(.label(settings.deletedMessageLabel))
    entries.append(.showDeletionTime(settings.showDeletionTime))
    entries.append(.preview(chogramDeletedMessagePreview(settings: settings)))
    return entries
}

private func chogramDeletedMessageAppearanceController(context: AccountContext, store: ChogramSettingsStore) -> ViewController {
    var presentControllerImpl: ((ViewController) -> Void)?
    let present: (ViewController) -> Void = { c in
        presentControllerImpl?(c)
    }

    let arguments = ChogramDeletedMessageAppearanceArguments(
        store: store,
        chooseStyle: {
            presentChogramOptions(context: context, title: "Стиль", options: chogramDeletedMessageAppearances.map { appearance in
                return (appearance.title, {
                    store.update { $0.deletedMessageAppearance = appearance.value }
                })
            }, present: present)
        },
        chooseOpacity: {
            presentChogramOptions(context: context, title: "Непрозрачность", options: chogramDeletedMessageOpacities.map { opacity in
                return ("\(opacity)%", {
                    store.update { $0.deletedMessageOpacity = opacity }
                })
            }, present: present)
        },
        chooseIcon: {
            presentChogramOptions(context: context, title: "Значок", options: chogramDeletedMessageIcons.map { icon in
                return (icon.title, {
                    store.update { $0.deletedMessageIcon = icon.value }
                })
            }, present: present)
        }
    )

    let signal = combineLatest(queue: .mainQueue(),
        context.sharedContext.presentationData,
        store.settings
    )
    |> map { presentationData, settings -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text("Внешний вид"), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: chogramDeletedMessageAppearanceEntries(settings: settings), style: .blocks, animateChanges: true)

        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)
    presentControllerImpl = { [weak controller] c in
        controller?.present(c, in: .window(.root))
    }
    return controller
}
