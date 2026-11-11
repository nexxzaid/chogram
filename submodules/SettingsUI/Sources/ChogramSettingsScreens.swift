import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import LegacyComponents
import ItemListUI
import PresentationDataUtils
import AccountContext
import LocalizedPeerData

// MARK: - Slider with a range

final class ChogramValueSliderItem: ChogramBlockItem {
    let title: String
    let minValue: Int
    let maxValue: Int
    let value: Int
    let suffix: String
    let updated: (Int) -> Void

    override var height: CGFloat {
        return 84.0
    }

    init(theme: PresentationTheme, title: String, minValue: Int, maxValue: Int, value: Int, suffix: String, sectionId: ItemListSectionId, updated: @escaping (Int) -> Void) {
        self.title = title
        self.minValue = minValue
        self.maxValue = maxValue
        self.value = value
        self.suffix = suffix
        self.updated = updated
        super.init(theme: theme, sectionId: sectionId)
    }

    override func makeNode() -> ChogramBlockItemNode {
        return ChogramValueSliderItemNode()
    }
}

final class ChogramValueSliderItemNode: ChogramBlockItemNode {
    private let titleNode: ImmediateTextNode
    private let valueNode: ImmediateTextNode
    private var sliderView: TGPhotoEditorSliderView?
    private var item: ChogramValueSliderItem?

    override init() {
        self.titleNode = ImmediateTextNode()
        self.valueNode = ImmediateTextNode()

        super.init()

        self.addSubnode(self.titleNode)
        self.addSubnode(self.valueNode)
    }

    override func updateContent(item: ChogramBlockItem, params: ListViewItemLayoutParams) {
        guard let item = item as? ChogramValueSliderItem else {
            return
        }
        let isInitial = self.item == nil
        self.item = item
        let theme = item.theme
        let inset: CGFloat = 16.0
        let width = params.width - params.leftInset - params.rightInset - inset * 2.0

        self.titleNode.attributedText = NSAttributedString(string: item.title, font: Font.regular(17.0), textColor: theme.list.itemPrimaryTextColor)
        self.valueNode.attributedText = NSAttributedString(string: "\(item.value)\(item.suffix)", font: Font.semibold(17.0), textColor: theme.list.itemAccentColor)
        let titleSize = self.titleNode.updateLayout(CGSize(width: width, height: 30.0))
        let valueSize = self.valueNode.updateLayout(CGSize(width: width, height: 30.0))
        self.titleNode.frame = CGRect(origin: CGPoint(x: params.leftInset + inset, y: 12.0), size: titleSize)
        self.valueNode.frame = CGRect(origin: CGPoint(x: params.width - params.rightInset - inset - valueSize.width, y: 12.0), size: valueSize)

        let sliderView: TGPhotoEditorSliderView
        if let current = self.sliderView {
            sliderView = current
        } else {
            sliderView = TGPhotoEditorSliderView()
            sliderView.enablePanHandling = true
            sliderView.trackCornerRadius = 2.0
            sliderView.lineSize = 4.0
            // The slider misplaces its track when the minimum is above zero, so it runs from zero.
            sliderView.minimumValue = 0.0
            sliderView.startValue = 0.0
            sliderView.maximumValue = CGFloat(item.maxValue - item.minValue)
            sliderView.disablesInteractiveTransitionGestureRecognizer = true
            sliderView.addTarget(self, action: #selector(self.sliderValueChanged), for: .valueChanged)
            self.view.addSubview(sliderView)
            self.sliderView = sliderView
        }
        if isInitial {
            sliderView.value = CGFloat(item.value - item.minValue)
        }
        sliderView.backgroundColor = theme.list.itemBlocksBackgroundColor
        sliderView.backColor = theme.list.itemSwitchColors.frameColor
        sliderView.trackColor = theme.list.itemAccentColor
        sliderView.knobImage = PresentationResourcesItemList.knobImage(theme)
        sliderView.frame = CGRect(origin: CGPoint(x: params.leftInset + inset - 8.0, y: 40.0), size: CGSize(width: width + 16.0, height: 44.0))
    }

    @objc private func sliderValueChanged() {
        guard let sliderView = self.sliderView, let item = self.item else {
            return
        }
        item.updated(Int(sliderView.value.rounded()) + item.minValue)
    }
}

// MARK: - Sticker size preview

// Shows a sticker at the chosen size next to a dashed outline of the standard one, both at the same
// reduced scale so the largest size still fits the row.
final class ChogramStickerSizePreviewItem: ChogramBlockItem {
    static let previewScale: CGFloat = 0.6
    static let standardSide: CGFloat = 184.0

