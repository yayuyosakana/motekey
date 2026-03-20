import Foundation

struct AppGroupKeys {
    static let suiteName = "group.com.motekey.shared"

    static let textStyleRegistered = "textStyleRegistered"
    static let textStyleSummary = "textStyleSummary"
    static let relationRegistered = "relationRegistered"
    static let relationProfile = "relationProfile"
    static let setupConfigured = "setupConfigured"
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
    }

    func loadTextStyleSummary() -> String {
        defaults?.string(forKey: AppGroupKeys.textStyleSummary) ?? ""
    }

    func isTextStyleRegistered() -> Bool {
        defaults?.bool(forKey: AppGroupKeys.textStyleRegistered) ?? false
    }

    func saveRelation(_ relation: RelationProfile) {
        defaults?.set(true, forKey: AppGroupKeys.relationRegistered)
        if let data = try? encoder.encode(relation) {
            defaults?.set(data, forKey: AppGroupKeys.relationProfile)
        }
    }

    func loadRelation() -> RelationProfile? {
        guard let data = defaults?.data(forKey: AppGroupKeys.relationProfile) else {
            return nil
        }
        return try? decoder.decode(RelationProfile.self, from: data)
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
}
