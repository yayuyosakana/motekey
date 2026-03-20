import XCTest
@testable import MoteKeyShared

final class GeminiSchemasTests: XCTestCase {
    func testAskUserQuestionsPayloadValidationForMVP() {
        let payload = AskUserQuestionsPayload(
            questions: [
                .init(question: "Q1", options: [.init(label: "A", value: "a"), .init(label: "B", value: "b"), .init(label: "C", value: "c")]),
                .init(question: "Q2", options: [.init(label: "A", value: "a"), .init(label: "B", value: "b"), .init(label: "C", value: "c")]),
                .init(question: "Q3", options: [.init(label: "A", value: "a"), .init(label: "B", value: "b"), .init(label: "C", value: "c")])
            ]
        )

        XCTAssertTrue(payload.isValidForMVP)
    }

    func testAskUserQuestionsPayloadValidationFailsWhenQuestionCountIsInvalid() {
        let payload = AskUserQuestionsPayload(
            questions: [
                .init(question: "Q1", options: [.init(label: "A", value: "a"), .init(label: "B", value: "b"), .init(label: "C", value: "c")]),
                .init(question: "Q2", options: [.init(label: "A", value: "a"), .init(label: "B", value: "b"), .init(label: "C", value: "c")])
            ]
        )

        XCTAssertFalse(payload.isValidForMVP)
    }

    func testReplyCandidatesPayloadValidationForMVP() {
        let payload = ReplyCandidatesPayload(
            chips: [
                .init(text: "了解、今日帰りに買ってくるね"),
                .init(text: "他に必要なものある？")
            ]
        )

        XCTAssertTrue(payload.isValidForMVP)
    }

    func testReplyCandidatesPayloadValidationFailsWhenChipIsBlank() {
        let payload = ReplyCandidatesPayload(
            chips: [
                .init(text: "  "),
                .init(text: "次の提案")
            ]
        )

        XCTAssertFalse(payload.isValidForMVP)
    }

    func testChatContextPayloadRoundTrip() throws {
        let original = ChatContextPayload(
            chat_detected: true,
            app: "LINE",
            messages: [
                .init(speaker: .partner, text: "今日どうする？", date_label: "今日", time: "18:10"),
                .init(speaker: .me, text: "20時なら行けるよ", date_label: "今日", time: "18:11")
            ],
            last_speaker: .me,
            last_message: "20時なら行けるよ"
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ChatContextPayload.self, from: encoded)

        XCTAssertEqual(decoded, original)
    }

    func testSchemaConstraintsMatchMVPDecisions() {
        XCTAssertEqual(GeminiSchemaConstraints.askUserQuestionCount, 3)
        XCTAssertEqual(GeminiSchemaConstraints.askUserOptionCount, 3)
        XCTAssertEqual(GeminiSchemaConstraints.replyChipCountRange, 2...5)
    }
}
