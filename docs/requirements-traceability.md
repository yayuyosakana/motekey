# 要件 ⇄ 実装 トレーサビリティ

[`requirements.md`](../requirements.md) の各要件が、どのコードで実現されているかの対応表。
今回の修正（キーボード本体の作り直し＋azooKey変換統合）で更新済み。

## 機能要件

| ID | 機能 | 実装 | 状態 |
| --- | --- | --- | --- |
| F-001 | 画面コンテキスト取得（Vision） | `KeyboardExtension/Services/GeminiKeyboardRuntimeService.swift`、`AppState.runAskUserFlow` / `waitForLatestFrameData` | 実装済み（要 実機の画面収録） |
| F-002 | アスクユーザー（3問3択・一括生成） | `AppState.generateAskUserQuestionsWithFallback`（count==3 / options==3 を検証）、`AskUserLayerView` | 実装済み |
| F-003 | ステージ（生成・チップ反映） | `AppState.runReplyGeneration`、`StageLayerView`（横スクロール短縮）、`FullTextLayerView`（全文）、`insertCandidateAndReturnToKeyboard` | 実装済み |
| F-004 | テキストハビット登録 | `HostApp/GeminiTextHabitAnalyzer.swift`、`HostApp/Views/S002TextHabitFlowView.swift` | 実装済み |
| F-005 | リレーション登録（同意必須） | `HostApp/Views/S003RelationFlowView.swift`、`HostApp/AppGroupStore.swift` | 実装済み |
| F-006 | キーボード許可誘導 | `HostApp/Views/S004PermissionGuideView.swift` | 実装済み |

## 画面・キーボードUI（S-005〜S-007 / 4.1節）

| 要件 | 実装 | 今回の対応 |
| --- | --- | --- |
| S-005「通常の日本語フリックキーボード（あかさたな配列）」 | `KeyboardExtension/UI/Flick/JapaneseKeyboardView.swift`、`JapaneseInputCore.swift` | **新規作成。** 旧実装は あ/い/う 行だけで え・お行欠落・濁点不可の壊れた配列だった（→削除） |
| 予測変換バー（キーボード本体の直上） | `JapaneseKeyboardView` 内 `PredictionBarView`＋`JapaneseConversionEngine`（azooKey変換） | **新規。** azooKey の `KanaKanjiConverter` でかな漢字変換 |
| ステージバー（予測変換バーのさらに上） | `KeyboardRuntimeRootView` が `StageLayerView` をキーボードの上に重ねる | **重なり順を修正。** 旧実装はステージを全面オーバーレイにしていてキーボードを覆っていた |
| 下部タブ mote+AI / キーボード / 全文表示 | `BottomActionBarView` | 既存（タブのアクティブ条件は要件どおり） |
| mote+AIタブがアクティブなのは質問UI表示中のみ | `BottomActionBarView`（`currentScreen == .askUser` で濃色）、`AppState.isKeyboardTabActive` | 既存 |
| キーボードタブへ切替時に質問フロー中断 | `AppState.switchToKeyboardAndCancelAskUserIfNeeded` / `cancelAskUserFlow` | 既存 |
| チップをタップ順で入力欄へ積み上げ | `AppState.insertChip`（`tappedChipHistory` に追記） | **挙動改善。** ステージバーが常時表示になり、戻った後も続けてチップを積める |
| S-007 全文表示（番号付き一覧） | `FullTextLayerView` | 既存 |

## キーボードの構成（実装後の重なり順）

```
┌─────────────────────────────┐
│ ステージバー（AI候補チップ・候補がある時だけ） │  ← KeyboardRuntimeRootView
├─────────────────────────────┤
│ 予測変換バー（azooKey変換候補）              │  ← JapaneseKeyboardView 内
├─────────────────────────────┤
│ フリックキーボード本体（あかさたな）          │  ← JapaneseKeyboardView 内
├─────────────────────────────┤
│ 下部タブ mote+AI / キーボード / 全文表示      │  ← BottomActionBarView
└─────────────────────────────┘
```

mote+AI質問・全文表示・ローディング・フォールバック・権限ブロックは、キーボードを覆う全面オーバーレイとして表示する（`KeyboardRuntimeRootView.overlayLayer`）。

## 既知の制約 / MVPの割り切り

- フリック入力は **かな直接入力**。濁点/半濁点/小文字トグルは「変換中の連続かな」に対して効く（確定後の文字には効かない）。
- 英字（QWERTY）・数字記号レイヤーはタップ入力。学習・絵文字変換・Zenzai（ニューラル変換）は未使用（[azookey-integration.md](azookey-integration.md) 参照）。
- 変換は入力毎にメインスレッド同期呼び出し。長文で重い場合はデバウンス検討。
- F-001 の画面収録は実機（ReplayKit）前提。シミュレータでは手入力フォールバックに収束する。
