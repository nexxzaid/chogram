import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramCore
import SwiftSignalKit
import Postbox
import TelegramPresentationData
import UndoUI
import ChatMessageBackground
import ChatMessageItemView
import ChatMessageItem

// "Save as image": the selected messages are snapshotted from the visible chat item nodes and stacked
// on the chat wallpaper. The selection panel and the context menu post this notification.
let chogramSaveAsImageNotification = Notification.Name("chogram.saveAsImage")

extension ChatControllerImpl {
    func chogramSetupSaveAsImage() {
        let _ = NotificationCenter.default.addObserver(forName: chogramSaveAsImageNotification, object: nil, queue: .main, using: { [weak self] notification in
            guard let self, self.isNodeLoaded, self.viewIfLoaded?.window != nil else {
                return
            }
            guard let ids = notification.userInfo?["ids"] as? [MessageId], let firstId = ids.first else {
                return
            }
            guard self.chatDisplayNode.historyNode.messageInCurrentHistoryView(firstId) != nil else {
                return
            }
            let fromSelection = (notification.userInfo?["fromSelection"] as? Bool) ?? false
            if fromSelection {
                // Selection checkmarks shift the bubbles, so leave selection mode before taking snapshots.
                self.updateChatPresentationInterfaceState(animated: false, interactive: false, { $0.updatedInterfaceState({ $0.withoutSelectionState() }) })
            }
            Queue.mainQueue().after(0.5, { [weak self] in
                self?.chogramRenderMessagesAsImage(ids: ids)
            })
        })
    }

    // Bubble fills in the chat come from a wallpaper portal view, which drawHierarchy does not render
    // (the bubble shape node is empty in that mode), so the fill is drawn here under the node snapshot.
    private func chogramBubbleFills(node: ChatMessageItemView, item: ChatMessageItem) -> [(CGRect, UIImage)] {
        let incoming = item.content.effectivelyIncoming(item.context.account.peerId, associatedData: item.associatedData)
        let bubbleColors = item.presentationData.theme.theme.chat.message
        let fill: [UIColor] = incoming ? bubbleColors.incoming.bubble.withWallpaper.fill : bubbleColors.outgoing.bubble.withWallpaper.fill
        if fill.isEmpty {
            return []
        }
        var backdrops: [ChatMessageBubbleBackdrop] = []
        func collect(_ current: ASDisplayNode) {
            for subnode in current.subnodes ?? [] {
                if let backdrop = subnode as? ChatMessageBubbleBackdrop {
                    backdrops.append(backdrop)
                } else {
                    collect(subnode)
                }
            }
        }
        collect(node)

        var result: [(CGRect, UIImage)] = []
        for backdrop in backdrops {
            guard backdrop.backgroundContent != nil, let maskView = backdrop.maskView, !backdrop.isHidden, backdrop.alpha > 0.0 else {
                continue
            }
            maskView.layoutIfNeeded()
            let size = maskView.bounds.size
            if size.width <= 0.0 || size.height <= 0.0 {
                continue
            }
            let rect = backdrop.view.convert(maskView.frame, to: node.view)
            let renderer = UIGraphicsImageRenderer(size: size)
            let maskImage = renderer.image { context in
                maskView.layer.render(in: context.cgContext)
            }
            let image = renderer.image { context in
                let cgContext = context.cgContext
                if fill.count > 1, let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: fill.map { $0.cgColor } as CFArray, locations: nil) {
                    cgContext.drawLinearGradient(gradient, start: CGPoint(), end: CGPoint(x: size.width, y: size.height), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
                } else {
                    fill[0].setFill()
                    UIRectFill(CGRect(origin: CGPoint(), size: size))
                }
                maskImage.draw(in: CGRect(origin: CGPoint(), size: size), blendMode: .destinationIn, alpha: 1.0)
            }
            result.append((rect, image))
        }
        return result
    }

