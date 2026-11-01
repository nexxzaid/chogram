import Foundation
import AppBundle
import UIKit
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import TelegramStringFormatting
import TextFormat
import LocalizedPeerData
import AccountContext

public enum MessageTimestampStatusFormat {
    case full
    case regular
    case minimal
}

private func dateStringForDay(strings: PresentationStrings, dateTimeFormat: PresentationDateTimeFormat, timestamp: Int32) -> String {
    var t: time_t = time_t(timestamp)
    var timeinfo: tm = tm()
    localtime_r(&t, &timeinfo)
    
    let timestampNow = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
    var now: time_t = time_t(timestampNow)
    var timeinfoNow: tm = tm()
    localtime_r(&now, &timeinfoNow)
    
    if timeinfo.tm_year != timeinfoNow.tm_year {
        return "\(stringForTimestamp(day: timeinfo.tm_mday, month: timeinfo.tm_mon + 1, year: timeinfo.tm_year, dateTimeFormat: dateTimeFormat))"
    } else {
        return "\(stringForTimestamp(day: timeinfo.tm_mday, month: timeinfo.tm_mon + 1, dateTimeFormat: dateTimeFormat))"
    }
}

private func monthAtIndex(_ index: Int, strings: PresentationStrings) -> String {
    switch index {
    case 0:
        return strings.Month_ShortJanuary
    case 1:
        return strings.Month_ShortFebruary
    case 2:
        return strings.Month_ShortMarch
    case 3:
        return strings.Month_ShortApril
    case 4:
        return strings.Month_ShortMay
    case 5:
        return strings.Month_ShortJune
    case 6:
        return strings.Month_ShortJuly
    case 7:
        return strings.Month_ShortAugust
    case 8:
        return strings.Month_ShortSeptember
    case 9:
        return strings.Month_ShortOctober
    case 10:
        return strings.Month_ShortNovember
    case 11:
        return strings.Month_ShortDecember
    default:
        return ""
    }
}

// The icon setting keeps its original emoji values as identifiers. A private-use character carries
// the choice through the plain date string to where the text is built.
private let chogramDeletedMessageIcons: [String: (marker: String, imageName: String)] = [
    "🗑": ("\u{E0C0}", "Chogram/StatusTrash"),
    "👻": ("\u{E0C1}", "Chogram/StatusGhost"),
    "👀": ("\u{E0C2}", "Chogram/StatusEye"),
    "❌": ("\u{E0C3}", "Chogram/StatusCross")
]

func messageDateAttributedString(_ text: String, font: UIFont, textColor: UIColor) -> NSAttributedString {
    let result = NSMutableAttributedString(string: text, attributes: [.font: font, .foregroundColor: textColor])
    for icon in chogramDeletedMessageIcons.values {
        let range = (text as NSString).range(of: icon.marker)
        if range.location != NSNotFound, let image = UIImage(bundleImageName: icon.imageName) {
            result.replaceCharacters(in: range, with: NSAttributedString(string: "\u{2003}", attributes: [.font: font, .foregroundColor: textColor, .attachment: image]))
        }
    }
    return result
}

