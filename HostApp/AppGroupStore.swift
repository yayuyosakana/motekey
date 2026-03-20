import Foundation
import MoteKeyShared

private enum LegacyAppGroupKeys {
    static let relationProfile = "relationProfile"
}

struct TextStyleProfile: Codable, Equatable {
    let summary: String
    let updatedAt: Date
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
    private let defaults: UserDefaults?
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(suiteName: String = AppGroupKeys.suiteName) {
        self.defaults = UserDefaults(suiteName: suiteName)
    }

    func saveTextStyle(_ profile: TextStyleProfile) {
        defaults?.set(true, forKey: AppGroupKeys.textStyleRegistered)
        defaults?.set(profile.summary, forKey: AppGroupKeys.textStyleSummary)
        if let data = try? encoder.encode(makeSharedTextStyleProfile(summary: profile.summary)) {
            defaults?.set(data, forKey: AppGroupKeys.textStyleProfileData)
        }
    }

    func loadTextStyleSummary() -> String {
        defaults?.string(forKey: AppGroupKeys.textStyleSummary) ?? ""
    }

    func isTextStyleRegistered() -> Bool {
        defaults?.bool(forKey: AppGroupKeys.textStyleRegistered) ?? false
    }

    func saveRelation(_ relation: RelationProfile) {
        defaults?.set(true, forKey: AppGroupKeys.relationRegistered)
        if let data = try? encoder.encode(makeSharedRelationProfile(from: relation)) {
            defaults?.set(data, forKey: AppGroupKeys.relationProfileData)
        }
        if let legacyData = try? encoder.encode(relation) {
            defaults?.set(legacyData, forKey: LegacyAppGroupKeys.relationProfile)
        }
    }

    func loadRelation() -> RelationProfile? {
        if let sharedData = defaults?.data(forKey: AppGroupKeys.relationProfileData),
           let sharedProfile = try? decoder.decode(MoteKeyShared.RelationProfile.self, from: sharedData) {
            return makeHostRelationProfile(from: sharedProfile)
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

    private func makeSharedTextStyleProfile(summary: String) -> MoteKeyShared.TextStyleProfile {
        MoteKeyShared.TextStyleProfile(
            tone_profile: .init(
                summary: summary,
                rules: [],
                details: .init(
                    ending_patterns: "",
                    emoji_usage: "",
                    empathy_style: "",
                    suggestion_style: "",
                    message_length: "",
                    colloquial_style: ""
                )
            )
        )
    }

    private func makeSharedRelationProfile(from relation: RelationProfile) -> MoteKeyShared.RelationProfile {
        MoteKeyShared.RelationProfile(
            nickname: relation.partnerNickname,
            relationshipType: relation.relationshipType.rawValue,
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
            relationshipType: RelationshipType(rawValue: shared.relationshipType) ?? .unknown,
            datingStartDate: shared.datingStartDate,
            marriageDate: shared.marriageDate,
            partnerBirthday: birthday,
            cautionNote: shared.cautionNote,
            updatedAt: Date()
        )
    }
}
