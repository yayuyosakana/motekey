# Keyboard Runtime UI

S-005〜S-007 の keyboard runtime フロー向け SwiftUI 骨組みです。

- `KeyboardRuntimeRootView`
  - stateに応じて ask-user / loading / stage / 全文 / fallback を重ねる
- `BottomActionBarView`
  - `mote+AI` / `キーボード` / `全文表示` の3タブ
  - `キーボード` タップ時は `AppState` 側で ask-user 中断・task cancel
- `StageLayerView`
  - チップタップで compose へ挿入
  - チップを `Double(index) * 0.05` の遅延で順次表示
- `FullTextLayerView`
  - 一覧タップで compose へ挿入して stage へ戻る
  - 高さ不足（< 200pt）時は利用不可メッセージを表示
- `AskUserLayerView`
  - 3問3択を順次表示
- `LoadingVeilView` / `FallbackLayerView`
  - 進行中と失敗時の表示
  - fallbackでは相手メッセージ手入力で ask-user フローへ復帰可能
- `PermissionBlockLayerView`
  - フルアクセス/画面収録の未許可時に案内表示

現状は target 未接続のため、次段で keyboard extension 実体に統合する。
