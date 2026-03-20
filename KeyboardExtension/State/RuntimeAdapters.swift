import Foundation
import MoteKeyShared

private enum LegacyProfileKeys {
    static let tone = "textHabit.tone"
    static let endingStyle = "textHabit.endingStyle"
    static let emojiStyle = "textHabit.emojiStyle"
    static let partnerName = "relation.partnerName"
    static let relationSummary = "relation.summary"
    static let cautionNotes = "relation.cautionNotes"
}

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
        if let data = defaults.data(forKey: AppGroupKeys.textStyleProfileData),
           let sharedProfile = try? JSONDecoder().decode(MoteKeyShared.TextStyleProfile.self, from: data) {
            let details = sharedProfile.tone_profile.details
            let tone = nonEmpty(sharedProfile.tone_profile.summary, fallback: "neutral")
            let endingStyle = nonEmpty(details.ending_patterns, fallback: "casual")
            let emojiStyle = nonEmpty(details.emoji_usage, fallback: "minimal")
            return TextStyleProfile(tone: tone, endingStyle: endingStyle, emojiStyle: emojiStyle)
        }

        let tone = defaults.string(forKey: LegacyProfileKeys.tone)
            ?? defaults.string(forKey: AppGroupKeys.textStyleSummary)
            ?? "neutral"
        let endingStyle = defaults.string(forKey: LegacyProfileKeys.endingStyle) ?? "casual"
        let emojiStyle = defaults.string(forKey: LegacyProfileKeys.emojiStyle) ?? "minimal"
        return TextStyleProfile(tone: tone, endingStyle: endingStyle, emojiStyle: emojiStyle)
    }

    func loadRelationProfile() -> RelationProfile {
        if let data = defaults.data(forKey: AppGroupKeys.relationProfileData),
           let sharedProfile = try? JSONDecoder().decode(MoteKeyShared.RelationProfile.self, from: data) {
            return RelationProfile(
                partnerName: nonEmpty(sharedProfile.nickname, fallback: "パートナー"),
                relationshipSummary: sharedProfile.relationshipType,
                cautionNotes: sharedProfile.cautionNote
            )
        }

        let partnerName = defaults.string(forKey: LegacyProfileKeys.partnerName) ?? "パートナー"
        let relationshipSummary = defaults.string(forKey: LegacyProfileKeys.relationSummary) ?? ""
        let cautionNotes = defaults.string(forKey: LegacyProfileKeys.cautionNotes) ?? ""
        return RelationProfile(
            partnerName: partnerName,
            relationshipSummary: relationshipSummary,
            cautionNotes: cautionNotes
        )
    }

    private func nonEmpty(_ value: String, fallback: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
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
        let hasFullAccess = defaults.object(forKey: AppGroupKeys.permissionFullAccessGranted) as? Bool ?? true
        let hasScreenRecording = defaults.object(forKey: AppGroupKeys.permissionScreenRecordingGranted) as? Bool ?? true

        if !hasFullAccess {
            return .fullAccessDenied
        }
        if !hasScreenRecording {
            return .screenRecordingDenied
        }
        return .none
    }
}
