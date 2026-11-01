import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AccountContext
import AppBundle
import AvatarNode

private let chogramDeletedMessageIcons: [String] = ["🗑", "👻", "👀", "❌", ""]

private let chogramDeletedMessageAppearances: [(value: ChogramSettings.DeletedMessageAppearance, title: String, subtitle: String)] = [
    (.gray, "Серое", "Без цвета, можно прозрачнее"),
    (.faded, "Полупрозрачное", "Цвета остаются"),
    (.labelOnly, "Обычное", "Только значок и подпись")
]

private let chogramAppIcons: [(name: String?, imageName: String, title: String)] = [
    (nil, "Chogram/AppIconClassic", "Классика"),
    ("ChogramMint", "Chogram/AppIconMint", "Мята"),
    ("ChogramWhite", "Chogram/AppIconWhite", "Белая"),
    ("ChogramNight", "Chogram/AppIconNight", "Ночь"),
    ("ChogramWave", "Chogram/AppIconWave", "Волна"),
    ("ChogramOutline", "Chogram/AppIconOutline", "Контур")
]

private let chogramThemeCache = Atomic<(base: PresentationTheme, theme: PresentationTheme)?>(value: nil)

private func chogramPresentationData(_ presentationData: PresentationData) -> PresentationData {
    let theme = presentationData.theme
    if let cached = chogramThemeCache.with({ $0 }), cached.base === theme {
        return presentationData.withUpdated(theme: cached.theme)
    }
    let accentColor = theme.overallDarkAppearance ? UIColor(rgb: 0x5EEAD4) : UIColor(rgb: 0x0F8F7E)
    let list = theme.list.withUpdated(
        itemAccentColor: accentColor,
        sectionHeaderTextColor: accentColor,
        itemSwitchColors: theme.list.itemSwitchColors.withUpdated(positiveColor: accentColor)
    )
    let updatedTheme = PresentationTheme(name: theme.name, index: theme.index, referenceTheme: theme.referenceTheme, overallDarkAppearance: theme.overallDarkAppearance, intro: theme.intro, passcode: theme.passcode, rootController: theme.rootController, list: list, chatList: theme.chatList, chat: theme.chat, actionSheet: theme.actionSheet, contextMenu: theme.contextMenu, inAppNotification: theme.inAppNotification, chart: theme.chart, preview: theme.preview)
    let _ = chogramThemeCache.swap((base: theme, theme: updatedTheme))
    return presentationData.withUpdated(theme: updatedTheme)
}

private func chogramIcon(_ name: String, presentationData: ItemListPresentationData) -> UIImage? {
    return generateTintedImage(image: UIImage(bundleImageName: "Chogram/\(name)"), color: presentationData.theme.list.itemAccentColor)
}

private func chogramStylePreviewImage(theme: PresentationTheme, appearance: ChogramSettings.DeletedMessageAppearance) -> UIImage? {
    return generateImage(CGSize(width: 44.0, height: 44.0), rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        let color: UIColor
        switch appearance {
        case .gray:
            color = theme.list.itemSecondaryTextColor.withAlphaComponent(0.55)
        case .faded:
            color = theme.list.itemAccentColor.withAlphaComponent(0.4)
        case .labelOnly:
            color = theme.list.itemAccentColor
        }
        context.setFillColor(color.cgColor)
        context.addPath(UIBezierPath(roundedRect: CGRect(x: 1.0, y: 6.0, width: 42.0, height: 32.0), cornerRadius: 12.0).cgPath)
        context.fillPath()
        context.setFillColor(theme.list.itemBlocksBackgroundColor.cgColor)
        context.fill(CGRect(x: 9.0, y: 15.0, width: 26.0, height: 3.0))
        context.fill(CGRect(x: 9.0, y: 24.0, width: 16.0, height: 3.0))
    })
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
        NotificationCenter.default.post(name: NSNotification.Name("ChogramSettingsDidChange"), object: nil)
    }

    // The chat list can toggle ghost mode while these screens exist.
    func reload() {
        let settings = ChogramSettings.current
        let _ = self.value.swap(settings)
        self.promise.set(settings)
    }
}

// MARK: - Main screen

private final class ChogramSettingsControllerArguments {
    let store: ChogramSettingsStore
    let openGhostMode: () -> Void
    let openDeletedMessages: () -> Void
    let openLooks: () -> Void
    let openRepository: () -> Void

