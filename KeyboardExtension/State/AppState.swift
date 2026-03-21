import Foundation
import Combine
import MoteKeyShared

@MainActor
final class AppState: ObservableObject {

    @Published var currentScreen: KbdScreen = .keyboard
    @Published var displayMode: DisplayMode = .chip

    @Published var isAIProcessing = false
    @Published var fallbackReason: FallbackReason = .none
    @Published var permissionIssue: PermissionIssue = .none
    @Published var manualFallbackInput = ""
    @Published var manualFallbackValidationMessage: String?

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
    private let permissionChecker: PermissionChecking
    private let requestScreenCaptureStart: (() -> Void)?
    private let frameAcquireTimeout: TimeInterval
    private let framePollInterval: TimeInterval
    private let frameFreshnessWindow: TimeInterval
    private let captureStartCooldown: TimeInterval
    private let composeProxy: ComposeTextProxy?
    private var lastCaptureStartRequestAt = Date.distantPast
    private var flowID = UUID()
    private var isUsingManualContextFallback = false

    init(
        frameLoader: LatestFrameLoading,
        visionExtractor: VisionContextExtracting,
        questionGenerator: AskUserQuestionGenerating,
        replyGenerator: ReplyGenerating,
        profileStore: ProfileStore,
        permissionChecker: PermissionChecking,
        requestScreenCaptureStart: (() -> Void)? = nil,
        frameAcquireTimeout: TimeInterval = 8.0,
        framePollInterval: TimeInterval = 0.2,
        frameFreshnessWindow: TimeInterval = 2.5,
        captureStartCooldown: TimeInterval = 10.0,
        composeProxy: ComposeTextProxy?
    ) {
        self.frameLoader = frameLoader
        self.visionExtractor = visionExtractor
        self.questionGenerator = questionGenerator
        self.replyGenerator = replyGenerator
        self.profileStore = profileStore
        self.permissionChecker = permissionChecker
        self.requestScreenCaptureStart = requestScreenCaptureStart
        self.frameAcquireTimeout = frameAcquireTimeout
        self.framePollInterval = framePollInterval
        self.frameFreshnessWindow = frameFreshnessWindow
        self.captureStartCooldown = captureStartCooldown
        self.composeProxy = composeProxy
    }

    deinit {
        generationTask?.cancel()
    }

