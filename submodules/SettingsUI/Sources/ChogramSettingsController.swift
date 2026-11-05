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
    ("ChogramMintIcon", "Chogram/AppIconMint", "Мята"),
    ("ChogramWhiteIcon", "Chogram/AppIconWhite", "Белая"),
    ("ChogramNightIcon", "Chogram/AppIconNight", "Ночь"),
    ("ChogramWaveIcon", "Chogram/AppIconWave", "Волна"),
    ("ChogramOutlineIcon", "Chogram/AppIconOutline", "Контур"),
    ("ChogramAutumnIcon", "Chogram/AppIconAutumn", "Осень"),
    ("ChogramWinterIcon", "Chogram/AppIconWinter", "Новый год")
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
    let openCleanText: () -> Void
    let openScreen: (Int) -> Void
    let openUpdate: () -> Void
    let openHistory: () -> Void
    let openDeveloper: () -> Void
    let openRepository: () -> Void
    let updateSearch: (String) -> Void
    let openSearchResult: (Int) -> Void

    init(store: ChogramSettingsStore, openGhostMode: @escaping () -> Void, openDeletedMessages: @escaping () -> Void, openLooks: @escaping () -> Void, openCleanText: @escaping () -> Void, openScreen: @escaping (Int) -> Void, openUpdate: @escaping () -> Void, openHistory: @escaping () -> Void, openDeveloper: @escaping () -> Void, openRepository: @escaping () -> Void, updateSearch: @escaping (String) -> Void, openSearchResult: @escaping (Int) -> Void) {
        self.store = store
        self.openGhostMode = openGhostMode
        self.openDeletedMessages = openDeletedMessages
        self.openLooks = openLooks
        self.openCleanText = openCleanText
        self.openScreen = openScreen
        self.openUpdate = openUpdate
        self.openHistory = openHistory
        self.openDeveloper = openDeveloper
        self.openRepository = openRepository
        self.updateSearch = updateSearch
        self.openSearchResult = openSearchResult
    }
}

private let chogramSearchItems: [(title: String, icon: String, screen: Int)] = [
    ("Режим призрака", "Ghost", 0),
    ("Не показывать онлайн", "Ghost", 0),
    ("Не читать сообщения", "Ghost", 0),
    ("Не читать истории", "Ghost", 0),
    ("Не показывать набор", "Ghost", 0),
    ("Сохранять удалённые", "Trash", 1),
    ("Непрозрачность удалённых", "Trash", 1),
    ("Значок удалённых", "Trash", 1),
    ("Очистить сохранённые", "Trash", 1),
    ("Читать чат при отправке", "Ghost", 0),
    ("Иконка приложения", "Palette", 2),
    ("Форма аватарок", "Palette", 2),
    ("Шрифт", "Palette", 7),
    ("Чистый текст", "Text", 3),
    ("ID и дата-центр", "Profile", 4),
    ("Видно, что я в Чограме", "Profile", 4),
    ("Чаты как группа", "Chats", 5),
    ("Ник в заголовке", "Chats", 5),
    ("Фото в высоком качестве", "Media", 6),
    ("Видео в лучшем качестве", "Media", 6),
    ("Что нового", "Update", 8)
]

private enum ChogramSettingsSection: Int32 {
    case search
    case header
    case update
    case categories
    case links
    case whatsNew
}

private enum ChogramSettingsControllerEntry: ItemListNodeEntry {
    case search(String)
    case searchResult(Int32)
    case header(String, String)
    case update(String)

    case categoriesHeader
    case ghostMode(String)
    case deletedMessages(String)
    case profiles
    case chats
    case media
    case looks
    case cleanText
    case hideAds(Bool)

    case linksHeader
    case developer
    case repository

    case whatsNewHeader(String)
    case whatsNew(String)
    case whatsNewHistory