    let percent: Int

    override var height: CGFloat {
        return floor(ChogramStickerSizePreviewItem.standardSide * 1.5 * ChogramStickerSizePreviewItem.previewScale) + 24.0
    }

    init(theme: PresentationTheme, percent: Int, sectionId: ItemListSectionId) {
        self.percent = percent
        super.init(theme: theme, sectionId: sectionId)
    }

    override func makeNode() -> ChogramBlockItemNode {
        return ChogramStickerSizePreviewItemNode()
    }
}

final class ChogramStickerSizePreviewItemNode: ChogramBlockItemNode {
    private let outlineLayer: CAShapeLayer
    private let stickerNode: ImmediateTextNode
    private var currentSide: CGFloat?

    override init() {
        self.outlineLayer = CAShapeLayer()
        self.outlineLayer.fillColor = nil
        self.outlineLayer.lineWidth = 1.0
        self.outlineLayer.lineDashPattern = [4.0, 4.0]
        self.stickerNode = ImmediateTextNode()
        self.stickerNode.displaysAsynchronously = false

        super.init()

        self.layer.addSublayer(self.outlineLayer)
        self.addSubnode(self.stickerNode)
    }

    override func updateContent(item: ChogramBlockItem, params: ListViewItemLayoutParams) {
        guard let item = item as? ChogramStickerSizePreviewItem else {
            return
        }
        let scale = ChogramStickerSizePreviewItem.previewScale
        let standardSide = floor(ChogramStickerSizePreviewItem.standardSide * scale)
        let side = floor(ChogramStickerSizePreviewItem.standardSide * CGFloat(item.percent) / 100.0 * scale)
        let rightX = params.width - params.rightInset - 16.0
        let bottomY = item.height - 12.0

        let standardFrame = CGRect(x: rightX - standardSide, y: bottomY - standardSide, width: standardSide, height: standardSide)
        self.outlineLayer.strokeColor = item.theme.list.itemSecondaryTextColor.withAlphaComponent(0.5).cgColor
        self.outlineLayer.frame = standardFrame
        self.outlineLayer.path = UIBezierPath(roundedRect: CGRect(origin: CGPoint(), size: standardFrame.size), cornerRadius: 12.0).cgPath

        // Emoji always come from the system emoji font, so the user's custom font does not change the glyph.
        if self.stickerNode.attributedText == nil {
            self.stickerNode.attributedText = NSAttributedString(string: "\u{1F60E}", attributes: [.font: UIFont.systemFont(ofSize: 100.0)])
        }
        let glyphSize = self.stickerNode.updateLayout(CGSize(width: 400.0, height: 400.0))
        let stickerFrame = CGRect(x: rightX - side, y: bottomY - side, width: side, height: side)
        let glyphScale = side / max(1.0, max(glyphSize.width, glyphSize.height))

        let transition: ContainedViewLayoutTransition = self.currentSide == nil ? .immediate : .animated(duration: 0.15, curve: .easeInOut)
        self.currentSide = side
        transition.updateBounds(node: self.stickerNode, bounds: CGRect(origin: CGPoint(), size: glyphSize))
        transition.updatePosition(node: self.stickerNode, position: CGPoint(x: stickerFrame.midX, y: stickerFrame.midY))
        transition.updateTransformScale(node: self.stickerNode, scale: glyphScale)
    }
}

// MARK: - Generic form screen

struct ChogramFormAccount: Equatable {
    let id: Int64
    let title: String
}

final class ChogramFormArguments {
    let store: ChogramSettingsStore
    let didUpdate: (ChogramSettings) -> Void
    let open: (String) -> Void

