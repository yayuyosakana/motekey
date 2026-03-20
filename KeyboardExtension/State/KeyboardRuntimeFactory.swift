import Foundation

struct KeyboardRuntimeFactory {
    /// specs で想定している App Group。
    static let appGroupSuiteName = "group.com.motekey.shared"
    static let latestFrameFileName = "latest_frame.jpg"

    @MainActor
    static func makeAppState(insertText: @escaping (String) -> Void) -> AppState? {
        guard let appGroupURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupSuiteName)
        else {
            return nil
        }

        let frameURL = appGroupURL.appendingPathComponent(latestFrameFileName)
        let frameLoader = FileLatestFrameLoader(frameURL: frameURL)
        let profileStore = AppGroupProfileStore(suiteName: appGroupSuiteName)
        let composeProxy = TextDocumentComposeProxy(insertHandler: insertText)

        let geminiService = GeminiKeyboardRuntimeService()

        return AppState(
            frameLoader: frameLoader,
            visionExtractor: geminiService,
            questionGenerator: geminiService,
            replyGenerator: geminiService,
            profileStore: profileStore,
            composeProxy: composeProxy
        )
    }

    @MainActor
    static func makeMockAppState(insertText: @escaping (String) -> Void = { _ in }) -> AppState {
        let frameLoader = InMemoryFrameLoader()
        let profileStore = InMemoryProfileStore(
            textStyleProfile: .init(tone: "friendly", endingStyle: "casual", emojiStyle: "light"),
            relationProfile: .init(partnerName: "パートナー", relationshipSummary: "彼女", cautionNotes: "")
        )
        return AppState(
            frameLoader: frameLoader,
            visionExtractor: MockVisionExtractor(),
            questionGenerator: MockQuestionGenerator(),
            replyGenerator: MockReplyGenerator(),
            profileStore: profileStore,
            composeProxy: TextDocumentComposeProxy(insertHandler: insertText)
        )
    }
}
