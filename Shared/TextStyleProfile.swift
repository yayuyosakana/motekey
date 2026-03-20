import Foundation

public struct ToneProfileDetails: Codable, Equatable, Sendable {
    public let ending_patterns: String
    public let emoji_usage: String
    public let empathy_style: String
    public let suggestion_style: String
    public let message_length: String
    public let colloquial_style: String

    public init(
        ending_patterns: String,
        emoji_usage: String,
        empathy_style: String,
        suggestion_style: String,
        message_length: String,
        colloquial_style: String
    ) {
        self.ending_patterns = ending_patterns
        self.emoji_usage = emoji_usage
        self.empathy_style = empathy_style
        self.suggestion_style = suggestion_style
        self.message_length = message_length
        self.colloquial_style = colloquial_style
    }
}

public struct ToneProfile: Codable, Equatable, Sendable {
    public let summary: String
    public let rules: [String]
    public let details: ToneProfileDetails

    public init(summary: String, rules: [String], details: ToneProfileDetails) {
        self.summary = summary
        self.rules = rules
        self.details = details
    }
}

public struct TextStyleProfile: Codable, Equatable, Sendable {
    public let tone_profile: ToneProfile

    public init(tone_profile: ToneProfile) {
        self.tone_profile = tone_profile
    }

    public var summary: String {
        tone_profile.summary
    }
}
