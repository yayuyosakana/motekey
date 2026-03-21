import XCTest
@testable import MoteKeyKeyboardRuntimeCore

@MainActor
final class AppStateFlowTests: XCTestCase {
    func testInsertChipReflectsTapOrderInComposeProxy() {
        let composeSpy = ComposeProxySpy()
        let appState = makeAppState(composeProxy: composeSpy)

        let first = ReplyCandidate(text: "first")
        let second = ReplyCandidate(text: "second")

        appState.insertChip(first)
        appState.insertChip(second)

        XCTAssertEqual(
            composeSpy.events,
            [.clearMarkedText, .insertText("first"), .clearMarkedText, .insertText("second")]
        )
        XCTAssertEqual(appState.tappedChipHistory, [first, second])
    }

    func testKeyboardTabCancelsAskUserAndClearsTemporaryState() async {
        let appState = makeAppState(
            visionExtractor: ImmediateVisionExtractor(context: "{\"chat_detected\":true}"),
            questionGenerator: ImmediateQuestionGenerator()
        )

        appState.handleBottomTabTap(.moteAI)
        await waitUntil("ask-user screen should be visible") {
            appState.currentScreen == .askUser
        }
        XCTAssertFalse(appState.askUserQuestions.isEmpty)

        appState.askUserAnswers = [0: "alpha", 1: "beta"]
        appState.currentQuestionIndex = 2
        appState.chatContext = "temporary-context"

        appState.handleBottomTabTap(.keyboard)

        XCTAssertEqual(appState.currentScreen, .keyboard)
        XCTAssertEqual(appState.displayMode, .chip)
        XCTAssertEqual(appState.askUserQuestions, [])
        XCTAssertEqual(appState.askUserAnswers, [:])
        XCTAssertEqual(appState.currentQuestionIndex, 0)
        XCTAssertEqual(appState.chatContext, "")
        XCTAssertNil(appState.generationTask)
        XCTAssertFalse(appState.isAIProcessing)
    }

    func testKeyboardTabDuringAskUserReturnsToKeyboardEvenWhenOldStageCandidatesExist() async {
        let appState = makeAppState(
            visionExtractor: ImmediateVisionExtractor(context: "{\"chat_detected\":true}"),
            questionGenerator: ImmediateQuestionGenerator()
        )
        let previousCandidates = [ReplyCandidate(text: "old-candidate")]
        appState.generatedCandidates = previousCandidates

        appState.handleBottomTabTap(.moteAI)
        await waitUntil("ask-user screen should be visible") {
            appState.currentScreen == .askUser
        }

        appState.handleBottomTabTap(.keyboard)

        XCTAssertEqual(appState.currentScreen, .keyboard)
        XCTAssertEqual(appState.generatedCandidates, previousCandidates)
        XCTAssertEqual(appState.askUserQuestions, [])
        XCTAssertEqual(appState.askUserAnswers, [:])
        XCTAssertEqual(appState.currentQuestionIndex, 0)
    }

