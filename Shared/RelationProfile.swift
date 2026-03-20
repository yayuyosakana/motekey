import Foundation

struct RelationProfile: Codable, Equatable, Sendable {
    let nickname: String
    let relationshipType: String
    let datingStartDate: Date?
    let marriageDate: Date?
    let birthdayMonth: Int?
    let birthdayDay: Int?
    let cautionNote: String
}
