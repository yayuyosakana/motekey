import Foundation

enum GeminiPromptFactory {

    static func visionPrompt() -> String {
        """
        この画像はメッセージアプリのトーク画面のスクリーンショットです。画像からチャット文脈を構造化し、JSONのみを返してください。

        厳守:
        - 前置き/説明/コードブロックは禁止
        - 出力は JSON オブジェクト1つのみ
        - speaker は `me` または `partner` のみ
        - テキストが読めない場合は推測せず null を使う

        抽出ルール:
        - 右寄せ吹き出しは `me`、左寄せ吹き出しは `partner`
        - スタンプ/画像/動画/音声のみの発言は `text: "stamp_or_media"`
        - ヘッダー/入力欄/タブなどアプリUIは無視
        - 会話が検出できない場合は `chat_detected: false`

        必須フォーマット:
        {
          "chat_detected": true,
          "app": "LINE",
          "messages": [
            {
              "speaker": "partner",
              "text": "...",
              "date_label": "今日",
              "time": "18:10"
            }
          ],
          "last_speaker": "partner",
          "last_message": "..."
        }

        会話が検出できない場合:
        {
          "chat_detected": false,
          "app": "unknown",
          "messages": [],
          "last_speaker": null,
          "last_message": null
        }
        """
    }

    static func askUserPrompt(context: AskUserContext) -> String {
        let payload: [String: Any] = [
            "chat_context": chatContextJSONValue(from: context.chatContext)
        ]

        return """
        あなたは返信文生成のための事実確認AIです。
        入力の `chat_context` だけを使い、質問を3問3択で生成してください。

        厳守:
        - 出力は JSON のみ（前置き/説明/コードブロック禁止）
        - `questions` は必ず3件
        - 各 `options` は必ず3件
        - `options[].value` は英語スネークケース
        - 同一質問内で options[].value は重複禁止
        - 返信トーンや感情表現をユーザーに考えさせる質問は禁止
        - 質問は「事実」「予定」「制約」「優先順位」のみ
        - 文脈と無関係な汎用質問は禁止

        入力:
        \(jsonString(from: payload))

        出力形式:
        {
          "questions": [
            {
              "question": "質問文",
              "options": [
                { "label": "選択肢1", "value": "snake_case_1" },
                { "label": "選択肢2", "value": "snake_case_2" },
                { "label": "選択肢3", "value": "snake_case_3" }
              ]
            },
            {
              "question": "質問文",
              "options": [
                { "label": "選択肢1", "value": "snake_case_1" },
                { "label": "選択肢2", "value": "snake_case_2" },
                { "label": "選択肢3", "value": "snake_case_3" }
              ]
            },
            {
              "question": "質問文",
              "options": [
                { "label": "選択肢1", "value": "snake_case_1" },
                { "label": "選択肢2", "value": "snake_case_2" },
                { "label": "選択肢3", "value": "snake_case_3" }
              ]
            }
          ]
        }
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
        あなたはメッセージ返信案を作るアシスタントです。入力を使って、送信可能な返信文チップを生成してください。

        厳守:
        - 出力は JSON のみ（前置き/説明/コードブロック禁止）
        - `chips` は 2〜5 件
        - 各チップは実際にそのまま送信できる自然な短文
        - 1つ目のチップで相手の発言を受け止める
        - 2つ目以降で、具体的な次アクション（いつ/何をする）を明示
        - `user_responses` の値を反映し、空疎な定型文だけにしない
        - 文体は `text_habit` を反映
        - 毎回同じ定型にしない

        絶対禁止:
        - 「了解」「OK」「任せる」「どっちでもいい」「の件」
        - 相手メッセージの引用復唱（例: 「...」の件）
        - 「パートナー」という語を本文に出す
        - 3チップ以上で同じ語尾を機械的に反復すること
        - 思考放棄の短文のみで終えること

        呼称ルール:
        - `relation.nickname` が null/空/汎用語のとき、呼び名を本文に入れない
        - 呼び名を使う場合も自然な会話文として1回まで

        入力:
        \(jsonString(from: payload))

        出力形式:
        {
          "chips": [
            { "text": "チップ1" },
            { "text": "チップ2" },
            { "text": "チップ3" }
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
            "nickname": relationNicknameJSONValue(from: profile.partnerName),
            "relationshipType": profile.relationshipSummary,
            "datingStartDate": NSNull(),
            "marriageDate": NSNull(),
            "birthdayMonth": NSNull(),
            "birthdayDay": NSNull(),
            "cautionNote": profile.cautionNotes
        ]
    }

    private static func relationNicknameJSONValue(from raw: String) -> Any {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return NSNull()
        }

        let normalized = trimmed.lowercased()
        let genericNames: Set<String> = [
            "パートナー",
            "partner",
            "相手"
        ]

        if genericNames.contains(trimmed) || genericNames.contains(normalized) {
            return NSNull()
        }

        return trimmed
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