    var section: ItemListSectionId {
        switch self {
        case .search, .searchResult:
            return ChogramSettingsSection.search.rawValue
        case .header:
            return ChogramSettingsSection.header.rawValue
        case .update:
            return ChogramSettingsSection.update.rawValue
        case .categoriesHeader, .ghostMode, .deletedMessages, .profiles, .chats, .media, .looks, .cleanText, .hideAds:
            return ChogramSettingsSection.categories.rawValue
        case .linksHeader, .developer, .repository:
            return ChogramSettingsSection.links.rawValue
        case .whatsNewHeader, .whatsNew, .whatsNewHistory:
            return ChogramSettingsSection.whatsNew.rawValue
        }
    }

    var stableId: Int32 {
        switch self {
        case .search:
            return -100
        case let .searchResult(index):
            return -99 + index
        case .header:
            return 0
        case .update:
            return 1
        case .categoriesHeader:
            return 2
        case .ghostMode:
            return 3
        case .deletedMessages:
            return 4
        case .profiles:
            return 5
        case .chats:
            return 6
        case .media:
            return 7
        case .looks:
            return 8
        case .cleanText:
            return 9
        case .hideAds:
            return 10
        case .linksHeader:
            return 11
        case .developer:
            return 12
        case .repository:
            return 13
        case .whatsNewHeader:
            return 14
        case .whatsNew:
            return 15
        case .whatsNewHistory:
            return 16
        }
    }