    init(store: ChogramSettingsStore, openGhostMode: @escaping () -> Void, openDeletedMessages: @escaping () -> Void, openLooks: @escaping () -> Void, openRepository: @escaping () -> Void) {
        self.store = store
        self.openGhostMode = openGhostMode
        self.openDeletedMessages = openDeletedMessages
        self.openLooks = openLooks
        self.openRepository = openRepository
    }
}

private enum ChogramSettingsSection: Int32 {
    case header
    case categories
    case links
}

private enum ChogramSettingsControllerEntry: ItemListNodeEntry {
    case header(String, String)

    case categoriesHeader
    case ghostMode(String)
    case deletedMessages(String)
    case looks
    case hideAds(Bool)

    case linksHeader
    case repository

    var section: ItemListSectionId {
        switch self {
        case .header:
            return ChogramSettingsSection.header.rawValue
        case .categoriesHeader, .ghostMode, .deletedMessages, .looks, .hideAds:
            return ChogramSettingsSection.categories.rawValue
        case .linksHeader, .repository:
            return ChogramSettingsSection.links.rawValue
        }
    }

    var stableId: Int32 {
        switch self {
        case .header:
            return 0
        case .categoriesHeader:
            return 1
        case .ghostMode:
            return 2
        case .deletedMessages:
            return 3
        case .looks:
            return 4
        case .hideAds:
            return 5
        case .linksHeader:
            return 6
        case .repository:
            return 7
        }
    }

    static func <(lhs: ChogramSettingsControllerEntry, rhs: ChogramSettingsControllerEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! ChogramSettingsControllerArguments
        switch self {
        case let .header(version, logoImageName):
            return ChogramSettingsHeaderItem(presentationData: presentationData, title: "Чограм", subtitle: version, logoImageName: logoImageName, sectionId: self.section)
        case .categoriesHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "КАТЕГОРИИ", sectionId: self.section)
        case let .ghostMode(summary):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, icon: chogramIcon("Ghost", presentationData: presentationData), title: "Режим призрака", label: summary, sectionId: self.section, style: .blocks, action: {
                arguments.openGhostMode()
            })
        case let .deletedMessages(summary):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, icon: chogramIcon("Trash", presentationData: presentationData), title: "Удалённые сообщения", label: summary, sectionId: self.section, style: .blocks, action: {
                arguments.openDeletedMessages()
            })
        case .looks:
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, icon: chogramIcon("Palette", presentationData: presentationData), title: "Оформление", label: "", sectionId: self.section, style: .blocks, action: {
                arguments.openLooks()
            })
        case let .hideAds(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, icon: chogramIcon("AdBlock", presentationData: presentationData), title: "Без рекламы", value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.store.update { $0.hideAds = value }
            })
        case .linksHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "ССЫЛКИ", sectionId: self.section)
        case .repository:
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, icon: chogramIcon("Link", presentationData: presentationData), title: "Исходный код", label: "GitHub", sectionId: self.section, style: .blocks, action: {
                arguments.openRepository()
            })
        }
    }
}

private func chogramGhostSummary(settings: ChogramSettings) -> String {
    guard settings.ghostMode else {
        return "Выкл."
    }
    let enabledCount = [settings.ghostHideOnline, settings.ghostHideRead, settings.ghostHideStoryViews, settings.ghostHideTyping].filter({ $0 }).count
    return "\(enabledCount) из 4"
}

private func chogramVersionString() -> String {
    let info = Bundle.main.infoDictionary
    let version = info?["CFBundleShortVersionString"] as? String ?? ""
    let build = info?["CFBundleVersion"] as? String ?? ""
    return "\(version) (\(build))"
}

