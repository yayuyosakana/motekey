import XCTest
@testable import MoteKeyKeyboardRuntimeCore

final class GeminiPromptFactoryTests: XCTestCase {
    func testReplyPromptIncludesNicknameRuleAndRelationPayload() {
        let prompt = GeminiPromptFactory.replyPrompt(
            chatContext: "{\"chat_detected\":true,\"messages\":[{\"speaker\":\"partner\",\"text\":\"今日どうする？\"}],\"last_speaker\":\"partner\",\"last_message\":\"今日どうする？\"}",
            answers: [0: "can_handle_now", 1: "by_end_of_today", 2: "propose_alternative"],
            textStyleProfile: TextStyleProfile(tone: "friendly", endingStyle: "casual", emojiStyle: "light"),
            relationProfile: RelationProfile(
                partnerName: "ゆい",
                relationshipSummary: "girlfriend",
                cautionNotes: "返信が遅いと不安になりやすい"
            ),
            todayDate: "2026-03-22"
        )

        XCTAssertTrue(prompt.contains("relation.nickname"))
        XCTAssertTrue(prompt.contains("少なくとも1件で自然に呼びかける"))
        XCTAssertTrue(prompt.contains("ゆい"))
        XCTAssertTrue(prompt.contains("\"cautionNote\""))
    }

    func testReplyPromptContainsVariationAndAntiTemplateGuidance() {
        let prompt = GeminiPromptFactory.replyPrompt(
            chatContext: "{\"chat_detected\":true,\"messages\":[],\"last_speaker\":\"partner\",\"last_message\":\"\"}",
            answers: [:],
            textStyleProfile: TextStyleProfile(tone: "neutral", endingStyle: "casual", emojiStyle: "minimal"),
            relationProfile: RelationProfile(partnerName: "パートナー", relationshipSummary: "", cautionNotes: ""),
            todayDate: "2026-03-22"
        )

        XCTAssertTrue(prompt.contains("毎回同じ定型にしない"))
        XCTAssertTrue(prompt.contains("思考放棄"))
        XCTAssertTrue(prompt.contains("JSONのみ"))
    }
}
