import Foundation
import TelegramCore
import TelegramPresentationData
import TelegramStringFormatting
import TextFormat

// Today: time only; this year: day, month and time; otherwise the numeric date with time.
func chogramForwardOriginalDateString(timestamp: Int32, strings: PresentationStrings, dateTimeFormat: PresentationDateTimeFormat) -> String {
    var t: time_t = time_t(timestamp)
    var timeinfo: tm = tm()
    localtime_r(&t, &timeinfo)
    
    var now: time_t = time_t(Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970))
    var timeinfoNow: tm = tm()
    localtime_r(&now, &timeinfoNow)
    
    if timeinfo.tm_year == timeinfoNow.tm_year && timeinfo.tm_yday == timeinfoNow.tm_yday {
        return stringForMessageTimestamp(timestamp: timestamp, dateTimeFormat: dateTimeFormat)
    } else if timeinfo.tm_year == timeinfoNow.tm_year {
        return stringForMediumCompactDate(timestamp: timestamp, strings: strings, dateTimeFormat: dateTimeFormat)
    } else {
        return stringForMediumDate(timestamp: timestamp, strings: strings, dateTimeFormat: dateTimeFormat)
    }
}
