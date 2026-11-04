import Foundation
import TelegramCore

// Telegram does not expose when an account was created. User IDs grow over time, so a table of
// known (ID, date) points gives a month-level estimate, which the profile marks as approximate.
private let chogramIdDatePoints: [(id: Int64, timestamp: Double)] = [
    (2_768_409, 1_383_264_000),
    (7_679_610, 1_388_448_000),
    (11_538_514, 1_391_212_000),
    (15_835_244, 1_392_940_000),
    (23_646_077, 1_393_459_000),
    (38_015_510, 1_393_632_000),
    (44_634_663, 1_399_334_000),
    (54_845_238, 1_411_257_000),
    (63_263_518, 1_414_454_000),
    (101_260_938, 1_425_600_000),
    (116_812_045, 1_437_696_000),
    (130_029_930, 1_441_324_000),
    (157_242_073, 1_446_768_000),
    (171_295_414, 1_457_481_000),
    (222_021_233, 1_465_344_000),
    (278_941_742, 1_473_465_000),
    (328_594_461, 1_482_969_000),
    (369_669_043, 1_490_918_000),
    (400_169_472, 1_501_459_000),
    (805_158_066, 1_563_208_000),
    (1_974_255_900, 1_634_000_000),
    (5_000_000_000, 1_641_000_000),
    (5_500_000_000, 1_657_000_000),
    (6_000_000_000, 1_672_000_000),
    (6_500_000_000, 1_691_000_000),
    (7_000_000_000, 1_704_000_000),
    (7_500_000_000, 1_722_000_000),
    (8_000_000_000, 1_736_000_000)
]

private let chogramMonthNames = ["январь", "февраль", "март", "апрель", "май", "июнь", "июль", "август", "сентябрь", "октябрь", "ноябрь", "декабрь"]

func chogramAccountCreationEstimate(userId: Int64) -> String? {
    guard userId > 0, let first = chogramIdDatePoints.first, let last = chogramIdDatePoints.last else {
        return nil
    }
    let timestamp: Double
    if userId <= first.id {
        timestamp = first.timestamp
    } else if userId >= last.id {
        // Past the table, a newer account than the newest known point: no better guess than that point.
        timestamp = last.timestamp
    } else {
        var result = last.timestamp
        for index in 1 ..< chogramIdDatePoints.count {
            let lower = chogramIdDatePoints[index - 1]
            let upper = chogramIdDatePoints[index]
            if userId <= upper.id {
                let fraction = Double(userId - lower.id) / Double(upper.id - lower.id)
                result = lower.timestamp + (upper.timestamp - lower.timestamp) * fraction
                break
            }
        }
        timestamp = result
    }
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC") ?? calendar.timeZone
    let components = calendar.dateComponents([.year, .month], from: Date(timeIntervalSince1970: timestamp))
    guard let year = components.year, let month = components.month, month >= 1, month <= 12 else {
        return nil
    }
    let prefix = userId >= last.id ? "не раньше" : "≈"
    return "\(prefix) \(chogramMonthNames[month - 1]) \(year)"
}

// The data center is the one that stores the profile photo, which is the account's home DC.
// Without a photo there is nothing to read it from.
func chogramDatacenter(user: TelegramUser) -> String? {
    for representation in user.photo {
        if let resource = representation.resource as? CloudPeerPhotoSizeMediaResource {
            let city: String
            switch resource.datacenterId {
            case 1, 3:
                city = "Майами"
            case 2, 4:
                city = "Амстердам"
            case 5:
                city = "Сингапур"
            default:
                city = ""
            }
            return city.isEmpty ? "DC \(resource.datacenterId)" : "DC \(resource.datacenterId) · \(city)"
        }
    }
    return nil
}
