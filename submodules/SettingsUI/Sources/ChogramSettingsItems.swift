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
import AppBundle

// A row with a fixed height inside a rounded settings block. Subclasses lay their content out on
// the main thread, which is enough for these few rows and keeps each of them short.
class ChogramBlockItem: ListViewItem, ItemListItem {
    let theme: PresentationTheme
    let sectionId: ItemListSectionId

    var height: CGFloat {
        return 44.0
    }

    var selectable: Bool {
        return false
    }

    init(theme: PresentationTheme, sectionId: ItemListSectionId) {
        self.theme = theme
        self.sectionId = sectionId
    }

    func makeNode() -> ChogramBlockItemNode {
        return ChogramBlockItemNode()
    }

    func selected(listView: ListView) {
    }

    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, neighbors: ListViewItemNeighbors, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            Queue.mainQueue().async {
                let node = self.makeNode()
                let (layout, apply) = node.asyncLayout()(self, params, itemListNeighbors(item: self, topFacet: neighbors.previous?.base(ItemListNeighborFacet.self), bottomFacet: neighbors.next?.base(ItemListNeighborFacet.self)))

                node.contentSize = layout.contentSize
                node.insets = layout.insets

                completion(node, {
                    return (nil, { _ in apply() })
                })
            }
        }
    }

    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, neighbors: ListViewItemNeighbors, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            guard let nodeValue = node() as? ChogramBlockItemNode else {
                assertionFailure()
                return
            }
            let (layout, apply) = nodeValue.asyncLayout()(self, params, itemListNeighbors(item: self, topFacet: neighbors.previous?.base(ItemListNeighborFacet.self), bottomFacet: neighbors.next?.base(ItemListNeighborFacet.self)))
            completion(layout, { _ in
                apply()
            })
        }
    }
}

class ChogramBlockItemNode: ListViewItemNode {
    private let backgroundNode: ASDisplayNode
    private let topStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    private let maskNode: ASImageNode

    init() {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        self.topStripeNode = ASDisplayNode()
        self.topStripeNode.isLayerBacked = true
        self.bottomStripeNode = ASDisplayNode()
        self.bottomStripeNode.isLayerBacked = true
        self.maskNode = ASImageNode()

        super.init(layerBacked: false)
    }

    func updateContent(item: ChogramBlockItem, params: ListViewItemLayoutParams) {
    }

    func asyncLayout() -> (_ item: ChogramBlockItem, _ params: ListViewItemLayoutParams, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, () -> Void) {
        return { [weak self] item, params, neighbors in
            let separatorHeight = UIScreenPixel
            let contentSize = CGSize(width: params.width, height: item.height)
            let insets = itemListNeighborsGroupedInsets(neighbors, params)
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)
            let layoutSize = layout.size

            return (layout, {
                guard let self else {
                    return
                }
                self.backgroundNode.backgroundColor = item.theme.list.itemBlocksBackgroundColor
                self.topStripeNode.backgroundColor = item.theme.list.itemBlocksSeparatorColor
                self.bottomStripeNode.backgroundColor = item.theme.list.itemBlocksSeparatorColor

                if self.backgroundNode.supernode == nil {
                    self.insertSubnode(self.backgroundNode, at: 0)
                    self.insertSubnode(self.topStripeNode, at: 1)
                    self.insertSubnode(self.bottomStripeNode, at: 2)
                    self.insertSubnode(self.maskNode, at: 3)
                }

                let hasCorners = itemListHasRoundedBlockLayout(params)
                var hasTopCorners = false
                var hasBottomCorners = false
                switch neighbors.top {
                case .sameSection(false):
                    self.topStripeNode.isHidden = true
                default:
                    hasTopCorners = true
                    self.topStripeNode.isHidden = hasCorners
                }
                let bottomStripeInset: CGFloat
                let bottomStripeOffset: CGFloat
                switch neighbors.bottom {
                case .sameSection(false):
                    bottomStripeInset = params.leftInset + 16.0
                    bottomStripeOffset = -separatorHeight
                    self.bottomStripeNode.isHidden = false
                default:
                    bottomStripeInset = 0.0
                    bottomStripeOffset = 0.0
                    hasBottomCorners = true
                    self.bottomStripeNode.isHidden = hasCorners
                }

                self.maskNode.image = hasCorners ? PresentationResourcesItemList.cornersImage(item.theme, top: hasTopCorners, bottom: hasBottomCorners) : nil

                self.backgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: params.width, height: contentSize.height + min(insets.top, separatorHeight) + min(insets.bottom, separatorHeight)))
                self.maskNode.frame = self.backgroundNode.frame.inset(by: UIEdgeInsets(top: 0.0, left: params.leftInset, bottom: 0.0, right: params.rightInset))
                self.topStripeNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: layoutSize.width, height: separatorHeight))
                self.bottomStripeNode.frame = CGRect(origin: CGPoint(x: bottomStripeInset, y: contentSize.height + bottomStripeOffset), size: CGSize(width: layoutSize.width - bottomStripeInset, height: separatorHeight))

                self.updateContent(item: item, params: params)
            })
        }
    }

    override func animateInsertion(_ currentTimestamp: Double, duration: Double, options: ListViewItemAnimationOptions) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.4)
    }

    override func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false)
    }
}

