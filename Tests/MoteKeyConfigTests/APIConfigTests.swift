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
}
