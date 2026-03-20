import Foundation

public struct RelationProfile: Codable, Equatable, Sendable {
    public let nickname: String
    public let relationshipType: String
    public let datingStartDate: Date?
    public let marriageDate: Date?
    public let birthdayMonth: Int?
    public let birthdayDay: Int?
    public let cautionNote: String

    public init(
        nickname: String,
        relationshipType: String,
        datingStartDate: Date?,
        marriageDate: Date?,
        birthdayMonth: Int?,
        birthdayDay: Int?,
        cautionNote: String
    ) {
        self.nickname = nickname
        self.relationshipType = relationshipType
        self.datingStartDate = datingStartDate
        self.marriageDate = marriageDate
        self.birthdayMonth = birthdayMonth
        self.birthdayDay = birthdayDay
        self.cautionNote = cautionNote
    }
}