public func chogramSettingsController(context: AccountContext) -> ViewController {
    let store = ChogramSettingsStore()

    let deletedMessagesCountPromise = Promise<Int>()
    deletedMessagesCountPromise.set(context.engine.messages.chogramDeletedMessagesCount())
    let appIconNamePromise = ValuePromise<String?>(context.sharedContext.applicationBindings.getAlternateIconName(), ignoreRepeated: true)

    var pushControllerImpl: ((ViewController) -> Void)?

    let arguments = ChogramSettingsControllerArguments(
        store: store,
        openGhostMode: {
            pushControllerImpl?(chogramGhostModeController(context: context, store: store))
        },
        openDeletedMessages: {
            pushControllerImpl?(chogramDeletedMessagesController(context: context, store: store))
        },
        openLooks: {
            pushControllerImpl?(chogramLooksController(context: context))
        },
        openRepository: {
            context.sharedContext.applicationBindings.openUrl("https://github.com/nexxzaid/chogram")
        }
    )

    let signal = combineLatest(queue: .mainQueue(),
        context.sharedContext.presentationData,
        store.settings,
        deletedMessagesCountPromise.get(),
        appIconNamePromise.get()
    )
    |> map { presentationData, settings, deletedMessagesCount, appIconName -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let presentationData = chogramPresentationData(presentationData)
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text("Чограм"), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let logoImageName = chogramAppIcons.first(where: { $0.name == appIconName })?.imageName ?? "Chogram/AppIconClassic"
        let entries: [ChogramSettingsControllerEntry] = [
            .header(chogramVersionString(), logoImageName),
            .categoriesHeader,
            .ghostMode(chogramGhostSummary(settings: settings)),
            .deletedMessages(settings.keepDeletedMessages ? "\(deletedMessagesCount)" : "Выкл."),
            .looks,
            .hideAds(settings.hideAds),
            .linksHeader,
            .repository
        ]
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: entries, style: .blocks, animateChanges: true)

        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)
    controller.didAppear = { _ in
        store.reload()
        deletedMessagesCountPromise.set(context.engine.messages.chogramDeletedMessagesCount())
        appIconNamePromise.set(context.sharedContext.applicationBindings.getAlternateIconName())
    }
    pushControllerImpl = { [weak controller] c in
        controller?.push(c)
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

private enum ChogramGhostModeSection: Int32 {
    case enabled
    case options
}

private enum ChogramGhostModeEntry: ItemListNodeEntry {
    case enabled(Bool)
    case optionsHeader
    case hideOnline(Bool)
    case hideRead(Bool)
    case hideStoryViews(Bool)
    case hideTyping(Bool)
    case footer

    var section: ItemListSectionId {
        switch self {
        case .enabled:
            return ChogramGhostModeSection.enabled.rawValue
        default:
            return ChogramGhostModeSection.options.rawValue
        }
    }

    var stableId: Int32 {
        switch self {
        case .enabled:
            return 0
        case .optionsHeader:
            return 1
        case .hideOnline:
            return 2
        case .hideRead:
            return 3
        case .hideStoryViews:
            return 4
        case .hideTyping:
            return 5
        case .footer:
            return 6
        }
    }

    static func <(lhs: ChogramGhostModeEntry, rhs: ChogramGhostModeEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! ChogramGhostModeControllerArguments
        switch self {
        case let .enabled(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, icon: chogramIcon("Ghost", presentationData: presentationData), title: "Режим призрака", value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.store.update { $0.ghostMode = value }
            })
        case .optionsHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "ЧТО СКРЫВАТЬ", sectionId: self.section)
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
            return ItemListTextItem(presentationData: presentationData, text: .plain("Отправка сообщения всё равно покажет тебя в сети. Включать режим можно кнопкой в списке чатов."), sectionId: self.section)
        }
    }
}

private func chogramGhostModeEntries(settings: ChogramSettings) -> [ChogramGhostModeEntry] {
    var entries: [ChogramGhostModeEntry] = [.enabled(settings.ghostMode)]
    if settings.ghostMode {
        entries.append(.optionsHeader)
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
        let presentationData = chogramPresentationData(presentationData)
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text("Режим призрака"), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: chogramGhostModeEntries(settings: settings), style: .blocks, animateChanges: true)

        return (controllerState, (listState, arguments))
    }

    return ItemListController(context: context, state: signal)
}

// MARK: - Deleted messages

private final class ChogramDeletedMessagesControllerArguments {
    let store: ChogramSettingsStore
    let clearDeletedMessages: () -> Void

    init(store: ChogramSettingsStore, clearDeletedMessages: @escaping () -> Void) {
        self.store = store
        self.clearDeletedMessages = clearDeletedMessages
    }
}

private enum ChogramDeletedMessagesSection: Int32 {
    case preview
    case keep
    case style
    case icon
    case label
    case clear
}

private enum ChogramDeletedMessagesEntry: ItemListNodeEntry {
    case preview(ChogramSettings)
    case keepDeletedMessages(Bool)

    case styleHeader
    case style(Int32, ChogramSettings.DeletedMessageAppearance, String, String, Bool)
    case opacity(Int)

    case iconHeader
    case icon(String)

    case labelHeader
    case label(String)
    case showDeletionTime(Bool)

    case clear(Int)
    case footer

