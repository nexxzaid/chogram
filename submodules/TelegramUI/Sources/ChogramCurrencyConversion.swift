import Foundation
import UIKit
import TelegramCore
import Display
import AppBundle
import ContextUI
import UndoUI
import ChatControllerInteraction

private struct ChogramCurrency {
    let code: String
    // Regex fragments, matched case-insensitively.
    let pattern: String
}

private let chogramCurrencies: [ChogramCurrency] = [
    ChogramCurrency(code: "USD", pattern: "\\$|usdt?|долл[а-яё]*|бакс[а-яё]*"),
    ChogramCurrency(code: "EUR", pattern: "€|eur|евро"),
    ChogramCurrency(code: "RUB", pattern: "₽|rub|руб[а-яё]*"),
    ChogramCurrency(code: "KZT", pattern: "₸|kzt|тенге|тг"),
    ChogramCurrency(code: "UAH", pattern: "₴|uah|грн|гривн[а-яё]*|гривен"),
    ChogramCurrency(code: "GBP", pattern: "£|gbp")
]

private let chogramTargetCurrencies = ["RUB", "USD", "EUR"]

// 1 000 000 | 1,000.50 | 1.000,50 | 3000 | 12,5
private let chogramNumberPattern = "\\d{1,3}(?:[ \\u00A0\\u202F,.]\\d{3})+(?:[.,]\\d+)?|\\d+(?:[.,]\\d+)?"

struct ChogramMoneyAmount {
    let value: Double
    let code: String
    let location: Int
}

func chogramParseNumber(_ raw: String) -> Double? {
    var text = raw.replacingOccurrences(of: "\u{00A0}", with: "").replacingOccurrences(of: "\u{202F}", with: "").replacingOccurrences(of: " ", with: "")
    let hasDot = text.contains(".")
    let hasComma = text.contains(",")
    if hasDot && hasComma {
        // The separator that comes last is the decimal one.
        let lastDot = text.lastIndex(of: ".")!
        let lastComma = text.lastIndex(of: ",")!
        if lastDot > lastComma {
            text = text.replacingOccurrences(of: ",", with: "")
        } else {
            text = text.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
        }
    } else if hasDot || hasComma {
        let separator: Character = hasDot ? "." : ","
        let parts = text.split(separator: separator, omittingEmptySubsequences: false)
        if parts.count > 2 {
            text = parts.joined()
        } else if parts.count == 2, parts[1].count == 3, parts[0] != "0", parts[0].count <= 3 {
            text = parts.joined()
        } else {
            text = parts.joined(separator: ".")
        }
    }
    return Double(text)
}

func chogramFindMoneyAmounts(in text: String) -> [ChogramMoneyAmount] {
    let nsText = text as NSString
    let fullRange = NSRange(location: 0, length: nsText.length)
    
    // Prefix ("$50") and suffix ("50 usd") forms are collected together and resolved left to right:
    // in "50€ 50$" the € belongs to the first number, not to the "€ 50" that starts inside it.
    var candidates: [(range: NSRange, amount: ChogramMoneyAmount)] = []
    func collect(_ pattern: String, code: String) {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return
        }
        for match in regex.matches(in: text, options: [], range: fullRange) {
            guard let value = chogramParseNumber(nsText.substring(with: match.range(at: 1))), value > 0 else {
                continue
            }
            candidates.append((match.range, ChogramMoneyAmount(value: value, code: code, location: match.range.location)))
        }
    }
    for currency in chogramCurrencies {
        collect("(?<![\\p{L}])(?:\(currency.pattern))\\s?(\(chogramNumberPattern))(?![\\d])", code: currency.code)
        collect("(?<![\\d.,])(\(chogramNumberPattern))\\s?(?:\(currency.pattern))(?![\\p{L}])", code: currency.code)
    }
    candidates.sort(by: { lhs, rhs in
        if lhs.range.location != rhs.range.location {
            return lhs.range.location < rhs.range.location
        }
        return lhs.range.length > rhs.range.length
    })
    
    var result: [ChogramMoneyAmount] = []
    var takenEnd = 0
    for candidate in candidates where candidate.range.location >= takenEnd {
        result.append(candidate.amount)
        takenEnd = candidate.range.location + candidate.range.length
    }
    return result
}