    static func <(lhs: ChogramSettingsControllerEntry, rhs: ChogramSettingsControllerEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! ChogramSettingsControllerArguments
        switch self {
        case let .search(query):
            return ItemListSingleLineInputItem(presentationData: presentationData, systemStyle: .glass, title: NSAttributedString(), text: query, placeholder: "Поиск по настройкам", sectionId: self.section, textUpdated: { value in
                arguments.updateSearch(value)
            }, action: {
            })
        case let .searchResult(index):
            let item = chogramSearchItems[Int(index)]
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, icon: chogramIcon(item.icon, presentationData: presentationData), title: item.title, label: "", sectionId: self.section, style: .blocks, action: {
                arguments.openSearchResult(Int(index))
            })
        case let .header(version, logoImageName):
            return ChogramSettingsHeaderItem(presentationData: presentationData, title: "Чограм", subtitle: version, logoImageName: logoImageName, sectionId: self.section)
        case let .update(title):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, icon: chogramIcon("Update", presentationData: presentationData), title: title, label: "Обновить", sectionId: self.section, style: .blocks, action: {
                arguments.openUpdate()
            })
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
        case .profiles:
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, icon: chogramIcon("Profile", presentationData: presentationData), title: "Профили", label: "", sectionId: self.section, style: .blocks, action: {
                arguments.openScreen(4)
            })
        case .chats:
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, icon: chogramIcon("Chats", presentationData: presentationData), title: "Чаты", label: "", sectionId: self.section, style: .blocks, action: {
                arguments.openScreen(5)
            })
        case .media:
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, icon: chogramIcon("Media", presentationData: presentationData), title: "Медиа", label: "", sectionId: self.section, style: .blocks, action: {
                arguments.openScreen(6)
            })
        case .looks:
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, icon: chogramIcon("Palette", presentationData: presentationData), title: "Оформление", label: "", sectionId: self.section, style: .blocks, action: {
                arguments.openLooks()
            })
        case .cleanText:
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, icon: chogramIcon("Text", presentationData: presentationData), title: "Чистый текст", label: "", sectionId: self.section, style: .blocks, action: {
                arguments.openCleanText()
            })
        case let .hideAds(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, icon: chogramIcon("AdBlock", presentationData: presentationData), title: "Без рекламы", value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.store.update { $0.hideAds = value }
            })
        case .linksHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "ССЫЛКИ", sectionId: self.section)
        case .developer:
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, icon: chogramIcon("Ghost", presentationData: presentationData), title: "Разработчик", label: "@wabexe", sectionId: self.section, style: .blocks, action: {
                arguments.openDeveloper()
            })
        case .repository:
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, icon: chogramIcon("Link", presentationData: presentationData), title: "Исходный код", label: "GitHub", sectionId: self.section, style: .blocks, action: {
                arguments.openRepository()
            })
        case let .whatsNewHeader(title):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: title, sectionId: self.section)
        case let .whatsNew(text):
            return ItemListMultilineTextItem(presentationData: presentationData, text: text, enabledEntityTypes: [], sectionId: self.section, style: .blocks)
        case .whatsNewHistory:
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: "Прошлые сборки", label: "", sectionId: self.section, style: .blocks, action: {
                arguments.openHistory()
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
    // The mint theme was removed; anyone who had it on gets their own colors back.
    if ChogramSettings.current.mintTheme {
        store.update { $0.mintTheme = false }
        chogramApplyMintTheme(context: context, enabled: false)
    }

    let deletedMessagesCountPromise = Promise<Int>()
    deletedMessagesCountPromise.set(context.engine.messages.chogramDeletedMessagesCount())
    let appIconNamePromise = ValuePromise<String?>(context.sharedContext.applicationBindings.getAlternateIconName(), ignoreRepeated: true)

    let searchPromise = ValuePromise<String>("", ignoreRepeated: true)
    let updatesPromise = Promise<ChogramUpdatesState?>(nil)
    updatesPromise.set(chogramUpdatesState())

    var pushControllerImpl: ((ViewController) -> Void)?

    let openScreen: (Int) -> Void = { screen in
        switch screen {
        case 0:
            pushControllerImpl?(chogramGhostModeController(context: context, store: store))
        case 1:
            pushControllerImpl?(chogramDeletedMessagesController(context: context, store: store))
        case 2:
            pushControllerImpl?(chogramLooksController(context: context, store: store))
        case 4:
            pushControllerImpl?(chogramToggleController(context: context, store: store, title: "Профили", rows: [
                ChogramToggleRow(title: "ID и дата-центр", keyPath: \.showProfileDetails, onChange: nil),
                ChogramToggleRow(title: "Видно, что я в Чограме", keyPath: \.shareChogramPresence, onChange: { _ in
                    ChogramPresence.shared.syncOwnPresence(accountPeerId: context.account.peerId)
                })
            ], footer: "В профиле появятся ID, примерная дата создания аккаунта и дата-центр. Чтобы другие пользователи Чограма видели у тебя отметку «Пользуется Чограмом», Чограм сообщает серверу только ID аккаунта. Выключишь — ID удалится с сервера."))
        case 5:
            pushControllerImpl?(chogramToggleController(context: context, store: store, title: "Чаты", rows: [
                ChogramToggleRow(title: "Чаты как группа", keyPath: \.personalChatAsGroup, onChange: nil),
                ChogramToggleRow(title: "Ник в заголовке", keyPath: \.usernameInHeader, onChange: nil)
            ], footer: "«Как группа» — у сообщений собеседника появится аватарка, а у всех сообщений имя. Ник показывается рядом со статусом в заголовке чата. Изменения видны после повторного открытия чата."))
        case 6:
            pushControllerImpl?(chogramToggleController(context: context, store: store, title: "Медиа", rows: [
                ChogramToggleRow(title: "Фото в высоком качестве", keyPath: \.photoWithoutCompression, onChange: { value in
                    UserDefaults.standard.set(value, forKey: "TG_photoHighQuality_v0")
                }),
                ChogramToggleRow(title: "Видео в лучшем качестве", keyPath: \.videoWithoutCompression, onChange: { value in
                    // 5 is the "very high" video preset, 0 lets Telegram pick.
                    UserDefaults.standard.set(value ? 5 : 0, forKey: "TG_preferredVideoPreset_v0")
                })
            ], footer: "Фото уходят в HD, а видео в лучшем качестве, которое позволяет Telegram. Для одного файла качество можно сменить в редакторе перед отправкой."))
        case 7:
            pushControllerImpl?(chogramFontsController(context: context))
        case 8:
            pushControllerImpl?(chogramBuildHistoryController(context: context, updates: updatesPromise.get()))
        default:
            pushControllerImpl?(chogramCleanTextController(context: context, store: store))
        }
    }

    let arguments = ChogramSettingsControllerArguments(
        store: store,
        openGhostMode: {
            openScreen(0)
        },
        openDeletedMessages: {
            openScreen(1)
        },
        openLooks: {
            openScreen(2)
        },
        openCleanText: {
            openScreen(3)
        },
        openScreen: { screen in
            openScreen(screen)
        },
        openUpdate: {
            let _ = (updatesPromise.get()
            |> take(1)
            |> deliverOnMainQueue).startStandalone(next: { state in
                if let latest = state?.latest {
                    context.sharedContext.applicationBindings.openUrl(chogramSideStoreInstallURL(for: latest))
                }
            })
        },
        openHistory: {
            openScreen(8)
        },
        openDeveloper: {
            context.sharedContext.applicationBindings.openUrl("tg://resolve?domain=wabexe")
        },
        openRepository: {
            context.sharedContext.applicationBindings.openUrl("https://github.com/nexxzaid/chogram")
        },
        updateSearch: { value in
            searchPromise.set(value)
        },
        openSearchResult: { index in
            openScreen(chogramSearchItems[index].screen)
        }
    )

    let signal = combineLatest(queue: .mainQueue(),
        context.sharedContext.presentationData,
        store.settings,
        deletedMessagesCountPromise.get(),
        appIconNamePromise.get(),
        searchPromise.get(),
        updatesPromise.get()
    )
    |> map { presentationData, settings, deletedMessagesCount, appIconName, search, updates -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let presentationData = chogramPresentationData(presentationData)
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text("Чограм"), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let logoImageName = chogramAppIcons.first(where: { $0.name == appIconName })?.imageName ?? "Chogram/AppIconClassic"
        var entries: [ChogramSettingsControllerEntry] = [.search(search)]
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        if query.isEmpty {
            entries.append(.header(chogramVersionString(), logoImageName))
            if let updates, updates.hasUpdate, let latest = updates.latest {
                entries.append(.update("Доступна сборка \(latest.build)"))
            }
            entries.append(contentsOf: [
                .categoriesHeader,
                .ghostMode(chogramGhostSummary(settings: settings)),
                .deletedMessages(settings.keepDeletedMessages ? "\(deletedMessagesCount)" : "Выкл."),
                .profiles,
                .chats,
                .media,
                .looks,
                .cleanText,
                .hideAds(settings.hideAds),
                .linksHeader,
                .developer,
                .repository
            ])
            // "Что нового" lists the changes of the build that is installed.
            if let updates, let current = updates.current, !current.notes.isEmpty {
                entries.append(.whatsNewHeader("ЧТО НОВОГО · СБОРКА \(current.build)"))
                entries.append(.whatsNew(current.notes))
                if updates.builds.count > 1 {
                    entries.append(.whatsNewHistory)
                }
            }
        } else {
            for (index, item) in chogramSearchItems.enumerated() where item.title.lowercased().contains(query.lowercased()) {
                entries.append(.searchResult(Int32(index)))
            }
        }
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
    case readOnSend(Bool)
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
        case .readOnSend:
            return 6
        case .footer:
            return 7
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
        case let .readOnSend(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Читать чат при отправке", value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.store.update { $0.ghostReadOnSend = value }
            })
        case .footer:
            return ItemListTextItem(presentationData: presentationData, text: .plain("Отправка сообщения всё равно покажет тебя в сети. «Читать чат при отправке» отмечает прочитанными сообщения только в том чате, куда ты пишешь. Включать режим можно кнопкой в списке чатов."), sectionId: self.section)
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
        if settings.ghostHideRead {
            entries.append(.readOnSend(settings.ghostReadOnSend))
        }
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
    let openFonts: () -> Void

    init(selectAppIcon: @escaping (String?) -> Void, updateAvatarCorners: @escaping (Double) -> Void, openFonts: @escaping () -> Void) {
        self.selectAppIcon = selectAppIcon
        self.updateAvatarCorners = updateAvatarCorners
        self.openFonts = openFonts
    }
}

