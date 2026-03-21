import Foundation
import MoteKeyShared

struct KeyboardRuntimeFactory {
    /// specs で想定している App Group。
    static let appGroupSuiteName = AppGroupKeys.suiteName
    static let latestFrameFileName = AppGroupKeys.latestFrameFileName
    static let latestFramePasteboardName = AppGroupKeys.latestFramePasteboardName
    static let latestFramePasteboardType = AppGroupKeys.latestFramePasteboardType

    @MainActor
    static func makeAppState(
        clearMarkedText: @escaping () -> Void = {},
        insertText: @escaping (String) -> Void,
        hasFullAccess: (() -> Bool)? = nil
    ) -> AppState? {
        let appGroupURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupSuiteName)
            ?? FileManager.default.temporaryDirectory.appendingPathComponent("motekey-fallback", isDirectory: true)

        try? FileManager.default.createDirectory(at: appGroupURL, withIntermediateDirectories: true)

        let frameURL = appGroupURL.appendingPathComponent(latestFrameFileName)
        let frameLoader = FileLatestFrameLoader(
            frameURL: frameURL,
            pasteboardName: latestFramePasteboardName,
            pasteboardType: latestFramePasteboardType
        )
        let profileStore = AppGroupProfileStore(suiteName: appGroupSuiteName)
        let permissionChecker = AppGroupPermissionChecker(
            suiteName: appGroupSuiteName,
            fullAccessProvider: hasFullAccess
        )
        let composeProxy = TextDocumentComposeProxy(
            clearMarkedTextHandler: clearMarkedText,
            insertHandler: insertText
        )

        let geminiService = GeminiKeyboardRuntimeService()

        return AppState(
            frameLoader: frameLoader,
            visionExtractor: geminiService,
            questionGenerator: geminiService,
            replyGenerator: geminiService,
            profileStore: profileStore,
            permissionChecker: permissionChecker,
            composeProxy: composeProxy
        )
    }

    @MainActor
    static func makeMockAppState(
        clearMarkedText: @escaping () -> Void = {},
        insertText: @escaping (String) -> Void = { _ in }
    ) -> AppState {
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
            permissionChecker: StaticPermissionChecker(),
            composeProxy: TextDocumentComposeProxy(
                clearMarkedTextHandler: clearMarkedText,
                insertHandler: insertText
            )
        )
    }
}