private let chogramRatesKey = "chogram.currencyRates"
private let chogramRatesTimeKey = "chogram.currencyRatesTime"
private let chogramRatesLifetime: Double = 12.0 * 60.0 * 60.0

private func chogramCachedRates() -> (rates: [String: Double], isFresh: Bool)? {
    let defaults = UserDefaults.standard
    guard let rates = defaults.dictionary(forKey: chogramRatesKey) as? [String: Double], !rates.isEmpty else {
        return nil
    }
    let time = defaults.double(forKey: chogramRatesTimeKey)
    return (rates, Date().timeIntervalSince1970 - time < chogramRatesLifetime)
}

// Calls back on the main queue; nil means there are no rates at all.
func chogramLoadCurrencyRates(completion: @escaping ([String: Double]?) -> Void) {
    let cached = chogramCachedRates()
    if let cached, cached.isFresh {
        completion(cached.rates)
        return
    }
    guard let url = URL(string: "https://open.er-api.com/v6/latest/USD") else {
        completion(cached?.rates)
        return
    }
    var request = URLRequest(url: url)
    request.timeoutInterval = 10.0
    URLSession.shared.dataTask(with: request) { data, _, _ in
        var fetched: [String: Double]?
        if let data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let rates = json["rates"] as? [String: Any] {
            var parsed: [String: Double] = [:]
            for (key, value) in rates {
                if let number = value as? NSNumber {
                    parsed[key] = number.doubleValue
                }
            }
            if !parsed.isEmpty {
                fetched = parsed
            }
        }
        let fetchedRates = fetched
        DispatchQueue.main.async {
            if let fetched = fetchedRates {
                UserDefaults.standard.set(fetched, forKey: chogramRatesKey)
                UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: chogramRatesTimeKey)
                completion(fetched)
            } else {
                // A stale cache is still better than nothing.
                completion(cached?.rates)
            }
        }
    }.resume()
}

private func chogramFormatMoney(_ value: Double) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.groupingSeparator = " "
    formatter.decimalSeparator = ","
    formatter.maximumFractionDigits = value < 100.0 ? 2 : 0
    formatter.minimumFractionDigits = 0
    return formatter.string(from: NSNumber(value: value)) ?? String(value)
}

func chogramCurrencyConversionText(amounts: [ChogramMoneyAmount], rates: [String: Double]) -> String? {
    var lines: [String] = []
    for amount in amounts.prefix(3) {
        guard let sourceRate = rates[amount.code], sourceRate > 0 else {
            continue
        }
        let usd = amount.value / sourceRate
        var parts: [String] = []
        for target in chogramTargetCurrencies where target != amount.code {
            if let targetRate = rates[target] {
                parts.append("\(chogramFormatMoney(usd * targetRate)) \(target)")
            }
        }
        if !parts.isEmpty {
            lines.append("\(chogramFormatMoney(amount.value)) \(amount.code) = " + parts.joined(separator: " · "))
        }
    }
    return lines.isEmpty ? nil : lines.joined(separator: "\n")
}

func chogramCurrencyContextMenuAction(text: String, controllerInteraction: ChatControllerInteraction) -> ContextMenuItem? {
    guard ChogramSettings.current.convertCurrency, !text.isEmpty else {
        return nil
    }
    let amounts = chogramFindMoneyAmounts(in: text)
    if amounts.isEmpty {
        return nil
    }
    return .action(ContextMenuActionItem(text: "Пересчитать валюту", icon: { theme in
        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Card"), color: theme.actionSheet.primaryTextColor)
    }, action: { _, f in
        f(.default)
        chogramLoadCurrencyRates(completion: { rates in
            var message = "Нет курсов, проверь интернет"
            if let rates, let converted = chogramCurrencyConversionText(amounts: amounts, rates: rates) {
                message = converted
            }
            controllerInteraction.displayUndo(.info(title: nil, text: message, timeout: 6.0, customUndoText: nil))
        })
    }))
}