private enum ChogramLooksSection: Int32 {
    case theme
    case appIcon
    case avatars
}

private enum ChogramLooksEntry: ItemListNodeEntry {
    case font(String)
    case appIconHeader
    case appIcon(String?)
    case avatarsHeader
    case avatarCorners(Double)
    case avatarsFooter

    var section: ItemListSectionId {
        switch self {
        case .font:
            return ChogramLooksSection.theme.rawValue
        case .appIconHeader, .appIcon:
            return ChogramLooksSection.appIcon.rawValue
        case .avatarsHeader, .avatarCorners, .avatarsFooter:
            return ChogramLooksSection.avatars.rawValue
        }
    }

    var stableId: Int32 {
        switch self {
        case .font:
            return -1
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
        case let .font(label):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, icon: chogramIcon("Text", presentationData: presentationData), title: "Шрифт", label: label, sectionId: self.section, style: .blocks, action: {
                arguments.openFonts()
            })
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

private func chogramLooksController(context: AccountContext, store: ChogramSettingsStore) -> ViewController {
    let appIconNamePromise = ValuePromise<String?>(context.sharedContext.applicationBindings.getAlternateIconName(), ignoreRepeated: true)
    let avatarCornersPromise = ValuePromise<Double>(UserDefaults.standard.object(forKey: chogramAvatarCornersKey) as? Double ?? 1.0, ignoreRepeated: true)
    let fontLabelPromise = ValuePromise<String>(chogramCurrentFontLabel(), ignoreRepeated: true)
    var pushControllerImpl: ((ViewController) -> Void)?

    let arguments = ChogramLooksControllerArguments(
        selectAppIcon: { name in
            appIconNamePromise.set(name)
            context.sharedContext.applicationBindings.requestSetAlternateIconName(name, { _ in
            })
        },
        updateAvatarCorners: { value in
            UserDefaults.standard.set(value, forKey: chogramAvatarCornersKey)
            avatarCornersPromise.set(value)
        },
        openFonts: {
            pushControllerImpl?(chogramFontsController(context: context))
        }
    )

    let signal = combineLatest(queue: .mainQueue(),
        context.sharedContext.presentationData,
        appIconNamePromise.get(),
        avatarCornersPromise.get(),
        fontLabelPromise.get()
    )
    |> map { presentationData, appIconName, avatarCorners, fontLabel -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let presentationData = chogramPresentationData(presentationData)
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text("Оформление"), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let entries: [ChogramLooksEntry] = [
            .font(fontLabel),
            .appIconHeader,
            .appIcon(appIconName),
            .avatarsHeader,
            .avatarCorners(avatarCorners),
            .avatarsFooter
        ]
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: entries, style: .blocks, animateChanges: false)

        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)
    controller.didAppear = { _ in
        fontLabelPromise.set(chogramCurrentFontLabel())
    }
    pushControllerImpl = { [weak controller] c in
        controller?.push(c)
    }
    return controller
}

// MARK: - Clean text

private final class ChogramCleanTextControllerArguments {
    let store: ChogramSettingsStore

