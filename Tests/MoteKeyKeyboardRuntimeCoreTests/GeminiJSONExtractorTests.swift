import XCTest
@testable import MoteKeyKeyboardRuntimeCore

final class GeminiJSONExtractorTests: XCTestCase {
    func testFirstJSONObjectExtractsPayloadWrappedByText() {
        let input = "prefix\\n{\"ok\":true,\"count\":3}\\nsuffix"

        let json = GeminiJSONExtractor.firstJSONObject(in: input)

        XCTAssertEqual(json, "{\"ok\":true,\"count\":3}")
    }

    func testFirstJSONObjectIgnoresBracesInsideStringLiteral() {
        let input = "note {\"message\":\"brace { inside } text\",\"ok\":true} tail"

        let json = GeminiJSONExtractor.firstJSONObject(in: input)

        XCTAssertEqual(json, "{\"message\":\"brace { inside } text\",\"ok\":true}")
    }

    func testFirstJSONObjectHandlesEscapedQuotesInStringLiteral() {
        let input = "x {\"message\":\"quote \\\"text\\\" and { brace }\",\"ok\":true} y"

        let json = GeminiJSONExtractor.firstJSONObject(in: input)

        XCTAssertEqual(json, "{\"message\":\"quote \\\"text\\\" and { brace }\",\"ok\":true}")
    }

    func testFirstJSONObjectReturnsNilWhenObjectIsNotClosed() {
        let input = "{\"ok\":true"

        XCTAssertNil(GeminiJSONExtractor.firstJSONObject(in: input))
    }
}
