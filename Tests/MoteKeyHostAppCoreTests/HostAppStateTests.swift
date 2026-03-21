import XCTest
@testable import MoteKeyHostAppCore

final class HostAppStateTests: XCTestCase {
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "test.host.state.\(UUID().uuidString)"
    }

    override func tearDown() {
        UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
        suiteName = nil
        super.tearDown()
    }

    @MainActor
    func testBeginTextHabitRegistrationClearsAnswers() {
        let state = HostAppState(store: AppGroupStore(suiteName: suiteName))
        state.textHabitAnswers = [
            0: "回答1",
            1: "回答2"
        ]

        state.beginTextHabitRegistration()

        XCTAssertTrue(state.textHabitAnswers.isEmpty)
    }

    @MainActor
    func testOrderedNonEmptyTextHabitAnswersUsesQuestionOrderAndTrimsWhitespace() {
        let state = HostAppState(store: AppGroupStore(suiteName: suiteName))
        state.textHabitAnswers = [
            8: "  後ろの回答  ",
            2: "   ",
            0: "  先頭の回答",
            10: "範囲外"
        ]

        let answers = state.orderedNonEmptyTextHabitAnswers(questionCount: 10)

        XCTAssertEqual(answers, ["先頭の回答", "後ろの回答"])
    }

    @MainActor
    func testClearTextHabitAnswersRemovesCachedValues() {
        let state = HostAppState(store: AppGroupStore(suiteName: suiteName))
        state.textHabitAnswers = [4: "キャッシュ"]

        state.clearTextHabitAnswers()

        XCTAssertEqual(state.textHabitAnswers.count, 0)
    }

    @MainActor
    func testSaveRelationProfileKeepsNicknameEmptyWhenUserSkipsIt() throws {
        let store = AppGroupStore(suiteName: suiteName)
        let state = HostAppState(store: store)
        state.partnerNickname = "   "

        state.saveRelationProfile()

        let saved = try XCTUnwrap(store.loadRelation())
        XCTAssertEqual(saved.partnerNickname, "")
    }
}