// MARK: - Preview

final class ChogramDeletedMessagePreviewItem: ChogramBlockItem {
    let settings: ChogramSettings

    override var height: CGFloat {
        return 92.0
    }

    init(theme: PresentationTheme, settings: ChogramSettings, sectionId: ItemListSectionId) {
        self.settings = settings
        super.init(theme: theme, sectionId: sectionId)
    }

    override func makeNode() -> ChogramBlockItemNode {
        return ChogramDeletedMessagePreviewItemNode()
    }
}

final class ChogramDeletedMessagePreviewItemNode: ChogramBlockItemNode {
    private let bubbleNode: ASDisplayNode
    private let textNode: ImmediateTextNode
    private let statusNode: ImmediateTextNode

    override init() {
        self.bubbleNode = ASDisplayNode()
        self.bubbleNode.cornerRadius = 16.0
        self.textNode = ImmediateTextNode()
        self.statusNode = ImmediateTextNode()

        super.init()

        self.addSubnode(self.bubbleNode)
        self.bubbleNode.addSubnode(self.textNode)
        self.bubbleNode.addSubnode(self.statusNode)
    }

    override func updateContent(item: ChogramBlockItem, params: ListViewItemLayoutParams) {
        guard let item = item as? ChogramDeletedMessagePreviewItem else {
            return
        }
        let settings = item.settings
        let theme = item.theme
        let contentWidth = params.width - params.leftInset - params.rightInset - 32.0

        let isGray = settings.deletedMessageAppearance == .gray
        let primaryColor = isGray ? theme.list.itemSecondaryTextColor : theme.list.itemPrimaryTextColor
        let secondaryColor = theme.list.itemSecondaryTextColor

        self.textNode.attributedText = NSAttributedString(string: "Сообщение собеседника", font: Font.regular(16.0), textColor: primaryColor)

        let status = NSMutableAttributedString()
        let statusFont = Font.regular(11.0)
        if let icon = chogramDeletedMessageStatusIcon(settings.deletedMessageIcon) {
            status.append(NSAttributedString(string: "\u{2003}", attributes: [.font: statusFont, .foregroundColor: secondaryColor, .attachment: icon]))
            status.append(NSAttributedString(string: " ", font: statusFont, textColor: secondaryColor))
        }
        var components: [String] = []
        if !settings.deletedMessageLabel.isEmpty {
            components.append(settings.deletedMessageLabel)
        }
        if settings.showDeletionTime {
            components.append("12:34")
        }
        components.append("· 12:20")
        status.append(NSAttributedString(string: components.joined(separator: " "), font: statusFont, textColor: secondaryColor))
        self.statusNode.attributedText = status

        let textSize = self.textNode.updateLayout(CGSize(width: contentWidth - 24.0, height: 40.0))
        let statusSize = self.statusNode.updateLayout(CGSize(width: contentWidth - 24.0, height: 20.0))

        let bubbleSize = CGSize(width: min(contentWidth, max(textSize.width, statusSize.width) + 24.0), height: textSize.height + statusSize.height + 22.0)
        self.bubbleNode.frame = CGRect(origin: CGPoint(x: params.leftInset + 16.0, y: floor((item.height - bubbleSize.height) * 0.5)), size: bubbleSize)
        self.textNode.frame = CGRect(origin: CGPoint(x: 12.0, y: 8.0), size: textSize)
        self.statusNode.frame = CGRect(origin: CGPoint(x: bubbleSize.width - statusSize.width - 12.0, y: textSize.height + 12.0), size: statusSize)

        self.bubbleNode.backgroundColor = isGray ? theme.list.itemSecondaryTextColor.withAlphaComponent(0.18) : theme.list.itemAccentColor.withAlphaComponent(0.2)
        self.bubbleNode.alpha = settings.deletedMessageAppearance == .labelOnly ? 1.0 : CGFloat(settings.deletedMessageOpacity) / 100.0
    }
}

