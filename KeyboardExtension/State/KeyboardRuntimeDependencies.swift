import Foundation

protocol LatestFrameLoading {
    func loadLatestFrameData() throws -> Data
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
    func insertText(_ text: String)
}

protocol PermissionChecking {
    func currentPermissionIssue() -> PermissionIssue
}

enum RuntimeError: Error {
    case invalidQuestionResponse
    case invalidReplyResponse
}
