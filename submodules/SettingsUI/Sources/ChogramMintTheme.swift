import Foundation
import SwiftSignalKit
import TelegramCore
import TelegramUIPreferences
import AccountContext

private let chogramMintBackupKey = "chogram.mintThemeBackup"
private let chogramMintAccentIndex: Int32 = 6100
private let chogramMintDarkWallpaper: UInt32 = 0x0B1A17
private let chogramMintLightWallpaper: UInt32 = 0xE7F3F0

// "Мятная тема Чограма" recolors the current theme: a mint accent, bubbles in tone and a deep green
// chat background. The accent the user had before is kept on the device, so turning the theme off
// brings it back. A chat background the user picked is never replaced.
func chogramApplyMintTheme(context: AccountContext, enabled: Bool) {
    let isDark = context.sharedContext.currentPresentationData.with { $0 }.theme.overallDarkAppearance
    let _ = updatePresentationThemeSettingsInteractively(accountManager: context.sharedContext.accountManager, { settings in
        var settings = settings
        let index = settings.theme.index
        let key = "\(index)"
        var backups = UserDefaults.standard.dictionary(forKey: chogramMintBackupKey) as? [String: Data] ?? [:]

        if enabled {
            if backups[key] == nil {
                if let current = settings.themeSpecificAccentColors[index], current.index != chogramMintAccentIndex {
                    let encoder = EnginePostboxEncoder()
                    current.encode(encoder)
                    backups[key] = encoder.makeData()
                } else {
                    backups[key] = Data()
                }
            }
            settings.themeSpecificAccentColors[index] = PresentationThemeAccentColor(
                index: chogramMintAccentIndex,
                baseColor: .preset,
                accentColor: isDark ? 0xFF5EEAD4 : 0xFF0F8F7E,
                bubbleColors: isDark ? [0xFF0E5A50, 0xFF0B4A42] : [0xFFD9F7F1, 0xFFC8F1E8],
                wallpaper: nil
            )
            if settings.themeSpecificChatWallpapers[index] == nil {
                settings.themeSpecificChatWallpapers[index] = .color(isDark ? chogramMintDarkWallpaper : chogramMintLightWallpaper)
            }
        } else {
            if let data = backups[key] {
                if data.isEmpty {
                    settings.themeSpecificAccentColors[index] = nil
                } else {
                    settings.themeSpecificAccentColors[index] = PresentationThemeAccentColor(decoder: EnginePostboxDecoder(buffer: EngineMemoryBuffer(data: data)))
                }
                backups[key] = nil
            } else if settings.themeSpecificAccentColors[index]?.index == chogramMintAccentIndex {
                settings.themeSpecificAccentColors[index] = nil
            }
            if let wallpaper = settings.themeSpecificChatWallpapers[index], wallpaper == .color(chogramMintDarkWallpaper) || wallpaper == .color(chogramMintLightWallpaper) {
                settings.themeSpecificChatWallpapers[index] = nil
            }
        }

        UserDefaults.standard.set(backups, forKey: chogramMintBackupKey)
        return settings
    }).startStandalone()
}
