import XCTest
@testable import MoteKeyConfig

final class APIConfigTests: XCTestCase {
    func testDedicatedEnvironmentKeyIsUsedForCallType() {
        let key = APIConfig.geminiAPIKey(
            for: .visionChatContextExtraction,
            bundle: .main,
            environment: [
                "GEMINI_API_KEY_VISION_CONTEXT": "vision-test-key",
                "GEMINI_API_KEY": "legacy-key"
            ]
        )

        XCTAssertEqual(key, "vision-test-key")
    }

    func testLegacyEnvironmentKeyIsFallbackWhenDedicatedMissing() {
        let key = APIConfig.geminiAPIKey(
            for: .replyGeneration,
            bundle: .main,
            environment: [
                "GEMINI_API_KEY": "legacy-fallback-key"
            ]
        )

        XCTAssertEqual(key, "legacy-fallback-key")
    }

    func testWhitespaceOnlyDedicatedEnvironmentKeyIsIgnored() {
        let key = APIConfig.geminiAPIKey(
            for: .textHabitAnalysis,
            bundle: .main,
            environment: [
                "GEMINI_API_KEY_TEXT_HABIT": "   ",
                "GEMINI_API_KEY": "legacy-fallback-key"
            ]
        )

        XCTAssertEqual(key, "legacy-fallback-key")
    }

    func testDedicatedEnvironmentKeyIsTrimmed() {
        let key = APIConfig.geminiAPIKey(
            for: .askUserQuestionGeneration,
            bundle: .main,
            environment: [
                "GEMINI_API_KEY_ASK_USER_QUESTION": "  ask-user-key  "
            ]
        )

        XCTAssertEqual(key, "ask-user-key")
    }

    func testHasDedicatedGeminiAPIKeyChecksOnlyRequestedCallType() {
        let environment = [
            "GEMINI_API_KEY_VISION_CONTEXT": "vision-key"
        ]

        XCTAssertTrue(
            APIConfig.hasDedicatedGeminiAPIKey(
                for: .visionChatContextExtraction,
                bundle: .main,
                environment: environment
            )
        )
        XCTAssertFalse(
            APIConfig.hasDedicatedGeminiAPIKey(
                for: .replyGeneration,
                bundle: .main,
                environment: environment
            )
        )
    }

    func testMissingDedicatedGeminiCallTypesReturnsUnconfiguredTypes() {
        let environment = [
            "GEMINI_API_KEY_TEXT_HABIT": "a",
            "GEMINI_API_KEY_VISION_CONTEXT": "b"
        ]

        let missing = Set(
            APIConfig.missingDedicatedGeminiCallTypes(
                bundle: .main,
                environment: environment
            )
        )

        XCTAssertEqual(
            missing,
            Set([.askUserQuestionGeneration, .replyGeneration])
        )
    }

    func testGeminiEndpointForCallType() {
        XCTAssertEqual(
            APIConfig.geminiEndpoint(for: .visionChatContextExtraction),
            APIConfig.geminiVisionEndpoint
        )
        XCTAssertEqual(
            APIConfig.geminiEndpoint(for: .replyGeneration),
            APIConfig.geminiTextEndpoint
        )
    }
}
