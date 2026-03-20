import Foundation
import Combine

@MainActor
final class AppState: ObservableObject {

    @Published var currentScreen: KbdScreen = .keyboard
    @Published var displayMode: DisplayMode = .chip

    @Published var isAIProcessing = false
    @Published var fallbackReason: FallbackReason = .none

    @Published var chatContext = ""
    @Published var askUserQuestions: [AskUserQuestion] = []
    @Published var askUserAnswers: [Int: String] = [:]
    @Published var currentQuestionIndex = 0

    @Published var generatedCandidates: [ReplyCandidate] = []
    @Published private(set) var tappedChipHistory: [ReplyCandidate] = []

    private(set) var generationTask: Task<Void, Never>?

    private let frameLoader: LatestFrameLoading
    private let visionExtractor: VisionContextExtracting
    private let questionGenerator: AskUserQuestionGenerating
    private let replyGenerator: ReplyGenerating
    private let profileStore: ProfileStore
    private weak var composeProxy: ComposeTextProxy?
    private var flowID = UUID()

    init(
        frameLoader: LatestFrameLoading,
        visionExtractor: VisionContextExtracting,
        questionGenerator: AskUserQuestionGenerating,
        replyGenerator: ReplyGenerating,
        profileStore: ProfileStore,
        composeProxy: ComposeTextProxy?
    ) {
        self.frameLoader = frameLoader
        self.visionExtractor = visionExtractor
        self.questionGenerator = questionGenerator
        self.replyGenerator = replyGenerator
        self.profileStore = profileStore
        self.composeProxy = composeProxy
    }

    deinit {
        generationTask?.cancel()
    }

    func handleBottomTabTap(_ tab: BottomTab) {
        switch tab {
        case .moteAI:
            startAskUserFlow()
        case .keyboard:
            switchToKeyboardAndCancelAskUserIfNeeded()
        case .fullText:
            guard canOpenFullText else { return }
            displayMode = .fullText
            transition(to: .fullText)
        }
    }

    func selectOption(_ value: String) {
        guard currentQuestionIndex < askUserQuestions.count else { return }
        askUserAnswers[currentQuestionIndex] = value

        if currentQuestionIndex >= askUserQuestions.count - 1 {
            startReplyGeneration()
        } else {
            currentQuestionIndex += 1
        }
    }

    func insertChip(_ candidate: ReplyCandidate) {
        composeProxy?.insertText(candidate.text)
        tappedChipHistory.append(candidate)
    }

    func showStage() {
        guard !generatedCandidates.isEmpty else {
            transition(to: .keyboard)
            return
        }
        displayMode = .chip
        transition(to: .stage)
    }

    func retryFromFallback() {
        guard currentScreen == .fallback else { return }
        handleBottomTabTap(.moteAI)
    }

    func closeFallback() {
        guard currentScreen == .fallback else { return }
        switchToKeyboardAndCancelAskUserIfNeeded()
    }

    func resetAll() {
        generationTask?.cancel()
        generationTask = nil

        isAIProcessing = false
        fallbackReason = .none

        chatContext = ""
        askUserQuestions = []
        askUserAnswers = [:]
        currentQuestionIndex = 0

        generatedCandidates = []
        tappedChipHistory = []

        displayMode = .chip
        currentScreen = .keyboard
    }

    /// `mote+AI` 質問フローを中断し、ローカル状態と in-flight Task を破棄する。
    func cancelAskUserFlow() {
        generationTask?.cancel()
        generationTask = nil
        flowID = UUID()

        isAIProcessing = false
        chatContext = ""
        askUserQuestions = []
        askUserAnswers = [:]
        currentQuestionIndex = 0

        displayMode = .chip
    }

    var canOpenFullText: Bool {
        !generatedCandidates.isEmpty && currentScreen != .askUser && currentScreen != .loading
    }

    private func startAskUserFlow() {
        guard !isAIProcessing else { return }

        cancelAskUserFlow()
        isAIProcessing = true
        transition(to: .loading)
        let activeFlowID = flowID

        generationTask = Task { [weak self] in
            await self?.runAskUserFlow(flowID: activeFlowID)
        }
    }

    private func startReplyGeneration() {
        guard !isAIProcessing else { return }

        isAIProcessing = true
        transition(to: .loading)
        let activeFlowID = flowID

        generationTask = Task { [weak self] in
            await self?.runReplyGeneration(flowID: activeFlowID)
        }
    }

    private func switchToKeyboardAndCancelAskUserIfNeeded() {
        if currentScreen == .askUser || currentScreen == .loading {
            cancelAskUserFlow()
        }
        displayMode = .chip
        transition(to: generatedCandidates.isEmpty ? .keyboard : .stage)
    }

    private func transition(to next: KbdScreen) {
        currentScreen = next
    }

    private func handleFlowError(_ error: Error, flowID: UUID) {
        guard self.flowID == flowID else { return }
        isAIProcessing = false

        if error is CancellationError {
            transition(to: generatedCandidates.isEmpty ? .keyboard : .stage)
            return
        }

        fallbackReason = classifyFallbackReason(error)
        transition(to: .fallback)
    }

    private func classifyFallbackReason(_ error: Error) -> FallbackReason {
        if let urlError = error as? URLError, urlError.code == .timedOut {
            return .apiTimeout
        }
        if let geminiError = error as? GeminiServiceError {
            switch geminiError {
            case .chatNotDetected:
                return .imageCaptureFailed
            case .invalidHTTPStatus(let code) where code == 408 || code == 504:
                return .apiTimeout
            default:
                return .apiError
            }
        }
        return .apiError
    }

    private func runAskUserFlow(flowID: UUID) async {
        do {
            let frameData: Data
            do {
                frameData = try frameLoader.loadLatestFrameData()
            } catch {
                guard self.flowID == flowID else { return }
                isAIProcessing = false
                fallbackReason = .imageCaptureFailed
                transition(to: .fallback)
                return
            }
            let contextText = try await visionExtractor.extractChatContext(imageData: frameData)

            let textStyleProfile = profileStore.loadTextStyleProfile()
            let relationProfile = profileStore.loadRelationProfile()
            let context = AskUserContext(
                chatContext: contextText,
                textStyleProfile: textStyleProfile,
                relationProfile: relationProfile
            )

            let questions = try await questionGenerator.generateQuestions(context: context)
            guard questions.count == 3, questions.allSatisfy({ $0.options.count == 3 }) else {
                throw RuntimeError.invalidQuestionResponse
            }

            if Task.isCancelled || self.flowID != flowID { return }

            chatContext = contextText
            askUserQuestions = questions
            askUserAnswers = [:]
            currentQuestionIndex = 0
            isAIProcessing = false
            fallbackReason = .none
            transition(to: .askUser)
        } catch {
            handleFlowError(error, flowID: flowID)
        }
    }

    private func runReplyGeneration(flowID: UUID) async {
        do {
            let textStyleProfile = profileStore.loadTextStyleProfile()
            let relationProfile = profileStore.loadRelationProfile()

            let candidates = try await replyGenerator.generateReplyCandidates(
                chatContext: chatContext,
                answers: askUserAnswers,
                textStyleProfile: textStyleProfile,
                relationProfile: relationProfile
            )

            guard !candidates.isEmpty else {
                throw RuntimeError.invalidReplyResponse
            }

            if Task.isCancelled || self.flowID != flowID { return }

            generatedCandidates = candidates
            displayMode = .chip
            isAIProcessing = false
            fallbackReason = .none
            transition(to: .stage)
        } catch {
            handleFlowError(error, flowID: flowID)
        }
    }
}
