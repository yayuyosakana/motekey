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
            "chat_context": chatContextJSONValue(from: context.chatContext)
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
        let userResponses = Dictionary(
            uniqueKeysWithValues: answers
                .sorted(by: { $0.key < $1.key })
                .map { (String($0.key), $0.value) }
        )

        let payload: [String: Any] = [
            "chat_context": chatContextJSONValue(from: chatContext),
            "user_responses": userResponses,
            "text_habit": textHabitPayload(from: textStyleProfile),
            "relation": relationPayload(from: relationProfile),
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

    private static func chatContextJSONValue(from raw: String) -> Any {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return emptyChatContext()
        }

        if let data = trimmed.data(using: .utf8),
           let jsonObject = try? JSONSerialization.jsonObject(with: data),
           JSONSerialization.isValidJSONObject(jsonObject) {
            return jsonObject
        }

        return manualInputChatContext(from: trimmed)
    }

    private static func textHabitPayload(from profile: TextStyleProfile) -> [String: Any] {
        [
            "tone_profile": [
                "summary": profile.tone,
                "rules": [],
                "details": [
                    "ending_patterns": profile.endingStyle,
                    "emoji_usage": profile.emojiStyle,
                    "empathy_style": "",
                    "suggestion_style": "",
                    "message_length": "",
                    "colloquial_style": ""
                ]
            ]
        ]
    }

    private static func relationPayload(from profile: RelationProfile) -> [String: Any] {
        [
            "nickname": profile.partnerName,
            "relationshipType": profile.relationshipSummary,
            "datingStartDate": NSNull(),
            "marriageDate": NSNull(),
            "birthdayMonth": NSNull(),
            "birthdayDay": NSNull(),
            "cautionNote": profile.cautionNotes
        ]
    }

    private static func emptyChatContext() -> [String: Any] {
        [
            "chat_detected": false,
            "app": "unknown",
            "messages": [],
            "last_speaker": NSNull(),
            "last_message": NSNull()
        ]
    }

    private static func manualInputChatContext(from text: String) -> [String: Any] {
        [
            "chat_detected": true,
            "app": "manual_input",
            "messages": [
                [
                    "speaker": "partner",
                    "text": text,
                    "date_label": NSNull(),
                    "time": NSNull()
                ]
            ],
            "last_speaker": "partner",
            "last_message": text
        ]
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
