# azooKey リファレンス — モテキー開発向け

azooKey（MIT License）をベースに「モテキー」を構築するにあたり、リポジトリ内の再利用可能なファイル・モジュール・パターンを、モテキーの機能要件（F-001〜F-006）および画面要件（S-001〜S-007）と対応付けてまとめたドキュメントです。

> 補足: S-002「テキストハビットチェック」と S-003「リレーションチェック」の参考画像は検討用モックであり、完成UIではない。ここでは画像そのものではなく、要件上の責務と再利用方針を扱う。

> リポジトリ: https://github.com/azooKey/azooKey
> ライセンス: MIT（フォーク・改変・再配布自由）
> デフォルトブランチ: `main`
> クローン: `git clone https://github.com/azooKey/azooKey --recursive`（サブモジュールあり）

---

## 目次

1. [azooKey 3層アーキテクチャ概要](#1-azookey-3層アーキテクチャ概要)
2. [モテキーで変更が必要なハードコード定数](#2-モテキーで変更が必要なハードコード定数)
3. [MainApp層 — 再利用マップ](#3-mainapp層--再利用マップ)
4. [Keyboard Extension層 — 再利用マップ](#4-keyboard-extension層--再利用マップ)
5. [AzooKeyCore層 — 再利用マップ](#5-azookeycore層--再利用マップ)
6. [機能要件ごとの活用ガイド](#6-機能要件ごとの活用ガイド)
7. [画面要件ごとの活用ガイド](#7-画面要件ごとの活用ガイド)
8. [注意事項・既知の制約](#8-注意事項既知の制約)

---

## 1. azooKey 3層アーキテクチャ概要

```
┌──────────────────────────────────────────────────────────┐
│  MainApp（コンテナアプリ）                                │
│  @main MainApp.swift → ContentView.swift                 │
│  タブ: 使い方 / 着せ替え / 拡張 / 設定                    │
│  チュートリアル: EnableAzooKeyView                        │
├──────────────────────────────────────────────────────────┤
│  Keyboard Extension（キーボード本体）                     │
│  KeyboardViewController : UIInputViewController          │
│  → SwiftUI KeyboardView<AzooKeyKeyboardViewExtension>    │
│  KeyboardActionManager → InputManager → KanaKanjiConverter│
├──────────────────────────────────────────────────────────┤
│  AzooKeyCore（共通ライブラリ Swift Package）              │
│  ├ SwiftUIUtils        ─ SwiftUI汎用ユーティリティ       │
│  ├ KeyboardThemes      ─ テーマ（着せ替え）データ        │
│  ├ KeyboardViews       ─ キーボードUI全体                │
│  ├ AzooKeyUtils        ─ azooKey固有ユーティリティ       │
│  └ KeyboardExtensionUtils ─ Extension用ユーティリティ    │
│  外部依存:                                                │
│  ├ AzooKeyKanaKanjiConverter ─ かな漢字変換エンジン      │
│  └ CustardKit               ─ カスタムキーボード定義     │
└──────────────────────────────────────────────────────────┘
     ↕ App Groups: group.com.azooKey.keyboard
     ↕ UserDefaults(shared) / ファイル共有
```

---

## 2. モテキーで変更が必要なハードコード定数

azooKeyの公式ドキュメント（`docs/advice_for_azooKey_based_development.md`）に明記されている変更必須項目:

| 項目 | 現在の値 | モテキーでの変更先 |
|------|---------|-------------------|
| App Group ID | `group.com.azooKey.keyboard` | `group.com.motekey.shared` |
| Bundle Identifier | `DevEn3.azooKey` | モテキー用に変更 |
| URLスキーム | `azooKey://` | `motekey://` |
| キーボード表示名 | `azooKey`（Info.plist: CFBundleDisplayName） | `モテキー` |
| 誤変換報告用Google Form ID | ハードコード | 削除または無効化 |
| おすすめカスタムタブAPI | ハードコード | 削除または無効化 |

### 変更対象ファイル

| ファイル | 変更内容 |
|---------|---------|
| `MainApp/azooKey.entitlements` | App Group IDを `group.com.motekey.shared` に変更 |
| `Keyboard/Keyboard.entitlements` | 同上 |
| `Keyboard/Info.plist` | `CFBundleDisplayName` を「モテキー」に変更 |
| `MainApp/Info.plist` | `CFBundleDisplayName`、`CFBundleURLSchemes` を変更 |
| `azooKey.xcodeproj` | Bundle Identifier、プロダクト名を全ターゲットで変更 |
| `AzooKeyCore`内の SharedStore 等 | App Group IDの参照を変更 |

---

## 3. MainApp層 — 再利用マップ

### 3.1 エントリポイント・全体構造

| ファイル | 役割 | モテキーでの活用 |
|---------|------|-----------------|
| `MainApp/MainApp.swift` | `@main` エントリポイント。`MainAppStates`（ObservableObject）で状態管理。`ContentView`を起動 | **そのまま改造**。`MainAppStates`にテキストハビット・リレーション情報のプロパティを追加 |
| `MainApp/ContentView.swift` | タブビュー（使い方/着せ替え/拡張/設定）。初回時`EnableAzooKeyView`をフルスクリーンカバーで表示 | **タブ構成を変更**: モテキーでは「セットアップ」「設定」の2タブ程度に簡素化。着せ替え・拡張タブは不要なら削除 |

### 3.2 チュートリアル・キーボード有効化（F-006対応）

| ファイル | 役割 | モテキーでの活用 |
|---------|------|-----------------|
| `MainApp/EnableAzooKeyView/EnableAzooKeyView.swift` | キーボード有効化のステップ型チュートリアル。4段階: `menu` → `append` → `setting` → `finish` | **F-006の核心。大幅に活用可能**。ステップを拡張してモテキーのオンボーディングフロー全体（テキストハビット→リレーション→キーボード許可→画面収録開始）にする |
| `MainApp/EnableAzooKeyView/EnableAzooKeyViewComponent.swift` | チュートリアルUIの再利用コンポーネント（ヘッダー、テキスト、ボタン、画像） | **そのまま再利用**。`EnableAzooKeyViewButton`, `EnableAzooKeyViewText`, `EnableAzooKeyViewHeader` 等のUI部品をモテキーのオンボーディングで使える |
| `MainApp/Utils/checkKeyboardActivation.swift` | キーボードがiOS設定で有効化されているかチェック | **そのまま再利用**。`SharedStore.checkKeyboardActivation()` |

#### EnableAzooKeyViewの再利用パターン

azooKeyのチュートリアルフロー:
```
menu（案内）→ append（設定画面へ誘導）→ setting（初期設定）→ finish（完了）
```

モテキーへの拡張案:
```
welcome（案内）
→ textHabit（テキストハビット登録 = F-004）
→ relation（リレーション登録 = F-005）
→ keyboardSetup（キーボード追加 = F-006の前半）
→ screenRecording（画面収録開始案内 = F-006の後半）
→ finish（完了確認）
```

**重要な実装パターン**: `EnableAzooKeyView.swift` では以下の仕組みが参考になる:
- `@State private var step: Progress` でステップ管理
- `appStates.setTutorialProgress(step)` でUserDefaultsに進捗保存 → アプリ再起動時に途中から再開可能
- `.task {}` で 0.2秒ごとにキーボード有効化をポーリング → 設定画面から戻ったときの自動検知
- `.onReceive(UITextInputMode.currentInputModeDidChangeNotification)` でキーボード切替を検知
- `UIApplication.openSettingsURLString` でiOS設定画面へディープリンク

### 3.3 設定画面

| ファイル | 役割 | モテキーでの活用 |
|---------|------|-----------------|
| `MainApp/Setting/SettingTab.swift` | 設定タブのルートビュー | テキストハビット編集・リレーション編集への導線を追加 |
| `MainApp/Setting/BooleanSetting/BoolSettingView.swift` | Bool型設定のトグルUI | そのまま再利用可能 |
| `MainApp/Setting/KeyboardLayout/` | キーボードレイアウト設定 | モテキーではフリックのみでOKなら簡素化 |
| `MainApp/InternalSetting/ContainerInternalSetting.swift` | アプリ内部設定の管理 | 拡張してモテキー固有設定を追加 |
| `MainApp/InternalSetting/WalkthroughState.swift` | ウォークスルー（初回案内）の表示制御 | そのまま再利用 |

### 3.4 その他の再利用可能なUI部品

| ファイル | 役割 | モテキーでの活用 |
|---------|------|-----------------|
| `MainApp/General/HeaderLogoView.swift` | ロゴ表示ヘッダー | モテキーのロゴに差し替え |
| `MainApp/General/LargeButtonStyle.swift` | 大きなボタンスタイル | オンボーディングのボタンに再利用 |
| `MainApp/General/BottomSheetView.swift` | ボトムシートUI | 設定変更UIに使用可能 |
| `MainApp/General/ImageSlideshowView.swift` | 画像スライドショー | チュートリアル画像表示に使用可能 |

### 3.5 不要・削除候補のファイル

モテキーでは不要になる可能性が高いファイル群:

- `MainApp/Theme/` — 着せ替え機能（モテキーではブランド固定テーマ）
- `MainApp/Customize/` — カスタムタブ編集（CustardKit関連）
- `MainApp/Tips/` — azooKey固有のTips記事群
- `MainApp/Setting/AdditionalDict/` — ユーザー辞書管理
- `MainApp/Setting/Zenzai/` — Zenzai設定（ニューラルかな漢字変換）
- `MainApp/Setting/ContactImportSetting/` — 連絡先インポート
- `MainApp/Setting/Contribution/` — 寄付設定

---

## 4. Keyboard Extension層 — 再利用マップ

### 4.1 KeyboardViewController（最重要ファイル）

**ファイル**: `Keyboard/Display/KeyboardViewController.swift`

このファイルがキーボードExtensionのエントリポイント。`UIInputViewController` を継承。

#### 再利用ポイント

| 機能 | 実装箇所 | モテキーでの活用 |
|------|---------|-----------------|
| SwiftUIホスティング | `KeyboardHostingController<Content: View>` + `setupKeyboardView()` | **そのまま再利用**。SwiftUIでキーボードUIを構築できる |
| キーボード高さ制御 | `keyboardHeightConstraint`, `setKeyboardHeight(to:)`, `updateScreenHeight()` | **そのまま再利用**。ステージUI表示時の高さ拡張に必須 |
| テキスト挿入 | `self.textDocumentProxy` | **そのまま再利用**。生成メッセージの送信に使用 |
| 向き・サイズ対応 | `applySizeUpdate()`, `viewWillTransition(to:with:)` | そのまま再利用 |
| テーマ適用 | `getCurrentTheme()` | モテキー固有テーマに変更 |
| アプリ起動 | `openApp(scheme:)`, `openURL(_:)` | キーボードからモテキー本体を開くときに使用 |
| Full Accessチェック | `self.hasFullAccess` → `SemiStaticStates.shared.setHasFullAccess()` | モテキーではフルアクセス必須 |

#### キーボードUIの注入パターン

```swift
// azooKeyの実装パターン
struct Keyboard: View {
    var theme: AzooKeyTheme
    var body: some View {
        KeyboardView<AzooKeyKeyboardViewExtension>()
            .themeEnvironment(theme)
            .environment(\.userActionManager, KeyboardViewController.action)
            .environmentObject(KeyboardViewController.variableStates)
    }
}
```

モテキーでは `AzooKeyKeyboardViewExtension` を独自の `MoteKeyKeyboardViewExtension` に差し替え、`ApplicationSpecificKeyboardViewExtension` プロトコルに準拠させることでカスタマイズする。

#### upsideComponent（上部拡張領域）

`VariableStates.upsideComponent` がキーボード上部に追加コンポーネントを表示する仕組み。これが**ステージUI（F-003）のベース**になる。

```swift
// KeyboardViewController.swift 内の関連箇所:
// upsideComponent の高さを計算してキーボード全体の高さに加算
let upsideComponentHeight = upsideComponent.map { component in
    Design.upsideComponentHeight(component, orientation: ...)
} ?? 0
let totalHeight = bodyHeight + upsideComponentHeight + Design.keyboardScreenBottomPadding
```

- `prepareScreenHeight(for component:)` で高さを事前準備
- `updateScreenHeight()` で制約を更新
- 既に `supplementaryCandidates`（追加変換候補）や `reportSuggestion`（誤変換報告）がupsideComponentとして実装されている

→ モテキーでは `UpsideComponent` に `.stage`, `.askUserInput` 等の新しいケースを追加すればよい。

### 4.2 アクション管理

| ファイル | 役割 | モテキーでの活用 |
|---------|------|-----------------|
| `Keyboard/Display/KeyboardActionManager.swift` | `UserActionManager` を継承。キーのタップ → `ActionType` に変換 → `doAction()` で実行 | **拡張して使う**。新しいActionType（例: `.captureScreen`, `.generateReply`）を追加 |
| `Keyboard/Display/InputManager.swift` | テキスト入力・変換・カーソル管理の中核 | **そのまま再利用**。通常キーボードモードでの日本語入力はこれに任せる |
| `Keyboard/Display/LiveConversionManager.swift` | ライブ変換（リアルタイムかな漢字変換） | そのまま再利用 |
| `Keyboard/Display/PredictionManager.swift` | 予測変換管理 | そのまま再利用 |

#### ActionType の拡張

`KeyboardActionManager.doAction()` 内の `switch action` に以下のモテキー固有アクションを追加できる:

```swift
// 追加するActionTypeの案:
case .captureScreen       // `mote+AI` タブ押下 → App Groupから画像取得 → Gemini Vision API
case .startAskUser        // アスクユーザーインプット開始
case .answerQuestion(Int) // 質問への回答選択
case .generateReply       // 返信文生成
case .insertStageChip(String)  // ステージのチップをテキストフィールドに挿入
case .switchToAIMode      // 通常キーボード → AI機能画面の切り替え
```

### 4.3 テキスト挿入の仕組み

`textDocumentProxy` を使ったテキスト操作は `InputManager` 経由で行われる。モテキーのステージ送信で必要な操作:

```swift
// テキストの挿入（InputManager経由）
self.inputManager.input(text: "生成されたメッセージ", simpleInsert: true, inputStyle: .direct)

// 直接textDocumentProxyを使う場合
self.textDocumentProxy.insertText("テキスト")

// 改行で送信（LINEでの送信相当）
self.textDocumentProxy.insertText("\n")
```

### 4.4 SharedStoreとApp Groupデータ共有

`KeyboardViewController` 内:
```swift
private static let variableStates = VariableStates(
    ...
    userDefaults: UserDefaults.standard,
    sharedUserDefaults: SharedStore.userDefaults  // ← App Group経由の共有UserDefaults
)
```

モテキーでは `SharedStore.userDefaults` を通じて以下のデータを読み書きする:
- テキストハビット情報（F-004で保存、Keyboard Extensionで読み込み）
- リレーション情報（F-005で保存、Keyboard Extensionで読み込み）
- 最新画面フレーム画像のファイルパス（Broadcast Extensionで書き込み、Keyboard Extensionで読み込み）

---

## 5. AzooKeyCore層 — 再利用マップ

### 5.1 Package.swift — モジュール構成

```
AzooKeyCore/
├─ SwiftUIUtils/          ─ SwiftUI汎用ユーティリティ
├─ KeyboardThemes/        ─ テーマデータ (ThemeData, AzooKeyTheme)
├─ KeyboardViews/         ─ キーボードUI全体 ★最重要
├─ AzooKeyUtils/          ─ azooKey固有ユーティリティ
├─ KeyboardExtensionUtils/─ Extension用ユーティリティ（SharedStore等）
外部依存:
├─ AzooKeyKanaKanjiConverter ─ かな漢字変換エンジン (Zenzai含む)
└─ CustardKit               ─ カスタムキーボード定義
```

**最低要件: iOS 17、Swift 6.2、C++相互運用有効**

### 5.2 KeyboardViews（最重要モジュール）

キーボードUIの全体を実装しているモジュール。

#### 主要コンポーネント

| コンポーネント | 役割 | モテキーでの活用 |
|---------------|------|-----------------|
| `KeyboardView<Extension>` | キーボード全体のルートビュー | **そのまま再利用**。ジェネリックパラメータで挙動をカスタマイズ |
| Result Bar（リザルトバー） | 変換候補を横スクロールで表示するバー | そのまま再利用。**ステージUI（F-003）のベース候補** |
| Tab Bar（タブバー） | キーボード下部の切り替えバー（日本語/英語/絵文字等） | AI機能タブへの切り替えボタンを追加 |
| Cursor Bar（カーソルバー） | カーソル移動用バー | そのまま再利用 |
| Flick Keyboard | フリック入力キーボード | **S-005 通常キーボード画面としてそのまま再利用** |
| `VariableStates` | キーボード全体の共有状態（ObservableObject） | **拡張して使う**。AI状態（質問/回答/生成中/ステージ）を追加 |
| `UserActionManager` | ユーザー操作のアクションハンドラ（プロトコル） | 継承して `MoteKeyActionManager` を実装 |

#### ApplicationSpecificKeyboardViewExtension プロトコル

```swift
// AzooKeyCore/README.md に記載のパターン:
var body: some View {
    KeyboardView<AppSpecificExtension>()
        .themeEnvironment(theme)
        .environment(\.userActionManager, KeyboardActionManager())
        .environmentObject(variableStates)
}
```

`ApplicationSpecificKeyboardViewExtension` を実装した型を注入することで、アプリ固有の設定やビヘイビアをKeyboardViewに渡せる。azooKeyでは `AzooKeyKeyboardViewExtension` として実装。

→ モテキーでは `MoteKeyKeyboardViewExtension` を作り、以下を注入:
- ユーザー設定（テキストハビット、リレーション）
- AI機能のUI
- カスタムテーマ

#### UpsideComponent（上部拡張コンポーネント）

キーボード本体の**上に追加表示**されるコンポーネントの仕組み。`VariableStates.upsideComponent` で管理。

既存のケース:
- `.supplementaryCandidates` — 追加変換候補の表示
- `.reportSuggestion` — 誤変換報告のUI

→ モテキーで追加するケース:
- `.askUserInput` — アスクユーザーインプットUI（F-002）
- `.stage` — ステージUI（F-003）
- `.aiLoading` — AI生成中のローディング

高さは `Design.upsideComponentHeight()` で計算され、自動的にキーボードの高さ制約が更新される。

### 5.3 KeyboardThemes

| 機能 | 説明 | モテキーでの活用 |
|------|------|-----------------|
| `ThemeData` / `AzooKeyTheme` | テーマのデータ構造（色、フォント等） | モテキーのブランドカラーテーマを定義 |
| `ThemeIndexManager` | テーマの選択・切り替え管理 | ライト/ダークモード対応 |
| `.themeEnvironment(theme)` | テーマをSwiftUI Environmentとして注入 | そのまま利用 |

### 5.4 KeyboardExtensionUtils

| 機能 | 説明 | モテキーでの活用 |
|------|------|-----------------|
| `SharedStore` | App Group経由のデータ共有ユーティリティ | **最重要**。`SharedStore.userDefaults` でMainApp↔Keyboard間データ共有 |
| `SemiStaticStates` | フルアクセス状態、画面幅等の半静的情報 | そのまま再利用 |
| `@KeyboardSetting` property wrapper | キーボード設定値の読み書き | モテキー固有の設定項目を追加登録 |

#### SharedStoreの活用パターン

```swift
// MainApp側で保存
let shared = UserDefaults(suiteName: "group.com.motekey.shared")!
shared.set(textHabitData, forKey: "textHabit")
shared.set(relationData, forKey: "relation")

// Keyboard Extension側で読み取り
let shared = UserDefaults(suiteName: "group.com.motekey.shared")!
let textHabit = shared.string(forKey: "textHabit")
let relation = shared.string(forKey: "relation")
```

ファイル共有（画面フレーム画像用）:
```swift
// Broadcast Extension側で書き込み
let containerURL = FileManager.default.containerURL(
    forSecurityApplicationGroupIdentifier: "group.com.motekey.shared"
)!
let frameURL = containerURL.appendingPathComponent("latest_frame.jpg")
try jpegData.write(to: frameURL)

// Keyboard Extension側で読み取り
let frameData = try Data(contentsOf: frameURL)
```

### 5.5 CustardKit（カスタムキーボード定義）

**リポジトリ**: https://github.com/ensan-hcl/CustardKit

CustardKitはカスタムキーボードタブを定義するためのフレームワーク。`Custard` = Custom Keyboard の略。

| 機能 | 説明 | モテキーでの活用 |
|------|------|-----------------|
| カスタムタブ定義 | JSON/Swiftでカスタムキーボードレイアウトを定義 | `mote+AI` タブボタン等のカスタムキーを定義可能 |
| カスタムアクション | キーに任意のアクションを割り当て | `.openApp(scheme:)` でモテキー本体を開く等 |
| グリッド/スクロールレイアウト | キーの配置方法 | AI機能画面のボタンレイアウトに使用可能 |
| タブバー管理 | タブの追加・切り替え | AI機能タブの追加 |

ただし、CustardKitは**静的なキーレイアウト定義**に適しているため、動的なAI応答UI（アスクユーザーインプット等）には直接使えない。動的UIは SwiftUIで直接実装してupsideComponentまたはタブ切り替えで表示する方が適切。

### 5.6 AzooKeyKanaKanjiConverter

**リポジトリ**: https://github.com/azooKey/AzooKeyKanaKanjiConverter

かな漢字変換エンジン。Zenzai（ニューラルかな漢字変換）を含む。

モテキーでは通常キーボードモード（S-005）での日本語入力に**そのまま活用**。AI機能と独立して動作する。

---

## 6. 機能要件ごとの活用ガイド

### F-001: 画面コンテキスト取得機能

| 必要な実装 | azooKeyの活用 | 新規実装 |
|-----------|---------------|---------|
| `mote+AI` タブボタン | `ActionType` に `.captureScreen` を追加。タブバー押下を起点に処理開始 | タブボタンのUI（CustardKit or SwiftUI直接） |
| App Groupから画像取得 | `SharedStore` / `FileManager.containerURL(forSecurityApplicationGroupIdentifier:)` | 画像読み取りロジック |
| Gemini Vision API呼び出し | フルアクセス時のURLSession利用パターン（azooKeyでは誤変換報告で外部通信あり） | API通信、リクエスト/レスポンス処理 |
| Broadcast Extension | **azooKeyに該当なし** | **完全新規**。ReplayKit Broadcast Upload Extension |

### F-002: アスクユーザーインプット機能

| 必要な実装 | azooKeyの活用 | 新規実装 |
|-----------|---------------|---------|
| 質問一括生成API呼び出し | フルアクセス時のURLSession利用パターン | Gemini APIへの1回の呼び出しで3問一括生成（分岐なし） |
| 質問表示UI | `mote+AI` タブとして表示するか、`UpsideComponent` に `.askUserInput` を追加して表示 | 質問テキスト＋3つの選択肢ボタンのSwiftUIビュー |
| 選択肢タップ時のアクション | `ActionType` に `.answerQuestion(Int)` を追加 | 回答を保持し、保持済みの次の質問を即座に表示（API呼び出し不要） |
| 画面遷移（3回の質問） | `VariableStates` に質問ステート管理を追加 | 状態遷移ロジック |

### F-003: ステージ（自動生成・編集）機能

| 必要な実装 | azooKeyの活用 | 新規実装 |
|-----------|---------------|---------|
| チップ表示UI | `UpsideComponent` に `.stage` を追加。Result Barのスクロール表示パターンを参考に | チップ（タグ）形式のSwiftUIビュー |
| 送信前編集 | 既存のメッセージアプリ側入力欄を利用 | チップ挿入後の編集ルール整理 |
| チップ反映 | `textDocumentProxy.insertText()` でテキストフィールドに挿入 | チップをタップした順で入力欄へ反映 |
| 送信 | 既存のメッセージアプリ側UIを利用 | モテキー側で専用送信ボタンは持たない |
| キーボード高さ拡張 | `prepareScreenHeight(for:)` / `setKeyboardHeight(to:)` | ステージ表示時の高さ計算 |

### F-004: テキストハビット登録機能

| 必要な実装 | azooKeyの活用 | 新規実装 |
|-----------|---------------|---------|
| 登録画面UI | `EnableAzooKeyView` のステップ型UIパターン | テキストスタイル入力フォーム |
| データ保存 | `SharedStore.userDefaults`（App Group UserDefaults） | テキストハビットのデータモデル、保存/読み取りロジック |
| 後から編集 | `SettingTab` に編集画面を追加 | 設定画面内の編集ビュー |

### F-005: リレーション登録機能

| 必要な実装 | azooKeyの活用 | 新規実装 |
|-----------|---------------|---------|
| 登録画面UI | `EnableAzooKeyView` のステップ型UIパターン | リレーション入力フォーム、同意チェックボックス |
| データ保存 | `SharedStore.userDefaults` | リレーションのデータモデル |
| 同意チェックボックス | — | チェックボックスUI + ボタンの活性/非活性制御 |

### F-006: キーボード許可誘導機能

| 必要な実装 | azooKeyの活用 | 新規実装 |
|-----------|---------------|---------|
| キーボード追加案内 | **`EnableAzooKeyView.swift` をほぼそのまま流用**。手順説明、iOS設定画面へのディープリンク（`UIApplication.openSettingsURLString`）、キーボード有効化のポーリングチェック | 文言・画像の差し替え |
| フルアクセス案内 | azooKeyでも `RequestsOpenAccess: true` で実装済み | フルアクセスの必要性の説明文 |
| 画面収録開始案内 | **azooKeyに該当なし** | **新規**。コントロールセンターからの画面収録開始手順の案内UI |

---

## 7. 画面要件ごとの活用ガイド

### S-001: アプリトップ画面

- **ベース**: `ContentView.swift` + `EnableAzooKeyView.swift`
- 初回は `EnableAzooKeyView` 相当のオンボーディングフローを `fullScreenCover` で表示
- 2回目以降は簡素なホーム画面（設定編集への導線）

### S-002: テキストハビットチェック画面

- **ベース**: `EnableAzooKeyView` のステップ型UIパターン
- **新規実装**: 10シチュエーション分の返信サンプル収集UI + Gemini APIによるテキストハビット解析フロー
- データ保存は `SharedStore.userDefaults` 経由

### S-003: リレーションチェック画面

- **ベース**: `EnableAzooKeyView` のステップ型UIパターン
- **新規実装**: リレーション入力フォーム + 同意チェックボックス
- `@State private var isAgreed = false` でチェックボックス管理、ボタンの `.disabled(!isAgreed)`

### S-004: キーボード許可 & 画面収録開始画面

- **ベース**: `EnableAzooKeyView.swift` の `.append` ステップを**そのまま流用**
- キーボード有効化チェック: `SharedStore.checkKeyboardActivation()` + ポーリング
- 画面収録開始: 手順説明UIを新規追加

### S-005: 通常キーボード画面

- **ベース**: **azooKeyのキーボードUIをそのまま使用**
- `KeyboardView<MoteKeyKeyboardViewExtension>()` として表示
- フリックキーボード + かな漢字変換 + 予測変換バー（Result Bar）がそのまま動作
- タブバーに `mote+AI` / `キーボード` / `全文表示` の切り替え導線を追加
- `キーボード` タブがアクティブ表示のときだけ、通常キーボード画面を表示する

### S-006: `mote+AI`（アスクユーザー）タブ

- **役割**: アスクユーザーインプットを表示する専用タブ
- **推奨**: `moveTab` で専用のカスタムタブに切り替え、質問と選択肢に表示領域を十分割り当てる
- タブ押下時に画面文脈抽出を開始し、3問の回答完了後に生成結果の確認状態（S-007）へ遷移する
- 各質問の選択肢は3つ固定とし、`mote+AI` タブがアクティブ表示なのは質問UI表示中のみとする

### S-007: ステージ / 全文表示確認状態

- **実装方式**: `キーボード` タブでは `UpsideComponent` として予測変換バーの上に表示し、`全文表示` タブでは同じチップ群の全文一覧を表示
- チップはSwiftUIの `ScrollView(.horizontal)` + `ForEach` で並べる
- 各チップはタップでLINE入力欄へ反映し、その後の編集は既存の入力欄で行う
- MVPでは専用のドラッグ並び替えUIは持たず、複数チップをタップした順をそのまま入力欄の並びとする
- 送信は既存のメッセージアプリ側の送信UIを使う
- `全文表示` タブがアクティブ表示なのは、チップの全文一覧が表示されているときのみとする

---

## 8. 注意事項・既知の制約

### 8.1 メモリリーク問題

`docs/view_controller_memory_leak.md` に記載:
- `KeyboardViewController` のインスタンスがiOSによって破棄されない問題がある
- 対策: static変数を多用（`private static var`, `private static let`）してインスタンス増加の影響を最小化
- 15インスタンス超過で `fatalError()` で強制終了 → iOS が再起動してメモリ解放

→ モテキーでも同様の対策を維持。AI関連のオブジェクトもstatic化するか、メモリ使用量に注意。

### 8.2 メモリ上限

- キーボードExtension: 約50MB
- Broadcast Upload Extension: 約50MB
- Gemini API呼び出し用の画像データはダウンスケール+JPEG圧縮で100-150KB以下に抑える
- Zenzai（ニューラルかな漢字変換のGGUFモデル）はメモリを相当消費する → モテキーではZenzaiを無効化してメモリ余裕を確保することを検討

### 8.3 データ保存の仕組み

`docs/advice_for_azooKey_based_development.md` より:
> azooKeyでは歴史的事情により、データの保存がナイーブな方法で行われています。具体的には、UserDefaultsと内部ディレクトリへのファイルの保存によって管理されており、Core DataやRealmなどユーザデータを保存するのに適した仕組みは利用していません。

→ モテキーではハッカソンMVPのため、azooKeyと同じUserDefaults方式で問題ない。将来的にはSwiftData等への移行を検討。

### 8.4 フルアクセスの前提

`docs/policies/full_access.md` より:
- azooKeyではフルアクセスは「必要な人だけオンにする」方針
- モテキーでは**フルアクセス必須**（ネットワーク通信 + App Groupアクセスに必要）
- `Keyboard/Info.plist` の `RequestsOpenAccess` は既に `true`

### 8.5 ビルド要件

- **Xcode**: 最新版
- **Apple Developer Account**: 無料でOK（実機テストまで）
- **クローン**: `--recursive` オプション必須（辞書・Zenzaiモデルがサブモジュール）
- **Swift 6.2** + **C++相互運用** (`interoperabilityMode(.Cxx)`)
- ターゲット: **iOS 17以上**

### 8.6 キーボードの高さ制御

`docs/keyboard_layout_behavior.md` より:
- 「縦・横」「iPhone・iPad」で4パターンのレイアウト
- まず幅を取得 → 幅から高さを決定 → キーのサイズを決定
- デバイス回転時のバグが多い領域
- `keyboardHeightConstraint` で高さを動的に変更可能

→ ステージUI等で高さを拡張する場合、`upsideComponent` の仕組みを使えば自動的に高さ制約が更新される。

---

## 付録: ファイル一覧と対応マトリクス

### MainApp/ — 全Swiftファイル

| ファイル | モテキーでの利用 |
|---------|-----------------|
| `MainApp.swift` | 改造して使う |
| `ContentView.swift` | 改造して使う（タブ構成変更） |
| `EnableAzooKeyView/EnableAzooKeyView.swift` | **F-006の核心。大幅活用** |
| `EnableAzooKeyView/EnableAzooKeyViewComponent.swift` | **UI部品をそのまま再利用** |
| `InternalSetting/ContainerInternalSetting.swift` | 拡張して使う |
| `InternalSetting/WalkthroughState.swift` | そのまま再利用 |
| `Setting/SettingTab.swift` | 改造して使う |
| `Setting/BooleanSetting/BoolSettingView.swift` | そのまま再利用 |
| `General/HeaderLogoView.swift` | ロゴ差し替えで再利用 |
| `General/LargeButtonStyle.swift` | そのまま再利用 |
| `General/BottomSheetView.swift` | 必要に応じて再利用 |
| `Utils/checkKeyboardActivation.swift` | **そのまま再利用** |
| その他 Theme/, Customize/, Tips/ 等 | 削除候補 |

### Keyboard/ — 全Swiftファイル

| ファイル | モテキーでの利用 |
|---------|-----------------|
| `Display/KeyboardViewController.swift` | **最重要。改造して使う** |
| `Display/KeyboardActionManager.swift` | **拡張して使う（AI機能アクション追加）** |
| `Display/InputManager.swift` | そのまま再利用 |
| `Display/LiveConversionManager.swift` | そのまま再利用 |
| `Display/PredictionManager.swift` | そのまま再利用 |
| `Display/ReportSubmissionHelper.swift` | 削除候補（誤変換報告はモテキーに不要） |
| `Display/KeyboardActionManager+Reporting.swift` | 削除候補 |

### AzooKeyCore/ — モジュール別

| モジュール | モテキーでの利用 |
|-----------|-----------------|
| `KeyboardViews` | **最重要。キーボードUIの全基盤** |
| `KeyboardExtensionUtils` | **重要。SharedStore等** |
| `KeyboardThemes` | テーマ固定で簡素化 |
| `SwiftUIUtils` | そのまま再利用 |
| `AzooKeyUtils` | 改造して使う |

---

## 9. モテキー新規追加ファイル構成案

azooKeyのフォークに対して、以下のファイルを新規追加する想定:

```
Keyboard/
├── Display/
│   ├── KeyboardViewController.swift     ← 既存を改修
│   ├── KeyboardActionManager.swift      ← 既存を拡張（AI機能アクション追加）
│   └── ...（既存ファイルは維持）
├── MoteKey/                             ← 新規ディレクトリ
│   ├── MoteKeyStateManager.swift        ← 状態管理（通常→mote+AI起動→Q1-Q3→ステージの遷移）
│   ├── GeminiAPIClient.swift            ← Gemini API通信クライアント
│   ├── Views/
│   │   ├── MoteAITabButton.swift        ← `mote+AI` タブ起動ボタン
│   │   ├── AskUserView.swift            ← アスクユーザーインプットUI
│   │   ├── StageView.swift              ← ステージUI（チップ表示・入力欄反映）
│   │   └── ChipView.swift               ← 個別チップのビュー
│   └── Models/
│       ├── ChatContext.swift             ← チャット文脈モデル
│       ├── AskUserQuestion.swift         ← 質問・選択肢モデル
│       └── UserResponse.swift            ← ユーザー回答モデル

MainApp/
├── MoteKey/                             ← 新規ディレクトリ
│   ├── TextHabitView.swift              ← テキストハビット登録画面（F-004, S-002）
│   ├── RelationView.swift               ← リレーション登録画面（F-005, S-003）
│   └── MoteKeyOnboardingView.swift      ← オンボーディング全体フロー

BroadcastExtension/                      ← 完全新規ターゲット
├── BroadcastExtension.entitlements      ← App Group設定
├── Info.plist
└── SampleHandler.swift                  ← ReplayKit Broadcast Upload Extension
```

### KeyboardViewの拡張イメージ

```swift
// 現在のazooKey構造（概念的）
VStack(spacing: 0) {
    CandidateView()      // 予測変換エリア
    KeyboardBody()       // フリック or QWERTYキーボード
}

// モテキー拡張後
VStack(spacing: 0) {
    if stateManager.showStage {
        StageView()      // ← 新規: ステージ枠（チップ表示）
    }
    CandidateView()      // 予測変換エリア（そのまま維持）

    // モードに応じた切り替え
    switch stateManager.currentMode {
    case .keyboard:
        KeyboardBody()           // 通常キーボード（S-005）
    case .askUser:
        AskUserView()            // ← 新規: アスクユーザーUI（S-006）
    case .stageEdit:
        StageEditView()          // ← 新規: ステージ編集ビュー（S-007）
    }
}
```

### 高さの動的制御コード例

```swift
// KeyboardViewController内
func updateKeyboardHeight(for mode: MoteKeyMode) {
    let baseHeight: CGFloat = 271  // 通常キーボードの高さ
    let stageHeight: CGFloat = 80  // ステージ枠の追加高さ

    switch mode {
    case .keyboard:
        heightConstraint.constant = baseHeight
    case .keyboardWithStage:
        heightConstraint.constant = baseHeight + stageHeight
    case .askUser:
        heightConstraint.constant = baseHeight  // キーボード本体を差し替え
    }
    UIView.animate(withDuration: 0.25) {
        self.view.layoutIfNeeded()
    }
}
```

### ステージからのテキスト送信コード例

```swift
// ステージの「送信」ボタン押下時
func sendStagedMessage(chips: [Chip]) {
    let fullMessage = chips.map { $0.text }.joined(separator: "\n")
    textDocumentProxy.insertText(fullMessage)
}
```

---

## 更新履歴

| 日付 | 変更内容 |
|------|---------|
| 2026-03-21 | 初版作成 |