    init(store: ChogramSettingsStore) {
        self.store = store
    }
}

private let chogramZalgoSample = "П\u{0336}\u{0338}\u{0322}\u{0335}\u{0321}р\u{0337}\u{0322}\u{0334}\u{0336}и\u{0335}\u{0338}\u{0322}\u{0321}в\u{0334}\u{0337}\u{0336}е\u{0337}\u{0335}\u{0322}т\u{0336}\u{0338}\u{0334}"

private enum ChogramCleanTextEntry: ItemListNodeEntry {
    case preview(Bool)
    case enabled(Bool)
    case footer

    var section: ItemListSectionId {
        return 0
    }

    var stableId: Int32 {
        switch self {
        case .preview:
            return 0
        case .enabled:
            return 1
        case .footer:
            return 2
        }
    }

    static func <(lhs: ChogramCleanTextEntry, rhs: ChogramCleanTextEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! ChogramCleanTextControllerArguments
        switch self {
        case let .preview(isEnabled):
            return ItemListTextItem(presentationData: presentationData, text: .plain(isEnabled ? "Пример: Привет" : "Пример: \(chogramZalgoSample)"), sectionId: self.section)
        case let .enabled(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Убирать искажённый текст", value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.store.update { $0.filterZalgo = value }
            })
        case .footer:
            return ItemListTextItem(presentationData: presentationData, text: .plain("Символы-«наездники» расползаются на соседние строки и ломают чат. Фильтр оставляет только сам текст."), sectionId: self.section)
        }
    }
}

