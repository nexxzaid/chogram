import Foundation
import UIKit
import CoreText
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AccountContext
import LegacyMediaPickerUI

// Fonts the user uploads live in Application Support/ChogramFonts. Display reads the chosen one
// through "chogram.customFontFile" and "chogram.customFontPostScriptName" at launch.
private struct ChogramFontEntry: Equatable {
    let file: String
    let postScriptName: String
    let displayName: String
}

private let chogramFontsListKey = "chogram.customFonts"
private let chogramFontFileKey = "chogram.customFontFile"
private let chogramFontNameKey = "chogram.customFontPostScriptName"

private func chogramFontsDirectory() -> URL? {
    guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
        return nil
    }
    let directory = base.appendingPathComponent("ChogramFonts")
    try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
}

private func chogramStoredFonts() -> [ChogramFontEntry] {
    let list = UserDefaults.standard.array(forKey: chogramFontsListKey) as? [[String]] ?? []
    return list.compactMap { item in
        item.count == 3 ? ChogramFontEntry(file: item[0], postScriptName: item[1], displayName: item[2]) : nil
    }
}

private func chogramSaveFonts(_ fonts: [ChogramFontEntry]) {
    UserDefaults.standard.set(fonts.map { [$0.file, $0.postScriptName, $0.displayName] }, forKey: chogramFontsListKey)
}

private func chogramSelectedFontFile() -> String? {
    let file = UserDefaults.standard.string(forKey: chogramFontFileKey)
    return (file?.isEmpty ?? true) ? nil : file
}

private func chogramSelectFont(_ font: ChogramFontEntry?) {
    UserDefaults.standard.set(font?.file ?? "", forKey: chogramFontFileKey)
    UserDefaults.standard.set(font?.postScriptName ?? "", forKey: chogramFontNameKey)
}

private enum ChogramFontImportError: Error {
    case unreadable
    case unsupported
}

private func chogramImportFont(from url: URL) -> Result<ChogramFontEntry, ChogramFontImportError> {
    let accessing = url.startAccessingSecurityScopedResource()
    defer {
        if accessing {
            url.stopAccessingSecurityScopedResource()
        }
    }
    guard let directory = chogramFontsDirectory(), let data = try? Data(contentsOf: url) else {
        return .failure(.unreadable)
    }
    guard let provider = CGDataProvider(data: data as CFData), let cgFont = CGFont(provider), let postScriptName = cgFont.postScriptName as String? else {
        return .failure(.unsupported)
    }
    let displayName = (cgFont.fullName as String?) ?? postScriptName
    let file = "\(postScriptName).\(url.pathExtension.lowercased())"
    let destination = directory.appendingPathComponent(file)
    try? FileManager.default.removeItem(at: destination)
    do {
        try data.write(to: destination)
    } catch {
        return .failure(.unreadable)
    }
    CTFontManagerRegisterFontsForURL(destination as CFURL, .process, nil)
    let entry = ChogramFontEntry(file: file, postScriptName: postScriptName, displayName: displayName)
    var fonts = chogramStoredFonts().filter { $0.postScriptName != postScriptName }
    fonts.append(entry)
    chogramSaveFonts(fonts)
    return .success(entry)
}

private func chogramDeleteFont(_ font: ChogramFontEntry) {
    if chogramSelectedFontFile() == font.file {
        chogramSelectFont(nil)
    }
    if let directory = chogramFontsDirectory() {
        try? FileManager.default.removeItem(at: directory.appendingPathComponent(font.file))
    }
    chogramSaveFonts(chogramStoredFonts().filter { $0.file != font.file })
}

private final class ChogramFontsArguments {
    let select: (ChogramFontEntry?) -> Void
    let delete: (ChogramFontEntry) -> Void
    let upload: () -> Void

    init(select: @escaping (ChogramFontEntry?) -> Void, delete: @escaping (ChogramFontEntry) -> Void, upload: @escaping () -> Void) {
        self.select = select
        self.delete = delete
        self.upload = upload
    }
}

