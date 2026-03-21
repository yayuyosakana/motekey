import Foundation

protocol LatestFrameLoading {
    func loadLatestFrameData() throws -> Data
    func hasRecentFrame(maxAge: TimeInterval) -> Bool
}

protocol VisionContextExtracting {
    func extractChatContext(imageData: Data) async throws -> String
}

protocol AskUserQuestionGenerating {
    func generateQuestions(context: AskUserContext) async throws -> [AskUserQuestion]
}

protocol ReplyGenerating {
    func generateReplyCandidates(
        chatContext: String,
        answers: [Int: String],
        textStyleProfile: TextStyleProfile,
        relationProfile: RelationProfile
    ) async throws -> [ReplyCandidate]
}

protocol ProfileStore {
    func loadTextStyleProfile() -> TextStyleProfile
    func loadRelationProfile() -> RelationProfile
}

protocol ComposeTextProxy: AnyObject {
    func clearMarkedText()
    func insertText(_ text: String)
}

protocol PermissionChecking {
    func currentPermissionIssue() -> PermissionIssue
}

enum RuntimeError: Error {
    case latestFrameUnavailable
    case invalidQuestionResponse
    case invalidReplyResponse
}
