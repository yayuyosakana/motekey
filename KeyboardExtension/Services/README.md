# Keyboard Runtime Services

Gemini API 呼び出し層です。`AppState` が必要とする以下3用途を実装しています。

- Vision文脈抽出
- Ask-user 3問生成
- 返信チップ生成

## ファイル

- `GeminiKeyboardRuntimeService.swift`
  - `VisionContextExtracting` / `AskUserQuestionGenerating` / `ReplyGenerating` を実装
  - `APIConfig` の用途別APIキーを利用
  - HTTP 10秒タイムアウト
  - HTTP 429 は2秒待機して1回だけ自動リトライ
  - レスポンスからJSONオブジェクトを抽出してデコード
- `GeminiWireModels.swift`
  - Gemini `generateContent` のRequest/Responseモデル
- `GeminiDomainModels.swift`
  - Vision/Q生成/返信生成のJSONペイロードモデル
- `GeminiPromptFactory.swift`
  - 各用途のプロンプト組み立て
- `GeminiJSONExtractor.swift`
  - 返却テキストから最初のJSONオブジェクトを抽出
- `MockKeyboardRuntimeServices.swift`
  - UI確認用のモック Vision/Q生成/返信生成
