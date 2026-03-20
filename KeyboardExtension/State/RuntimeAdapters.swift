import Foundation

struct FileLatestFrameLoader: LatestFrameLoading {
    let frameURL: URL

    func loadLatestFrameData() throws -> Data {
        try Data(contentsOf: frameURL)
    }
}

struct InMemoryProfileStore: ProfileStore {
    let textStyleProfile: TextStyleProfile
    let relationProfile: RelationProfile

    func loadTextStyleProfile() -> TextStyleProfile {
        textStyleProfile
    }

    func loadRelationProfile() -> RelationProfile {
        relationProfile
    }
}

final class TextDocumentComposeProxy: ComposeTextProxy {
    private let insertHandler: (String) -> Void

    init(insertHandler: @escaping (String) -> Void) {
        self.insertHandler = insertHandler
    }

    func insertText(_ text: String) {
        insertHandler(text)
    }
}

struct AppGroupProfileStore: ProfileStore {
    private let defaults: UserDefaults

    init(suiteName: String) {
        self.defaults = UserDefaults(suiteName: suiteName) ?? .standard
    }

    func loadTextStyleProfile() -> TextStyleProfile {
        let tone = defaults.string(forKey: "textHabit.tone") ?? "neutral"
        let endingStyle = defaults.string(forKey: "textHabit.endingStyle") ?? "casual"
        let emojiStyle = defaults.string(forKey: "textHabit.emojiStyle") ?? "minimal"
        return TextStyleProfile(tone: tone, endingStyle: endingStyle, emojiStyle: emojiStyle)
    }

    func loadRelationProfile() -> RelationProfile {
        let partnerName = defaults.string(forKey: "relation.partnerName") ?? "パートナー"
        let relationshipSummary = defaults.string(forKey: "relation.summary") ?? ""
        let cautionNotes = defaults.string(forKey: "relation.cautionNotes") ?? ""
        return RelationProfile(
            partnerName: partnerName,
            relationshipSummary: relationshipSummary,
            cautionNotes: cautionNotes
        )
    }
}