private func chogramCleanTextController(context: AccountContext, store: ChogramSettingsStore) -> ViewController {
    let arguments = ChogramCleanTextControllerArguments(store: store)

    let signal = combineLatest(queue: .mainQueue(),
        context.sharedContext.presentationData,
        store.settings
    )
    |> map { presentationData, settings -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let presentationData = chogramPresentationData(presentationData)
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text("Чистый текст"), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let entries: [ChogramCleanTextEntry] = [.preview(settings.filterZalgo), .enabled(settings.filterZalgo), .footer]
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: entries, style: .blocks, animateChanges: true)

        return (controllerState, (listState, arguments))
    }

    return ItemListController(context: context, state: signal)
}

// MARK: - Deleted messages of one chat

private final class ChogramPeerDeletedMessagesArguments {
    let updateSearch: (String) -> Void

    init(updateSearch: @escaping (String) -> Void) {
        self.updateSearch = updateSearch
    }
}

private enum ChogramPeerDeletedMessagesSection: Int32 {
    case search
    case messages
}

private enum ChogramPeerDeletedMessagesEntry: ItemListNodeEntry {
    case search(String)
    case header(Int)
    case message(Int32, String)
    case footer

    var section: ItemListSectionId {
        switch self {
        case .search:
            return ChogramPeerDeletedMessagesSection.search.rawValue
        default:
            return ChogramPeerDeletedMessagesSection.messages.rawValue
        }
    }

    var stableId: Int32 {
        switch self {
        case .search:
            return 0
        case .header:
            return 1
        case let .message(id, _):
            return 2 + id
        case .footer:
            return Int32.max
        }
    }

    static func <(lhs: ChogramPeerDeletedMessagesEntry, rhs: ChogramPeerDeletedMessagesEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! ChogramPeerDeletedMessagesArguments
        switch self {
        case let .search(query):
            return ItemListSingleLineInputItem(presentationData: presentationData, systemStyle: .glass, title: NSAttributedString(), text: query, placeholder: "Поиск по удалённым", sectionId: self.section, textUpdated: { value in
                arguments.updateSearch(value)
            }, action: {
            })
        case let .header(count):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "ВСЕГО: \(count)", sectionId: self.section)
        case let .message(_, text):
            return ItemListMultilineTextItem(presentationData: presentationData, text: text, enabledEntityTypes: [], sectionId: self.section, style: .blocks)
        case .footer:
            return ItemListTextItem(presentationData: presentationData, text: .plain("Видны только тебе. Хранятся, пока не очистишь их."), sectionId: self.section)
        }
    }
}

public func chogramPeerDeletedMessagesController(context: AccountContext, peerId: EnginePeer.Id) -> ViewController {
    let searchPromise = ValuePromise<String>("", ignoreRepeated: true)
    let arguments = ChogramPeerDeletedMessagesArguments(updateSearch: { value in
        searchPromise.set(value)
    })

    let signal = combineLatest(queue: .mainQueue(),
        context.sharedContext.presentationData,
        context.engine.messages.chogramDeletedMessages(peerId: peerId),
        searchPromise.get()
    )
    |> map { presentationData, messages, search -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let presentationData = chogramPresentationData(presentationData)
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text("Удалённые в этом чате"), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))

        let query = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let filtered = messages.filter { query.isEmpty || $0.text.lowercased().contains(query) }
        var entries: [ChogramPeerDeletedMessagesEntry] = [.search(search), .header(filtered.count)]
        for (index, message) in filtered.enumerated() {
            entries.append(.message(Int32(index), message.text.isEmpty ? "Медиа" : message.text))
        }
        entries.append(.footer)
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: entries, style: .blocks, animateChanges: true)

        return (controllerState, (listState, arguments))
    }

    return ItemListController(context: context, state: signal)
}

// MARK: - Simple toggle screens (Профили, Чаты, Медиа)

