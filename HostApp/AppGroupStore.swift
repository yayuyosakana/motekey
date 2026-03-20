import Foundation
import MoteKeyShared

private enum LegacyAppGroupKeys {
    static let relationProfile = "relationProfile"
}

private enum RuntimeCompatibilityKeys {
    static let textHabitTone = "textHabit.tone"
    static let textHabitEndingStyle = "textHabit.endingStyle"
    static let textHabitEmojiStyle = "textHabit.emojiStyle"
    static let relationPartnerName = "relation.partnerName"
    static let relationSummary = "relation.summary"
    static let relationCautionNotes = "relation.cautionNotes"
}

struct TextStyleProfile: Codable, Equatable {
    struct ToneProfileDetails: Codable, Equatable {
        let endingPatterns: String
        let emojiUsage: String
        let empathyStyle: String
        let suggestionStyle: String
        let messageLength: String
        let colloquialStyle: String

        enum CodingKeys: String, CodingKey {
            case endingPatterns = "ending_patterns"
            case emojiUsage = "emoji_usage"
            case empathyStyle = "empathy_style"
            case suggestionStyle = "suggestion_style"
            case messageLength = "message_length"
            case colloquialStyle = "colloquial_style"
        }
    }

    struct ToneProfile: Codable, Equatable {
        let summary: String
        let rules: [String]
        let details: ToneProfileDetails
    }

    let toneProfile: ToneProfile
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case toneProfile = "tone_profile"
        case updatedAt
    }

    var summary: String { toneProfile.summary }
    var runtimeTone: String { toneProfile.summary }
    var runtimeEndingStyle: String { toneProfile.details.endingPatterns }
    var runtimeEmojiStyle: String { toneProfile.details.emojiUsage }

    static func fallback(summary: String, updatedAt: Date = Date()) -> TextStyleProfile {
        TextStyleProfile(
            toneProfile: .init(
                summary: summary,
                rules: [],
                details: .init(
                    endingPatterns: summary,
                    emojiUsage: summary,
                    empathyStyle: "",
                    suggestionStyle: "",
                    messageLength: "",
                    colloquialStyle: ""
                )
            ),
            updatedAt: updatedAt
        )
    }
}

struct MonthDay: Codable, Equatable {
    let month: Int
    let day: Int
}

enum RelationshipType: String, Codable, CaseIterable, Identifiable {
    case girlfriend = "彼女"
    case fiance = "婚約者"
    case wife = "妻"
    case other = "その他"
    case unknown = "不明"

    var id: String { rawValue }

    var requiresMarriageDate: Bool {
        self == .wife || self == .fiance
    }

    /// API/保存スキーマ向けの安定識別子
    var schemaValue: String {
        switch self {
        case .girlfriend: return "girlfriend"
        case .fiance: return "fiance"
        case .wife: return "wife"
        case .other: return "other"
        case .unknown: return "unknown"
        }
    }

    init(schemaOrRawValue: String) {
        switch schemaOrRawValue {
        case "girlfriend", Self.girlfriend.rawValue:
            self = .girlfriend
        case "fiance", Self.fiance.rawValue:
            self = .fiance
        case "wife", Self.wife.rawValue:
            self = .wife
        case "other", Self.other.rawValue:
            self = .other
        case "unknown", Self.unknown.rawValue:
            self = .unknown
        default:
            self = .unknown
        }
    }
}

struct RelationProfile: Codable, Equatable {
    let partnerNickname: String
    let relationshipType: RelationshipType
    let datingStartDate: Date?
    let marriageDate: Date?
    let partnerBirthday: MonthDay?
    let cautionNote: String
    let updatedAt: Date
}

struct AppGroupStore {
    private struct RelationProfileDataPayload: Codable {
        let nickname: String
        let relationshipType: String
        let datingStartDate: Date?
        let marriageDate: Date?
        let birthdayMonth: Int?
        let birthdayDay: Int?
        let cautionNote: String
        let updatedAt: Date
    }

