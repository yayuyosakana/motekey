import Foundation

/// Gemini API キーを管理する設定ファイル
///
/// 【セットアップ手順】
/// 1. `Config/Secrets.xcconfig` ファイルを作成（.gitignore済み）
/// 2. 以下の4行を追加:
///    - GEMINI_API_KEY_TEXT_HABIT
///    - GEMINI_API_KEY_VISION_CONTEXT
///    - GEMINI_API_KEY_ASK_USER_QUESTION
///    - GEMINI_API_KEY_REPLY_GENERATION
/// 3. Xcode > Project Settings > Configurations で Secrets.xcconfig を適用
/// 4. Info.plist に以下を追加:
///    - GeminiAPIKeyTextHabit = $(GEMINI_API_KEY_TEXT_HABIT)
///    - GeminiAPIKeyVisionContext = $(GEMINI_API_KEY_VISION_CONTEXT)
///    - GeminiAPIKeyAskUserQuestion = $(GEMINI_API_KEY_ASK_USER_QUESTION)
///    - GeminiAPIKeyReplyGeneration = $(GEMINI_API_KEY_REPLY_GENERATION)
///
/// 【緊急時ハードコード】
/// ハッカソン本番中に上記設定が間に合わない場合は、
/// Secrets.xcconfig 側に直接値を入れてビルドしてください。
/// ただし絶対にコミットしないこと。
public enum APIConfig {

    // MARK: - Gemini API Key

    public enum GeminiCallType {
        case textHabitAnalysis
        case visionChatContextExtraction
        case askUserQuestionGeneration
        case replyGeneration
    }

    /// 既存コード向けの後方互換（単一キー参照）
    public static var geminiAPIKey: String {
        geminiAPIKey(for: .replyGeneration)
    }

    /// 呼び出し種別ごとに対応するGemini APIキーを取得する。
    /// 専用キー未設定時は後方互換として `GeminiAPIKey`（単一キー）にフォールバックする。
    ///
    /// 取得優先順:
    /// 1. Info.plist の専用キー
    /// 2. 環境変数の専用キー（CLIビルド/テスト向け）
    /// 3. Info.plist の共通キー（GeminiAPIKey）
    /// 4. 環境変数の共通キー（GEMINI_API_KEY）
    public static func geminiAPIKey(
        for callType: GeminiCallType,
        bundle: Bundle = .main,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> String {
        let dedicatedInfoPlistKey: String
        let dedicatedPlaceholder: String
        let dedicatedEnvironmentKey: String

        switch callType {
        case .textHabitAnalysis:
            dedicatedInfoPlistKey = "GeminiAPIKeyTextHabit"
            dedicatedPlaceholder = "$(GEMINI_API_KEY_TEXT_HABIT)"
            dedicatedEnvironmentKey = "GEMINI_API_KEY_TEXT_HABIT"
        case .visionChatContextExtraction:
            dedicatedInfoPlistKey = "GeminiAPIKeyVisionContext"
            dedicatedPlaceholder = "$(GEMINI_API_KEY_VISION_CONTEXT)"
            dedicatedEnvironmentKey = "GEMINI_API_KEY_VISION_CONTEXT"
        case .askUserQuestionGeneration:
            dedicatedInfoPlistKey = "GeminiAPIKeyAskUserQuestion"
            dedicatedPlaceholder = "$(GEMINI_API_KEY_ASK_USER_QUESTION)"
            dedicatedEnvironmentKey = "GEMINI_API_KEY_ASK_USER_QUESTION"
        case .replyGeneration:
            dedicatedInfoPlistKey = "GeminiAPIKeyReplyGeneration"
            dedicatedPlaceholder = "$(GEMINI_API_KEY_REPLY_GENERATION)"
            dedicatedEnvironmentKey = "GEMINI_API_KEY_REPLY_GENERATION"
        }

        if let dedicated = resolvedInfoPlistValue(
            bundle: bundle,
            key: dedicatedInfoPlistKey,
            placeholder: dedicatedPlaceholder
        ) {
            return dedicated
        }
        if let dedicated = resolvedEnvironmentValue(
            environment: environment,
            key: dedicatedEnvironmentKey,
            placeholder: dedicatedPlaceholder
        ) {
            return dedicated
        }
        if let legacy = resolvedInfoPlistValue(
            bundle: bundle,
            key: "GeminiAPIKey",
            placeholder: "$(GEMINI_API_KEY)"
        ) {
            return legacy
        }
        if let legacy = resolvedEnvironmentValue(
            environment: environment,
            key: "GEMINI_API_KEY",
            placeholder: "$(GEMINI_API_KEY)"
        ) {
            return legacy
        }

        assertionFailure(
            "Gemini API キーが未設定です。Secrets.xcconfig / Info.plist / 環境変数を確認してください。"
        )
        return ""
    }

    private static func resolvedInfoPlistValue(bundle: Bundle, key: String, placeholder: String) -> String? {
        guard let value = bundle.object(forInfoDictionaryKey: key) as? String,
              !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              value != placeholder
        else {
            return nil
        }
        return value
    }

    private static func resolvedEnvironmentValue(
        environment: [String: String],
        key: String,
        placeholder: String
    ) -> String? {
        guard let value = environment[key],
              !value.isEmpty,
              value != placeholder
        else {
            return nil
        }
        return value
    }

    // MARK: - Gemini API Endpoints

    public static let geminiTextEndpoint =
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent"

    public static let geminiVisionEndpoint =
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent"
}