    init(store: ChogramSettingsStore, didUpdate: @escaping (ChogramSettings) -> Void, open: @escaping (String) -> Void) {
        self.store = store
        self.didUpdate = didUpdate
        self.open = open
    }
}

enum ChogramFormEntry: ItemListNodeEntry {
    case header(Int32, Int32, String)
    case footer(Int32, Int32, String)
    case toggle(Int32, Int32, String, WritableKeyPath<ChogramSettings, Bool>, Bool)
    case disclosure(Int32, Int32, String, String, String)
    case slider(Int32, Int32, String, Int, Int, Int, WritableKeyPath<ChogramSettings, Int>)
    case input(Int32, Int32, String, String, String, WritableKeyPath<ChogramSettings, String>)
    case menuItem(Int32, Int32, String, String, Bool)
    case account(Int32, Int32, String, Int64, Bool)
    case stickerPreview(Int32, Int32, Int)

    var section: ItemListSectionId {
        switch self {
        case let .header(section, _, _):
            return section
        case let .footer(section, _, _):
            return section
        case let .toggle(section, _, _, _, _):
            return section
        case let .disclosure(section, _, _, _, _):
            return section
        case let .slider(section, _, _, _, _, _, _):
            return section
        case let .input(section, _, _, _, _, _):
            return section
        case let .menuItem(section, _, _, _, _):
            return section
        case let .account(section, _, _, _, _):
            return section
        case let .stickerPreview(section, _, _):
            return section
        }
    }

    var stableId: Int32 {
        switch self {
        case let .header(_, id, _):
            return id
        case let .footer(_, id, _):
            return id
        case let .toggle(_, id, _, _, _):
            return id
        case let .disclosure(_, id, _, _, _):
            return id
        case let .slider(_, id, _, _, _, _, _):
            return id
        case let .input(_, id, _, _, _, _):
            return id
        case let .menuItem(_, id, _, _, _):
            return id
        case let .account(_, id, _, _, _):
            return id
        case let .stickerPreview(_, id, _):
            return id
        }
    }

    static func <(lhs: ChogramFormEntry, rhs: ChogramFormEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! ChogramFormArguments
        let sectionId = self.section
        switch self {
        case let .header(_, _, text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: sectionId)
        case let .footer(_, _, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: sectionId)
        case let .toggle(_, _, title, keyPath, value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: title, value: value, maximumNumberOfLines: 2, sectionId: sectionId, style: .blocks, updated: { value in
                arguments.store.update { $0[keyPath: keyPath] = value }
                arguments.didUpdate(ChogramSettings.current)
            })
        case let .disclosure(_, _, title, label, key):
            // Wide custom fonts leave no room for a value beside the title, so the value goes under it.
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: title, label: label, labelStyle: label.isEmpty ? .text : .detailText, sectionId: sectionId, style: .blocks, action: {
                arguments.open(key)
            })
        case let .slider(_, _, title, minValue, maxValue, value, keyPath):
            return ChogramValueSliderItem(theme: presentationData.theme, title: title, minValue: minValue, maxValue: maxValue, value: value, suffix: "%", sectionId: sectionId, updated: { value in
                arguments.store.update { $0[keyPath: keyPath] = value }
                arguments.didUpdate(ChogramSettings.current)
            })
        case let .input(_, _, title, placeholder, value, keyPath):
            return ItemListSingleLineInputItem(presentationData: presentationData, systemStyle: .glass, title: NSAttributedString(string: title, textColor: presentationData.theme.list.itemPrimaryTextColor), text: value, placeholder: placeholder, spacing: 12.0, maxLength: 24, sectionId: sectionId, textUpdated: { value in
                arguments.store.update { $0[keyPath: keyPath] = value }
            }, action: {
            })
        case let .menuItem(_, _, title, rawValue, value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: title, value: value, maximumNumberOfLines: 2, sectionId: sectionId, style: .blocks, updated: { value in
                arguments.store.update { settings in
                    if value {
                        settings.hiddenMessageMenuItems.remove(rawValue)
                    } else {
                        settings.hiddenMessageMenuItems.insert(rawValue)
                    }
                }
            })
        case let .account(_, _, title, accountId, value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: title, value: value, maximumNumberOfLines: 2, sectionId: sectionId, style: .blocks, updated: { value in
                arguments.store.update { settings in
                    if value {
                        settings.ghostDisabledAccountIds.remove(accountId)
                    } else {
                        settings.ghostDisabledAccountIds.insert(accountId)
                    }
                }
            })
        case let .stickerPreview(_, _, percent):
            return ChogramStickerSizePreviewItem(theme: presentationData.theme, percent: percent, sectionId: sectionId)
        }
    }
}

