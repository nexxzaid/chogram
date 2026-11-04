import Foundation
import UIKit
import Photos
import Display
import Postbox
import SwiftSignalKit
import TelegramCore
import AccountContext
import UndoUI
import WebPBinding

// "Сохранить как картинку" for a sticker. A static sticker is saved at full size as a PNG with
// its transparent background; an animated or video sticker has no single image, so its preview
// frame is saved instead.
func chogramSaveStickerAsImage(context: AccountContext, message: Message, file: TelegramMediaFile, present: @escaping (ViewController) -> Void) {
    let resource: MediaResource
    if file.isStaticSticker || (!file.isAnimatedSticker && !file.isVideoSticker) {
        resource = file.resource
    } else if let preview = file.previewRepresentations.last {
        resource = preview.resource
    } else {
        return
    }

    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
    let mediaBox = context.account.postbox.mediaBox
    let fetch = fetchedMediaResource(mediaBox: mediaBox, userLocation: .peer(message.id.peerId), userContentType: .sticker, reference: .media(media: .message(message: MessageReference(message), media: file), resource: resource)).startStandalone()

    let _ = (mediaBox.resourceData(resource, option: .complete(waitUntilFetchStatus: false))
    |> filter { $0.complete }
    |> take(1)
    |> deliverOnMainQueue).startStandalone(next: { data in
        fetch.dispose()
        guard let raw = try? Data(contentsOf: URL(fileURLWithPath: data.path)) else {
            return
        }
        guard let image = WebP.convert(fromWebP: raw) ?? UIImage(data: raw), let png = image.pngData() else {
            return
        }
        let save: () -> Void = {
            PHPhotoLibrary.shared().performChanges({
                let request = PHAssetCreationRequest.forAsset()
                request.addResource(with: .photo, data: png, options: nil)
            }, completionHandler: { success, _ in
                Queue.mainQueue().async {
                    let text = success ? "Стикер сохранён в Фото" : "Не удалось сохранить: нет доступа к Фото"
                    present(UndoOverlayController(presentationData: presentationData, content: .info(title: nil, text: text, timeout: nil, customUndoText: nil), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }))
                }
            })
        }
        if #available(iOS 14.0, *) {
            PHPhotoLibrary.requestAuthorization(for: .addOnly, handler: { status in
                if status == .authorized || status == .limited {
                    save()
                } else {
                    Queue.mainQueue().async {
                        present(UndoOverlayController(presentationData: presentationData, content: .info(title: nil, text: "Разреши Чограму добавлять в Фото в настройках iPhone", timeout: nil, customUndoText: nil), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }))
                    }
                }
            })
        } else {
            save()
        }
    })
}
