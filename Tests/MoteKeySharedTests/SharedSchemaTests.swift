import XCTest
@testable import MoteKeyShared

final class SharedSchemaTests: XCTestCase {
    func testAppGroupConstantsMatchSpec() {
        XCTAssertEqual(AppGroupKeys.suiteName, "group.com.motekey.shared")
        XCTAssertEqual(AppGroupKeys.latestFrameFileName, "latest_frame.jpg")
        XCTAssertEqual(AppGroupKeys.latestFramePasteboardName, "com.motekey.latest-frame")
        XCTAssertEqual(AppGroupKeys.latestFramePasteboardType, "com.motekey.latest-frame-jpeg")
        XCTAssertEqual(AppGroupKeys.textStyleProfileData, "textStyleProfileData")
        XCTAssertEqual(AppGroupKeys.relationProfileData, "relationProfileData")
    }

    func testTextStyleProfileRoundTrip() throws {
        let original = TextStyleProfile(
            tone_profile: ToneProfile(
                summary: "やさしく具体的に返す",
                rules: ["相手の感情に先に触れる", "提案は1つずつ"],
                details: ToneProfileDetails(
                    ending_patterns: "〜だよ、〜ね",
                    emoji_usage: "控えめ",
                    empathy_style: "先に共感",
                    suggestion_style: "押しつけない提案",
                    message_length: "中程度",
                    colloquial_style: "自然な口語"
                )
            )
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TextStyleProfile.self, from: encoded)

        XCTAssertEqual(decoded, original)
        XCTAssertEqual(decoded.summary, "やさしく具体的に返す")
    }

    func testRelationProfileRoundTrip() throws {
        let original = RelationProfile(
            nickname: "ゆい",
            relationshipType: "girlfriend",
            datingStartDate: Date(timeIntervalSince1970: 1_700_000_000),
            marriageDate: nil,
            birthdayMonth: 5,
            birthdayDay: 14,
            cautionNote: "返信は短すぎないように"
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(RelationProfile.self, from: encoded)

        XCTAssertEqual(decoded, original)
    }
}
