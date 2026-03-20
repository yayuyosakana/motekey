# Keyboard Runtime UI

S-005〜S-007 の keyboard runtime フロー向け SwiftUI 骨組みです。

- `KeyboardRuntimeRootView`
  - stateに応じて ask-user / loading / stage / 全文 / fallback を重ねる
- `BottomActionBarView`
  - `mote+AI` / `キーボード` / `全文表示` の3タブ
  - `キーボード` タップ時は `AppState` 側で ask-user 中断・task cancel
- `StageLayerView`
  - チップタップで compose へ挿入
- `FullTextLayerView`
  - 一覧タップで compose へ挿入して stage へ戻る
- `AskUserLayerView`
  - 3問3択を順次表示
- `LoadingVeilView` / `FallbackLayerView`
  - 進行中と失敗時の表示

現状は target 未接続のため、次段で keyboard extension 実体に統合する。
