import XCTest
@testable import MoteKeyHostAppCore

final class GeminiTextHabitAnalyzerTests: XCTestCase {
    func testParseProfileResponseTextDecodesJSONWrappedInCodeFence() {
        let response = """
        ```json
        {
          "tone_profile": {
            "summary": "やさしく短め",
            "rules": ["語尾を柔らかくする"],
            "details": {
              "ending_patterns": "〜だよ",
              "emoji_usage": "！を使う",
              "empathy_style": "先に共感する",
              "suggestion_style": "提案は控えめ",
              "message_length": "短文中心",
              "colloquial_style": "口語寄り"
            }
          }
        }
        ```
        """

        let profile = GeminiTextHabitAnalyzer.parseProfileResponseText(response)

        XCTAssertEqual(profile?.summary, "やさしく短め")
        XCTAssertEqual(profile?.toneProfile.details.emojiUsage, "！を使う")
    }

    func testParseProfileResponseTextFallsBackToToneProfileSummaryWhenSchemaIsPartial() {
        let response = """
        {
          "tone_profile": {
            "summary": "フランクで前向き"
          }
        }
        """

        let profile = GeminiTextHabitAnalyzer.parseProfileResponseText(response)

        XCTAssertEqual(profile?.summary, "フランクで前向き")
    }

    func testParseProfileResponseTextReturnsNilForJSONObjectWithoutAnySummary() {
        let response = """
        {
          "tone_profile": {
            "rules": ["a"]
          }
        }
        """

        XCTAssertNil(GeminiTextHabitAnalyzer.parseProfileResponseText(response))
    }

    func testFirstJSONObjectStringIgnoresBracesInsideStringLiteral() {
        let response = #"前置き {"tone_profile":{"summary":"中括弧 { } と \"quote\" を含む"}} 後続 {"ignored":true}"#

        let extracted = GeminiTextHabitAnalyzer.firstJSONObjectString(in: response)

        XCTAssertEqual(
            extracted,
            #"{"tone_profile":{"summary":"中括弧 { } と \"quote\" を含む"}}"#
        )
    }
}
