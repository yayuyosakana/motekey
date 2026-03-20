import Foundation

/// キーボード拡張内の主状態。
enum KbdScreen: Equatable {
    case keyboard
    case askUser
    case loading
    case stage
    case fullText
    case fallback
    case permissionBlock
}

/// 下部タブの表示モード。
enum DisplayMode: Equatable {
    case chip
    case fullText
}

/// 下部タブ操作。
enum BottomTab {
    case moteAI
    case keyboard
    case fullText
}

enum FallbackReason: Equatable {
    case none
    case imageCaptureFailed
    case apiTimeout
    case apiError
}

struct AskUserOption: Equatable, Sendable {
    let label: String
    let value: String
}

struct AskUserQuestion: Equatable, Sendable {
    let index: Int
    let text: String
    let options: [AskUserOption]
}

struct ReplyCandidate: Equatable, Sendable {
    let text: String
}

struct RelationProfile: Equatable, Sendable {
    let partnerName: String
    let relationshipSummary: String
    let cautionNotes: String
}

struct TextStyleProfile: Equatable, Sendable {
    let tone: String
    let endingStyle: String
    let emojiStyle: String
}

struct AskUserContext: Equatable, Sendable {
    let chatContext: String
    let textStyleProfile: TextStyleProfile
    let relationProfile: RelationProfile
}
