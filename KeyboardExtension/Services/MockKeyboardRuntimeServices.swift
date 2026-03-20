import Foundation

struct MockVisionExtractor: VisionContextExtracting {
    let delayNanoseconds: UInt64
    let contextJSON: String

    init(delayNanoseconds: UInt64 = 100_000_000, contextJSON: String = "{\"chat_detected\":true,\"messages\":[{\"speaker\":\"partner\",\"text\":\"今日どうする？\"}],\"last_speaker\":\"partner\",\"last_message\":\"今日どうする？\"}") {
        self.delayNanoseconds = delayNanoseconds
        self.contextJSON = contextJSON
    }

    func extractChatContext(imageData: Data) async throws -> String {
        try await Task.sleep(nanoseconds: delayNanoseconds)
        return contextJSON
    }
}

struct MockQuestionGenerator: AskUserQuestionGenerating {
    let delayNanoseconds: UInt64

    init(delayNanoseconds: UInt64 = 100_000_000) {
        self.delayNanoseconds = delayNanoseconds
    }

    func generateQuestions(context: AskUserContext) async throws -> [AskUserQuestion] {
        try await Task.sleep(nanoseconds: delayNanoseconds)
        return [
            AskUserQuestion(
                index: 0,
                text: "今夜の合流可能時間は？",
                options: [
                    AskUserOption(label: "19時ごろ", value: "around_19"),
                    AskUserOption(label: "20時以降", value: "after_20"),
                    AskUserOption(label: "難しい", value: "difficult_today")
                ]
            ),
            AskUserQuestion(
                index: 1,
                text: "夕食の希望は？",
                options: [
                    AskUserOption(label: "外食", value: "dine_out"),
                    AskUserOption(label: "家で食べる", value: "eat_home"),
                    AskUserOption(label: "相手に合わせる", value: "follow_partner")
                ]
            ),
            AskUserQuestion(
                index: 2,
                text: "返信に入れたい要素は？",
                options: [
                    AskUserOption(label: "具体的提案", value: "concrete_plan"),
                    AskUserOption(label: "まず謝意", value: "apology_first"),
                    AskUserOption(label: "短め", value: "short_reply")
                ]
            )
        ]
    }
}

struct MockReplyGenerator: ReplyGenerating {
    let delayNanoseconds: UInt64

    init(delayNanoseconds: UInt64 = 100_000_000) {
        self.delayNanoseconds = delayNanoseconds
    }

    func generateReplyCandidates(
        chatContext: String,
        answers: [Int: String],
        textStyleProfile: TextStyleProfile,
        relationProfile: RelationProfile
    ) async throws -> [ReplyCandidate] {
        try await Task.sleep(nanoseconds: delayNanoseconds)
        return [
            ReplyCandidate(text: "連絡ありがとう、今日の予定ちゃんと合わせたい！"),
            ReplyCandidate(text: "19時過ぎなら合流できそうだから、駅近でご飯どう？"),
            ReplyCandidate(text: "難しそうなら先に食べてて大丈夫、終わったらすぐ連絡するね")
        ]
    }
}