// MARK: - Radio option

final class ChogramRadioItem: ChogramBlockItem {
    let icon: UIImage?
    let title: String
    let subtitle: String
    let isSelected: Bool
    let action: () -> Void

    override var height: CGFloat {
        return 66.0
    }

    override var selectable: Bool {
        return true
    }

    init(theme: PresentationTheme, icon: UIImage?, title: String, subtitle: String, isSelected: Bool, sectionId: ItemListSectionId, action: @escaping () -> Void) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.isSelected = isSelected
        self.action = action
        super.init(theme: theme, sectionId: sectionId)
    }

    override func makeNode() -> ChogramBlockItemNode {
        return ChogramRadioItemNode()
    }

    override func selected(listView: ListView) {
        listView.clearHighlightAnimated(true)
        self.action()
    }
}

final class ChogramRadioItemNode: ChogramBlockItemNode {
    private let iconNode: ASImageNode
    private let titleNode: ImmediateTextNode
    private let subtitleNode: ImmediateTextNode
    private let radioNode: ASImageNode

    override init() {
        self.iconNode = ASImageNode()
        self.iconNode.displaysAsynchronously = false
        self.titleNode = ImmediateTextNode()
        self.subtitleNode = ImmediateTextNode()
        self.radioNode = ASImageNode()
        self.radioNode.displaysAsynchronously = false

        super.init()

        self.addSubnode(self.iconNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.subtitleNode)
        self.addSubnode(self.radioNode)
    }

    override func updateContent(item: ChogramBlockItem, params: ListViewItemLayoutParams) {
        guard let item = item as? ChogramRadioItem else {
            return
        }
        let theme = item.theme
        let leftInset = params.leftInset + 16.0
        let iconSize = CGSize(width: 44.0, height: 44.0)
        let radioSize = CGSize(width: 22.0, height: 22.0)

        self.iconNode.image = item.icon
        self.iconNode.frame = CGRect(origin: CGPoint(x: leftInset, y: floor((item.height - iconSize.height) * 0.5)), size: iconSize)

        let textX = leftInset + iconSize.width + 14.0
        let textWidth = params.width - params.rightInset - 16.0 - radioSize.width - 10.0 - textX
        self.titleNode.attributedText = NSAttributedString(string: item.title, font: Font.regular(17.0), textColor: theme.list.itemPrimaryTextColor)
        self.subtitleNode.attributedText = NSAttributedString(string: item.subtitle, font: Font.regular(14.0), textColor: theme.list.itemAccentColor)
        let titleSize = self.titleNode.updateLayout(CGSize(width: textWidth, height: 30.0))
        let subtitleSize = self.subtitleNode.updateLayout(CGSize(width: textWidth, height: 22.0))

        let textY = floor((item.height - titleSize.height - subtitleSize.height - 2.0) * 0.5)
        self.titleNode.frame = CGRect(origin: CGPoint(x: textX, y: textY), size: titleSize)
        self.subtitleNode.frame = CGRect(origin: CGPoint(x: textX, y: textY + titleSize.height + 2.0), size: subtitleSize)

        self.radioNode.image = chogramRadioImage(theme: theme, isSelected: item.isSelected)
        self.radioNode.frame = CGRect(origin: CGPoint(x: params.width - params.rightInset - 16.0 - radioSize.width, y: floor((item.height - radioSize.height) * 0.5)), size: radioSize)
    }
}

