import Foundation

struct ToneProfileDetails: Codable, Equatable, Sendable {
    let ending_patterns: String
    let emoji_usage: String
    let empathy_style: String
    let suggestion_style: String
    let message_length: String
    let colloquial_style: String
}

struct ToneProfile: Codable, Equatable, Sendable {
    let summary: String
    let rules: [String]
    let details: ToneProfileDetails
}

struct TextStyleProfile: Codable, Equatable, Sendable {
    let tone_profile: ToneProfile

    var summary: String {
        tone_profile.summary
    }
}
