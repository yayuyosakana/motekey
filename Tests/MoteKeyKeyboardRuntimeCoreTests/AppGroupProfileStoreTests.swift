import XCTest
import MoteKeyShared
@testable import MoteKeyKeyboardRuntimeCore

final class AppGroupProfileStoreTests: XCTestCase {
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "test.keyboard.appgroup.\(UUID().uuidString)"
    }

    override func tearDown() {
        UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
        suiteName = nil
        super.tearDown()
    }

    func testLoadTextStyleProfileFromSharedSchema() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        let sharedProfile = MoteKeyShared.TextStyleProfile(
            tone_profile: .init(
                summary: "丁寧で共感的",
                rules: ["先に感情へ共感"],
                details: .init(
                    ending_patterns: "〜だよ、〜ね",
                    emoji_usage: "控えめ",
                    empathy_style: "高め",
                    suggestion_style: "一案のみ",
                    message_length: "中",
                    colloquial_style: "自然"
                )
            )
        )
        defaults.set(try JSONEncoder().encode(sharedProfile), forKey: AppGroupKeys.textStyleProfileData)

        let profileStore = AppGroupProfileStore(suiteName: suiteName)
        let loaded = profileStore.loadTextStyleProfile()

        XCTAssertEqual(loaded.tone, "丁寧で共感的")
        XCTAssertEqual(loaded.endingStyle, "〜だよ、〜ね")
        XCTAssertEqual(loaded.emojiStyle, "控えめ")
    }

    func testLoadRelationProfileFromSharedSchema() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        let shared = MoteKeyShared.RelationProfile(
            nickname: "はる",
            relationshipType: "妻",
            datingStartDate: nil,
            marriageDate: nil,
            birthdayMonth: nil,
            birthdayDay: nil,
            cautionNote: "平日は短文になりすぎない"
        )
        defaults.set(try JSONEncoder().encode(shared), forKey: AppGroupKeys.relationProfileData)

        let profileStore = AppGroupProfileStore(suiteName: suiteName)
        let loaded = profileStore.loadRelationProfile()

        XCTAssertEqual(loaded.partnerName, "はる")
        XCTAssertEqual(loaded.relationshipSummary, "妻")
        XCTAssertEqual(loaded.cautionNotes, "平日は短文になりすぎない")
    }

    func testLoadRelationProfileSanitizesGenericNickname() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        let shared = MoteKeyShared.RelationProfile(
            nickname: "パートナー",
            relationshipType: "girlfriend",
            datingStartDate: nil,
            marriageDate: nil,
            birthdayMonth: nil,
            birthdayDay: nil,
            cautionNote: ""
        )
        defaults.set(try JSONEncoder().encode(shared), forKey: AppGroupKeys.relationProfileData)

        let profileStore = AppGroupProfileStore(suiteName: suiteName)
        let loaded = profileStore.loadRelationProfile()

        XCTAssertEqual(loaded.partnerName, "")
    }

    func testPermissionCheckerUsesSharedKeys() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.set(false, forKey: AppGroupKeys.permissionFullAccessGranted)
        defaults.set(true, forKey: AppGroupKeys.permissionScreenRecordingGranted)

        let checker = AppGroupPermissionChecker(suiteName: suiteName)
        XCTAssertEqual(checker.currentPermissionIssue(), .fullAccessDenied)

        defaults.set(true, forKey: AppGroupKeys.permissionFullAccessGranted)
        defaults.set(false, forKey: AppGroupKeys.permissionScreenRecordingGranted)
        XCTAssertEqual(checker.currentPermissionIssue(), .none)
    }
}