    private let defaults: UserDefaults?
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(suiteName: String = AppGroupKeys.suiteName) {
        self.defaults = UserDefaults(suiteName: suiteName)
    }

    func saveTextStyle(_ profile: TextStyleProfile) {
        defaults?.set(true, forKey: AppGroupKeys.textStyleRegistered)
        defaults?.set(profile.summary, forKey: AppGroupKeys.textStyleSummary)

        if let data = try? encoder.encode(makeSharedTextStyleProfile(from: profile)) {
            defaults?.set(data, forKey: AppGroupKeys.textStyleProfileData)
        }

        defaults?.set(profile.runtimeTone, forKey: RuntimeCompatibilityKeys.textHabitTone)
        defaults?.set(profile.runtimeEndingStyle, forKey: RuntimeCompatibilityKeys.textHabitEndingStyle)
        defaults?.set(profile.runtimeEmojiStyle, forKey: RuntimeCompatibilityKeys.textHabitEmojiStyle)
    }

    func loadTextStyleSummary() -> String {
        if let summary = defaults?.string(forKey: AppGroupKeys.textStyleSummary), !summary.isEmpty {
            return summary
        }
        return loadTextStyleProfile()?.summary ?? ""
    }

    func isTextStyleRegistered() -> Bool {
        defaults?.bool(forKey: AppGroupKeys.textStyleRegistered) ?? false
    }

    func loadTextStyleProfile() -> TextStyleProfile? {
        guard let data = defaults?.data(forKey: AppGroupKeys.textStyleProfileData) else {
            return nil
        }

        if let profile = try? decoder.decode(TextStyleProfile.self, from: data) {
            return profile
        }

        if let shared = try? decoder.decode(MoteKeyShared.TextStyleProfile.self, from: data) {
            return makeHostTextStyleProfile(from: shared)
        }

        return nil
    }

    func saveRelation(_ relation: RelationProfile) {
        defaults?.set(true, forKey: AppGroupKeys.relationRegistered)

        if let data = try? encoder.encode(makeSharedRelationProfile(from: relation)) {
            defaults?.set(data, forKey: AppGroupKeys.relationProfileData)
        }

        if let legacyData = try? encoder.encode(relation) {
            defaults?.set(legacyData, forKey: LegacyAppGroupKeys.relationProfile)
        }

        defaults?.set(relation.partnerNickname, forKey: RuntimeCompatibilityKeys.relationPartnerName)
        defaults?.set(relation.relationshipType.rawValue, forKey: RuntimeCompatibilityKeys.relationSummary)
        defaults?.set(relation.cautionNote, forKey: RuntimeCompatibilityKeys.relationCautionNotes)
    }

    func loadRelation() -> RelationProfile? {
        if let data = defaults?.data(forKey: AppGroupKeys.relationProfileData) {
            if let shared = try? decoder.decode(MoteKeyShared.RelationProfile.self, from: data) {
                return makeHostRelationProfile(from: shared)
            }

            if let payload = try? decoder.decode(RelationProfileDataPayload.self, from: data) {
                let birthday: MonthDay?
                if let month = payload.birthdayMonth, let day = payload.birthdayDay {
                    birthday = MonthDay(month: month, day: day)
                } else {
                    birthday = nil
                }

                return RelationProfile(
                    partnerNickname: payload.nickname,
                    relationshipType: RelationshipType(schemaOrRawValue: payload.relationshipType),
                    datingStartDate: payload.datingStartDate,
                    marriageDate: payload.marriageDate,
                    partnerBirthday: birthday,
                    cautionNote: payload.cautionNote,
                    updatedAt: payload.updatedAt
                )
            }
        }

        guard let legacyData = defaults?.data(forKey: LegacyAppGroupKeys.relationProfile) else {
            return nil
        }
        return try? decoder.decode(RelationProfile.self, from: legacyData)
    }

