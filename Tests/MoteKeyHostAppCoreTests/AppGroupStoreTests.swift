import XCTest
import MoteKeyShared
@testable import MoteKeyHostAppCore

final class AppGroupStoreTests: XCTestCase {
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "test.host.appgroup.\(UUID().uuidString)"
    }

    override func tearDown() {
        UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
        suiteName = nil
        super.tearDown()
    }

    func testSaveTextStyleWritesSharedSchemaData() throws {
        let store = AppGroupStore(suiteName: suiteName)
        store.saveTextStyle(.init(summary: "やさしく短め", updatedAt: Date(timeIntervalSince1970: 1_700_000_000)))

        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        let profileData = try XCTUnwrap(defaults.data(forKey: AppGroupKeys.textStyleProfileData))
        let decoded = try JSONDecoder().decode(MoteKeyShared.TextStyleProfile.self, from: profileData)

        XCTAssertEqual(decoded.summary, "やさしく短め")
        XCTAssertEqual(defaults.string(forKey: AppGroupKeys.textStyleSummary), "やさしく短め")
        XCTAssertTrue(defaults.bool(forKey: AppGroupKeys.textStyleRegistered))
    }

    func testLoadRelationReadsSharedSchemaData() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        let store = AppGroupStore(suiteName: suiteName)

        let shared = MoteKeyShared.RelationProfile(
            nickname: "ゆい",
            relationshipType: "彼女",
            datingStartDate: Date(timeIntervalSince1970: 1_680_000_000),
            marriageDate: nil,
            birthdayMonth: 5,
            birthdayDay: 14,
            cautionNote: "返信が遅いと不安になりやすい"
        )
        defaults.set(try JSONEncoder().encode(shared), forKey: AppGroupKeys.relationProfileData)

        let loaded = try XCTUnwrap(store.loadRelation())

        XCTAssertEqual(loaded.partnerNickname, "ゆい")
        XCTAssertEqual(loaded.relationshipType, .girlfriend)
        XCTAssertEqual(loaded.partnerBirthday?.month, 5)
        XCTAssertEqual(loaded.partnerBirthday?.day, 14)
        XCTAssertEqual(loaded.cautionNote, "返信が遅いと不安になりやすい")
    }
}