    var section: ItemListSectionId {
        switch self {
        case .preview:
            return ChogramDeletedMessagesSection.preview.rawValue
        case .keepDeletedMessages:
            return ChogramDeletedMessagesSection.keep.rawValue
        case .styleHeader, .style, .opacity:
            return ChogramDeletedMessagesSection.style.rawValue
        case .iconHeader, .icon:
            return ChogramDeletedMessagesSection.icon.rawValue
        case .labelHeader, .label, .showDeletionTime:
            return ChogramDeletedMessagesSection.label.rawValue
        case .clear, .footer:
            return ChogramDeletedMessagesSection.clear.rawValue
        }
    }

    var stableId: Int32 {
        switch self {
        case .preview:
            return 0
        case .keepDeletedMessages:
            return 1
        case .styleHeader:
            return 2
        case let .style(index, _, _, _, _):
            return 3 + index
        case .opacity:
            return 10
        case .iconHeader:
            return 11
        case .icon:
            return 12
        case .labelHeader:
            return 13
        case .label:
            return 14
        case .showDeletionTime:
            return 15
        case .clear:
            return 16
        case .footer:
            return 17
        }
    }

    static func <(lhs: ChogramDeletedMessagesEntry, rhs: ChogramDeletedMessagesEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! ChogramDeletedMessagesControllerArguments
        let theme = presentationData.theme
        switch self {
        case let .preview(settings):
            return ChogramDeletedMessagePreviewItem(theme: theme, settings: settings, sectionId: self.section)
        case let .keepDeletedMessages(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Сохранять удалённые", value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.store.update { $0.keepDeletedMessages = value }
            })
        case .styleHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "СТИЛЬ", sectionId: self.section)
        case let .style(_, appearance, title, subtitle, isSelected):
            return ChogramRadioItem(theme: theme, icon: chogramStylePreviewImage(theme: theme, appearance: appearance), title: title, subtitle: subtitle, isSelected: isSelected, sectionId: self.section, action: {
                arguments.store.update { $0.deletedMessageAppearance = appearance }
            })
        case let .opacity(value):
            return ChogramOpacitySliderItem(theme: theme, value: value, sectionId: self.section, updated: { value in
                arguments.store.update { $0.deletedMessageOpacity = value }
            })
        case .iconHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "ЗНАЧОК", sectionId: self.section)
        case let .icon(value):
            return ChogramIconPickerItem(theme: theme, values: chogramDeletedMessageIcons, selectedValue: value, sectionId: self.section, updated: { value in
                arguments.store.update { $0.deletedMessageIcon = value }
            })
        case .labelHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "ПОДПИСЬ", sectionId: self.section)
        case let .label(value):
            return ItemListSingleLineInputItem(presentationData: presentationData, systemStyle: .glass, title: NSAttributedString(string: "Текст", textColor: presentationData.theme.list.itemPrimaryTextColor), text: value, placeholder: "удалено", spacing: 12.0, maxLength: 24, sectionId: self.section, textUpdated: { value in
                arguments.store.update { $0.deletedMessageLabel = value }
            }, action: {
            })
        case let .showDeletionTime(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Время удаления", value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.store.update { $0.showDeletionTime = value }
            })
        case let .clear(count):
            return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: "Очистить сохранённые (\(count))", kind: count == 0 ? .disabled : .destructive, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                arguments.clearDeletedMessages()
            })
        case .footer:
            return ItemListTextItem(presentationData: presentationData, text: .plain("Видны только тебе. Секретные чаты и сообщения с таймером не сохраняются. Новый вид появится, когда откроешь чат заново."), sectionId: self.section)
        }
    }
}

private func chogramDeletedMessagesEntries(settings: ChogramSettings, deletedMessagesCount: Int) -> [ChogramDeletedMessagesEntry] {
    var entries: [ChogramDeletedMessagesEntry] = [
        .preview(settings),
        .keepDeletedMessages(settings.keepDeletedMessages),
        .styleHeader
    ]
    for (index, appearance) in chogramDeletedMessageAppearances.enumerated() {
        entries.append(.style(Int32(index), appearance.value, appearance.title, appearance.subtitle, settings.deletedMessageAppearance == appearance.value))
    }
    if settings.deletedMessageAppearance != .labelOnly {
        entries.append(.opacity(settings.deletedMessageOpacity))
    }
    entries.append(.iconHeader)
    entries.append(.icon(settings.deletedMessageIcon))
    entries.append(.labelHeader)
    entries.append(.label(settings.deletedMessageLabel))
    entries.append(.showDeletionTime(settings.showDeletionTime))
    entries.append(.clear(deletedMessagesCount))
    entries.append(.footer)
    return entries
}