private func chogramRadioImage(theme: PresentationTheme, isSelected: Bool) -> UIImage? {
    return generateImage(CGSize(width: 22.0, height: 22.0), rotatedContext: { size, context in
        let bounds = CGRect(origin: CGPoint(), size: size)
        context.clear(bounds)
        context.setStrokeColor((isSelected ? theme.list.itemAccentColor : theme.list.itemSecondaryTextColor).cgColor)
        context.setLineWidth(2.0)
        context.strokeEllipse(in: bounds.insetBy(dx: 1.0, dy: 1.0))
        if isSelected {
            context.setFillColor(theme.list.itemAccentColor.cgColor)
            context.fillEllipse(in: bounds.insetBy(dx: 5.5, dy: 5.5))
        }
    })
}

// MARK: - Opacity slider

final class ChogramOpacitySliderItem: ChogramBlockItem {
    let value: Int
    let updated: (Int) -> Void

    override var height: CGFloat {
        return 84.0
    }

    init(theme: PresentationTheme, value: Int, sectionId: ItemListSectionId, updated: @escaping (Int) -> Void) {
        self.value = value
        self.updated = updated
        super.init(theme: theme, sectionId: sectionId)
    }

    override func makeNode() -> ChogramBlockItemNode {
        return ChogramOpacitySliderItemNode()
    }
}

final class ChogramOpacitySliderItemNode: ChogramBlockItemNode {
    private let titleNode: ImmediateTextNode
    private let valueNode: ImmediateTextNode
    private var sliderView: TGPhotoEditorSliderView?
    private var item: ChogramOpacitySliderItem?

    override init() {
        self.titleNode = ImmediateTextNode()
        self.valueNode = ImmediateTextNode()

        super.init()

        self.addSubnode(self.titleNode)
        self.addSubnode(self.valueNode)
    }

    override func updateContent(item: ChogramBlockItem, params: ListViewItemLayoutParams) {
        guard let item = item as? ChogramOpacitySliderItem else {
            return
        }
        let isInitial = self.item == nil
        self.item = item
        let theme = item.theme
        let inset: CGFloat = 16.0
        let width = params.width - params.leftInset - params.rightInset - inset * 2.0

        self.titleNode.attributedText = NSAttributedString(string: "Непрозрачность", font: Font.regular(17.0), textColor: theme.list.itemPrimaryTextColor)
        self.valueNode.attributedText = NSAttributedString(string: "\(item.value)%", font: Font.semibold(17.0), textColor: theme.list.itemAccentColor)
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
            sliderView.minimumValue = 10.0
            sliderView.startValue = 10.0
            sliderView.maximumValue = 100.0
            sliderView.disablesInteractiveTransitionGestureRecognizer = true
            sliderView.addTarget(self, action: #selector(self.sliderValueChanged), for: .valueChanged)
            self.view.addSubview(sliderView)
            self.sliderView = sliderView
        }
        if isInitial {
            sliderView.value = CGFloat(item.value)
        }
        sliderView.backgroundColor = theme.list.itemBlocksBackgroundColor
        sliderView.backColor = theme.list.itemSwitchColors.frameColor
        sliderView.trackColor = theme.list.itemAccentColor
        sliderView.knobImage = PresentationResourcesItemList.knobImage(theme)
        sliderView.frame = CGRect(origin: CGPoint(x: params.leftInset + inset - 8.0, y: 40.0), size: CGSize(width: width + 16.0, height: 44.0))
    }

    @objc private func sliderValueChanged() {
        guard let sliderView = self.sliderView else {
            return
        }
        self.item?.updated(Int(sliderView.value))
    }
}

// MARK: - Icon picker

final class ChogramIconPickerItem: ChogramBlockItem {
    let values: [String]
    let selectedValue: String
    let updated: (String) -> Void

