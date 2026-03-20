import Foundation

enum GeminiPromptFactory {

    static func visionPrompt() -> String {
        """
        画像からチャット文脈を抽出してください。前置き不要、JSONのみを返してください。
        speaker は me / partner、会話が検出できない場合は chat_detected を false にしてください。
        """
    }

    static func askUserPrompt(context: AskUserContext) -> String {
        let payload: [String: Any] = [
            "chat_context": context.chatContext,
            "text_habit": [
                "tone": context.textStyleProfile.tone,
                "ending_style": context.textStyleProfile.endingStyle,
                "emoji_style": context.textStyleProfile.emojiStyle
            ],
            "relation": [
                "partner_name": context.relationProfile.partnerName,
                "relationship_summary": context.relationProfile.relationshipSummary,
                "caution_notes": context.relationProfile.cautionNotes
            ]
        ]

        return """
        以下の入力に対して、返信生成に必要な質問を3問生成してください。
        ルール:
        - 質問は3件固定
        - 各質問の options は3件固定
        - options[].value は英語スネークケース
        - 前置き不要、JSONのみ

        入力:
        \(jsonString(from: payload))
        """
    }

    static func replyPrompt(
        chatContext: String,
        answers: [Int: String],
        textStyleProfile: TextStyleProfile,
        relationProfile: RelationProfile,
        todayDate: String
    ) -> String {
        let payload: [String: Any] = [
            "chat_context": chatContext,
            "user_responses": answers
                .sorted(by: { $0.key < $1.key })
                .map { ["index": $0.key, "value": $0.value] },
            "text_habit": [
                "tone": textStyleProfile.tone,
                "ending_style": textStyleProfile.endingStyle,
                "emoji_style": textStyleProfile.emojiStyle
            ],
            "relation": [
                "partner_name": relationProfile.partnerName,
                "relationship_summary": relationProfile.relationshipSummary,
                "caution_notes": relationProfile.cautionNotes
            ],
            "today_date": todayDate
        ]

        return """
        以下の入力を使って返信チップを生成してください。
        ルール:
        - chips は2〜5件
        - 各チップはそのまま送信できる自然文
        - 前置き不要、JSONのみ

        入力:
        \(jsonString(from: payload))
        """
    }

    private static func jsonString(from payload: [String: Any]) -> String {
        guard JSONSerialization.isValidJSONObject(payload),
              let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted]),
              let text = String(data: data, encoding: .utf8)
        else {
            return "{}"
        }
        return text
    }
}