// Collects entries with ascending stable ids and one section per group of rows.
final class ChogramFormBuilder {
    private(set) var entries: [ChogramFormEntry] = []
    private var section: Int32 = 0
    private var nextId: Int32
    private var closed = false

    init(firstId: Int32 = 0, firstSection: Int32 = 0) {
        self.nextId = firstId
        self.section = firstSection
    }

    private func take() -> (Int32, Int32) {
        if self.closed {
            self.section += 1
            self.closed = false
        }
        let id = self.nextId
        self.nextId += 1
        return (self.section, id)
    }

    // Starts a new block for whatever is added next.
    func gap() {
        self.closed = true
    }

    func header(_ text: String) {
        if !self.entries.isEmpty {
            self.closed = true
        }
        let (section, id) = self.take()
        self.entries.append(.header(section, id, text))
    }

    func footer(_ text: String) {
        let (section, id) = self.take()
        self.entries.append(.footer(section, id, text))
        self.closed = true
    }

    func toggle(_ title: String, _ keyPath: WritableKeyPath<ChogramSettings, Bool>, _ settings: ChogramSettings) {
        let (section, id) = self.take()
        self.entries.append(.toggle(section, id, title, keyPath, settings[keyPath: keyPath]))
    }

    func disclosure(_ title: String, label: String, key: String) {
        let (section, id) = self.take()
        self.entries.append(.disclosure(section, id, title, label, key))
    }

    func slider(_ title: String, min: Int, max: Int, _ keyPath: WritableKeyPath<ChogramSettings, Int>, _ settings: ChogramSettings) {
        let (section, id) = self.take()
        self.entries.append(.slider(section, id, title, min, max, settings[keyPath: keyPath], keyPath))
    }

    func stickerPreview(_ percent: Int) {
        let (section, id) = self.take()
        self.entries.append(.stickerPreview(section, id, percent))
    }

    func input(_ title: String, placeholder: String, _ keyPath: WritableKeyPath<ChogramSettings, String>, _ settings: ChogramSettings) {
        let (section, id) = self.take()
        self.entries.append(.input(section, id, title, placeholder, settings[keyPath: keyPath], keyPath))
    }

    func menuItem(_ item: ChogramMessageMenuItem, _ settings: ChogramSettings) {
        let (section, id) = self.take()
        self.entries.append(.menuItem(section, id, item.title, item.rawValue, !settings.hiddenMessageMenuItems.contains(item.rawValue)))
    }

    func account(_ account: ChogramFormAccount, _ settings: ChogramSettings) {
        let (section, id) = self.take()
        self.entries.append(.account(section, id, account.title, account.id, !settings.ghostDisabledAccountIds.contains(account.id)))
    }
}

func chogramFormController(context: AccountContext, store: ChogramSettingsStore, title: String, accounts: Signal<[ChogramFormAccount], NoError> = .single([]), didUpdate: @escaping (ChogramSettings) -> Void = { _ in }, build: @escaping (ChogramSettings, [ChogramFormAccount]) -> [ChogramFormEntry], open: @escaping (String, @escaping (ViewController) -> Void) -> Void = { _, _ in }) -> ViewController {
    var pushControllerImpl: ((ViewController) -> Void)?

    let arguments = ChogramFormArguments(store: store, didUpdate: didUpdate, open: { key in
        open(key, { c in
            pushControllerImpl?(c)
        })
    })

    let signal = combineLatest(queue: .mainQueue(),
        context.sharedContext.presentationData,
        store.settings,
        accounts
    )
    |> map { presentationData, settings, accounts -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let presentationData = chogramPresentationData(presentationData)
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(title), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: build(settings, accounts), style: .blocks, animateChanges: true)
        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)
    controller.didAppear = { _ in
        store.reload()
    }
    pushControllerImpl = { [weak controller] c in
        controller?.push(c)
    }
    return controller
}

