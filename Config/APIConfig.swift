import Foundation

/// Gemini API キーを管理する設定ファイル
///
/// 【セットアップ手順】
/// 1. `Config/Secrets.xcconfig` ファイルを作成（.gitignore済み）
/// 2. 以下の行を追加: GEMINI_API_KEY = あなたのAPIキー
/// 3. Xcode > Project Settings > Configurations で Secrets.xcconfig を適用
/// 4. Info.plist に `GeminiAPIKey = $(GEMINI_API_KEY)` を追加
///
/// 【緊急時ハードコード】
/// ハッカソン本番中に上記設定が間に合わない場合は、
/// `hardcodedKey` に直接キーを入れてビルドしてください。
/// ただし絶対にコミットしないこと。
enum APIConfig {

    // MARK: - Gemini API Key

    /// Gemini API キー（本番）
    /// Info.plist 経由で取得を試み、失敗した場合は hardcodedKey にフォールバック
    static var geminiAPIKey: String {
        if let key = Bundle.main.object(forInfoDictionaryKey: "GeminiAPIKey") as? String,
           !key.isEmpty,
           key != "$(GEMINI_API_KEY)" {
            return key
        }
        // ハッカソン緊急用: 以下に直接キーを入れる（コミット禁止）
        let hardcodedKey = ""
        assert(!hardcodedKey.isEmpty, "Gemini API キーが未設定です。Secrets.xcconfig を確認してください。")
        return hardcodedKey
    }

    // MARK: - Gemini API Endpoints

    static let geminiTextEndpoint =
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent"

    static let geminiVisionEndpoint =
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent"
}