    func isRelationRegistered() -> Bool {
        defaults?.bool(forKey: AppGroupKeys.relationRegistered) ?? false
    }

    func saveSetupConfigured(_ isConfigured: Bool) {
        defaults?.set(isConfigured, forKey: AppGroupKeys.setupConfigured)
    }

    func isSetupConfigured() -> Bool {
        defaults?.bool(forKey: AppGroupKeys.setupConfigured) ?? false
    }

    func savePermissionFlags(fullAccessGranted: Bool? = nil, screenRecordingGranted: Bool? = nil) {
        if let fullAccessGranted {
            defaults?.set(fullAccessGranted, forKey: AppGroupKeys.permissionFullAccessGranted)
        }
        if let screenRecordingGranted {
            defaults?.set(screenRecordingGranted, forKey: AppGroupKeys.permissionScreenRecordingGranted)
        }
    }

    func loadPermissionFlags() -> (fullAccessGranted: Bool?, screenRecordingGranted: Bool?) {
        let fullAccessGranted = defaults?.object(forKey: AppGroupKeys.permissionFullAccessGranted) as? Bool
        let screenRecordingGranted = defaults?.object(forKey: AppGroupKeys.permissionScreenRecordingGranted) as? Bool
        return (fullAccessGranted, screenRecordingGranted)
    }

    private func makeSharedTextStyleProfile(from profile: TextStyleProfile) -> MoteKeyShared.TextStyleProfile {
        .init(
            tone_profile: .init(
                summary: profile.toneProfile.summary,
                rules: profile.toneProfile.rules,
                details: .init(
                    ending_patterns: profile.toneProfile.details.endingPatterns,
                    emoji_usage: profile.toneProfile.details.emojiUsage,
                    empathy_style: profile.toneProfile.details.empathyStyle,
                    suggestion_style: profile.toneProfile.details.suggestionStyle,
                    message_length: profile.toneProfile.details.messageLength,
                    colloquial_style: profile.toneProfile.details.colloquialStyle
                )
            )
        )
    }

    private func makeHostTextStyleProfile(from shared: MoteKeyShared.TextStyleProfile) -> TextStyleProfile {
        .init(
            toneProfile: .init(
                summary: shared.tone_profile.summary,
                rules: shared.tone_profile.rules,
                details: .init(
                    endingPatterns: shared.tone_profile.details.ending_patterns,
                    emojiUsage: shared.tone_profile.details.emoji_usage,
                    empathyStyle: shared.tone_profile.details.empathy_style,
                    suggestionStyle: shared.tone_profile.details.suggestion_style,
                    messageLength: shared.tone_profile.details.message_length,
                    colloquialStyle: shared.tone_profile.details.colloquial_style
                )
            ),
            updatedAt: nil
        )
    }

    private func makeSharedRelationProfile(from relation: RelationProfile) -> MoteKeyShared.RelationProfile {
        .init(
            nickname: relation.partnerNickname,
            relationshipType: relation.relationshipType.schemaValue,
            datingStartDate: relation.datingStartDate,
            marriageDate: relation.marriageDate,
            birthdayMonth: relation.partnerBirthday?.month,
            birthdayDay: relation.partnerBirthday?.day,
            cautionNote: relation.cautionNote
        )
    }

    private func makeHostRelationProfile(from shared: MoteKeyShared.RelationProfile) -> RelationProfile {
        let birthday: MonthDay?
        if let month = shared.birthdayMonth, let day = shared.birthdayDay {
            birthday = MonthDay(month: month, day: day)
        } else {
            birthday = nil
        }

        return RelationProfile(
            partnerNickname: shared.nickname,
            relationshipType: RelationshipType(schemaOrRawValue: shared.relationshipType),
            datingStartDate: shared.datingStartDate,
            marriageDate: shared.marriageDate,
            partnerBirthday: birthday,
            cautionNote: shared.cautionNote,
            updatedAt: Date()
        )
    }
}
