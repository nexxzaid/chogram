import Foundation
import AccountContext
import TelegramCore

public let chogramHiddenPhoneNumberText = "Номер скрыт"

// Formats the account's own phone number, or returns the placeholder when it is hidden.
public func chogramFormatOwnPhoneNumber(context: AccountContext, number: String) -> String {
    if ChogramSettings.current.hidePhoneNumber {
        return chogramHiddenPhoneNumberText
    }
    return formatPhoneNumber(context: context, number: number)
}