// MARK: - Picker screen

private final class ChogramPickerArguments {
    let select: (Int) -> Void

    init(select: @escaping (Int) -> Void) {
        self.select = select
    }
}

private enum ChogramPickerEntry: ItemListNodeEntry {
    case option(Int32, String, Bool)
    case footer(String)

    var section: ItemListSectionId {
        switch self {
        case .option:
            return 0
        case .footer:
            return 1
        }
    }

    var stableId: Int32 {
        switch self {
        case let .option(index, _, _):
            return index
        case .footer:
            return 10000
        }
    }

    static func <(lhs: ChogramPickerEntry, rhs: ChogramPickerEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! ChogramPickerArguments
        switch self {
        case let .option(index, title, checked):
            return ItemListCheckboxItem(presentationData: presentationData, systemStyle: .glass, title: title, style: .left, checked: checked, zeroSeparatorInsets: false, sectionId: self.section, action: {
                arguments.select(Int(index))
            })
        case let .footer(text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        }
    }
}

func chogramPickerController(context: AccountContext, store: ChogramSettingsStore, title: String, footer: String?, options: [(title: String, value: String)], current: @escaping (ChogramSettings) -> String, select: @escaping (inout ChogramSettings, String) -> Void) -> ViewController {
    let arguments = ChogramPickerArguments(select: { index in
        let value = options[index].value
        store.update { settings in
            select(&settings, value)
        }
    })

    let signal = combineLatest(queue: .mainQueue(),
        context.sharedContext.presentationData,
        store.settings
    )
    |> map { presentationData, settings -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let presentationData = chogramPresentationData(presentationData)
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(title), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let selected = current(settings)
        var entries: [ChogramPickerEntry] = []
        for (index, option) in options.enumerated() {
            entries.append(.option(Int32(index), option.title, option.value == selected))
        }
        if let footer {
            entries.append(.footer(footer))
        }
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: entries, style: .blocks, animateChanges: true)
        return (controllerState, (listState, arguments))
    }

    return ItemListController(context: context, state: signal)
}

// MARK: - Titles

func chogramDoubleTapTitle(_ action: ChogramSettings.DoubleTapAction) -> String {
    switch action {
    case .reaction:
        return "Реакция"
    case .reply:
        return "Ответить"
    case .copy:
        return "Скопировать"
    case .forward:
        return "Переслать"
    case .edit:
        return "Изменить"
    case .nothing:
        return "Ничего"
    }
}

func chogramRoundVideoCameraTitle(_ camera: ChogramSettings.RoundVideoCamera) -> String {
    switch camera {
    case .front:
        return "Фронтальная"
    case .back:
        return "Основная"
    case .last:
        return "Последняя"
    }
}

func chogramChatListTitleTitle(_ title: ChogramSettings.ChatListTitle) -> String {
    switch title {
    case .standard:
        return "Чаты"
    case .chogram:
        return "Чограм"
    case .username:
        return "Мой ник"
    case .name:
        return "Моё имя"
    case .folder:
        return "Открытая папка"
    }
}

private func chogramMonospaceChoices() -> [(title: String, value: String)] {
    var choices: [(title: String, value: String)] = [
        (title: "Системный", value: ""),
        (title: "Menlo", value: "Menlo"),
        (title: "Courier New", value: "Courier New"),
        (title: "Courier", value: "Courier")
    ]
    for font in chogramCustomFontChoices() {
        if !choices.contains(where: { $0.value == font.name }) {
            choices.append((title: font.title, value: font.name))
        }
    }
    return choices
}

// MARK: - Accounts

func chogramFormAccountsSignal(context: AccountContext) -> Signal<[ChogramFormAccount], NoError> {
    return context.sharedContext.activeAccountContexts
    |> mapToSignal { _, accounts, _ -> Signal<[ChogramFormAccount], NoError> in
        let signals = accounts.map { _, accountContext, _ -> Signal<ChogramFormAccount, NoError> in
            let peerId = accountContext.account.peerId
            return accountContext.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
            |> map { peer -> ChogramFormAccount in
                let id = peerId.toInt64()
                return ChogramFormAccount(id: id, title: peer?.compactDisplayTitle ?? "\(id)")
            }
        }
        if signals.isEmpty {
            return .single([])
        }
        return combineLatest(signals)
    }
}