    func handleBottomTabTap(_ tab: BottomTab) {
        switch tab {
        case .moteAI:
            guard currentScreen != .askUser else { return }
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
        let currentQuestion = askUserQuestions[currentQuestionIndex]
        guard currentQuestion.options.contains(where: { $0.value == value }) else { return }
        askUserAnswers[currentQuestionIndex] = value

        if currentQuestionIndex >= askUserQuestions.count - 1 {
            startReplyGeneration()
        } else {
            currentQuestionIndex += 1
        }
    }

    func insertChip(_ candidate: ReplyCandidate) {
        composeProxy?.clearMarkedText()
        composeProxy?.insertText(candidate.text)
        tappedChipHistory.append(candidate)
    }

    /// 候補を選択したら、入力欄へ挿入して通常キーボード面へ戻す。
    func insertCandidateAndReturnToKeyboard(_ candidate: ReplyCandidate) {
        insertChip(candidate)
        displayMode = .chip
        transition(to: .keyboard)
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

    func continueFromManualFallbackInput() {
        guard currentScreen == .fallback else { return }
        let trimmed = manualFallbackInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            manualFallbackValidationMessage = "相手のメッセージを入力してください。"
            return
        }

        manualFallbackValidationMessage = nil
        isAIProcessing = true
        transition(to: .loading)
        let activeFlowID = flowID
        generationTask = Task { [weak self] in
            await self?.runManualFallbackAskUserFlow(chatContext: trimmed, flowID: activeFlowID)
        }
    }

    func closeFallback() {
        guard currentScreen == .fallback else { return }
        manualFallbackInput = ""
        manualFallbackValidationMessage = nil
        switchToKeyboardAndCancelAskUserIfNeeded()
    }

    func retryAfterPermissionGrant() {
        guard currentScreen == .permissionBlock else { return }
        handleBottomTabTap(.moteAI)
    }

    func closePermissionBlock() {
        guard currentScreen == .permissionBlock else { return }
        permissionIssue = .none
        switchToKeyboardAndCancelAskUserIfNeeded()
    }

    func resetAll() {
        generationTask?.cancel()
        generationTask = nil

        isAIProcessing = false
        fallbackReason = .none
        permissionIssue = .none
        isUsingManualContextFallback = false
        manualFallbackInput = ""
        manualFallbackValidationMessage = nil

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
        fallbackReason = .none
        permissionIssue = .none
        isUsingManualContextFallback = false
        chatContext = ""
        askUserQuestions = []
        askUserAnswers = [:]
        currentQuestionIndex = 0
        manualFallbackInput = ""
        manualFallbackValidationMessage = nil

        displayMode = .chip
    }

    var canOpenFullText: Bool {
        !generatedCandidates.isEmpty && currentScreen != .askUser && currentScreen != .loading
    }

    /// `キーボード` タブがアクティブ表示される条件（通常キーボード/ステージ）。
    var isKeyboardTabActive: Bool {
        currentScreen == .keyboard || currentScreen == .stage
    }

    var isFullTextTabActive: Bool {
        currentScreen == .fullText
    }

    private func startAskUserFlow() {
        guard !isAIProcessing else { return }

        // iOSの制約上、画面収録の最終開始確認はユーザー操作が必要。
        // ただし既に収録中なら再要求せず、未稼働時のみ開始UIを出す。
        requestScreenCaptureStartIfNeeded()

        let issue = permissionChecker.currentPermissionIssue()
        guard issue == .none else {
            permissionIssue = issue
            transition(to: .permissionBlock)
            return
        }

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
        let shouldCancelAskUserFlow = currentScreen == .askUser
            || currentScreen == .loading
            || currentScreen == .fallback
            || currentScreen == .permissionBlock

        if shouldCancelAskUserFlow {
            cancelAskUserFlow()
            transition(to: .keyboard)
            return
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
                frameData = try await waitForLatestFrameData()
            } catch {
                guard self.flowID == flowID else { return }
                isAIProcessing = false
                fallbackReason = .imageCaptureFailed
                transition(to: .fallback)
                return
            }
            let contextText = try await visionExtractor.extractChatContext(imageData: frameData)

            let context = AskUserContext(chatContext: contextText)

            let questions = try await questionGenerator.generateQuestions(context: context)
            guard questions.count == 3, questions.allSatisfy({ $0.options.count == 3 }) else {
                throw RuntimeError.invalidQuestionResponse
            }

            if Task.isCancelled || self.flowID != flowID { return }

            chatContext = contextText
            isUsingManualContextFallback = false
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

    private func waitForLatestFrameData() async throws -> Data {
        let timeoutAt = Date().addingTimeInterval(frameAcquireTimeout)
        while true {
            if let frameData = try? frameLoader.loadLatestFrameData(), !frameData.isEmpty {
                return frameData
            }

            if Task.isCancelled {
                throw CancellationError()
            }
            if Date() >= timeoutAt {
                throw RuntimeError.latestFrameUnavailable
            }

            let nanos = UInt64(max(framePollInterval, 0.02) * 1_000_000_000)
            try await Task.sleep(nanoseconds: nanos)
        }
    }

    private func requestScreenCaptureStartIfNeeded() {
        guard requestScreenCaptureStart != nil else { return }
        guard !frameLoader.hasRecentFrame(maxAge: frameFreshnessWindow) else { return }

        let now = Date()
        guard now.timeIntervalSince(lastCaptureStartRequestAt) >= captureStartCooldown else { return }
        lastCaptureStartRequestAt = now
        requestScreenCaptureStart?()
    }

    private func runReplyGeneration(flowID: UUID) async {
        do {
            let textStyleProfile = profileStore.loadTextStyleProfile()
            let relationProfile = profileStore.loadRelationProfile()
            let candidates: [ReplyCandidate]
            do {
                let generated = try await replyGenerator.generateReplyCandidates(
                    chatContext: chatContext,
                    answers: askUserAnswers,
                    textStyleProfile: textStyleProfile,
                    relationProfile: relationProfile
                )
                let normalized = generated
                    .map { ReplyCandidate(text: $0.text.trimmingCharacters(in: .whitespacesAndNewlines)) }
                    .filter { !$0.text.isEmpty }
                guard !normalized.isEmpty else {
                    throw RuntimeError.invalidReplyResponse
                }
                candidates = normalized
            } catch {
                guard !(error is CancellationError), isUsingManualContextFallback else {
                    throw error
                }
                candidates = makeLocalReplyCandidates(
                    chatContext: chatContext,
                    relationProfile: relationProfile
                )
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

    private func runManualFallbackAskUserFlow(chatContext: String, flowID: UUID) async {
        do {
            let context = AskUserContext(chatContext: chatContext)
            let questions = try await questionGenerator.generateQuestions(context: context)
            guard questions.count == 3, questions.allSatisfy({ $0.options.count == 3 }) else {
                throw RuntimeError.invalidQuestionResponse
            }

            if Task.isCancelled || self.flowID != flowID { return }

            self.chatContext = chatContext
            isUsingManualContextFallback = true
            askUserQuestions = questions
            askUserAnswers = [:]
            currentQuestionIndex = 0
            displayMode = .chip
            manualFallbackInput = ""
            manualFallbackValidationMessage = nil
            isAIProcessing = false
            fallbackReason = .none
            transition(to: .askUser)
        } catch {
            handleFlowError(error, flowID: flowID)
        }
    }

    private func makeLocalReplyCandidates(
        chatContext: String,
        relationProfile: RelationProfile
    ) -> [ReplyCandidate] {
        let snippet = latestPartnerMessageSnippet(from: chatContext)
        let prefix: String
        switch askUserAnswers[0] {
        case "tone_warm":
            prefix = "うん、"
        case "tone_concise":
            prefix = "了解。"
        default:
            prefix = "了解！"
        }

        let partner = relationProfile.partnerName.trimmingCharacters(in: .whitespacesAndNewlines)
        let safePartner = partner.isEmpty ? "相手" : partner
        let topic = snippet.isEmpty ? "その件" : "「\(snippet)」の件"

        return [
            ReplyCandidate(text: "\(prefix)\(topic)、帰りに対応しておくね。"),
            ReplyCandidate(text: "\(safePartner)ありがとう、\(topic)了解！ほかに必要なものある？"),
            ReplyCandidate(text: "わかった！\(topic)、忘れずにやっておくよ。")
        ]
    }

    private func latestPartnerMessageSnippet(from chatContext: String) -> String {
        let trimmed = chatContext.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        if let data = trimmed.data(using: .utf8),
           let payload = try? JSONDecoder().decode(ChatContextPayload.self, from: data),
           let lastMessage = payload.last_message {
            return shortSnippet(from: lastMessage)
        }
        return shortSnippet(from: trimmed)
    }

    private func shortSnippet(from text: String) -> String {
        let normalized = text
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return "" }
        return String(normalized.prefix(18))
    }

}