public func stringForMessageTimestampStatus(
    context: AccountContext,
    message: EngineMessage,
    dateTimeFormat: PresentationDateTimeFormat,
    nameDisplayOrder: PresentationPersonNameOrder,
    strings: PresentationStrings,
    format: MessageTimestampStatusFormat = .regular,
    associatedData: ChatMessageItemAssociatedData,
    ignoreAuthor: Bool = false
) -> String {
    if let adAttribute = message.adAttribute {
        switch adAttribute.messageType {
        case .sponsored:
            return strings.Message_SponsoredLabel
        case .recommended:
            return strings.Message_RecommendedLabel
        }
    }
    
    var format = format
    var timestamp: Int32
    var isFullEditedDate = false
    if let scheduleTime = message.scheduleTime {
        timestamp = scheduleTime
    } else {
        if let useEditedTimestamp = context.getAppConfigValue("message_primary_edited_date") as? Bool, useEditedTimestamp, let editedTimestamp = message.editedTime {
            timestamp = editedTimestamp
            format = .full
            isFullEditedDate = true
        } else {
            timestamp = message.timestamp
        }
    }
    
    var displayFullDate = false
    if case .full = format, timestamp > 100000 {
        displayFullDate = true
    } else if let forwardInfo = message.forwardInfo, message.id.peerId == context.account.peerId, !associatedData.isForwardOptionsPreview {
        displayFullDate = true
        timestamp = forwardInfo.date
    }
    
    if let sourceAuthorInfo = message.sourceAuthorInfo, let orignalDate = sourceAuthorInfo.orignalDate {
        timestamp = orignalDate
    }
    
    var dateText = stringForMessageTimestamp(timestamp: timestamp, dateTimeFormat: dateTimeFormat)
    if timestamp == scheduleWhenOnlineTimestamp {
        dateText = "         "
    }
    
    if let repeatPeriod = message.scheduleRepeatPeriod {
        let repeatString: String
        switch repeatPeriod {
        case 60:
            repeatString = "1 min"
        case 300:
            repeatString = "5 min"
        case 86400:
            repeatString = strings.Message_RepeatPeriod_Daily
        case 7 * 86400:
            repeatString = strings.Message_RepeatPeriod_Weekly
        case 14 * 86400:
            repeatString = strings.Message_RepeatPeriod_Biweekly
        case 30 * 86400:
            repeatString = strings.Message_RepeatPeriod_Monthly
        case 91 * 86400:
            repeatString = strings.Message_RepeatPeriod_3Months
        case 182 * 86400:
            repeatString = strings.Message_RepeatPeriod_6Months
        case 365 * 86400:
            repeatString = strings.Message_RepeatPeriod_Yearly
        default:
            repeatString = "\(repeatPeriod)s"
        }
        dateText = strings.Message_RepeatAt(repeatString, dateText).string
    }
    
    if message.id.namespace == Namespaces.Message.ScheduledCloud, let _ = message.pendingProcessingAttribute {
        return strings.Message_Approximate(dateText).string
    }
    
    if displayFullDate {
        let dayText: String
        
        let nowTimestamp = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
        
        var t: time_t = time_t(timestamp)
        var timeinfo: tm = tm()
        localtime_r(&t, &timeinfo)
        
        var now: time_t = time_t(nowTimestamp)
        var timeinfoNow: tm = tm()
        localtime_r(&now, &timeinfoNow)
        
        if timeinfo.tm_year == timeinfoNow.tm_year {
            if format != .full || isFullEditedDate, timeinfo.tm_yday == timeinfoNow.tm_yday {
                if isFullEditedDate {
                    dayText = ""
                } else {
                    dayText = strings.Weekday_Today
                }
            } else {
                dayText = strings.Date_ChatDateHeader(monthAtIndex(Int(timeinfo.tm_mon), strings: strings), "\(timeinfo.tm_mday)").string
            }
        } else {
            dayText = strings.Date_ChatDateHeaderYear(monthAtIndex(Int(timeinfo.tm_mon), strings: strings), "\(timeinfo.tm_mday)", "\(1900 + timeinfo.tm_year)").string
        }
        if isFullEditedDate {
            if dayText.isEmpty {
                dateText = strings.Message_EditTodayFullDateFormat(stringForMessageTimestamp(timestamp: timestamp, dateTimeFormat: dateTimeFormat)).string
            } else {
                dateText = strings.Message_EditFullDateFormat(dayText, stringForMessageTimestamp(timestamp: timestamp, dateTimeFormat: dateTimeFormat)).string
            }
        } else {
            dateText = strings.Message_FullDateFormat(dayText, stringForMessageTimestamp(timestamp: timestamp, dateTimeFormat: dateTimeFormat)).string
        }
    } else if let forwardInfo = message.forwardInfo, forwardInfo.flags.contains(.isImported) {
        dateText = strings.Message_ImportedDateFormat(dateStringForDay(strings: strings, dateTimeFormat: dateTimeFormat, timestamp: forwardInfo.date), stringForMessageTimestamp(timestamp: forwardInfo.date, dateTimeFormat: dateTimeFormat), dateText).string
    }
    
    var authorTitle: String?
    if let author = message.author, case .user = author {
        if let peer = message.peers[message.id.peerId] as? TelegramChannel, case .broadcast = peer.info {
            if let channel = message.peers[message.id.peerId] as? TelegramChannel, case let .broadcast(info) = channel.info, message.author?.id != channel.id, info.flags.contains(.messagesShouldHaveProfiles) {
            } else {
                authorTitle = author.displayTitle(strings: strings, displayOrder: nameDisplayOrder)
            }
        } else if let forwardInfo = message.forwardInfo, forwardInfo.sourceMessageId?.peerId.namespace == Namespaces.Peer.CloudChannel {
            authorTitle = forwardInfo.authorSignature
        }
    } else {
        if let peer = message.peers[message.id.peerId] as? TelegramChannel, case .broadcast = peer.info {
            if let channel = message.peers[message.id.peerId] as? TelegramChannel, case let .broadcast(info) = channel.info, message.author?.id != channel.id, info.flags.contains(.messagesShouldHaveProfiles) {
            } else {
                for attribute in message.attributes {
                    if let attribute = attribute as? AuthorSignatureMessageAttribute {
                        authorTitle = attribute.signature
                        break
                    }
                }
            }
        }
        
        if message.id.peerId != context.account.peerId {
            for attribute in message.attributes {
                if let attribute = attribute as? SourceReferenceMessageAttribute {
                    if let forwardInfo = message.forwardInfo {
                        if forwardInfo.author?.id == attribute.messageId.peerId {
                            if authorTitle == nil {
                                authorTitle = forwardInfo.authorSignature
                            }
                        }
                    }
                    break
                }
            }
        }
    }
    
    if authorTitle == nil {
        for attribute in message.attributes {
            if let attribute = attribute as? InlineBusinessBotMessageAttribute {
                if let title = attribute.title {
                    authorTitle = title
                } else if let peerId = attribute.peerId, let peer = message.peers[peerId] {
                    authorTitle = peer.debugDisplayTitle
                }
            }
        }
    }
    if (Namespaces.Message.allEphemeral.contains(message.id.namespace) || Namespaces.Message.allWelcomeMessages.contains(message.id.namespace)), let channel = message.peers[message.id.peerId] as? TelegramChannel, case .broadcast = channel.info {
        authorTitle = nil
    }
    
    if let subject = associatedData.subject, case let .messageOptions(_, _, info) = subject, case .forward = info {
        authorTitle = nil
    }
    if ignoreAuthor {
        authorTitle = nil
    }
    
    if case .minimal = format {
        
    } else {
        if let authorTitle = authorTitle, !authorTitle.isEmpty {
            dateText = "\(authorTitle), \(dateText)"
        }
    }
    
    if let deletedAttribute = message.attributes.first(where: { $0 is ChogramDeletedMessageAttribute }) as? ChogramDeletedMessageAttribute {
        let settings = ChogramSettings.current
        var components: [String] = []
        if let icon = chogramDeletedMessageIcons[settings.deletedMessageIcon] {
            components.append(icon.marker)
        }
        if !settings.deletedMessageLabel.isEmpty {
            components.append(settings.deletedMessageLabel)
        }
        if settings.showDeletionTime {
            components.append(stringForMessageTimestamp(timestamp: deletedAttribute.date, dateTimeFormat: dateTimeFormat))
        }
        if !components.isEmpty {
            dateText = "\(components.joined(separator: " ")) · \(dateText)"
        }
    }
    
    return dateText
}