    override var height: CGFloat {
        return 72.0
    }

    init(theme: PresentationTheme, values: [String], selectedValue: String, sectionId: ItemListSectionId, updated: @escaping (String) -> Void) {
        self.values = values
        self.selectedValue = selectedValue
        self.updated = updated
        super.init(theme: theme, sectionId: sectionId)
    }

    override func makeNode() -> ChogramBlockItemNode {
        return ChogramIconPickerItemNode()
    }
}

final class ChogramIconPickerItemNode: ChogramBlockItemNode {
    private var itemNodes: [ASImageNode] = []
    private var ringNode: ASDisplayNode?
    private var item: ChogramIconPickerItem?

    override func didLoad() {
        super.didLoad()

        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
    }

    override func updateContent(item: ChogramBlockItem, params: ListViewItemLayoutParams) {
        guard let item = item as? ChogramIconPickerItem else {
            return
        }
        self.item = item
        let theme = item.theme
        let size = CGSize(width: 48.0, height: 48.0)
        let iconSize = CGSize(width: 29.0, height: 29.0)
        let inset = params.leftInset + 12.0
        let step = (params.width - params.leftInset - params.rightInset - 24.0) / CGFloat(max(1, item.values.count))

        let ringNode: ASDisplayNode
        if let current = self.ringNode {
            ringNode = current
        } else {
            ringNode = ASDisplayNode()
            ringNode.cornerRadius = size.width * 0.5
            ringNode.borderWidth = 2.0
            self.addSubnode(ringNode)
            self.ringNode = ringNode
        }
        ringNode.borderColor = theme.list.itemAccentColor.cgColor
        ringNode.backgroundColor = theme.list.itemAccentColor.withAlphaComponent(0.14)

        while self.itemNodes.count < item.values.count {
            let node = ASImageNode()
            node.displaysAsynchronously = false
            self.addSubnode(node)
            self.itemNodes.append(node)
        }

        ringNode.isHidden = true
        for (index, value) in item.values.enumerated() {
            let center = CGPoint(x: inset + step * (CGFloat(index) + 0.5), y: floor(item.height * 0.5))
            let isSelected = value == item.selectedValue
            let color = isSelected ? theme.list.itemAccentColor : theme.list.itemSecondaryTextColor
            let node = self.itemNodes[index]
            node.image = generateTintedImage(image: UIImage(bundleImageName: chogramDeletedMessageIconName(value)), color: color)
            node.frame = CGRect(origin: CGPoint(x: center.x - iconSize.width * 0.5, y: center.y - iconSize.height * 0.5), size: iconSize)
            if isSelected {
                ringNode.isHidden = false
                ringNode.frame = CGRect(origin: CGPoint(x: center.x - size.width * 0.5, y: center.y - size.height * 0.5), size: size)
            }
        }
    }

    @objc private func tapGesture(_ recognizer: UITapGestureRecognizer) {
        guard let item = self.item, !item.values.isEmpty else {
            return
        }
        let location = recognizer.location(in: self.view)
        for (index, node) in self.itemNodes.enumerated() where index < item.values.count {
            if node.frame.insetBy(dx: -14.0, dy: -14.0).contains(location) {
                item.updated(item.values[index])
                return
            }
        }
    }
}

// The icon setting keeps its original emoji values as identifiers.
func chogramDeletedMessageIconName(_ value: String) -> String {
    switch value {
    case "🗑":
        return "Chogram/Trash"
    case "👻":
        return "Chogram/Ghost"
    case "👀":
        return "Chogram/Eye"
    case "❌":
        return "Chogram/Cross"
    default:
        return "Chogram/None"
    }
}

func chogramDeletedMessageStatusIcon(_ value: String) -> UIImage? {
    switch value {
    case "🗑":
        return UIImage(bundleImageName: "Chogram/StatusTrash")
    case "👻":
        return UIImage(bundleImageName: "Chogram/StatusGhost")
    case "👀":
        return UIImage(bundleImageName: "Chogram/StatusEye")
    case "❌":
        return UIImage(bundleImageName: "Chogram/StatusCross")
    default:
        return nil
    }
}