// MARK: - Entries embedded into the older screens (firstId is where their stable ids start)

func chogramGhostFormEntries(settings: ChogramSettings, accounts: [ChogramFormAccount]) -> [ChogramFormEntry] {
    let b = ChogramFormBuilder(firstId: 100, firstSection: 100)
    guard settings.ghostMode else {
        return []
    }
    b.toggle("Писать, не появляясь в сети", \.ghostSendScheduled, settings)
    b.footer("Сообщение уходит как отложенное на пару секунд, поэтому ты не появляешься в сети.")
    b.toggle("Спрашивать перед просмотром истории", \.ghostAskBeforeStory, settings)
    b.gap()
    b.toggle("Отдельно для каждого аккаунта", \.ghostPerAccount, settings)
    if settings.ghostPerAccount && accounts.count > 1 {
        b.footer("Выбери аккаунты, для которых режим призрака включён.")
        b.header("АККАУНТЫ")
        for account in accounts {
            b.account(account, settings)
        }
    }
    return b.entries
}

func chogramDeletedFormEntries(settings: ChogramSettings) -> [ChogramFormEntry] {
    let b = ChogramFormBuilder(firstId: 100, firstSection: 100)
    b.toggle("История правок", \.keepEditHistory, settings)
    b.input("Метка изменённых", placeholder: "изменено", \.editedLabel, settings)
    b.footer("Сохраняет прошлые версии изменённых сообщений. Посмотреть — в меню сообщения → История правок.")
    b.header("МЕДИА УДАЛЁННЫХ СООБЩЕНИЙ")
    b.toggle("Сохранять фото и файлы", \.keepDeletedMedia, settings)
    if settings.keepDeletedMedia {
        b.toggle("В личных чатах", \.deletedMediaInPrivateChats, settings)
        b.toggle("В группах", \.deletedMediaInGroups, settings)
        b.toggle("В каналах", \.deletedMediaInChannels, settings)
    }
    b.gap()
    b.toggle("Сохранять в чатах с ботами", \.keepDeletedInBotChats, settings)
    return b.entries
}

func chogramLooksFormEntries(settings: ChogramSettings) -> [ChogramFormEntry] {
    let b = ChogramFormBuilder(firstId: 100, firstSection: 100)
    b.header("ВНЕШНИЙ ВИД")
    b.toggle("Сообщения без хвостиков", \.hideBubbleTails, settings)
    b.disclosure("Заголовок списка чатов", label: chogramChatListTitleTitle(settings.chatListTitle), key: "chatListTitle")
    b.toggle("Скрыть вкладку «Все чаты»", \.hideAllChatsTab, settings)
    b.toggle("Снег", \.snow, settings)
    b.toggle("Цвет у HEX-кодов", \.hexColorSwatches, settings)
    b.toggle("Без видеоаватарок", \.disableVideoAvatars, settings)
    b.toggle("Без чужих тем в чатах", \.disableChatThemes, settings)
    b.gap()
    let fontTitle = chogramMonospaceChoices().first(where: { $0.value == settings.monospaceFontName })?.title ?? settings.monospaceFontName
    b.disclosure("Шрифт кода", label: fontTitle, key: "monospaceFont")
    b.disclosure("Убрать лишнее", label: "", key: "cleanup")
    return b.entries
}

