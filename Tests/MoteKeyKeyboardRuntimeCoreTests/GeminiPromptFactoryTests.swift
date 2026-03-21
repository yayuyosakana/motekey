import XCTest
@testable import MoteKeyKeyboardRuntimeCore

final class GeminiPromptFactoryTests: XCTestCase {
    func testReplyPromptMasksGenericRelationNickname() {
        let prompt = GeminiPromptFactory.replyPrompt(
            chatContext: "{\"chat_detected\":true,\"messages\":[{\"speaker\":\"partner\",\"text\":\"トイレットペーパーなくなりそう\"}],\"last_speaker\":\"partner\",\"last_message\":\"トイレットペーパーなくなりそう\"}",
            answers: [0: "two_or_less", 1: "on_the_way_home", 2: "usual_brand"],
            textStyleProfile: .init(tone: "friendly", endingStyle: "soft", emojiStyle: "minimal"),
            relationProfile: .init(partnerName: "パートナー", relationshipSummary: "girlfriend", cautionNotes: ""),
            todayDate: "2026-03-22"
        )

        XCTAssertTrue(prompt.contains("\"nickname\" : null"))
        XCTAssertTrue(prompt.contains("「パートナー」という語を本文に出す"))
        XCTAssertTrue(prompt.contains("「了解」「OK」「任せる」「どっちでもいい」「の件」"))
    }

    func testReplyPromptKeepsExplicitNickname() {
        let prompt = GeminiPromptFactory.replyPrompt(
            chatContext: "{}",
            answers: [0: "a", 1: "b", 2: "c"],
            textStyleProfile: .init(tone: "friendly", endingStyle: "soft", emojiStyle: "minimal"),
            relationProfile: .init(partnerName: "ゆい", relationshipSummary: "girlfriend", cautionNotes: ""),
            todayDate: "2026-03-22"
        )

        XCTAssertTrue(prompt.contains("\"nickname\" : \"ゆい\""))
    }

    func testAskUserPromptIncludesStrictSchemaRules() {
        let prompt = GeminiPromptFactory.askUserPrompt(
            context: .init(chatContext: "{\"chat_detected\":true,\"messages\":[{\"speaker\":\"partner\",\"text\":\"今夜どうする？\"}],\"last_speaker\":\"partner\",\"last_message\":\"今夜どうする？\"}")
        )

        XCTAssertTrue(prompt.contains("`questions` は必ず3件"))
        XCTAssertTrue(prompt.contains("各 `options` は必ず3件"))
        XCTAssertTrue(prompt.contains("`options[].value` は英語スネークケース"))
    }

    func testReplyPromptContainsVariationAndAntiTemplateGuidance() {
        let prompt = GeminiPromptFactory.replyPrompt(
            chatContext: "{\"chat_detected\":true,\"messages\":[],\"last_speaker\":\"partner\",\"last_message\":\"\"}",
            answers: [:],
            textStyleProfile: .init(tone: "neutral", endingStyle: "casual", emojiStyle: "minimal"),
            relationProfile: .init(partnerName: "", relationshipSummary: "", cautionNotes: ""),
            todayDate: "2026-03-22"
        )

        XCTAssertTrue(prompt.contains("毎回同じ定型にしない"))
        XCTAssertTrue(prompt.contains("思考放棄"))
        XCTAssertTrue(prompt.contains("出力は JSON のみ"))
    }
}
