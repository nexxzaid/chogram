import Foundation
import Postbox

// Earlier versions of a message edited on the server, oldest first.
public class ChogramEditHistoryAttribute: MessageAttribute {
    public struct Version: Equatable {
        public let text: String
        public let entities: [MessageTextEntity]
        // When this version was written: the previous edit date, or the sending date.
        public let date: Int32

        public init(text: String, entities: [MessageTextEntity], date: Int32) {
            self.text = text
            self.entities = entities
            self.date = date
        }
    }

    public let versions: [Version]

    public init(versions: [Version]) {
        self.versions = versions
    }

    required public init(decoder: PostboxDecoder) {
        let texts = decoder.decodeStringArrayForKey("t")
        let dates = decoder.decodeInt32ArrayForKey("d")
        let entities: [TextEntitiesMessageAttribute] = decoder.decodeObjectArrayWithDecoderForKey("e")
        var versions: [Version] = []
        for i in 0 ..< texts.count {
            if i < dates.count && i < entities.count {
                versions.append(Version(text: texts[i], entities: entities[i].entities, date: dates[i]))
            }
        }
        self.versions = versions
    }

    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeStringArray(self.versions.map { $0.text }, forKey: "t")
        encoder.encodeInt32Array(self.versions.map { $0.date }, forKey: "d")
        encoder.encodeObjectArray(self.versions.map { TextEntitiesMessageAttribute(entities: $0.entities) }, forKey: "e")
    }
}

public extension Message {
    var chogramEditVersions: [ChogramEditHistoryAttribute.Version] {
        return (self.attributes.first(where: { $0 is ChogramEditHistoryAttribute }) as? ChogramEditHistoryAttribute)?.versions ?? []
    }
}