    private func chogramRenderMessagesAsImage(ids: [MessageId]) {
        let idSet = Set(ids)
        var foundNodes: [ChatMessageItemView] = []
        var foundIds = Set<MessageId>()
        self.chatDisplayNode.historyNode.forEachVisibleItemNode { itemNode in
            guard let itemNode = itemNode as? ChatMessageItemView, let item = itemNode.item else {
                return
            }
            var matched = false
            for entry in item.content {
                if idSet.contains(entry.0.id) {
                    matched = true
                    foundIds.insert(entry.0.id)
                }
            }
            if matched {
                foundNodes.append(itemNode)
            }
        }
        foundNodes.sort(by: { lhs, rhs in
            guard let lhsItem = lhs.item, let rhsItem = rhs.item else {
                return false
            }
            return lhsItem.content.index < rhsItem.content.index
        })

        let presentationData = self.presentationData
        if foundNodes.isEmpty {
            self.present(UndoOverlayController(presentationData: presentationData, content: .info(title: nil, text: "Сообщения не видны на экране", timeout: 4.0, customUndoText: nil), elevatedLayout: false, action: { _ in return false }), in: .current)
            return
        }

        var bubbleFills: [[(CGRect, UIImage)]] = []
        for node in foundNodes {
            if let item = node.item {
                bubbleFills.append(self.chogramBubbleFills(node: node, item: item))
            } else {
                bubbleFills.append([])
            }
        }

        let padding: CGFloat = 8.0
        let width = foundNodes.map { $0.bounds.width }.max() ?? 0.0
        var height = padding * 2.0
        for node in foundNodes {
            height += node.bounds.height
        }
        if width <= 0.0 || height <= 0.0 {
            return
        }
        let size = CGSize(width: width, height: height)

        let backgroundView = self.chatDisplayNode.backgroundNode.view
        var wallpaperImage: UIImage?
        if self.presentationInterfaceState.chatWallpaper.singleColor == nil, backgroundView.bounds.width > 0.0, backgroundView.bounds.height > 0.0 {
            let wallpaperRenderer = UIGraphicsImageRenderer(size: backgroundView.bounds.size)
            wallpaperImage = wallpaperRenderer.image { _ in
                let _ = backgroundView.drawHierarchy(in: CGRect(origin: CGPoint(), size: backgroundView.bounds.size), afterScreenUpdates: false)
            }
        }
        let fillColor: UIColor = self.presentationInterfaceState.chatWallpaper.singleColor ?? presentationData.theme.list.plainBackgroundColor

        let format = UIGraphicsImageRendererFormat()
        format.scale = UIScreen.main.scale
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let image = renderer.image { _ in
            fillColor.setFill()
            UIRectFill(CGRect(origin: CGPoint(), size: size))
            if let wallpaperImage {
                var y: CGFloat = 0.0
                while y < size.height {
                    wallpaperImage.draw(in: CGRect(x: 0.0, y: y, width: size.width, height: wallpaperImage.size.height))
                    y += wallpaperImage.size.height
                }
            }
            var offset = padding
            for (index, node) in foundNodes.enumerated() {
                let nodeSize = node.bounds.size
                let nodeOrigin = CGPoint(x: floor((size.width - nodeSize.width) / 2.0), y: offset)
                for (rect, fillImage) in bubbleFills[index] {
                    fillImage.draw(in: rect.offsetBy(dx: nodeOrigin.x, dy: nodeOrigin.y))
                }
                let _ = node.view.drawHierarchy(in: CGRect(origin: nodeOrigin, size: nodeSize), afterScreenUpdates: false)
                offset += nodeSize.height
            }
        }

        if foundIds.count < idSet.count {
            self.present(UndoOverlayController(presentationData: presentationData, content: .info(title: nil, text: "Часть сообщений не на экране, они не попали в картинку", timeout: 4.0, customUndoText: nil), elevatedLayout: false, action: { _ in return false }), in: .current)
        }

        // The system share sheet offers "Save Image" and handles the photo library permission itself.
        let activityController = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        self.context.sharedContext.applicationBindings.presentNativeController(activityController)
    }
}