func chogramOpenLooksForm(key: String, context: AccountContext, store: ChogramSettingsStore, push: @escaping (ViewController) -> Void) {
    switch key {
    case "chatListTitle":
        let options: [(title: String, value: String)] = [
            ChogramSettings.ChatListTitle.standard,
            ChogramSettings.ChatListTitle.chogram,
            ChogramSettings.ChatListTitle.username,
            ChogramSettings.ChatListTitle.name,
            ChogramSettings.ChatListTitle.folder
        ].map { (title: chogramChatListTitleTitle($0), value: String($0.rawValue)) }
        push(chogramPickerController(context: context, store: store, title: "Заголовок списка чатов", footer: nil, options: options, current: { settings in
            return String(settings.chatListTitle.rawValue)
        }, select: { settings, value in
            settings.chatListTitle = ChogramSettings.ChatListTitle(rawValue: Int(value) ?? 0) ?? .standard
        }))
    case "monospaceFont":
        push(chogramPickerController(context: context, store: store, title: "Шрифт кода", footer: nil, options: chogramMonospaceChoices(), current: { settings in
            return settings.monospaceFontName
        }, select: { settings, value in
            settings.monospaceFontName = value
        }))
    case "cleanup":
        push(chogramFormController(context: context, store: store, title: "Убрать лишнее", build: { settings, _ in
            let b = ChogramFormBuilder()
            b.toggle("Кнопку «Поделиться» сбоку", \.hideShareButton, settings)
            b.toggle("Отправить как канал", \.hideSendAsChannel, settings)
            b.toggle("Приветственный стикер", \.hideGreetingSticker, settings)
            b.toggle("Кнопку звука в каналах", \.hideChannelMuteButton, settings)
            b.toggle("Премиум-кнопки", \.hidePremiumUpsell, settings)
            b.toggle("Похожие каналы", \.hideSimilarChannels, settings)
            b.footer("Включённое скрывается из интерфейса.")
            return b.entries
        }))
    default:
        break
    }
}

// MARK: - Screens

func chogramProtectionController(context: AccountContext, store: ChogramSettingsStore) -> ViewController {
    return chogramFormController(context: context, store: store, title: "Защита", build: { settings, _ in
        let b = ChogramFormBuilder()
        b.toggle("Разрешить скриншоты и запись экрана", \.allowScreenshots, settings)
        b.toggle("Сохранять фото и видео с таймером", \.saveViewOnceMedia, settings)
        b.toggle("Снять запреты на копирование и пересылку", \.bypassCopyProtection, settings)
        b.footer("Работает в защищённых чатах, каналах и секретных чатах. Telegram может ограничить аккаунт, который обходит защиту, поэтому включай осознанно.")
        return b.entries
    })
}

func chogramMessageMenuController(context: AccountContext, store: ChogramSettingsStore) -> ViewController {
    return chogramFormController(context: context, store: store, title: "Меню сообщения", build: { settings, _ in
        let b = ChogramFormBuilder()
        b.header("TELEGRAM")
        for item in ChogramMessageMenuItem.allCases where !item.isChogramItem {
            b.menuItem(item, settings)
        }
        b.header("ЧОГРАМ")
        for item in ChogramMessageMenuItem.allCases where item.isChogramItem {
            b.menuItem(item, settings)
        }
        b.footer("Выключенные пункты не показываются в меню сообщения.")
        return b.entries
    })
}