    func testKeyboardTabDuringLoadingCancelsInflightAskUserTask() async {
        let probe = CancellationProbe()
        let appState = makeAppState(
            visionExtractor: HangingVisionExtractor(probe: probe)
        )

        appState.handleBottomTabTap(.moteAI)
        XCTAssertEqual(appState.currentScreen, .loading)

        for _ in 0..<50 {
            if await probe.startedCount() > 0 {
                break
            }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        let startedCount = await probe.startedCount()
        XCTAssertGreaterThan(startedCount, 0)

        appState.handleBottomTabTap(.keyboard)

        XCTAssertEqual(appState.currentScreen, .keyboard)
        XCTAssertEqual(appState.displayMode, .chip)
        XCTAssertEqual(appState.askUserQuestions, [])
        XCTAssertEqual(appState.askUserAnswers, [:])
        XCTAssertEqual(appState.currentQuestionIndex, 0)
        XCTAssertNil(appState.generationTask)
        XCTAssertFalse(appState.isAIProcessing)

        for _ in 0..<50 {
            if await probe.cancelledCount() > 0 {
                break
            }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        let cancelledCount = await probe.cancelledCount()
        XCTAssertGreaterThan(cancelledCount, 0)
    }

    func testQuestionGenerationFailureTransitionsToFallbackWithoutDefaultQuestions() async {
        let appState = makeAppState(
            visionExtractor: ImmediateVisionExtractor(context: "{\"chat_detected\":true}"),
            questionGenerator: FailingQuestionGenerator()
        )

        appState.handleBottomTabTap(.moteAI)

        await waitUntil("question generation failure should show fallback") {
            appState.currentScreen == .fallback && !appState.isAIProcessing
        }

        XCTAssertEqual(appState.fallbackReason, .apiError)
        XCTAssertEqual(appState.askUserQuestions, [])
        XCTAssertEqual(appState.askUserAnswers, [:])
        XCTAssertEqual(appState.currentQuestionIndex, 0)
    }

    func testManualFallbackQuestionFailureStaysOnFallbackWithoutDefaultQuestions() async {
        let appState = makeAppState(
            frameLoader: MissingFrameLoader(),
            questionGenerator: FailingQuestionGenerator()
        )

        appState.handleBottomTabTap(.moteAI)
        await waitUntil("missing frame should show fallback") {
            appState.currentScreen == .fallback && !appState.isAIProcessing
        }
        XCTAssertEqual(appState.fallbackReason, .imageCaptureFailed)

        appState.manualFallbackInput = "相手のメッセージ"
        appState.continueFromManualFallbackInput()

        await waitUntil("manual fallback question generation failure should return to fallback") {
            appState.currentScreen == .fallback && !appState.isAIProcessing
        }
        XCTAssertEqual(appState.fallbackReason, .apiError)
        XCTAssertEqual(appState.askUserQuestions, [])
        XCTAssertEqual(appState.askUserAnswers, [:])
        XCTAssertEqual(appState.currentQuestionIndex, 0)
    }

    func testReplyCandidatesKeepGeneratorOrderWithoutReorderUI() async {
        let expected = [
            ReplyCandidate(text: "chip-1"),
            ReplyCandidate(text: "chip-2"),
            ReplyCandidate(text: "chip-3")
        ]
        let appState = makeAppState(
            visionExtractor: ImmediateVisionExtractor(context: "{\"chat_detected\":true}"),
            questionGenerator: ImmediateQuestionGenerator(),
            replyGenerator: OrderedReplyGenerator(candidates: expected)
        )

        appState.handleBottomTabTap(.moteAI)
        await waitUntil("ask-user should be shown before answering") {
            appState.currentScreen == .askUser
        }

        appState.selectOption("a")
        appState.selectOption("b")
        appState.selectOption("c")

        await waitUntil("reply generation should end at stage") {
            appState.currentScreen == .stage && !appState.isAIProcessing
        }

        XCTAssertEqual(appState.generatedCandidates, expected)
    }

    func testMoteAITapIsNoOpWhileAskUserScreenIsAlreadyVisible() async {
        let appState = makeAppState(
            visionExtractor: ImmediateVisionExtractor(context: "{\"chat_detected\":true}"),
            questionGenerator: ImmediateQuestionGenerator()
        )

        appState.handleBottomTabTap(.moteAI)
        await waitUntil("ask-user should be shown") {
            appState.currentScreen == .askUser
        }

        let initialQuestions = appState.askUserQuestions
        let initialIndex = appState.currentQuestionIndex

        appState.handleBottomTabTap(.moteAI)

        XCTAssertEqual(appState.currentScreen, .askUser)
        XCTAssertEqual(appState.askUserQuestions, initialQuestions)
        XCTAssertEqual(appState.currentQuestionIndex, initialIndex)
        XCTAssertFalse(appState.isAIProcessing)
    }

    func testSelectOptionIgnoresValueOutsideCurrentQuestionOptions() async {
        let appState = makeAppState(
            visionExtractor: ImmediateVisionExtractor(context: "{\"chat_detected\":true}"),
            questionGenerator: ImmediateQuestionGenerator()
        )

        appState.handleBottomTabTap(.moteAI)
        await waitUntil("ask-user should be shown") {
            appState.currentScreen == .askUser
        }

        appState.selectOption("unknown_option")

        XCTAssertEqual(appState.askUserAnswers, [:])
        XCTAssertEqual(appState.currentQuestionIndex, 0)
        XCTAssertEqual(appState.currentScreen, .askUser)
        XCTAssertFalse(appState.isAIProcessing)
    }

    func testFullTextTabIsBlockedWhileAskUserOrLoading() {
        let appState = makeAppState()
        appState.generatedCandidates = [ReplyCandidate(text: "candidate")]

        appState.currentScreen = .askUser
        appState.handleBottomTabTap(.fullText)
        XCTAssertFalse(appState.canOpenFullText)
        XCTAssertEqual(appState.currentScreen, .askUser)

        appState.currentScreen = .loading
        appState.handleBottomTabTap(.fullText)
        XCTAssertFalse(appState.canOpenFullText)
        XCTAssertEqual(appState.currentScreen, .loading)
    }

    private func makeAppState(
        frameLoader: LatestFrameLoading = StaticFrameLoader(),
        visionExtractor: VisionContextExtracting = ImmediateVisionExtractor(context: "{\"chat_detected\":true}"),
        questionGenerator: AskUserQuestionGenerating = ImmediateQuestionGenerator(),
        replyGenerator: ReplyGenerating = ImmediateReplyGenerator(),
        composeProxy: ComposeTextProxy? = nil
    ) -> AppState {
        AppState(
            frameLoader: frameLoader,
            visionExtractor: visionExtractor,
            questionGenerator: questionGenerator,
            replyGenerator: replyGenerator,
            profileStore: StaticProfileStore(),
            permissionChecker: StaticPermissionChecker(issue: .none),
            composeProxy: composeProxy
        )
    }

    private func waitUntil(
        _ message: String,
        timeoutNanoseconds: UInt64 = 1_000_000_000,
        pollNanoseconds: UInt64 = 20_000_000,
        condition: @escaping () -> Bool
    ) async {
        let deadline = DispatchTime.now().uptimeNanoseconds + timeoutNanoseconds
        while DispatchTime.now().uptimeNanoseconds < deadline {
            if condition() {
                return
            }
            try? await Task.sleep(nanoseconds: pollNanoseconds)
        }
        XCTFail(message)
    }
}

private struct StaticFrameLoader: LatestFrameLoading {
    func loadLatestFrameData() throws -> Data {
        Data([0xFF, 0xD8, 0xFF, 0xD9])
    }
}

private struct MissingFrameLoader: LatestFrameLoading {
    func loadLatestFrameData() throws -> Data {
        throw TestError.forced
    }
}

private struct ImmediateVisionExtractor: VisionContextExtracting {
    let context: String

    func extractChatContext(imageData: Data) async throws -> String {
        context
    }
}

private struct HangingVisionExtractor: VisionContextExtracting {
    let probe: CancellationProbe

    func extractChatContext(imageData: Data) async throws -> String {
        await probe.markStarted()
        do {
            try await Task.sleep(nanoseconds: 5_000_000_000)
            return "{\"chat_detected\":true}"
        } catch {
            if error is CancellationError {
                await probe.markCancelled()
            }
            throw error
        }
    }
}

private struct ImmediateQuestionGenerator: AskUserQuestionGenerating {
    func generateQuestions(context: AskUserContext) async throws -> [AskUserQuestion] {
        [
            AskUserQuestion(
                index: 0,
                text: "Q1",
                options: [
                    AskUserOption(label: "A", value: "a"),
                    AskUserOption(label: "B", value: "b"),
                    AskUserOption(label: "C", value: "c")
                ]
            ),
            AskUserQuestion(
                index: 1,
                text: "Q2",
                options: [
                    AskUserOption(label: "A", value: "a"),
                    AskUserOption(label: "B", value: "b"),
                    AskUserOption(label: "C", value: "c")
                ]
            ),
            AskUserQuestion(
                index: 2,
                text: "Q3",
                options: [
                    AskUserOption(label: "A", value: "a"),
                    AskUserOption(label: "B", value: "b"),
                    AskUserOption(label: "C", value: "c")
                ]
            )
        ]
    }
}

private struct FailingQuestionGenerator: AskUserQuestionGenerating {
    func generateQuestions(context: AskUserContext) async throws -> [AskUserQuestion] {
        throw TestError.forced
    }
}

private struct ImmediateReplyGenerator: ReplyGenerating {
    func generateReplyCandidates(
        chatContext: String,
        answers: [Int : String],
        textStyleProfile: TextStyleProfile,
        relationProfile: RelationProfile
    ) async throws -> [ReplyCandidate] {
        [
            ReplyCandidate(text: "candidate-1"),
            ReplyCandidate(text: "candidate-2")
        ]
    }
}

private struct OrderedReplyGenerator: ReplyGenerating {
    let candidates: [ReplyCandidate]

    func generateReplyCandidates(
        chatContext: String,
        answers: [Int : String],
        textStyleProfile: TextStyleProfile,
        relationProfile: RelationProfile
    ) async throws -> [ReplyCandidate] {
        candidates
    }
}

private struct StaticProfileStore: ProfileStore {
    func loadTextStyleProfile() -> TextStyleProfile {
        TextStyleProfile(tone: "neutral", endingStyle: "casual", emojiStyle: "minimal")
    }

    func loadRelationProfile() -> RelationProfile {
        RelationProfile(partnerName: "partner", relationshipSummary: "girlfriend", cautionNotes: "")
    }
}

private enum TestError: Error {
    case forced
}

private actor CancellationProbe {
    private var started = 0
    private var cancelled = 0

    func markStarted() {
        started += 1
    }

    func markCancelled() {
        cancelled += 1
    }

    func startedCount() -> Int {
        started
    }

    func cancelledCount() -> Int {
        cancelled
    }
}

private final class ComposeProxySpy: ComposeTextProxy {
    enum Event: Equatable {
        case clearMarkedText
        case insertText(String)
    }

    private(set) var events: [Event] = []

    func clearMarkedText() {
        events.append(.clearMarkedText)
    }

    func insertText(_ text: String) {
        events.append(.insertText(text))
    }
}
