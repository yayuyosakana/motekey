import Foundation

struct FileLatestFrameLoader: LatestFrameLoading {
    let frameURL: URL

    func loadLatestFrameData() throws -> Data {
        try Data(contentsOf: frameURL)
    }
}

struct InMemoryFrameLoader: LatestFrameLoading {
    let frameData: Data

    init(frameData: Data = Data([0xFF, 0xD8, 0xFF, 0xD9])) {
        self.frameData = frameData
    }

    func loadLatestFrameData() throws -> Data {
        frameData
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
    private let clearMarkedTextHandler: () -> Void
    private let insertHandler: (String) -> Void

    init(
        clearMarkedTextHandler: @escaping () -> Void = {},
        insertHandler: @escaping (String) -> Void
    ) {
        self.clearMarkedTextHandler = clearMarkedTextHandler
        self.insertHandler = insertHandler
    }

    func clearMarkedText() {
        clearMarkedTextHandler()
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

struct StaticPermissionChecker: PermissionChecking {
    let issue: PermissionIssue

    init(issue: PermissionIssue = .none) {
        self.issue = issue
    }

    func currentPermissionIssue() -> PermissionIssue {
        issue
    }
}

struct AppGroupPermissionChecker: PermissionChecking {
    private let defaults: UserDefaults

    init(suiteName: String) {
        self.defaults = UserDefaults(suiteName: suiteName) ?? .standard
    }

    func currentPermissionIssue() -> PermissionIssue {
        let hasFullAccess = defaults.object(forKey: "permission.fullAccessGranted") as? Bool ?? true
        let hasScreenRecording = defaults.object(forKey: "permission.screenRecordingGranted") as? Bool ?? true

        if !hasFullAccess {
            return .fullAccessDenied
        }
        if !hasScreenRecording {
            return .screenRecordingDenied
        }
        return .none
    }
}