private func chogramDeletedMessagesController(context: AccountContext, store: ChogramSettingsStore) -> ViewController {
    let deletedMessagesCountPromise = Promise<Int>()
    deletedMessagesCountPromise.set(context.engine.messages.chogramDeletedMessagesCount())

    var presentControllerImpl: ((ViewController) -> Void)?

    let arguments = ChogramDeletedMessagesControllerArguments(
        store: store,
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
        let presentationData = chogramPresentationData(presentationData)
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text("Удалённые сообщения"), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: chogramDeletedMessagesEntries(settings: settings, deletedMessagesCount: deletedMessagesCount), style: .blocks, animateChanges: true)

        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)
    presentControllerImpl = { [weak controller] c in
        controller?.present(c, in: .window(.root))
    }
    return controller
}

// MARK: - Looks

private final class ChogramLooksControllerArguments {
    let selectAppIcon: (String?) -> Void
    let updateAvatarCorners: (Double) -> Void

    init(selectAppIcon: @escaping (String?) -> Void, updateAvatarCorners: @escaping (Double) -> Void) {
        self.selectAppIcon = selectAppIcon
        self.updateAvatarCorners = updateAvatarCorners
    }
}

private enum ChogramLooksSection: Int32 {
    case appIcon
    case avatars
}

private enum ChogramLooksEntry: ItemListNodeEntry {
    case appIconHeader
    case appIcon(String?)
    case avatarsHeader
    case avatarCorners(Double)
    case avatarsFooter

    var section: ItemListSectionId {
        switch self {
        case .appIconHeader, .appIcon:
            return ChogramLooksSection.appIcon.rawValue
        case .avatarsHeader, .avatarCorners, .avatarsFooter:
            return ChogramLooksSection.avatars.rawValue
        }
    }

    var stableId: Int32 {
        switch self {
        case .appIconHeader:
            return 0
        case .appIcon:
            return 1
        case .avatarsHeader:
            return 2
        case .avatarCorners:
            return 3
        case .avatarsFooter:
            return 4
        }
    }

    static func <(lhs: ChogramLooksEntry, rhs: ChogramLooksEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! ChogramLooksControllerArguments
        switch self {
        case .appIconHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "ИКОНКА ПРИЛОЖЕНИЯ", sectionId: self.section)
        case let .appIcon(name):
            return ChogramAppIconItem(theme: presentationData.theme, icons: chogramAppIcons, selectedName: name, sectionId: self.section, updated: { name in
                arguments.selectAppIcon(name)
            })
        case .avatarsHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "ФОРМА АВАТАРОК", sectionId: self.section)
        case let .avatarCorners(value):
            return ChogramAvatarShapeItem(theme: presentationData.theme, value: value, sectionId: self.section, updated: { value in
                arguments.updateAvatarCorners(value)
            })
        case .avatarsFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain("Новая форма появится после перезапуска приложения."), sectionId: self.section)
        }
    }
}

private func chogramLooksController(context: AccountContext) -> ViewController {
    let appIconNamePromise = ValuePromise<String?>(context.sharedContext.applicationBindings.getAlternateIconName(), ignoreRepeated: true)
    let avatarCornersPromise = ValuePromise<Double>(UserDefaults.standard.object(forKey: chogramAvatarCornersKey) as? Double ?? 1.0, ignoreRepeated: true)

    let arguments = ChogramLooksControllerArguments(
        selectAppIcon: { name in
            appIconNamePromise.set(name)
            context.sharedContext.applicationBindings.requestSetAlternateIconName(name, { _ in
            })
        },
        updateAvatarCorners: { value in
            UserDefaults.standard.set(value, forKey: chogramAvatarCornersKey)
            avatarCornersPromise.set(value)
        }
    )

    let signal = combineLatest(queue: .mainQueue(),
        context.sharedContext.presentationData,
        appIconNamePromise.get(),
        avatarCornersPromise.get()
    )
    |> map { presentationData, appIconName, avatarCorners -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let presentationData = chogramPresentationData(presentationData)
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text("Оформление"), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let entries: [ChogramLooksEntry] = [
            .appIconHeader,
            .appIcon(appIconName),
            .avatarsHeader,
            .avatarCorners(avatarCorners),
            .avatarsFooter
        ]
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: entries, style: .blocks, animateChanges: false)

        return (controllerState, (listState, arguments))
    }

    return ItemListController(context: context, state: signal)
}
