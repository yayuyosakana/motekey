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
        あなたは返信文生成に必要な追加情報を集める質問生成アシスタントです。
        目的は「返信の不足コンテキスト（事実・予定・ステータス）」のみを3問3択で補完することです。

        絶対ルール:
        - ユーザーに返信文の作り方やトーンを考えさせる質問は禁止
        - 客観的な事実・予定・明確な選択結果のみを問う
        - 質問は3件固定
        - 各質問の options は3件固定
        - options[].value は英語スネークケース
        - 同一質問内で options[].value は重複禁止
        - 前置き・説明文・Markdown禁止。JSONのみを返す

        出力JSONスキーマ:
        {
          "questions": [
            {
              "question": "質問テキスト",
              "options": [
                { "label": "表示文言", "value": "snake_case_value" },
                { "label": "表示文言", "value": "snake_case_value" },
                { "label": "表示文言", "value": "snake_case_value" }
              ]
            },
            {
              "question": "質問テキスト",
              "options": [
                { "label": "表示文言", "value": "snake_case_value" },
                { "label": "表示文言", "value": "snake_case_value" },
                { "label": "表示文言", "value": "snake_case_value" }
              ]
            },
            {
              "question": "質問テキスト",
              "options": [
                { "label": "表示文言", "value": "snake_case_value" },
                { "label": "表示文言", "value": "snake_case_value" },
                { "label": "表示文言", "value": "snake_case_value" }
              ]
            }
          ]
        }

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
        あなたは、パートナーへの返信メッセージを代わりに考えるアシスタントです。
        目的は「相手の感情に配慮しつつ、当事者意識のある具体的な返信」を作ることです。
        前置きや説明文は不要。JSONのみを返してください。

        生成ルール:
        - 出力は chips 2〜5件
        - 各チップは実際にLINEで1通として送れる自然文
        - チップ順 = 送信順として意味が通る構成にする
        - まず相手の発話意図を判定し、次のどちらかの流れを取る:
          - 感情共有型: 感情リアクション → 承認/労い → 具体的な展開提案
          - 実務/トラブル型: 受容/謝意or謝罪 → 状況共有/配慮 → 具体的ネクストアクション

        文体ルール:
        - text_habit に忠実に口調を合わせる
        - relation.relationshipType と relation.cautionNote を反映して距離感を調整する
        - relation.nickname が有効値（空文字・"パートナー" 以外）の場合、chipsのうち少なくとも1件で自然に呼びかける
        - 毎回同じ定型にしない。語彙・文頭・言い回しの重複を避ける

        禁止事項:
        - 「了解」「OK」「任せる」「どっちでもいい」等の思考放棄
        - 相手の感情を無視した即断/説教/正論押しつけ
        - 条件付き謝罪（例: 「不快にさせたならごめん」）
        - 言い訳先行

        入力:
        \(jsonString(from: payload))

        出力形式:
        {
          "chips": [
            { "text": "チップ1" },
            { "text": "チップ2" }
          ]
        }
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
