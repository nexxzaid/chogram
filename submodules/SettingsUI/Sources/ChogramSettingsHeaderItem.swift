import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramPresentationData
import ItemListUI
import AppBundle

private let logoSize: CGFloat = 88.0

final class ChogramSettingsHeaderItem: ListViewItem, ItemListItem {
    let presentationData: ItemListPresentationData
    let title: String
    let subtitle: String
    let logoImageName: String
    let sectionId: ItemListSectionId
    let isAlwaysPlain: Bool = true
    let selectable: Bool = false

    init(presentationData: ItemListPresentationData, title: String, subtitle: String, logoImageName: String, sectionId: ItemListSectionId) {
        self.presentationData = presentationData
        self.title = title
        self.subtitle = subtitle
        self.logoImageName = logoImageName
        self.sectionId = sectionId
    }

    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, neighbors: ListViewItemNeighbors, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = ChogramSettingsHeaderItemNode()
            let (layout, apply) = node.asyncLayout()(self, params, itemListNeighbors(item: self, topFacet: neighbors.previous?.base(ItemListNeighborFacet.self), bottomFacet: neighbors.next?.base(ItemListNeighborFacet.self)))

            node.contentSize = layout.contentSize
            node.insets = layout.insets

            Queue.mainQueue().async {
                completion(node, {
                    return (nil, { _ in apply() })
                })
            }
        }
    }

    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, neighbors: ListViewItemNeighbors, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            guard let nodeValue = node() as? ChogramSettingsHeaderItemNode else {
                assertionFailure()
                return
            }

            let makeLayout = nodeValue.asyncLayout()

            async {
                let (layout, apply) = makeLayout(self, params, itemListNeighbors(item: self, topFacet: neighbors.previous?.base(ItemListNeighborFacet.self), bottomFacet: neighbors.next?.base(ItemListNeighborFacet.self)))
                Queue.mainQueue().async {
                    completion(layout, { _ in
                        apply()
                    })
                }
            }
        }
    }
}

final class ChogramSettingsHeaderItemNode: ListViewItemNode, ItemListItemNode {
    private let logoNode: ASImageNode
    private let titleNode: TextNode
    private let subtitleNode: TextNode

    var tag: ItemListItemTag? {
        return nil
    }

    init() {
        self.logoNode = ASImageNode()
        self.logoNode.isLayerBacked = true
        self.logoNode.displaysAsynchronously = false

        self.titleNode = TextNode()
        self.titleNode.isUserInteractionEnabled = false

        self.subtitleNode = TextNode()
        self.subtitleNode.isUserInteractionEnabled = false

        super.init(layerBacked: false)

        self.addSubnode(self.logoNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.subtitleNode)
    }

    func asyncLayout() -> (_ item: ChogramSettingsHeaderItem, _ params: ListViewItemLayoutParams, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, () -> Void) {
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let makeSubtitleLayout = TextNode.asyncLayout(self.subtitleNode)

        return { [weak self] item, params, neighbors in
            let theme = item.presentationData.theme
            let constrainedSize = CGSize(width: params.width - params.leftInset - params.rightInset - 32.0, height: CGFloat.greatestFiniteMagnitude)

            let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.title, font: Font.bold(22.0), textColor: theme.list.itemPrimaryTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: constrainedSize, alignment: .center, cutout: nil, insets: UIEdgeInsets()))
            let (subtitleLayout, subtitleApply) = makeSubtitleLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.subtitle, font: Font.regular(14.0), textColor: theme.list.freeTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: constrainedSize, alignment: .center, cutout: nil, insets: UIEdgeInsets()))

            let topInset: CGFloat = 8.0
            let logoSpacing: CGFloat = 12.0
            let subtitleSpacing: CGFloat = 2.0
            let bottomInset: CGFloat = 6.0

            let contentSize = CGSize(width: params.width, height: topInset + logoSize + logoSpacing + titleLayout.size.height + subtitleSpacing + subtitleLayout.size.height + bottomInset)
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: itemListNeighborsGroupedInsets(neighbors, params))

            return (layout, {
                guard let self else {
                    return
                }
                let _ = titleApply()
                let _ = subtitleApply()
                self.logoNode.image = UIImage(bundleImageName: item.logoImageName)

                let titleY = topInset + logoSize + logoSpacing
                self.logoNode.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((params.width - logoSize) * 0.5), y: topInset), size: CGSize(width: logoSize, height: logoSize))
                self.titleNode.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((params.width - titleLayout.size.width) * 0.5), y: titleY), size: titleLayout.size)
                self.subtitleNode.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((params.width - subtitleLayout.size.width) * 0.5), y: titleY + titleLayout.size.height + subtitleSpacing), size: subtitleLayout.size)
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