func chogramChatsController(context: AccountContext, store: ChogramSettingsStore) -> ViewController {
    return chogramFormController(context: context, store: store, title: "Чаты", build: { settings, _ in
        let b = ChogramFormBuilder()
        b.toggle("Чаты как группа", \.personalChatAsGroup, settings)
        b.toggle("Ник в заголовке", \.usernameInHeader, settings)
        b.footer("«Как группа» — у сообщений собеседника появится аватарка, а у всех сообщений имя. Ник показывается рядом со статусом в заголовке чата. Изменения видны после повторного открытия чата.")
        b.toggle("Подтверждать звонки", \.confirmCalls, settings)
        b.header("СПРАШИВАТЬ ПЕРЕД ОТПРАВКОЙ")
        b.toggle("Стикеров", \.confirmSendStickers, settings)
        b.toggle("GIF", \.confirmSendGifs, settings)
        b.toggle("Голосовых", \.confirmSendVoice, settings)
        b.toggle("Кружков", \.confirmSendRoundVideos, settings)
        b.header("ЖЕСТЫ И МЕНЮ")
        b.disclosure("Двойной тап по чужим", label: chogramDoubleTapTitle(settings.doubleTapIncoming), key: "doubleTapIncoming")
        b.disclosure("Двойной тап по своим", label: chogramDoubleTapTitle(settings.doubleTapOutgoing), key: "doubleTapOutgoing")
        let hiddenCount = ChogramMessageMenuItem.allCases.filter({ settings.hiddenMessageMenuItems.contains($0.rawValue) }).count
        b.disclosure("Меню сообщения", label: hiddenCount == 0 ? "" : "скрыто: \(hiddenCount)", key: "menu")
        b.header("ВРЕМЯ И ДАТЫ")
        b.toggle("Секунды во времени", \.showSecondsInTime, settings)
        b.toggle("Время у служебных сообщений", \.showServiceMessageTime, settings)
        b.toggle("Дата пересланных сообщений", \.showForwardOriginalDate, settings)
        b.header("ПРОЧЕЕ")
        b.toggle("Не переходить в следующий канал", \.disableNextChannelSwipe, settings)
        b.toggle("Пересчёт валют", \.convertCurrency, settings)
        return b.entries
    }, open: { key, push in
        switch key {
        case "doubleTapIncoming", "doubleTapOutgoing":
            let isIncoming = key == "doubleTapIncoming"
            var actions: [ChogramSettings.DoubleTapAction] = [.reaction, .reply, .copy, .forward]
            if !isIncoming {
                actions.append(.edit)
            }
            actions.append(.nothing)
            let options = actions.map { (title: chogramDoubleTapTitle($0), value: String($0.rawValue)) }
            push(chogramPickerController(context: context, store: store, title: isIncoming ? "Двойной тап по чужим" : "Двойной тап по своим", footer: nil, options: options, current: { settings in
                return String((isIncoming ? settings.doubleTapIncoming : settings.doubleTapOutgoing).rawValue)
            }, select: { settings, value in
                let action = ChogramSettings.DoubleTapAction(rawValue: Int(value) ?? 0) ?? .reaction
                if isIncoming {
                    settings.doubleTapIncoming = action
                } else {
                    settings.doubleTapOutgoing = action
                }
            }))
        case "menu":
            push(chogramMessageMenuController(context: context, store: store))
        default:
            break
        }
    })
}

func chogramMediaController(context: AccountContext, store: ChogramSettingsStore) -> ViewController {
    return chogramFormController(context: context, store: store, title: "Медиа", didUpdate: { settings in
        UserDefaults.standard.set(settings.photoWithoutCompression, forKey: "TG_photoHighQuality_v0")
        // 5 is the "very high" video preset, 0 lets Telegram pick.
        UserDefaults.standard.set(settings.videoWithoutCompression ? 5 : 0, forKey: "TG_preferredVideoPreset_v0")
    }, build: { settings, _ in
        let b = ChogramFormBuilder()
        b.toggle("Фото в высоком качестве", \.photoWithoutCompression, settings)
        b.toggle("Видео в лучшем качестве", \.videoWithoutCompression, settings)
        b.footer("Фото уходят в HD, а видео в лучшем качестве, которое позволяет Telegram. Для одного файла качество можно сменить в редакторе перед отправкой.")
        b.slider("Размер стикеров", min: 50, max: 150, \.stickerSizePercent, settings)
        b.stickerPreview(settings.stickerSizePercent)
        b.gap()
        b.disclosure("Камера для кружков", label: chogramRoundVideoCameraTitle(settings.roundVideoCamera), key: "roundVideoCamera")
        b.gap()
        b.toggle("Только мои стикеры и эмодзи", \.onlyMyStickerPacks, settings)
        b.toggle("Ускорить загрузку и отправку", \.fasterTransfers, settings)
        b.footer("Файлы качаются в несколько потоков. Telegram может временно притормозить слишком частые запросы.")
        return b.entries
    }, open: { key, push in
        if key == "roundVideoCamera" {
            let options = [ChogramSettings.RoundVideoCamera.front, ChogramSettings.RoundVideoCamera.back, ChogramSettings.RoundVideoCamera.last].map { (title: chogramRoundVideoCameraTitle($0), value: String($0.rawValue)) }
            push(chogramPickerController(context: context, store: store, title: "Камера для кружков", footer: nil, options: options, current: { settings in
                return String(settings.roundVideoCamera.rawValue)
            }, select: { settings, value in
                settings.roundVideoCamera = ChogramSettings.RoundVideoCamera(rawValue: Int(value) ?? 0) ?? .front
            }))
        }
    })
}
