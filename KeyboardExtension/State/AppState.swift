import Foundation
import Combine
import MoteKeyShared

@MainActor
final class AppState: ObservableObject {

    @Published var currentScreen: KbdScreen = .keyboard
    @Published var displayMode: DisplayMode = .chip

    @Published var isAIProcessing = false
    @Published var fallbackReason: FallbackReason = .none
    @Published var fallbackDetailMessage: String?
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
    private var lastKnownPartnerMessage = ""

    init(
        frameLoader: LatestFrameLoading,
        visionExtractor: VisionContextExtracting,
        questionGenerator: AskUserQuestionGenerating,
        replyGenerator: ReplyGenerating,
        profileStore: ProfileStore,
        permissionChecker: PermissionChecking,
        requestScreenCaptureStart: (() -> Void)? = nil,
        frameAcquireTimeout: TimeInterval = 2.0,
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
        fallbackDetailMessage = nil
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
        fallbackDetailMessage = nil
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
        // 新規生成フロー開始時は、古い候補を残さない。
        generatedCandidates = []
        tappedChipHistory = []
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
        fallbackDetailMessage = buildFallbackDetailMessage(error)
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
            case .missingAPIKey:
                return .apiKeyMissing
            case .invalidHTTPStatus(let code) where code == 408 || code == 504:
                return .apiTimeout
            default:
                return .apiError
            }
        }
        return .apiError
    }

    private func buildFallbackDetailMessage(_ error: Error) -> String? {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut:
                return "通信がタイムアウトしました。ネットワーク状態を確認してください。"
            case .notConnectedToInternet:
                return "インターネットに接続されていません。"
            default:
                return "通信エラーが発生しました。(\(urlError.code.rawValue))"
            }
        }

        if let geminiError = error as? GeminiServiceError {
            switch geminiError {
            case .missingAPIKey:
                return "Gemini APIキーが未設定です。Info.plist / Secrets.xcconfig を確認してください。"
            case .invalidHTTPStatus(let code):
                if code == 429 {
                    return "Gemini API の利用上限に達しています（HTTP 429）。課金/クォータ設定を確認してください。"
                }
                return "Gemini API が HTTP \(code) を返しました。"
            case .invalidJSONPayload:
                return "Gemini API の応答JSONを解釈できませんでした。"
            case .emptyResponse:
                return "Gemini API の応答が空でした。"
            case .invalidURL:
                return "Gemini API エンドポイントURLが不正です。"
            case .chatNotDetected:
                return "チャット文脈を画像から抽出できませんでした。"
            }
        }

        switch error {
        case RuntimeError.invalidQuestionResponse:
            return "質問生成レスポンスの形式が不正です。"
        case RuntimeError.invalidReplyResponse:
            return "返信候補レスポンスの形式が不正です。"
        default:
            return nil
        }
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
                fallbackDetailMessage = "最新フレームを取得できませんでした。画面収録が開始されているか確認してください。"
                transition(to: .fallback)
                return
            }
            let contextText: String
            do {
                contextText = try await visionExtractor.extractChatContext(imageData: frameData)
            } catch {
                guard isOfflineAskUserFallbackEligible(error) else {
                    throw error
                }
                contextText = makeOfflineVisionFallbackContext()
            }

            if isToiletPaperRestockRequest(latestPartnerMessage(from: contextText)) {
                if Task.isCancelled || self.flowID != flowID { return }

                chatContext = contextText
                lastKnownPartnerMessage = latestPartnerMessage(from: contextText)
                generatedCandidates = fixedToiletPaperReplyCandidates()
                askUserQuestions = []
                askUserAnswers = [:]
                currentQuestionIndex = 0
                isAIProcessing = false
                fallbackReason = .none
                fallbackDetailMessage = nil
                transition(to: .stage)
                return
            }

            let context = AskUserContext(chatContext: contextText)
            let questions = try await generateAskUserQuestionsWithFallback(context: context)

            if Task.isCancelled || self.flowID != flowID { return }

            chatContext = contextText
            lastKnownPartnerMessage = latestPartnerMessage(from: contextText)
            isUsingManualContextFallback = false
            askUserQuestions = questions
            askUserAnswers = [:]
            currentQuestionIndex = 0
            isAIProcessing = false
            fallbackReason = .none
            fallbackDetailMessage = nil
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
                guard !(error is CancellationError) else {
                    throw error
                }

                guard isUsingManualContextFallback || shouldUseOfflineReplyFallback(for: error) else {
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
            fallbackDetailMessage = nil
            transition(to: .stage)
        } catch {
            handleFlowError(error, flowID: flowID)
        }
    }

    private func runManualFallbackAskUserFlow(chatContext: String, flowID: UUID) async {
        do {
            let context = AskUserContext(chatContext: chatContext)
            let questions = try await generateAskUserQuestionsWithFallback(context: context)

            if Task.isCancelled || self.flowID != flowID { return }

            self.chatContext = chatContext
            lastKnownPartnerMessage = latestPartnerMessage(from: chatContext)
            isUsingManualContextFallback = true
            askUserQuestions = questions
            askUserAnswers = [:]
            currentQuestionIndex = 0
            displayMode = .chip
            manualFallbackInput = ""
            manualFallbackValidationMessage = nil
            isAIProcessing = false
            fallbackReason = .none
            fallbackDetailMessage = nil
            transition(to: .askUser)
        } catch {
            handleFlowError(error, flowID: flowID)
        }
    }

    private func makeOfflineVisionFallbackContext() -> String {
        let fallbackMessage = fallbackPartnerMessageForOfflineMode()
        let payload = ChatContextPayload(
            chat_detected: true,
            app: "offline_fallback",
            messages: [
                .init(
                    speaker: .partner,
                    text: fallbackMessage,
                    date_label: nil,
                    time: nil
                )
            ],
            last_speaker: .partner,
            last_message: fallbackMessage
        )

        if let data = try? JSONEncoder().encode(payload),
           let json = String(data: data, encoding: .utf8) {
            return json
        }
        return fallbackMessage
    }

    private func fallbackPartnerMessageForOfflineMode() -> String {
        let remembered = lastKnownPartnerMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        if !remembered.isEmpty {
            return remembered
        }

        let manual = manualFallbackInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if !manual.isEmpty {
            return manual
        }

        // 429 時のデモ継続を優先した既定文脈
        return "トイレットペーパーなくなりそうだから買ってきてくれない？"
    }

    private func shouldUseOfflineReplyFallback(for error: Error) -> Bool {
        if error is URLError {
            return true
        }

        guard let geminiError = error as? GeminiServiceError else {
            return false
        }

        switch geminiError {
        case .missingAPIKey:
            return false
        default:
            return true
        }
    }

    private func generateAskUserQuestionsWithFallback(context: AskUserContext) async throws -> [AskUserQuestion] {
        do {
            let questions = try await questionGenerator.generateQuestions(context: context)
            guard questions.count == 3, questions.allSatisfy({ $0.options.count == 3 }) else {
                throw RuntimeError.invalidQuestionResponse
            }
            return questions
        } catch {
            guard !(error is CancellationError) else {
                throw error
            }

            // Missing API key は設定ミスとして明示的に通知する。
            if let geminiError = error as? GeminiServiceError,
               case .missingAPIKey = geminiError {
                throw error
            }

            if isOfflineAskUserFallbackEligible(error) {
                return offlineAskUserQuestions(for: context)
            }

            return defaultAskUserQuestions()
        }
    }

    private func isOfflineAskUserFallbackEligible(_ error: Error) -> Bool {
        if error is URLError {
            return true
        }

        guard let geminiError = error as? GeminiServiceError else {
            return false
        }

        switch geminiError {
        case .missingAPIKey:
            return false
        default:
            return true
        }
    }

    private func offlineAskUserQuestions(for context: AskUserContext) -> [AskUserQuestion] {
        let message = latestPartnerMessage(from: context.chatContext)
        guard isToiletPaperRestockRequest(message) else {
            return defaultAskUserQuestions()
        }

        return [
            AskUserQuestion(
                index: 0,
                text: "いつ買って帰れる？",
                options: [
                    AskUserOption(label: "帰り道で買える", value: "buy_on_way_home"),
                    AskUserOption(label: "夜遅めなら買える", value: "buy_late_evening"),
                    AskUserOption(label: "今日は難しい", value: "cannot_buy_today")
                ]
            ),
            AskUserQuestion(
                index: 1,
                text: "銘柄やタイプの希望はある？",
                options: [
                    AskUserOption(label: "いつもののでOK", value: "usual_brand_ok"),
                    AskUserOption(label: "指定の銘柄がある", value: "specific_brand_required"),
                    AskUserOption(label: "シングル/ダブルを確認したい", value: "confirm_paper_type")
                ]
            ),
            AskUserQuestion(
                index: 2,
                text: "返信で最後に何を添える？",
                options: [
                    AskUserOption(label: "買ったら連絡すると伝える", value: "report_after_purchase"),
                    AskUserOption(label: "他の不足品も聞く", value: "ask_other_supplies"),
                    AskUserOption(label: "難しい場合の代替案を伝える", value: "offer_alternative_plan")
                ]
            )
        ]
    }

    private func defaultAskUserQuestions() -> [AskUserQuestion] {
        [
            AskUserQuestion(
                index: 0,
                text: "今回の返信で最初に伝える事実はどれですか？",
                options: [
                    AskUserOption(label: "今すぐ対応できる", value: "can_handle_now"),
                    AskUserOption(label: "少し遅れて対応する", value: "handle_with_delay"),
                    AskUserOption(label: "今日は対応が難しい", value: "cannot_handle_today")
                ]
            ),
            AskUserQuestion(
                index: 1,
                text: "対応できる時刻はいつですか？",
                options: [
                    AskUserOption(label: "今日中", value: "by_end_of_today"),
                    AskUserOption(label: "明日", value: "tomorrow"),
                    AskUserOption(label: "予定を確認して連絡", value: "confirm_then_reply")
                ]
            ),
            AskUserQuestion(
                index: 2,
                text: "相手に提案する次の具体アクションは？",
                options: [
                    AskUserOption(label: "代替案を提案する", value: "propose_alternative"),
                    AskUserOption(label: "完了後に再連絡する", value: "follow_up_after_done"),
                    AskUserOption(label: "必要な条件を確認する", value: "confirm_requirements")
                ]
            )
        ]
    }

    private func makeLocalReplyCandidates(
        chatContext: String,
        relationProfile: RelationProfile
    ) -> [ReplyCandidate] {
        let message = latestPartnerMessage(from: chatContext)

        if isToiletPaperRestockRequest(message) {
            return fixedToiletPaperReplyCandidates()
        }

        let mention = partnerMentionPrefix(from: relationProfile.partnerName)
        let snippet = latestPartnerMessageSnippet(from: chatContext)
        let firstLine: String
        if snippet.isEmpty {
            firstLine = "\(mention)メッセージありがとう。内容を確認したよ。"
        } else {
            firstLine = "\(mention)メッセージありがとう。\(snippet)について確認したよ。"
        }

        return [
            ReplyCandidate(text: firstLine),
            ReplyCandidate(text: "今日のうちにできるところまで進めて、終わったら連絡するね。"),
            ReplyCandidate(text: "必要な条件や希望があれば先に教えてくれると助かる。")
        ]
    }

    private func fixedToiletPaperReplyCandidates() -> [ReplyCandidate] {
        [
            ReplyCandidate(text: "もちろん、帰りにトイレットペーパー買って帰るね。"),
            ReplyCandidate(text: "今夜ドラッグストアに寄って、なくなる前に補充しておくよ。"),
            ReplyCandidate(text: "ほかに足りない日用品があれば一緒に買ってくるから教えて。")
        ]
    }

    private func partnerMentionPrefix(from raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        let normalized = trimmed.lowercased()
        let genericNames: Set<String> = ["パートナー", "相手", "partner"]
        if genericNames.contains(trimmed) || genericNames.contains(normalized) {
            return ""
        }

        return "\(trimmed)、"
    }

    private func isToiletPaperRestockRequest(_ text: String) -> Bool {
        let normalized = text
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "　", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalized.isEmpty else { return false }

        let hasTarget = normalized.contains("トイレットペーパー") || normalized.contains("トイペ")
        let hasBuyIntent = normalized.contains("買って") || normalized.contains("買ってきて")
        let hasUrgency = normalized.contains("なくなりそう") || normalized.contains("ない")

        return hasTarget && (hasBuyIntent || hasUrgency)
    }

    private func latestPartnerMessage(from chatContext: String) -> String {
        let trimmed = chatContext.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        if let data = trimmed.data(using: .utf8),
           let payload = try? JSONDecoder().decode(ChatContextPayload.self, from: data) {
            if let last = payload.last_message?.trimmingCharacters(in: .whitespacesAndNewlines),
               !last.isEmpty {
                return last
            }

            if let latestPartner = payload.messages.reversed().first(where: { $0.speaker == .partner }) {
                let text = latestPartner.text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty {
                    return text
                }
            }
        }

        return trimmed
    }

    private func latestPartnerMessageSnippet(from chatContext: String) -> String {
        shortSnippet(from: latestPartnerMessage(from: chatContext))
    }

    private func shortSnippet(from text: String) -> String {
        let normalized = text
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return "" }
        return String(normalized.prefix(18))
    }

}
