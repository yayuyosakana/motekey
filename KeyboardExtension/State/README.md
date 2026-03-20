# Keyboard Runtime State

このディレクトリは、`mote+AI` の runtime フロー（S-005〜S-007）向けの状態管理骨組みです。

## 含まれる実装

- `AppState.swift`
  - 画面状態（keyboard / askUser / loading / stage / fullText / fallback）
  - `キーボード` タブ切替時の ask-user 中断 + in-flight task cancel
  - 3問3択の質問検証
  - チップタップ時の compose 挿入（タップ順履歴を保持）
- `KeyboardRuntimeModels.swift`
  - runtime 状態・質問・候補モデル
- `KeyboardRuntimeDependencies.swift`
  - Gemini/Frame/Profile/Compose の依存プロトコル

## 仕様との対応

- チップタップで compose に挿入
- MVP では reorder UI なし（タップ順）
- `キーボード` タブ切替で ask-user の一時状態破棄 + task cancel
- 送信は既存メッセージアプリ側 UI を利用（本実装は送信ボタンを持たない）
