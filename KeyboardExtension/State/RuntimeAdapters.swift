import Foundation
import MoteKeyShared
#if canImport(UIKit)
import UIKit
#endif

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
    let pasteboardName: String?
    let pasteboardType: String?

    init(
        frameURL: URL,
        pasteboardName: String? = nil,
        pasteboardType: String? = nil
    ) {
        self.frameURL = frameURL
        self.pasteboardName = pasteboardName
        self.pasteboardType = pasteboardType
    }

    func loadLatestFrameData() throws -> Data {
        if let frameData = try? Data(contentsOf: frameURL), !frameData.isEmpty {
            return frameData
        }

#if canImport(UIKit)
        if let pasteboardName,
           let pasteboardType,
           let pasteboard = UIPasteboard(name: .init(pasteboardName), create: false),
           let pasteboardData = pasteboard.data(forPasteboardType: pasteboardType),
           !pasteboardData.isEmpty {
            return pasteboardData
        }
#endif

        return try Data(contentsOf: frameURL)
    }

    func hasRecentFrame(maxAge: TimeInterval) -> Bool {
        guard maxAge > 0 else { return false }

        if let attributes = try? FileManager.default.attributesOfItem(atPath: frameURL.path),
           let modifiedAt = attributes[.modificationDate] as? Date,
           Date().timeIntervalSince(modifiedAt) <= maxAge {
            return true
        }

#if canImport(UIKit)
        if let pasteboardName,
           let pasteboardType,
           let pasteboard = UIPasteboard(name: .init(pasteboardName), create: false),
           let pasteboardData = pasteboard.data(forPasteboardType: pasteboardType),
           !pasteboardData.isEmpty {
            return true
        }
#endif

        return false
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

    func hasRecentFrame(maxAge: TimeInterval) -> Bool {
        !frameData.isEmpty
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
    private let fullAccessProvider: (() -> Bool)?

    init(
        suiteName: String,
        fullAccessProvider: (() -> Bool)? = nil
    ) {
        self.defaults = UserDefaults(suiteName: suiteName) ?? .standard
        self.fullAccessProvider = fullAccessProvider
    }

    func currentPermissionIssue() -> PermissionIssue {
        let hasFullAccess = fullAccessProvider?()
            ?? (defaults.object(forKey: AppGroupKeys.permissionFullAccessGranted) as? Bool ?? true)

        if !hasFullAccess {
            return .fullAccessDenied
        }
        // 画面収録は mote+AI 押下で開始トリガーをかけるため、
        // 事前フラグだけでブロックせず実フレーム取得結果で扱う。
        return .none
    }
}
