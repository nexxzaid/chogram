import Foundation

// The items of the message context menu that can be turned off in Чограм → Чаты → Меню сообщения.
// The raw value is what ChogramSettings.hiddenMessageMenuItems stores, so never rename a case's value.
public enum ChogramMessageMenuItem: String, CaseIterable {
    // Telegram's own items.
    case reply = "reply"
    case copy = "copy"
    case forward = "forward"
    case edit = "edit"
    case pin = "pin"
    case translate = "translate"
    case select = "select"
    case report = "report"
    case delete = "delete"

    // Items Чограм adds.
    case details = "details"
    case repeatMessage = "repeat"
    case hideLocally = "hideLocally"
    case readUntil = "readUntil"
    case saveAsImage = "saveAsImage"

    public var title: String {
        switch self {
        case .reply:
            return "Ответить"
        case .copy:
            return "Скопировать"
        case .forward:
            return "Переслать"
        case .edit:
            return "Изменить"
        case .pin:
            return "Закрепить"
        case .translate:
            return "Перевести"
        case .select:
            return "Выбрать"
        case .report:
            return "Пожаловаться"
        case .delete:
            return "Удалить"
        case .details:
            return "Подробности"
        case .repeatMessage:
            return "Повторить"
        case .hideLocally:
            return "Скрыть у себя"
        case .readUntil:
            return "Прочитать до сюда"
        case .saveAsImage:
            return "Сохранить картинкой"
        }
    }

    public var isChogramItem: Bool {
        switch self {
        case .details, .repeatMessage, .hideLocally, .readUntil, .saveAsImage:
            return true
        default:
            return false
        }
    }

    // Whether the item shows, given the current settings.
    public static func isVisible(_ item: ChogramMessageMenuItem, settings: ChogramSettings = .current) -> Bool {
        return !settings.hiddenMessageMenuItems.contains(item.rawValue)
    }
}
