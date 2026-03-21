# Keyboard Runtime Services

Gemini API 呼び出し層です。`AppState` が必要とする以下3用途を実装しています。

- Vision文脈抽出
- Ask-user 3問生成
- 返信チップ生成

## ファイル

- `GeminiKeyboardRuntimeService.swift`
  - `VisionContextExtracting` / `AskUserQuestionGenerating` / `ReplyGenerating` を実装
  - `APIConfig` の用途別APIキー + `geminiEndpoint(for:)` を利用
  - HTTP 10秒タイムアウト
  - HTTP 429 は2秒待機して1回だけ自動リトライ
  - レスポンスからJSONオブジェクトを抽出して `MoteKeyShared` スキーマへデコード
  - Vision/Q生成レスポンスの基本スキーマを検証（3問3択・snake_case値・非空テキスト制約など）
- `GeminiWireModels.swift`
  - Gemini `generateContent` のRequest/Responseモデル
- `GeminiPromptFactory.swift`
  - 各用途のプロンプト組み立て
- `GeminiJSONExtractor.swift`
  - 返却テキストから最初のJSONオブジェクトを抽出
  - 文字列内の `{` `}` を誤検知しないようにエスケープ/クォート状態を考慮
- `MockKeyboardRuntimeServices.swift`
  - UI確認用のモック Vision/Q生成/返信生成