private enum ChogramFontsEntry: ItemListNodeEntry {
    case header
    case system(Bool)
    case font(Int32, ChogramFontEntry, Bool)
    case upload
    case footer

    var section: ItemListSectionId {
        switch self {
        case .upload:
            return 1
        default:
            return 0
        }
    }

    var stableId: Int32 {
        switch self {
        case .header:
            return 0
        case .system:
            return 1
        case let .font(index, _, _):
            return 10 + index
        case .upload:
            return 10000
        case .footer:
            return 10001
        }
    }

    static func <(lhs: ChogramFontsEntry, rhs: ChogramFontsEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! ChogramFontsArguments
        switch self {
        case .header:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "ШРИФТ", sectionId: self.section)
        case let .system(checked):
            return ItemListCheckboxItem(presentationData: presentationData, systemStyle: .glass, title: "Системный", style: .left, checked: checked, zeroSeparatorInsets: false, sectionId: self.section, action: {
                arguments.select(nil)
            })
        case let .font(_, font, checked):
            return ItemListCheckboxItem(presentationData: presentationData, systemStyle: .glass, title: font.displayName, style: .left, checked: checked, zeroSeparatorInsets: false, sectionId: self.section, action: {
                arguments.select(font)
            }, deleteAction: {
                arguments.delete(font)
            })
        case .upload:
            return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: "Загрузить шрифт…", kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                arguments.upload()
            })
        case .footer:
            return ItemListTextItem(presentationData: presentationData, text: .plain("Подходят файлы .ttf, .otf и .ttc из «Файлов». Шрифт меняет текст во всём приложении и сменится после перезапуска Чограма. Смахни шрифт влево, чтобы удалить его."), sectionId: self.section)
        }
    }
}

func chogramFontsController(context: AccountContext) -> ViewController {
    let statePromise = Promise<(fonts: [ChogramFontEntry], selected: String?)>((chogramStoredFonts(), chogramSelectedFontFile()))
    let reload = {
        statePromise.set(.single((chogramStoredFonts(), chogramSelectedFontFile())))
    }

    var presentControllerImpl: ((ViewController) -> Void)?

    let arguments = ChogramFontsArguments(select: { font in
        chogramSelectFont(font)
        reload()
    }, delete: { font in
        chogramDeleteFont(font)
        reload()
    }, upload: {
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let picker = legacyICloudFilePicker(theme: presentationData.theme, mode: .import, documentTypes: ["public.font", "public.truetype-ttf-font", "public.opentype-font", "public.truetype-collection-font"], completion: { urls in
            guard let url = urls.first else {
                return
            }
            switch chogramImportFont(from: url) {
            case let .success(font):
                chogramSelectFont(font)
                reload()
            case .failure:
                presentControllerImpl?(textAlertController(context: context, title: nil, text: "Не получилось прочитать шрифт. Подходят файлы .ttf, .otf и .ttc.", actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]))
            }
        })
        presentControllerImpl?(picker)
    })

    let signal = combineLatest(queue: .mainQueue(),
        context.sharedContext.presentationData,
        statePromise.get()
    )
    |> map { presentationData, state -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text("Шрифт"), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        var entries: [ChogramFontsEntry] = [.header, .system(state.selected == nil)]
        for (index, font) in state.fonts.enumerated() {
            entries.append(.font(Int32(index), font, state.selected == font.file))
        }
        entries.append(.upload)
        entries.append(.footer)
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: entries, style: .blocks, animateChanges: true)
        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)
    presentControllerImpl = { [weak controller] c in
        controller?.present(c, in: .window(.root))
    }
    return controller
}

func chogramCurrentFontLabel() -> String {
    guard let file = chogramSelectedFontFile(), let font = chogramStoredFonts().first(where: { $0.file == file }) else {
        return "Системный"
    }
    return font.displayName
}