private struct ChogramToggleRow {
    let title: String
    let keyPath: WritableKeyPath<ChogramSettings, Bool>
    let onChange: ((Bool) -> Void)?
}

private final class ChogramToggleArguments {
    let store: ChogramSettingsStore
    let rows: [ChogramToggleRow]

    init(store: ChogramSettingsStore, rows: [ChogramToggleRow]) {
        self.store = store
        self.rows = rows
    }
}

private enum ChogramToggleEntry: ItemListNodeEntry {
    case toggle(Int32, String, Bool)
    case footer(String)

    var section: ItemListSectionId {
        return 0
    }

    var stableId: Int32 {
        switch self {
        case let .toggle(index, _, _):
            return index
        case .footer:
            return 1000
        }
    }

    static func <(lhs: ChogramToggleEntry, rhs: ChogramToggleEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! ChogramToggleArguments
        switch self {
        case let .toggle(index, title, value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: title, value: value, sectionId: self.section, style: .blocks, updated: { value in
                let row = arguments.rows[Int(index)]
                arguments.store.update { $0[keyPath: row.keyPath] = value }
                row.onChange?(value)
            })
        case let .footer(text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        }
    }
}

private func chogramToggleController(context: AccountContext, store: ChogramSettingsStore, title: String, rows: [ChogramToggleRow], footer: String) -> ViewController {
    let arguments = ChogramToggleArguments(store: store, rows: rows)

    let signal = combineLatest(queue: .mainQueue(),
        context.sharedContext.presentationData,
        store.settings
    )
    |> map { presentationData, settings -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let presentationData = chogramPresentationData(presentationData)
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(title), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        var entries: [ChogramToggleEntry] = []
        for (index, row) in rows.enumerated() {
            entries.append(.toggle(Int32(index), row.title, settings[keyPath: row.keyPath]))
        }
        entries.append(.footer(footer))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: entries, style: .blocks, animateChanges: true)
        return (controllerState, (listState, arguments))
    }

    return ItemListController(context: context, state: signal)
}

// MARK: - Past builds

private enum ChogramBuildHistoryEntry: ItemListNodeEntry {
    case header(Int32, String)
    case notes(Int32, String)
    case empty

    var section: ItemListSectionId {
        switch self {
        case let .header(index, _), let .notes(index, _):
            return index
        case .empty:
            return 0
        }
    }

    var stableId: Int32 {
        switch self {
        case let .header(index, _):
            return index * 2
        case let .notes(index, _):
            return index * 2 + 1
        case .empty:
            return 0
        }
    }

    static func <(lhs: ChogramBuildHistoryEntry, rhs: ChogramBuildHistoryEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        switch self {
        case let .header(_, text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .notes(_, text):
            return ItemListMultilineTextItem(presentationData: presentationData, text: text, enabledEntityTypes: [], sectionId: self.section, style: .blocks)
        case .empty:
            return ItemListTextItem(presentationData: presentationData, text: .plain("Не удалось загрузить список сборок. Проверь интернет."), sectionId: self.section)
        }
    }
}

private func chogramBuildHistoryController(context: AccountContext, updates: Signal<ChogramUpdatesState?, NoError>) -> ViewController {
    let signal = combineLatest(queue: .mainQueue(),
        context.sharedContext.presentationData,
        updates
    )
    |> map { presentationData, updates -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let presentationData = chogramPresentationData(presentationData)
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text("Что нового"), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        var entries: [ChogramBuildHistoryEntry] = []
        if let updates, !updates.builds.isEmpty {
            for (index, build) in updates.builds.enumerated() {
                let installed = build.build == updates.currentBuild ? " · УСТАНОВЛЕНА" : ""
                let date = build.date.isEmpty ? "" : " · \(build.date.uppercased())"
                entries.append(.header(Int32(index), "СБОРКА \(build.build)\(date)\(installed)"))
                entries.append(.notes(Int32(index), build.notes.isEmpty ? "Исправления и улучшения." : build.notes))
            }
        } else {
            entries.append(.empty)
        }
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: entries, style: .blocks, animateChanges: false)
        return (controllerState, (listState, ()))
    }

    return ItemListController(context: context, state: signal)
}
