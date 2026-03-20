# モテキー 統合UI仕様書 v1.2
## SwiftUI実装リファレンス — ホストアプリ + キーボード拡張

> **読み方の原則**
> 本書は [要件定義書 v1.7](../requirements.md) を絶対的な技術制約として前提とする。
> すべての実装判断は `requirements.md` の制約に従い、本書はその制約の上でユーザー体験を定義する。
> S-002「テキストハビットチェック」と S-003「リレーションチェック」の参考画像は検討用モックであり、完成UIではない。画像との差異がある場合は本書のテキスト仕様を正とする。
> Vibeコーディングにおいて「エラーが出ないこと」を最優先とし、すべての実装パターンはSwiftUIのベストプラクティスに則る。

---

## 目次

### Part 1: 共通設計システム
- 1-1. アーキテクチャ概要
- 1-2. デザイントークン（色・フォント・スペーシング）
- 1-3. 共通コンポーネントカタログ
- 1-4. アニメーション・ハプティクスカタログ

### Part 2: ホストアプリ（設定用）
- 2-1. アプリ全体の状態管理
- 2-2. S-001 ホーム画面
- 2-3. S-002-Q1〜Q10 テキストハビット収集画面
- 2-4. S-002-LOADING 解析中画面
- 2-5. S-003-1〜4, DONE リレーション登録画面
- 2-6. S-004, S-004-ERROR キーボード許可・画面収録案内画面
- 2-7. S-004-COMPLETE 初期設定完了画面
- 2-8. S-004-TUTORIAL チュートリアル画面
- 2-9. ホストアプリ遷移定義

### Part 3: キーボード拡張（キーボード用）
- 3-1. Extension全体の状態管理
- 3-2. KBD-S-005 通常キーボード画面
- 3-3. KBD-S-006 返信考案アスクユーザー画面
- 3-4. KBD-S-006.5 AI思考中ローディング画面
- 3-5. KBD-S-007 ステージ画面
- 3-6. KBD-S-008 全文表示画面
- 3-7. KBD-S-009 手入力フォールバック画面
- 3-8. KBD-S-010 権限未許可ブロック画面
- 3-9. BottomActionBar 常時表示バー
- 3-10. Extension遷移定義

### Part 4: 実装リファレンス
- 4-1. SwiftUIエラー防止パターン集
- 4-2. azooKey統合インターフェース
- 4-3. App Group共有データスキーマ
- 4-4. 実装チェックリスト

---

# Part 1: 共通設計システム

## 1-1. アーキテクチャ概要

### アプリ構成

```
モテキー（Xcode Project）
├── HostApp Target（設定用アプリ）
│   ├── NavigationStack ベースのルーティング ✅（ホストアプリは使用可能）
│   ├── SwiftUI App / Scene
│   └── URLスキーム受信処理（motekey://）
│
├── KeyboardExtension Target（キーボード拡張）
│   ├── UIInputViewController（azooKey）
│   ├── UIHostingController<MoteKeyRootView>
│   ├── ZStackベースのインプレース切り替え ✅（モーダル禁止）
│   └── App Group経由でHostAppとデータ共有
│
└── Shared Framework（共有コード）
    ├── AppGroupKeys.swift
    ├── TextStyleProfile.swift（AI解析結果）
    └── RelationProfile.swift（リレーション情報）
```

### データフロー

```
[HostApp] テキストハビット収集 → Gemini API → TextStyleProfile
[HostApp] リレーション登録    → 直接保存   → RelationProfile
[HostApp] キーボード・画面収録案内 → セットアップ完了フラグ更新

App Group (UserDefaults suite: "group.com.motekey.shared")
      ↓ 読み取り
[KeyboardExtension] AI返信生成リクエスト → TextStyleProfile + RelationProfile を含める
```

---

## 1-2. デザイントークン

### カラーパレット

すべての色はAsset Catalogのカラーセットで定義する。ライト/ダークモード両対応。
コードでは `Color("TokenName")` または `UIColor(named: "TokenName")` で参照する。

```
// Colors.xcassets に以下を登録する

// ── ブランドカラー ──────────────────────────────────
AccentPink          Light: #F06292   Dark: #F48FB1
AccentPinkDark      Light: #E91E8C   Dark: #F06292  （タップ時・強調）

// ── バックグラウンド ──────────────────────────────────
BgPrimary           = UIColor.systemBackground          （自動対応）
BgGrouped           = UIColor.systemGroupedBackground   （自動対応）
BgSecondary         = UIColor.secondarySystemBackground （自動対応）
BgTertiary          = UIColor.tertiarySystemBackground  （自動対応）

// ── テキスト ──────────────────────────────────────────
TextPrimary         = UIColor.label                     （自動対応）
TextSecondary       = UIColor.secondaryLabel            （自動対応）
TextTertiary        = UIColor.tertiaryLabel             （自動対応）
TextOnAccent        Light: #FFFFFF   Dark: #FFFFFF

// ── ボーダー・区切り ─────────────────────────────────
Separator           = UIColor.separator                 （自動対応）
Border              = UIColor.opaqueSeparator           （自動対応）

// ── ステート ──────────────────────────────────────────
ErrorRed            Light: #FF3B30   Dark: #FF453A
SuccessGreen        Light: #34C759   Dark: #30D158
WarningYellow       Light: #FF9500   Dark: #FF9F0A

// ── オーバーレイ ──────────────────────────────────────
VeilBackground      Light: rgba(0,0,0,0.45)  Dark: rgba(0,0,0,0.60)
```

> **実装ノート**: `UIColor.systemXxx` はコードで直接使用可能。カスタム色のみAsset Catalogに登録する。

### タイポグラフィ

外部フォント不使用。SF Proシステムフォントのみ使用。

```swift
// Typography.swift — 再利用可能なTextStyle定義
extension Font {
    // ホストアプリ
    static let moteTitle    = Font.system(size: 22, weight: .bold)
    static let moteHeadline = Font.system(size: 17, weight: .semibold)
    static let moteBody     = Font.system(size: 15, weight: .regular)
    static let moteCaption  = Font.system(size: 12, weight: .regular)
    static let moteButton   = Font.system(size: 16, weight: .semibold)

    // キーボードExtension（高さが限られるため小さめ）
    static let kbdChip      = Font.system(size: 14, weight: .regular)
    static let kbdCaption   = Font.system(size: 11, weight: .regular)
    static let kbdQuestion  = Font.system(size: 15, weight: .medium)
    static let kbdButton    = Font.system(size: 14, weight: .semibold)
}
```

### スペーシング・角丸

```swift
// Spacing.swift
enum Spacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 24
}

enum Radius {
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let chip: CGFloat = 20   // チップの角丸
    static let card: CGFloat = 14   // カードの角丸
    static let button: CGFloat = 12 // ボタンの角丸
}
```

---

## 1-3. 共通コンポーネントカタログ

### PinkPrimaryButton（ホストアプリ用メインボタン）

```swift
// PinkPrimaryButton.swift
struct PinkPrimaryButton: View {
    let title: String
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.moteButton)
                .foregroundStyle(Color("TextOnAccent"))
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    isEnabled
                        ? Color("AccentPink")
                        : Color("AccentPink").opacity(0.4)
                )
                .clipShape(RoundedRectangle(cornerRadius: Radius.button))
        }
        .disabled(!isEnabled)
    }
}
```

### LinkTextButton（リンク形式のテキストボタン）

```swift
// LinkTextButton.swift
struct LinkTextButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.moteCaption)
                .foregroundStyle(Color("TextSecondary"))
                .underline()
        }
    }
}
```

### ProgressBar（質問フロー用）

```swift
// MoteProgressBar.swift
struct MoteProgressBar: View {
    let current: Int
    let total: Int

    var progress: Double { Double(current) / Double(total) }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color("BgSecondary"))
                    .frame(height: 4)
                Capsule()
                    .fill(Color("AccentPink"))
                    .frame(width: geo.size.width * progress, height: 4)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: current)
            }
        }
        .frame(height: 4)
    }
}
```

### ChatBubble（トーク画面用吹き出し）

```swift
// ChatBubble.swift
enum BubbleSide { case leading, trailing }

struct ChatBubble: View {
    let text: String
    let side: BubbleSide

    private var isTrailing: Bool { side == .trailing }
    private var bubbleColor: Color {
        isTrailing ? Color("AccentPink") : Color("BgSecondary")
    }
    private var textColor: Color {
        isTrailing ? Color("TextOnAccent") : Color("TextPrimary")
    }

    var body: some View {
        HStack {
            if isTrailing { Spacer(minLength: 60) }
            Text(text)
                .font(.moteBody)
                .foregroundStyle(textColor)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background(bubbleColor)
                .clipShape(
                    RoundedRectangle(cornerRadius: Radius.md)
                        // 発話側の角だけ少し角張らせる（オプション）
                )
            if !isTrailing { Spacer(minLength: 60) }
        }
    }
}
```

### SelectionChip（選択肢チップ）

```swift
// SelectionChip.swift
struct SelectionChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.moteBody)
                .foregroundStyle(
                    isSelected ? Color("TextOnAccent") : Color("TextPrimary")
                )
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.md)
                .frame(maxWidth: .infinity)
                .background(
                    isSelected
                        ? Color("AccentPink")
                        : Color("BgSecondary")
                )
                .clipShape(RoundedRectangle(cornerRadius: Radius.button))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.button)
                        .stroke(
                            isSelected ? Color.clear : Color("Border"),
                            lineWidth: 1
                        )
                )
        }
        .animation(.snappy(duration: 0.15), value: isSelected)
    }
}
```

---

## 1-4. アニメーション・ハプティクスカタログ

### アニメーション定義

```swift
// Animations.swift
extension Animation {
    // 画面フェード（基本遷移）
    static let screenFade = Animation.easeOut(duration: 0.2)

    // ボタンタップ縮小
    static let buttonBounce = Animation.spring(response: 0.2, dampingFraction: 0.6)

    // 選択肢の背景色変化
    static let selectionHighlight = Animation.snappy(duration: 0.15)

    // チップスライドイン
    static let chipSlideIn = Animation.spring(response: 0.35, dampingFraction: 0.8)

    // スライダーインジケーター
    static let sliderMove = Animation.spring(response: 0.3, dampingFraction: 0.75)

    // プログレスバー
    static let progressUpdate = Animation.spring(response: 0.4, dampingFraction: 0.8)

    // ローディングベール表示
    static let veilAppear = Animation.easeIn(duration: 0.15)

    // ローディングベール消去
    static let veilDisappear = Animation.easeOut(duration: 0.2)

    // チェックマーク完了アニメーション（ホストアプリ用）
    static let completionCheck = Animation.spring(response: 0.5, dampingFraction: 0.65)
}
```

### ハプティクス定義

```swift
// Haptics.swift
enum Haptics {
    static func light() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    static func medium() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
}
```

### 使用ルール早見表

| タイミング | ハプティクス | アニメーション |
|---|---|---|
| ボタン（メイン）タップ | `light` | `buttonBounce` でscaleEffect 0.95 |
| 選択肢チップタップ | `light` | `selectionHighlight` |
| 画面遷移（全般） | なし | `screenFade` |
| スライダー切り替え | `medium` | `sliderMove` |
| テキスト挿入完了 | `medium` | なし（即時） |
| キャンセル操作 | `medium` | `screenFade` |
| 登録完了（ホストアプリ） | `success` | `completionCheck` |
| エラー発生 | `error` | `screenFade` |

---

# Part 2: ホストアプリ（設定用）

## 2-1. ホストアプリ全体の状態管理

```swift
// HostAppState.swift
@MainActor
final class HostAppState: ObservableObject {

    // ── ナビゲーション ─────────────────────────────────
    // HostAppはNavigationStackを使用可能
    @Published var navigationPath = NavigationPath()

    // ── テキストハビット ──────────────────────────────────
    @Published var textStyleRegistered: Bool = false
    @Published var textStyleSummary: String = ""
    @Published var textHabitAnswers: [Int: String] = [:]  // [questionIndex(0-9): 入力テキスト]

    // ── リレーション ──────────────────────────────────────
    @Published var relationRegistered: Bool = false
    @Published var partnerNickname: String = ""
    @Published var relationshipType: RelationshipType = .unknown
    @Published var datingStartDate: Date? = nil
    @Published var marriageDate: Date? = nil
    @Published var partnerBirthday: MonthDay? = nil   // 年なし
    @Published var cautionNote: String = ""

    // ── 初期設定 ──────────────────────────────────────────
    @Published var setupConfigured: Bool = false

    // ── UIフラグ ──────────────────────────────────────────
    @Published var isAnalyzing: Bool = false

    // ── App Group読み込み ─────────────────────────────────
    // ※ AppGroupKeys.suiteName = "group.com.motekey.shared"
    func loadFromAppGroup() {
        let defaults = UserDefaults(suiteName: AppGroupKeys.suiteName)
        textStyleRegistered = defaults?.bool(forKey: AppGroupKeys.textStyleRegistered) ?? false
        textStyleSummary    = defaults?.string(forKey: AppGroupKeys.textStyleSummary) ?? ""
        relationRegistered  = defaults?.bool(forKey: AppGroupKeys.relationRegistered) ?? false
        setupConfigured     = defaults?.bool(forKey: AppGroupKeys.setupConfigured) ?? false
    }
}

enum RelationshipType: String, CaseIterable {
    case girlfriend = "彼女"
    case fiance     = "婚約者"
    case wife       = "妻"
    case other      = "その他"
    case unknown    = "不明"

    var requiresMarriageDate: Bool {
        self == .wife || self == .fiance
    }
}

struct MonthDay: Codable {
    let month: Int
    let day: Int
}
```

---

## 2-2. S-001｜ホーム画面

### 画面要素

| 要素 | 詳細 |
|---|---|
| タイトル | 「あなたのメッセージスタイルを教えてください」 Font: `.moteTitle` |
| サブタイトル | 「実際にメッセージを打ってもらうだけでOK。AIがあなたの語尾・口調・癖を自動で読み取ります。」 Font: `.moteBody` Color: `TextSecondary` |
| ブロック1 | テキストハビットチェック（登録状態で表示切り替え） |
| ブロック2 | リレーションチェック（登録状態で表示切り替え） |
| ブロック3 | キーボード・画面収録設定（設定状態で表示切り替え） |

### ブロックの状態別表示

```swift
// HomeBlockView.swift
struct HomeBlockView: View {
    let icon: String         // SF Symbol名
    let title: String        // ブロックタイトル
    let actionLabel: String  // 未登録時ボタンラベル
    let isCompleted: Bool
    let summaryText: String? // 登録済み時のサマリー（オプション）
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.md) {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : icon)
                    .font(.system(size: 22))
                    .foregroundStyle(
                        isCompleted ? Color("SuccessGreen") : Color("AccentPink")
                    )
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(title)
                        .font(.moteHeadline)
                        .foregroundStyle(Color("TextPrimary"))

                    if isCompleted, let summary = summaryText {
                        Text(summary)
                            .font(.moteCaption)
                            .foregroundStyle(Color("TextSecondary"))
                            .lineLimit(2)
                    } else if !isCompleted {
                        Text(actionLabel)
                            .font(.moteCaption)
                            .foregroundStyle(Color("AccentPink"))
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color("TextTertiary"))
            }
            .padding(Spacing.lg)
            .background(Color("BgSecondary"))
            .clipShape(RoundedRectangle(cornerRadius: Radius.card))
        }
        .buttonStyle(.plain)
    }
}
```

### ボタンと遷移

| ブロック | 状態 | アクション | アニメーション |
|---|---|---|---|
| テキストハビット | 未登録 | NavigationPath に `.textHabit(questionIndex: 0)` をpush | `default`（NavigationStack標準） |
| テキストハビット | 登録済み | 同上（上書き再登録） | 同上 |
| リレーション | 未登録 | NavigationPath に `.relation(.nickname)` をpush | 同上 |
| リレーション | 登録済み | 同上（上書き再登録） | 同上 |
| キーボード・画面収録設定 | 未設定 | NavigationPath に `.keyboardPermission` をpush | 同上 |
| キーボード・画面収録設定 | 設定済み | 同上（再確認） | 同上 |

### デザイン指定

- 背景：`BgGrouped`（`UIColor.systemGroupedBackground`）
- ブロック間のスペーシング：`Spacing.md`（12pt）
- 全体のパディング：水平 `Spacing.lg`（16pt）
- NavigationBar タイトル：「モテキー」（`inline` スタイル）

---

## 2-3. S-002-Q1〜Q10｜テキストハビット収集画面

> 補足: S-002の参考画像は検討用モックであり、完成UIではない。この節のレイアウトと文言を現時点の正とする。

### 質問シナリオ定義

```swift
// TextHabitQuestions.swift
struct TextHabitQuestion {
    let index: Int
    let scenario: String  // シナリオ見出し（内部管理用）
    let messages: [ChatMessage]
}

struct ChatMessage {
    let text: String
    let side: BubbleSide
}

let textHabitQuestions: [TextHabitQuestion] = [
    TextHabitQuestion(index: 0, scenario: "デート提案", messages: [
        ChatMessage(text: "今夜、どこか外食いかない？", side: .leading),
        ChatMessage(text: "いいよ！どこ行こうか", side: .trailing),
        ChatMessage(text: "決めていいよ！", side: .leading)
    ]),
    TextHabitQuestion(index: 1, scenario: "愚痴・共感", messages: [
        ChatMessage(text: "ちょっと悲しいことがあって、聞いてほしい", side: .leading)
    ]),
    TextHabitQuestion(index: 2, scenario: "仕事の愚痴", messages: [
        ChatMessage(text: "今日も残業だった…もう疲れた", side: .leading),
        ChatMessage(text: "お疲れ。大変だったね", side: .trailing),
        ChatMessage(text: "なんか頑張る気力もなくなってきた", side: .leading)
    ]),
    TextHabitQuestion(index: 3, scenario: "週末の予定", messages: [
        ChatMessage(text: "今週末、何する？", side: .leading),
        ChatMessage(text: "特に決めてないけど、どっか行く？", side: .trailing),
        ChatMessage(text: "うーん、家でのんびりでもいいかな", side: .leading)
    ]),
    TextHabitQuestion(index: 4, scenario: "ちょっとした喧嘩後", messages: [
        ChatMessage(text: "さっきはごめんね。言いすぎた", side: .leading)
    ]),
    TextHabitQuestion(index: 5, scenario: "不安な気持ち", messages: [
        ChatMessage(text: "最近、私のこと好き？", side: .leading)
    ]),
    TextHabitQuestion(index: 6, scenario: "体調不良", messages: [
        ChatMessage(text: "なんか頭痛がひどくて…", side: .leading),
        ChatMessage(text: "大丈夫？何かできることある？", side: .trailing),
        ChatMessage(text: "大丈夫だよ、心配してくれてありがと", side: .leading)
    ]),
    TextHabitQuestion(index: 7, scenario: "嬉しい報告", messages: [
        ChatMessage(text: "やった！仕事でめっちゃ褒められた！", side: .leading)
    ]),
    TextHabitQuestion(index: 8, scenario: "悩み相談", messages: [
        ChatMessage(text: "友達と最近うまくいってなくて…", side: .leading),
        ChatMessage(text: "何かあったの？", side: .trailing),
        ChatMessage(text: "向こうから急に冷たくなった気がして、理由もわからなくて不安", side: .leading)
    ]),
    TextHabitQuestion(index: 9, scenario: "趣味・買い物報告", messages: [
        ChatMessage(text: "かわいい服見つけたんだけど、ちょっと高くて迷ってる", side: .leading),
        ChatMessage(text: "いくらくらい？", side: .trailing),
        ChatMessage(text: "1万5千円…。似合うと思う？写真送る", side: .leading)
    ])
]
```

### 画面レイアウト

```
NavigationBar
├── タイトル: "テキストハビットチェック"（center、Font: .moteHeadline）
└── trailing: Button("スキップ") → 全10問スキップ → S-002-LOADING へ遷移（空回答で解析）

VStack（上から）
├── Text: "{questionIndex+1}/10 シチュエーション"
│   Font: .moteCaption Color: TextSecondary
│   multilineTextAlignment: .center
├── MoteProgressBar(current: questionIndex+1, total: 10)  ← 高さ4pt
├── Spacer(minLength: 20)
├── ScrollView（トーク履歴）
│   └── VStack(spacing: 8) { ChatBubble... }
├── Spacer()
└── 入力エリア（KeyboardAwareView）
    ├── TextField / TextEditor（単行入力）
    └── 「送信」ボタン（右端）
```

### 入力エリアの仕様

```swift
// TextHabitInputArea.swift
struct TextHabitInputArea: View {
    @Binding var inputText: String
    let onSend: () -> Void

    var body: some View {
        HStack(spacing: Spacing.sm) {
            TextField("返信を入力...", text: $inputText, axis: .vertical)
                .font(.moteBody)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background(Color("BgSecondary"))
                .clipShape(RoundedRectangle(cornerRadius: Radius.chip))
                .lineLimit(1...4)

            Button(action: {
                guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                Haptics.light()
                onSend()
            }) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(
                        inputText.isEmpty ? Color("AccentPink").opacity(0.4) : Color("AccentPink")
                    )
            }
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
        .background(Color("BgPrimary"))
        .overlay(
            Divider(), alignment: .top
        )
    }
}
```

### ボタンと遷移

| アクション | 条件 | 処理 | 遷移 |
|---|---|---|---|
| 送信ボタンタップ | inputText に1文字以上 | 1. `light` ハプティクス / 2. ユーザー吹き出しをトーク履歴に追加（0.3秒表示） / 3. `textHabitAnswers[questionIndex] = inputText` 保存 | Q1〜Q9: 0.3秒後に次の質問へ push / Q10: S-002-LOADING へ遷移 |
| 送信ボタンタップ | inputText 空 | ボタン非活性のためトリガーなし | — |

### デザイン指定

- 背景：`BgPrimary`（白 / 黒）
- NavigationBarスタイル：`inline`
- ユーザー吹き出し追加アニメーション：`withAnimation(.spring(response: 0.3, dampingFraction: 0.8))`
- ScrollViewは新しい吹き出し追加時に自動スクロール：`ScrollViewReader` を使用し `proxy.scrollTo(lastID, anchor: .bottom)`

---

## 2-4. S-002-LOADING｜解析中画面

### 画面要素

- Q10の画面レイアウトをそのまま維持する（背景・吹き出し群をそのまま表示）
- 入力エリアを非活性化（`disabled(true)` + opacity 0.5）
- 画面中央にローディングインジケーターを重ねて表示

```swift
// TextHabitLoadingOverlay.swift
struct TextHabitLoadingOverlay: View {
    @State private var rotation: Double = 0
    @State private var pulsing: Bool = false

    var body: some View {
        ZStack {
            Color("VeilBackground")
                .ignoresSafeArea()

            VStack(spacing: Spacing.lg) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 44))
                    .foregroundStyle(Color("AccentPink"))
                    .rotationEffect(.degrees(rotation))
                    .opacity(pulsing ? 0.5 : 1.0)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 1.2).repeatForever()) {
                            pulsing = true
                        }
                    }

                Text("テキストハビットを解析中...")
                    .font(.moteBody)
                    .foregroundStyle(Color("TextPrimary"))
            }
            .padding(Spacing.xxl)
            .background(Color("BgSecondary"))
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
        }
    }
}
```

### バックグラウンド処理

```
1. Q1〜Q10の全入力を配列にまとめる
2. Gemini API にリクエスト送信
   - 語尾・絵文字有無・文章の長さ・口調を構造データとして抽出するプロンプトを使用
3. レスポンスを TextStyleProfile に変換
4. App Group の UserDefaults に保存
5. S-001（ホーム画面）へ自動遷移（NavigationPath をリセット）
6. ホーム画面の「テキストハビットチェック」ブロックが「登録済み ✓」表示に更新される
```

### エラー処理

| エラー種別 | 処理 |
|---|---|
| タイムアウト（10秒） | `error` ハプティクス + エラーアラート表示 + 「もう一度試す」「スキップ」ボタン |
| ネットワークエラー | 同上 |

---

## 2-5. S-003-1〜4, DONE｜リレーション登録画面

> 補足: S-003の参考画像は検討用モックであり、完成UIではない。特に `partner_relationship.png` は完成版ではなく、ここでは情報設計と入力責務を正とする。

> **画面構成**: 4ステップ。ステップ3は妻・婚約者の場合に入籍日を同一画面のトグルで追加できる設計。
> 「ステップ N / 4」はナビゲーションバータイトルとして表示する。

### S-003-1｜呼び名入力

```
NavigationBar: 「ステップ 1 / 4」（center、Font: .moteCaption）

VStack
├── タイトル: 「パートナーの呼び名を教えてください」 Font: .moteTitle
├── TextField
│   ├── placeholder: "ゆいちゃん、妻、など"
│   ├── Font: .moteBody
│   └── 背景: BgSecondary、角丸: Radius.sm
├── LinkTextButton: 「わからない・決めていない」
│   └── action: partnerNickname = "" → S-003-2 へ遷移
├── Spacer()
└── PinkPrimaryButton: 「次へ」（常時アクティブ）
    └── action: nickname 保存 → S-003-2 へ push
```

**「次へ」の挙動**：入力なし → `partnerNickname = "パートナー"` として保存し遷移。

---

### S-003-2｜関係性選択

```
NavigationBar: 「ステップ 2 / 4」

VStack
├── タイトル: 「どんな関係ですか？」 Font: .moteTitle
├── VStack(spacing: Spacing.sm) {
│   SelectionChip（彼女、婚約者、妻、その他、不明）
│   ← 1つのみ選択可。未選択は「不明」扱い
│ }
├── Spacer()
└── PinkPrimaryButton: 「次へ」（常時アクティブ）
```

**「次へ」の遷移**：選択値に関わらず → S-003-3 へ push（入籍日はS-003-3でトグル追加）

---

### S-003-3｜付き合った日入力（全関係種別共通）

> **UIのポイント**（`partner_relationship.png` は検討用モック）：日付をテキスト形式で大きく表示し、
> 下部のトグルボタンで「付き合った日のみ」か「入籍日も追加」を切り替える。
> DatePickerは非表示で、日付表示欄タップ時にモーダルピッカーを表示する。

```
NavigationBar: 「ステップ 3 / 4」

VStack
├── MoteProgressBar(current: 3, total: 4)
├── Spacer(minLength: 20)
├── タイトル: 「付き合い始めたのはいつ？」 Font: .moteTitle
│
├── // 日付表示欄（タップでDatePickerシート表示）
│   RoundedRectangle
│   ├── Text: "YYYY年 M月 DD日"  Font: .moteHeadline  Color: AccentPink
│   └── isUnknown == true の場合は "不明" を表示
│
├── // 関係種別がmarriageRequiredの場合のみ入籍日トグルを表示
│   if relationshipType.requiresMarriageDate {
│     Text: "※ 結婚している場合は入籍日も入力できます"
│         Font: .moteCaption Color: TextSecondary
│     VStack(spacing: Spacing.sm)
│     ├── SelectionChip: 「付き合った日のみ」（選択中: AccentPink）
│     │   → action: showMarriageDate = false
│     └── SelectionChip: 「入籍日も追加」
│         → action: showMarriageDate = true
│
│     if showMarriageDate {
│       // 入籍日入力欄（同様のレイアウト）
│       RoundedRectangle ← 入籍日テキスト表示
│     }
│   }
│
├── Spacer()
└── PinkPrimaryButton: 「次へ」
    └── action: 付き合った日 + 入籍日（optional）を保存 → S-003-4 へ push
```

**.sheet でDatePickerを表示する実装**：

```swift
.sheet(isPresented: $showDatePicker) {
    VStack {
        DatePicker("", selection: $selectedDate, displayedComponents: [.date])
            .datePickerStyle(.wheel)
            .labelsHidden()
        PinkPrimaryButton(title: "決定") { showDatePicker = false }
            .padding()
    }
    .presentationDetents([.height(300)])
}
```

---

### S-003-4｜誕生日 & 最近の出来事・気をつけること入力

```
NavigationBar: 「ステップ 4 / 4」

ScrollView
VStack(spacing: Spacing.xl)
│
├── // ── 誕生日セクション ──────────────────────────────
│   Text: 「誕生日を教えてください」 Font: .moteHeadline
│   Text: 「誕生日の前後7日は、AIが自動で気の利いた返信を提案します」
│       Font: .moteCaption Color: TextSecondary
│
│   // 月・日のみの Picker（年なし）
│   // ※ UIPickerViewをUIViewRepresentableでラップして実装
│   MonthDayPicker(selection: $partnerBirthday)
│       .frame(height: 120)
│
│   LinkTextButton: 「不明・スキップ」
│       → action: partnerBirthday = nil
│
├── Divider()
│
├── // ── 最近の出来事・気をつけることセクション ───────────
    Text: 「最近の出来事や気をつけることはありますか？」 Font: .moteHeadline
    Text: 「最近の関係の変化、過去に怒らせたこと、ケンカしたことなど」
        Font: .moteCaption Color: TextSecondary
    ZStack（TextEditorとプレースホルダー）
    ├── TextEditor（背景: BgSecondary、角丸: Radius.sm）
    │   └── maxLength: 200文字（.onChange で enforceLimit）
    └── プレースホルダーText（TextEditorが空かつ非フォーカス時）
        「例：来週が記念日、最近仕事が忙しくて余裕がない、返信が遅いと怒りやすい、など」
    HStack
    ├── Spacer()
    └── Text: "\(cautionNote.count)/200"  Font: .moteCaption Color: TextTertiary
    LinkTextButton: 「特にない・わからない」
        → action: cautionNote = ""
│
├── Divider()
│
├── HStack(alignment: .top, spacing: Spacing.sm)
│   ├── CheckboxButton(isChecked: isAgreed)
│   └── Text: 「入力した内容およびLINEの会話文脈はAI（Gemini API）に送信されます。相手がこのことを知っていない場合、送信前に共有することを推奨します」
│       Font: .moteCaption Color: TextSecondary
│
└── PinkPrimaryButton: 「登録する」（isEnabled: isAgreed）
    └── action: guard isAgreed else { return }
                全データを App Group に書き込み → S-003-DONE へ push
```

> **実装ノート（エラー防止）**：
> - `MonthDayPicker` は `UIPickerView` を `UIViewRepresentable` でラップして月（1-12）・日（1-31）の2カラムで実装する。SwiftUIの標準 `DatePicker` では年が必ず表示されるため使用しない。
> - TextEditorのプレースホルダーは `ZStack` で重ねる（SwiftUI標準APIは存在しない）。
> - 同意チェックボックスは `@State private var isAgreed = false` で管理し、未チェック時は `PinkPrimaryButton` を非活性にする。

---

> **削除済みステップ**: S-003-3A/3B（関係種別別の分岐画面）および S-003-5（独立した気をつけること画面）は廃止。
> S-003-3 のトグルと S-003-4 のスクロールビューに統合済み。

---

### S-003-5（廃止）

独立画面としては廃止済み。TextEditor、同意チェックボックス、登録ボタンの仕様はすべて S-003-4 に統合済みであり、実装時は参照しないこと。

---

### S-003-DONE｜リレーション登録完了

```
VStack（中央揃え）
├── CheckmarkAnimationView（後述）
├── Text: 「登録完了！」 Font: .moteTitle
├── Text: 「いつでもアプリから変更できます」
│   Font: .moteBody Color: TextSecondary
├── Spacer()
└── PinkPrimaryButton: 「ホームに戻る」
    └── action: NavigationPath をリセット → S-001 に戻る
         + `success` ハプティクス
```

```swift
// CheckmarkAnimationView.swift
struct CheckmarkAnimationView: View {
    @State private var scale: CGFloat = 0
    @State private var opacity: Double = 0

    var body: some View {
        ZStack {
            Circle()
                .fill(Color("SuccessGreen").opacity(0.15))
                .frame(width: 100, height: 100)

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(Color("SuccessGreen"))
                .scaleEffect(scale)
                .opacity(opacity)
        }
        .onAppear {
            withAnimation(.completionCheck) {
                scale = 1.0
                opacity = 1.0
            }
        }
    }
}
```

---

## 2-6. S-004, S-004-ERROR｜キーボード許可・画面収録案内画面

### S-004｜初期表示

> **補足**: 画面収録の稼働可否はHostAppから厳密には検知しにくいため、この画面では「手順案内 + ユーザー確認」までを扱う。実際の未開始状態は KBD-S-010 で再検知する。

```
NavigationBar: 「使用準備」

ScrollView（縦方向）
VStack(spacing: Spacing.xl)
├── Image(systemName: "keyboard.badge.ellipsis")
│   .font(.system(size: 64))
│   .foregroundStyle(Color("AccentPink"))
│
├── Text: 「キーボードと画面収録の準備をお願いします」 Font: .moteTitle
│
├── Text: 「`mote+AI` を使うために、キーボードの有効化と画面収録の開始が必要です」
│   Font: .moteBody Color: TextSecondary
│
├── SectionTitle: 「1. キーボードを有効にする」
├── StepInstructionView（以下の手順をリスト表示）
│   1. iOSの設定アプリを開く
│   2. 「一般」→「キーボード」→「キーボード」に進む
│   3. 「新しいキーボードを追加」→「モテキー」をタップ
│   4. 「モテキー」をタップ →「フルアクセスを許可」トグルをオン
│   5. 確認ダイアログ「許可」をタップ
│
├── PinkPrimaryButton: 「設定を開く」
    └── action: UIApplication.shared.open(settingsURL)
         settingsURL = URL(string: UIApplication.openSettingsURLString)!
│
├── Divider()
│
├── SectionTitle: 「2. 画面収録を開始する」
├── StepInstructionView（以下の手順をリスト表示）
│   1. コントロールセンターを開く
│   2. 「画面収録」を長押しする
│   3. Broadcast Extensionの一覧から「モテキー」を選ぶ
│   4. 「ブロードキャストを開始」をタップする
│   5. LINEに戻る
│
├── CheckboxRow: 「画面収録の開始手順を確認した」
│   └── action: hasAcknowledgedScreenRecording.toggle()
│
└── PinkPrimaryButton: 「次へ」（isEnabled: hasMotekeyEnabled && hasAcknowledgedScreenRecording)
    └── action: navigationPath.append(HostRoute.keyboardComplete)
```

> **実装ノート**：`UIApplication.openSettingsURLString` で設定アプリを開くのが最も安全。
> `prefs:root=General&path=Keyboard` のようなプライベートURLスキームは
> Appレビュー時にリジェクトリスクがあるため使用しない。

### アプリ復帰時の自動処理

```swift
// S-004View.swift
@State private var hasMotekeyEnabled = false
@State private var hasAcknowledgedScreenRecording = false

.onReceive(NotificationCenter.default.publisher(
    for: UIApplication.didBecomeActiveNotification
)) { _ in
    checkKeyboardPermission()
}

func checkKeyboardPermission() {
    // UITextInputMode でモテキーが有効か確認する
    // hasFullAccess はExtension内でのみチェック可能
    // HostApp側では「モテキーが追加されているか」のみ確認する
    let hasMotekeyEnabled = UITextInputMode.activeInputModes.contains {
        $0.primaryLanguage?.contains("motekeyapp") == true
    }
    if hasMotekeyEnabled {
        self.hasMotekeyEnabled = true
        showError = false
    } else {
        self.hasMotekeyEnabled = false
        showError = true  // S-004-ERROR 状態に切り替え
    }
}
```

### S-004-ERROR｜エラー状態（S-004の状態変化）

S-004のView内で `@State var showError: Bool = false` で制御する。
モーダルや別画面ではなく、S-004のレイアウト下部にエラーメッセージを追加表示する。

```swift
// S-004View.swift 内に追記
if showError {
    VStack(spacing: Spacing.sm) {
        Text("キーボードの追加またはフルアクセス許可が完了していないようです")
            .font(.moteCaption)
            .foregroundStyle(Color("ErrorRed"))
        PinkPrimaryButton(title: "もう一度設定を開く", ...) {
            openSettings()
        }
    }
    .transition(.opacity)
}
```

---

## 2-7. S-004-COMPLETE｜初期設定完了画面

```
VStack（中央揃え）
├── CheckmarkAnimationView（S-003-DONEと同じコンポーネント）
├── Text: 「準備完了です」 Font: .moteTitle
├── Text: 「キーボードと画面収録の準備ができました。次にメッセージアプリでモテキーへ切り替える手順を確認します。」
│   Font: .moteBody Color: TextSecondary
│   multilineTextAlignment: .center
├── Spacer()
├── PinkPrimaryButton: 「メッセージアプリの使い方を見る」
│   └── action: `success` ハプティクス → S-004-TUTORIAL へ push
└── LinkTextButton: 「あとで」
    └── action: navigationPath をリセット → S-001へ戻る
         + hostAppState.setupConfigured = true
```

---

## 2-8. S-004-TUTORIAL｜メッセージキーボード切り替えチュートリアル画面

```
NavigationBar
├── タイトル: 「使い方」
└── trailing: Button(「閉じる」) {
       hostAppState.setupConfigured = true
       navigationPath = NavigationPath()
   }

ScrollView
VStack(spacing: Spacing.xl)
├── TutorialStepView（以下の手順を図解）
│   Step 1: メッセージアプリを開く
│   Step 2: テキスト入力欄をタップしてキーボードを表示する
│   Step 3: キーボード左下の🌐（地球儀）を長押し
│   Step 4: 「モテキー」を選択する
│   Step 5: mote+AIボタンをタップして使い始める
│
└── PinkPrimaryButton: 「はじめる」
    └── action: hostAppState.setupConfigured = true
               navigationPath をリセット → S-001 へ戻る
```

```swift
// TutorialStepView.swift
struct TutorialStepView: View {
    let stepNumber: Int
    let instruction: String
    let symbol: String  // SF Symbol名

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            ZStack {
                Circle()
                    .fill(Color("AccentPink"))
                    .frame(width: 32, height: 32)
                Text("\(stepNumber)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color("TextOnAccent"))
            }
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Image(systemName: symbol)
                    .font(.system(size: 28))
                    .foregroundStyle(Color("AccentPink"))
                Text(instruction)
                    .font(.moteBody)
                    .foregroundStyle(Color("TextPrimary"))
            }
            Spacer()
        }
    }
}
```

---

## 2-9. ホストアプリ遷移定義

### NavigationRoute 定義

```swift
// HostRoute.swift
enum HostRoute: Hashable {
    case textHabit(questionIndex: Int)
    case textHabitLoading
    case relation(RelationStep)
    case keyboardPermission
    case keyboardComplete
    case tutorial
}

enum RelationStep: Hashable {
    case nickname       // S-003-1
    case relationship   // S-003-2
    case datingDate     // S-003-3（入籍日トグル込み・全関係種別共通）
    case birthdayAndCaution  // S-003-4（誕生日 + 気をつけること、統合）
    case done           // S-003-DONE
}
```

### NavigationStack 設定

```swift
// HostAppView.swift
NavigationStack(path: $hostAppState.navigationPath) {
    HomeView()
        .navigationDestination(for: HostRoute.self) { route in
            switch route {
            case .textHabit(let index):
                TextHabitQuestionView(questionIndex: index)
            case .textHabitLoading:
                TextHabitLoadingView()
            case .relation(let step):
                switch step {
                case .nickname:           RelationNicknameView()
                case .relationship:       RelationTypeView()
                case .datingDate:         RelationDatingDateView()
                case .birthdayAndCaution: RelationBirthdayAndCautionView()
                case .done:               RelationDoneView()
                }
            case .keyboardPermission:
                KeyboardPermissionView()
            case .keyboardComplete:
                KeyboardCompleteView()
            case .tutorial:
                TutorialView()
            }
        }
}
```

### 遷移アニメーション

ホストアプリはNavigationStack標準のスライドアニメーションを使用する。
カスタムTransitionは使用しない（エラーリスク低減のため）。

---

# Part 3: キーボード拡張（キーボード用）

## 3-1. Extension全体の状態管理

### AppState（キーボード拡張用）

```swift
// AppState.swift（Extension Target）
enum KbdScreen: Equatable {
    case keyboard       // KBD-S-005: 通常キーボード（デフォルト）
    case askUser        // KBD-S-006: 質問フロー
    case loading        // KBD-S-006.5: AI思考中
    case stage          // KBD-S-007: ステージ
    case fullText       // KBD-S-008: 全文表示
    case fallback       // KBD-S-009: 手入力フォールバック
    case permissionBlock // KBD-S-010: 権限ブロック
}

enum DisplayMode: Equatable {
    case chip     // スライダー左：チップ表示（KBD-S-007）
    case fullText // スライダー右：全文表示（KBD-S-008）
}

enum FallbackReason {
    case none
    case imageCaptureFailed
    case apiTimeout
    case apiError
}

enum PermissionIssue {
    case none
    case fullAccessDenied
    case screenRecordingDenied
}

@MainActor
final class AppState: ObservableObject {

    // ── 画面制御 ─────────────────────────────────────────
    @Published var currentScreen: KbdScreen = .keyboard
    @Published var displayMode: DisplayMode = .chip

    // ── AI処理フロー ──────────────────────────────────────
    @Published var isAIProcessing: Bool = false
    @Published var chatContext: String = ""            // Gemini Vision API で抽出したチャット文脈
    @Published var askUserAnswers: [Int: String] = [:] // [questionIndex: 選択した value]
    @Published var currentQuestionIndex: Int = 0
    @Published var askUserQuestions: [AskUserQuestion] = []  // ③ Q1〜Q3一括生成APIから取得
    var generationTask: Task<Void, Never>? = nil

    // ── 生成結果 ──────────────────────────────────────────
    @Published var generatedCandidates: [String] = []

    // ── エラー制御 ────────────────────────────────────────
    @Published var fallbackReason: FallbackReason = .none
    @Published var permissionIssue: PermissionIssue = .none

    // ── ハプティクスのワンショット発火 ────────────────────
    func transition(to screen: KbdScreen) {
        withAnimation(.screenFade) {
            currentScreen = screen
        }
    }

    func reset() {
        generationTask?.cancel()
        generationTask = nil
        isAIProcessing = false
        chatContext = ""
        askUserAnswers = [:]
        currentQuestionIndex = 0
        askUserQuestions = []
        generatedCandidates = []
        fallbackReason = .none
        permissionIssue = .none
        displayMode = .chip
    }

    func cancelAskUserFlow() {
        generationTask?.cancel()
        generationTask = nil
        isAIProcessing = false
        chatContext = ""
        askUserAnswers = [:]
        currentQuestionIndex = 0
        askUserQuestions = []
        displayMode = .chip
    }
}

// ※ api-design.md の ③ アスクユーザーQ1〜Q3一括生成 レスポンスフォーマットに準拠
struct AskUserOption {
    let label: String   // 表示テキスト
    let value: String   // 識別値（英語スネークケース）
}

struct AskUserQuestion {
    let index: Int
    let text: String
    let options: [AskUserOption]   // 常に3件
}
```

### ZStackルートView

```swift
// MoteKeyRootView.swift（Extension Target）
struct MoteKeyRootView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var heightProvider: KeyboardHeightProvider

    var body: some View {
        ZStack(alignment: .bottom) {

            // Z=20: ステージ（チップ表示）
            // 非表示時もopacity制御（頻繁な切り替えのため再マウントしない）
            StageLayerView()
                .zIndex(20)
                .opacity(appState.currentScreen == .stage ? 1 : 0)
                .allowsHitTesting(appState.currentScreen == .stage)

            // Z=30: 全文表示
            FullTextLayerView()
                .zIndex(30)
                .opacity(appState.currentScreen == .fullText ? 1 : 0)
                .allowsHitTesting(appState.currentScreen == .fullText)

            // Z=40: 質問フロー
            AskUserLayerView()
                .zIndex(40)
                .opacity(appState.currentScreen == .askUser ? 1 : 0)
                .allowsHitTesting(appState.currentScreen == .askUser)

            // Z=50: ローディングベール（条件付きでツリーに追加）
            if appState.currentScreen == .loading {
                LoadingVeilView()
                    .zIndex(50)
                    .transition(.opacity.animation(.veilAppear))
            }

            // Z=60: 手入力フォールバック
            if appState.currentScreen == .fallback {
                FallbackLayerView()
                    .zIndex(60)
                    .transition(.opacity.animation(.screenFade))
            }

            // Z=70: 権限ブロック（最前面オーバーレイ）
            if appState.currentScreen == .permissionBlock {
                PermissionBlockLayerView()
                    .zIndex(70)
                    .transition(.opacity.animation(.screenFade))
            }

            // Z=100: BottomActionBar（常時最前面）
            BottomActionBarView()
                .zIndex(100)
                .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
        .frame(height: heightProvider.keyboardHeight)
        .background(Color("BgGrouped"))
    }
}
```

---

## 3-2. KBD-S-005｜通常キーボード画面

### 概要

azooKeyのネイティブキーボードView（UIKit）がベースとして表示される。
SwiftUI側ではステージや全文のオーバーレイが非表示のとき、azooKeyが透けて見える状態。
MoteKeyRootViewのZStack内でopacity=0の状態がKBD-S-005に相当する。

### 予測変換バーの扱い

- azooKeyの予測変換バー（通常は画面上部）は、S-007ステージが表示されるときに `isHidden = true` にする。
- `UIInputViewController` のサブViewとして制御する（SwiftUI外）。

```swift
// KeyboardViewController.swift
func updatePredictionBarVisibility() {
    let shouldHide = appState.currentScreen == .stage
                  || appState.currentScreen == .fullText
    azooKeyPredictionBar?.isHidden = shouldHide
}
```

---

## 3-3. KBD-S-006｜返信考案アスクユーザー画面

### 画面レイアウト

```
VStack（全体）
├── ヘッダー（高さ36pt）
│   HStack
│   ├── Text: "Q{index+1}/{total}"
│   │   Font: .kbdCaption Color: TextSecondary
│   └── MoteProgressBar（高さ4pt）← Extensionではキーボード版を使用
│
├── Text（質問テキスト）
│   Font: .kbdQuestion
│   multilineTextAlignment: .center
│   lineLimit: 3
│   padding: 水平16pt、垂直8pt
│
├── ScrollView（選択肢群）
│   VStack(spacing: Spacing.sm)
│   └── ForEach(question.options, id: \.value) { option in
│         // option.label を表示、option.value を回答として記録
│         AskUserOptionButton(text: option.label, action: { selectOption(option.value) })
│       }
│
└── BottomActionBar（常時表示）
```

### AskUserOptionButton

```swift
// AskUserOptionButton.swift
struct AskUserOptionButton: View {
    let text: String
    let onSelect: () -> Void
    @State private var isHighlighted: Bool = false

    var body: some View {
        Button(action: {
            Haptics.light()
            withAnimation(.selectionHighlight) { isHighlighted = true }
            // 0.25秒後に次の質問へ遷移
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                onSelect()
            }
        }) {
            Text(text)
                .font(.kbdButton)
                .foregroundStyle(
                    isHighlighted ? Color("TextOnAccent") : Color("TextPrimary")
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.sm)
                .background(
                    isHighlighted
                        ? Color("AccentPinkDark")
                        : Color("BgSecondary")
                )
                .clipShape(RoundedRectangle(cornerRadius: Radius.button))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Spacing.lg)
    }
}
```

### 選択肢タップ時の処理

```swift
func selectOption(_ option: String) {
    askUserAnswers[currentQuestionIndex] = option
    advanceQuestion()
}

func advanceQuestion() {
    let isLast = currentQuestionIndex >= askUserQuestions.count - 1
    if isLast {
        appState.transition(to: .loading)
        appState.generationTask = Task { await requestAIGeneration() }
    } else {
        withAnimation(.screenFade) {
            currentQuestionIndex += 1
        }
    }
}
```

### デザイン指定

- 背景：`BgGrouped`
- ヘッダー下に1ptのセパレータ（`Divider()`）
- 選択肢ボタンの最小タップ高さ：44pt（`.frame(minHeight: 44)` を指定）

### タブ切替時の中断ルール

- `mote+AI` 質問フロー中に `キーボード` タブをタップした場合、質問フローはその時点で中断する
- 中断時は `askUserAnswers`、`askUserQuestions`、`currentQuestionIndex` を破棄し、進行中の `generationTask` があれば `cancel()` する
- `全文表示` タブは生成済み候補が存在する場合のみ有効化し、質問フロー中は開かない

---

## 3-4. KBD-S-006.5｜AI思考中ローディング画面

### 概要

S-006の背景を維持したまま、半透明のベールを重ねてローディングを表示する。
インプレースで表示するため、ZIndexを50に設定しS-006の上に重ねる。

### LoadingVeilView

```swift
// LoadingVeilView.swift
struct LoadingVeilView: View {
    @State private var pulsing: Bool = false
    @State private var messageIndex: Int = 0

    private let messages = [
        "考え中...",
        "あなたのスタイルを分析中...",
        "最適な返信を生成中..."
    ]
    private let timer = Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            // ベール
            Color("VeilBackground")
                .ignoresSafeArea()

            // ローディングカード
            VStack(spacing: Spacing.md) {
                Image(systemName: "sparkles")
                    .font(.system(size: 32, weight: .light))
                    .foregroundStyle(Color("AccentPink"))
                    .opacity(pulsing ? 0.4 : 1.0)
                    .scaleEffect(pulsing ? 0.9 : 1.0)
                    .onAppear {
                        withAnimation(
                            .easeInOut(duration: 0.8).repeatForever(autoreverses: true)
                        ) {
                            pulsing = true
                        }
                    }

                Text(messages[messageIndex])
                    .font(.kbdCaption)
                    .foregroundStyle(Color("TextSecondary"))
                    .id(messageIndex)  // idを変えてfadeアニメーション
                    .transition(.opacity)
            }
            .padding(Spacing.xl)
            .background(Color("BgSecondary"))
            .clipShape(RoundedRectangle(cornerRadius: Radius.card))
            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
        }
        .onReceive(timer) { _ in
            withAnimation(.screenFade) {
                messageIndex = (messageIndex + 1) % messages.count
            }
        }
    }
}
```

### APIリクエスト後の遷移

```swift
// AppState.swift
// ※ api-design.md の ④ 返信文生成 に準拠
// 入力: チャット文脈 + Q1〜Q3回答 + テキストハビット + リレーション情報 + SP
func requestAIGeneration() async {
    do {
        let candidates = try await GeminiService.shared.generateReplies(
            chatContext: chatContext,          // ② で抽出した文脈（手入力時はユーザー入力）
            userResponses: askUserAnswers,     // ③ Q1〜Q3の選択結果 [index: value]
            textStyleProfile: loadTextStyleProfile(),
            relationProfile: loadRelationProfile()
        )
        await MainActor.run {
            generatedCandidates = candidates  // 2〜5個のチップ
            generationTask = nil
            Haptics.success()
            transition(to: .stage)
        }
    } catch {
        await MainActor.run {
            generationTask = nil
            Haptics.error()
            fallbackReason = .apiError
            transition(to: .fallback)
        }
    }
}
```

---

## 3-5. KBD-S-007｜ステージ画面

### 画面レイアウト

```
VStack（全体）
├── azooKeyキーボードエリア（ネイティブ、S-005のまま）
│
└── ステージオーバーレイ（azooKeyの予測変換バー位置に表示）
    ScrollView（.horizontal、showsIndicators: false）
    LazyHStack(spacing: Spacing.sm)
    └── ForEach(candidates) { StageChipView }
    padding: 水平8pt、垂直6pt
```

チップをタップすると、その文面がLINEの入力欄に即時反映される。ステージ自体は残し、ユーザーは複数チップをタップ順で積み上げたあと、入力欄上で手編集して送信する。

### StageChipView

```swift
// StageChipView.swift
struct StageChipView: View {
    let text: String
    let onTap: () -> Void
    @State private var appeared: Bool = false

    var body: some View {
        Button(action: {
            Haptics.medium()
            onTap()
        }) {
            Text(text)
                .font(.kbdChip)
                .foregroundStyle(Color("TextPrimary"))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .frame(maxWidth: 200, alignment: .leading)
                .background(Color("BgSecondary"))
                .clipShape(RoundedRectangle(cornerRadius: Radius.chip))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.chip)
                        .stroke(Color("Border"), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .offset(x: appeared ? 0 : 40)
        .opacity(appeared ? 1 : 0)
    }
}
```

### チップ出現アニメーション

```swift
// StageLayerView.swift
struct StageLayerView: View {
    @EnvironmentObject var appState: AppState
    @State private var appearedIndices: Set<Int> = []

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: Spacing.sm) {
                ForEach(Array(appState.generatedCandidates.enumerated()), id: \.offset) { index, text in
                    StageChipView(text: text) {
                        insertTextIntoComposer(text)
                    }
                    .opacity(appearedIndices.contains(index) ? 1 : 0)
                    .offset(x: appearedIndices.contains(index) ? 0 : 40)
                    .animation(
                        .chipSlideIn.delay(Double(index) * 0.05),
                        value: appearedIndices.contains(index)
                    )
                }
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
        }
        .frame(height: 80)
        .background(Color("BgGrouped"))
        .overlay(Divider(), alignment: .bottom)
        .onAppear {
            // 各チップを順次表示
            for index in appState.generatedCandidates.indices {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.05) {
                    withAnimation(.chipSlideIn) {
                        appearedIndices.insert(index)
                    }
                }
            }
        }
    }

    func insertTextIntoComposer(_ text: String) {
        // LINEの入力欄へ挿入し、ステージは維持する
        moteKeyContext?.clearMarkedText()
        moteKeyContext?.insertText(text)
        Haptics.medium()
    }
}
```

### 運用ルール

- タップ順がそのまま入力欄への反映順になる
- MVPでは専用のドラッグ並び替えUIは持たない
- 送信はモテキー側の独自ボタンではなく、既存メッセージアプリ側の送信UIを使う

---

## 3-6. KBD-S-008｜全文表示画面

### 画面レイアウト

```
VStack（全体、maxHeight: keyboardHeight）
├── ヘッダー（高さ44pt）
│   HStack
│   ├── Button（Image(systemName: "xmark")）
│   │   → action: スライダーをchipに戻す → appState.displayMode = .chip → currentScreen = .stage
│   ├── Spacer()
│   └── Text: 「全文表示」 Font: .kbdButton
│
├── ScrollView（縦方向、showsIndicators: true）
│   frame(maxHeight: availableHeight)  ← keyboardHeight - 44（ヘッダー）- 52（BottomBar）
│   LazyVStack(spacing: Spacing.sm)
│   └── ForEach(candidates) { FullTextCardView }
│
└── BottomActionBar（常時表示）
```

### FullTextCardView

```swift
// FullTextCardView.swift
struct FullTextCardView: View {
    let text: String
    let index: Int
    let onTap: () -> Void

    var body: some View {
        Button(action: {
            Haptics.medium()
            onTap()
        }) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("候補 \(index + 1)")
                    .font(.kbdCaption)
                    .foregroundStyle(Color("TextTertiary"))

                Text(text)
                    .font(.kbdChip)
                    .foregroundStyle(Color("TextPrimary"))
                    .multilineTextAlignment(.leading)
                    .lineLimit(nil)  // 省略禁止（仕様上の必須要件）
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.md)
            .background(Color("BgSecondary"))
            .clipShape(RoundedRectangle(cornerRadius: Radius.card))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Spacing.sm)
    }
}
```

カードタップ時は、その全文を入力欄へ反映したうえで `キーボード` タブ側へ戻り、続けて手編集できる状態にする。

### 横持ち対応

```swift
// FullTextLayerView.swift
struct FullTextLayerView: View {
    @EnvironmentObject var heightProvider: KeyboardHeightProvider

    var isCompact: Bool { heightProvider.keyboardHeight < 200 }

    var body: some View {
        if isCompact {
            // 横持ちで高さが足りない場合
            VStack {
                Spacer()
                Text("横向きでは全文表示を利用できません")
                    .font(.kbdCaption)
                    .foregroundStyle(Color("TextSecondary"))
                Spacer()
            }
        } else {
            // 通常表示
            fullTextContent
        }
    }
}
```

---

## 3-7. KBD-S-009｜手入力フォールバック画面

### 画面レイアウト

```
VStack（全体）
├── エラーヘッダー
│   HStack(spacing: Spacing.sm)
│   ├── Image(systemName: "exclamationmark.triangle.fill")
│   │   .foregroundStyle(Color("WarningYellow"))
│   └── Text（fallbackReason に対応するエラーテキスト）
│       Font: .kbdCaption Color: TextSecondary
│
├── ZStack（入力エリア）
│   ├── RoundedRectangle（背景）
│   │   .fill(Color("BgSecondary"))
│   │   .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
│   ├── TextEditor（複数行入力）
│   │   .font(.kbdChip)
│   │   .scrollContentBackground(.hidden)
│   │   .background(.clear)
│   └── プレースホルダーText（空かつ非フォーカス時）
│       「相手のメッセージを入力してください」
│       Font: .kbdCaption Color: TextTertiary
│
├── HStack（アクションボタン行）
│   ├── Button: 「キャンセル」（グレー）
│   │   → action: `medium` ハプティクス + appState.reset() + transition(.keyboard)
│   └── Spacer()
└── Button: 「次へ →」（ピンク）
    → 活性条件: inputText.count >= 1
    → action:
        1. appState.chatContext = inputText   // 手動入力をチャット文脈として設定
        2. Q1〜Q3生成APIを呼び出す（startAIFlow の ③ のみ実行）
        3. transition(.askUser)

└── BottomActionBar
```

### エラーテキスト定義

```swift
// FallbackLayerView.swift
var errorMessage: String {
    switch appState.fallbackReason {
    case .imageCaptureFailed:
        return "画面の読み取りができませんでした。相手のメッセージを入力してください。"
    case .apiTimeout:
        return "AI処理がタイムアウトしました。直接メッセージを入力して続けられます。"
    case .apiError:
        return "AI処理でエラーが発生しました。直接メッセージを入力して続けられます。"
    case .none:
        return ""
    }
}
```

---

## 3-8. KBD-S-010｜権限未許可ブロック画面

### 画面レイアウト

```
ZStack（全体）
├── Color("VeilBackground")  ← 半透明ベール
│   .ignoresSafeArea()
│
└── VStack（通知カード）
    ├── Image(systemName: "exclamationmark.shield.fill")
    │   .font(.system(size: 36))
    │   .foregroundStyle(Color("WarningYellow"))
    ├── Text: 「設定が必要です」 Font: .kbdButton
    ├── Text（permissionIssueに対応するメッセージ）
    │   Font: .kbdCaption Color: TextSecondary
    │   multilineTextAlignment: .center
    ├── PinkPrimaryButton相当: 「アプリを開いて設定する」
    │   → action: extensionContext?.open(URL(string: "motekey://settings/permission")!)
    └── Button: 「あとで」（テキストリンク）
        → action: transition(.keyboard)

    .padding(Spacing.xl)
    .background(Color("BgSecondary"))
    .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
    .padding(.horizontal, Spacing.xl)
```

### ブロック解除の自動検知

```swift
// PermissionBlockLayerView.swift
.onReceive(
    NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
) { _ in
    recheckPermissions()
}

func recheckPermissions() {
    guard let context = moteKeyContext else { return }
    if context.hasFullAccess {
        withAnimation(.screenFade) {
            appState.permissionIssue = .none
            appState.transition(to: .keyboard)
        }
    }
}
```

### 権限種別メッセージ

```swift
var permissionMessage: String {
    switch appState.permissionIssue {
    case .fullAccessDenied:
        return "mote+AIを使うには、キーボードのフルアクセスが必要です。アプリを開いて設定してください。"
    case .screenRecordingDenied:
        return "相手のメッセージを読み取るには、画面収録の許可が必要です。アプリを開いて設定してください。"
    case .none:
        return ""
    }
}
```

---

## 3-9. BottomActionBar｜常時表示バー

### 仕様

- 高さ：52pt（固定）
- 背景：`BgGrouped`
- 上部ボーダー：`Divider()`（1pt、Separator色）
- ZIndex：100（最前面固定）
- `キーボード` タブは常にタップ可能とし、`mote+AI` 質問中の中断導線としても使う
- `全文` タブは生成済み候補が存在する場合のみ活性とする

### レイアウト

```swift
// BottomActionBarView.swift
struct BottomActionBarView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var heightProvider: KeyboardHeightProvider
    @Namespace var sliderNamespace

    static let height: CGFloat = 52

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 0) {

                // ── 要素1: 地球儀アイコン ─────────────────────────
                Button(action: {
                    moteKeyContext?.advanceToNextInputMode()
                }) {
                    Image(systemName: "globe")
                        .font(.system(size: 20))
                        .foregroundStyle(Color("TextSecondary"))
                        .frame(width: 52, height: BottomActionBarView.height)
                        .contentShape(Rectangle())
                }

                Spacer()

                // ── 要素2: mote+AIボタン ──────────────────────────
                MotePlusAIButton()

                Spacer()

                // ── 要素3: 表示モードスライダー ───────────────────
                DisplayModeSlider(namespace: sliderNamespace)
            }
            .frame(height: BottomActionBarView.height)
            .padding(.horizontal, Spacing.sm)
        }
        .background(Color("BgGrouped"))
    }
}
```

### MotePlusAIButton

```swift
// MotePlusAIButton.swift
struct MotePlusAIButton: View {
    @EnvironmentObject var appState: AppState
    @State private var scale: CGFloat = 1.0

    var body: some View {
        Button(action: handleTap) {
            HStack(spacing: Spacing.xs) {
                if appState.isAIProcessing {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(Color("TextOnAccent"))
                } else {
                    Image(systemName: "sparkles")
                        .font(.system(size: 13, weight: .semibold))
                }
                Text("mote+AI")
                    .font(.kbdButton)
            }
            .foregroundStyle(Color("TextOnAccent"))
            .padding(.horizontal, Spacing.md)
            .frame(height: 36)
            .background(
                appState.isAIProcessing
                    ? Color("AccentPink").opacity(0.6)
                    : Color("AccentPink")
            )
            .clipShape(RoundedRectangle(cornerRadius: Radius.button))
        }
        .disabled(appState.isAIProcessing)
        .scaleEffect(scale)
        .buttonStyle(.plain)
    }

    func handleTap() {
        // 1. ハプティクス
        Haptics.light()

        // 2. バウンスアニメーション
        withAnimation(.buttonBounce) { scale = 0.95 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.buttonBounce) { scale = 1.0 }
        }

        // 3. 権限チェック
        guard let context = moteKeyContext, context.hasFullAccess else {
            appState.permissionIssue = .fullAccessDenied
            appState.transition(to: .permissionBlock)
            return
        }

        // 4. AI処理開始
        appState.isAIProcessing = true
        appState.generationTask = Task {
            await startAIFlow()
        }
    }
}
```

### DisplayModeSlider

```swift
// DisplayModeSlider.swift
struct DisplayModeSlider: View {
    @EnvironmentObject var appState: AppState
    var namespace: Namespace.ID

    private var isFullTextDisabled: Bool {
        appState.generatedCandidates.isEmpty
    }

    var body: some View {
        HStack(spacing: 0) {
            sliderTab(label: "キーボード", mode: .chip, isDisabled: false)
            sliderTab(label: "全文", mode: .fullText, isDisabled: isFullTextDisabled)
        }
        .background(Color("BgSecondary"))
        .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
        .frame(height: 30)
        .frame(width: 130)
    }

    @ViewBuilder
    func sliderTab(label: String, mode: DisplayMode, isDisabled: Bool) -> some View {
        let isSelected = appState.displayMode == mode

        ZStack {
            if isSelected {
                RoundedRectangle(cornerRadius: Radius.sm - 2)
                    .fill(Color("BgPrimary"))
                    .matchedGeometryEffect(id: "indicator", in: namespace)
                    .padding(2)
            }
            Text(label)
                .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(
                    isSelected ? Color("TextPrimary") : Color("TextSecondary")
                )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .opacity(isDisabled ? 0.4 : 1.0)
        .contentShape(Rectangle())
        .onTapGesture {
            guard !isDisabled else { return }
            guard mode != appState.displayMode || appState.currentScreen == .askUser || appState.currentScreen == .loading else { return }
            Haptics.medium()
            withAnimation(.sliderMove) {
                if mode == .chip {
                    if appState.currentScreen == .askUser || appState.currentScreen == .loading {
                        appState.cancelAskUserFlow()
                        appState.currentScreen = .keyboard
                    } else {
                        appState.displayMode = .chip
                        appState.currentScreen = appState.generatedCandidates.isEmpty ? .keyboard : .stage
                    }
                } else {
                    appState.displayMode = .fullText
                    appState.currentScreen = .fullText
                }
            }
        }
    }
}
```

---

## 3-10. Extension遷移定義

### AIフロー起動処理

```swift
// AIFlowCoordinator.swift（AppState の extension として実装）
// ※ アーキテクチャ設計書 2.2「キーボード使用時フロー」に準拠
extension AppState {

    func startAIFlow() async {
        // ① App Group から最新フレーム（latest_frame.jpg）を読み込む
        //    Broadcast Upload Extension が常時上書き保存しているファイル
        let appGroupURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: AppGroupKeys.suiteName)
        guard let frameURL = appGroupURL?.appendingPathComponent(AppGroupKeys.latestFrameFileName),
              let imageData = try? Data(contentsOf: frameURL) else {
            await MainActor.run {
                isAIProcessing = false
                fallbackReason = .imageCaptureFailed
                transition(to: .fallback)
            }
            return
        }

        // ② Gemini Vision API でチャット文脈を抽出
        //    画像は送信後即破棄（メモリ節約）
        do {
            let extractedContext = try await GeminiService.shared.extractChatContext(imageData: imageData)
            // imageData はこのスコープ後に解放される

            // ③ チャット文脈をもとに Q1〜Q3 を一括生成（1回のAPI呼び出し）
            let questions = try await GeminiService.shared.generateAskUserQuestions(
                chatContext: extractedContext,
                textStyleProfile: loadTextStyleProfile(),
                relationProfile: loadRelationProfile()
            )

            await MainActor.run {
                chatContext = extractedContext        // 返信生成④で使用
                askUserQuestions = questions          // 常に3件
                currentQuestionIndex = 0
                isAIProcessing = false
                transition(to: .askUser)
            }
        } catch {
            // Vision API 失敗 or Q生成失敗 → 手入力フォールバック
            await MainActor.run {
                isAIProcessing = false
                fallbackReason = .imageCaptureFailed
                transition(to: .fallback)
            }
        }
    }
}
```

### 全遷移マトリクス

| 遷移元 | 遷移先 | トリガー | ハプティクス | アニメーション |
|---|---|---|---|---|
| KBD-S-005 | KBD-S-006 | mote+AIタップ + 権限OK + 画像解析OK | light（タップ時）| screenFade |
| KBD-S-005 | KBD-S-009 | mote+AIタップ + 画像解析失敗 | error | screenFade |
| KBD-S-005 | KBD-S-010 | mote+AIタップ + 権限NG | light（タップ時）| screenFade |
| KBD-S-006 | KBD-S-006（次問） | 選択肢タップ | light | 0.25秒後 screenFade |
| KBD-S-006（最終問） | KBD-S-006.5 | 選択肢タップ | light | veilAppear |
| KBD-S-006.5 | KBD-S-007 | AI生成成功（自動） | success | veilDisappear + chipSlideIn |
| KBD-S-006.5 | KBD-S-009 | AI生成失敗（自動） | error | veilDisappear + screenFade |
| KBD-S-006 | KBD-S-005 | `キーボード` タブタップ | medium | screenFade + 質問状態破棄 |
| KBD-S-006.5 | KBD-S-005 | `キーボード` タブタップ | medium | screenFade + Task cancel |
| KBD-S-007 | KBD-S-007 | チップタップ | medium | 画面遷移なし（入力欄へ反映） |
| KBD-S-008 | KBD-S-007 | カードタップ | medium | screenFade + 入力欄へ反映 |
| KBD-S-007 ↔ KBD-S-008 | スライダー操作 | medium | sliderMove |
| KBD-S-009 | KBD-S-006 | 「次へ」タップ | light | screenFade |
| KBD-S-009 | KBD-S-005 | 「キャンセル」タップ | medium | screenFade |
| KBD-S-010 | KBD-S-005 | 権限確認後（自動） | なし | screenFade |

---

# Part 4: 実装リファレンス

## 4-1. SwiftUIエラー防止パターン集

### ❌ 禁止パターンと ✅ 代替

```swift
// ❌ 禁止: Extension内でのNavigationStack使用
NavigationStack { ... }

// ✅ 代替: ZStack + opacity制御
ZStack {
    ViewA().opacity(condition ? 1 : 0).allowsHitTesting(condition)
    ViewB().opacity(!condition ? 1 : 0).allowsHitTesting(!condition)
}
```

```swift
// ❌ 禁止: Extension内でのsheet/fullScreenCover
.sheet(isPresented: $show) { ... }
.fullScreenCover(isPresented: $show) { ... }

// ✅ 代替: ZStack内のTransition
if showFallback {
    FallbackLayerView()
        .zIndex(60)
        .transition(.opacity.animation(.screenFade))
}
```

```swift
// ❌ 禁止: 外部画像ファイルの使用
Image("custom_image")

// ✅ 代替: SF Symbolsのみ
Image(systemName: "sparkles")
```

```swift
// ❌ 禁止: UIColor.label を Color() で直接ラップ
// (ダークモード対応が保証されない場合がある)
Color(UIColor.label)

// ✅ 代替: Asset Catalogのカラーセット または 動的Color
Color("TextPrimary")  // Asset Catalog経由
// または
Color(UIColor.label)  // UIColorは自動適応するため、これは実は安全
```

```swift
// ❌ 禁止: 大量のViewを一度にツリーに追加
ForEach(0..<1000) { i in HeavyView(index: i) }

// ✅ 代替: LazyVStack / LazyHStack を使用
LazyVStack { ForEach(items) { ItemView($0) } }
```

```swift
// ❌ 禁止: TextEditorにプレースホルダーを直接設定しようとする
TextEditor(text: $text).placeholder("...")  // このAPIは存在しない

// ✅ 代替: ZStackでプレースホルダーを重ねる
ZStack(alignment: .topLeading) {
    if text.isEmpty {
        Text("プレースホルダー")
            .foregroundStyle(Color("TextTertiary"))
            .padding(.top, 8).padding(.leading, 4)
            .allowsHitTesting(false)
    }
    TextEditor(text: $text)
}
```

```swift
// ❌ 禁止: DatePickerで年なし月日のみを出そうとする
DatePicker("", selection: $date, displayedComponents: [.date])
// → 年が必ず表示される

// ✅ 代替: UIPickerViewをUIViewRepresentableでラップ
struct MonthDayPicker: UIViewRepresentable {
    @Binding var selection: MonthDay
    // 月（1-12）と日（1-31）の2カラム
}
```

```swift
// ❌ 禁止: matchedGeometryEffectを条件付きViewに適用
if condition {
    View().matchedGeometryEffect(id: "id", in: ns)  // クラッシュリスク
}

// ✅ 代替: 常にツリーに存在させてopacityで制御
View()
    .matchedGeometryEffect(id: "id", in: ns)
    .opacity(condition ? 1 : 0)
```

```swift
// ❌ 禁止: Task内でMainActor以外からPublished変数を更新
Task {
    let result = await fetch()
    appState.data = result  // コンパイルエラー or 実行時警告
}

// ✅ 代替: MainActorで明示的にラップ
Task {
    let result = await fetch()
    await MainActor.run {
        appState.data = result
    }
}
```

### メモリ安全チェックリスト

```swift
// ✅ タイマーは必ず無効化する
struct LoadingVeilView: View {
    let timer = Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()
    // autoconnectは.onReceiveと組み合わせた場合、
    // Viewが破棄されると自動でキャンセルされる（安全）
}

// ✅ TaskはViewが消えたらキャンセルされる（SwiftUI管理）
.task {
    await longRunningWork()  // Viewが消えると自動キャンセル
}

// ✅ NotificationCenter の購読はonReceiveで管理（自動解除）
.onReceive(NotificationCenter.default.publisher(for: ...)) { _ in ... }
```

---

## 4-2. azooKey統合インターフェース

```swift
// MoteKeyContext.swift（Shared Framework）
protocol MoteKeyHostContext: AnyObject {
    func insertText(_ text: String)
    func clearMarkedText()
    func advanceToNextInputMode()
    var hasFullAccess: Bool { get }
}

// KeyboardViewController.swift（Extension Target）
class KeyboardViewController: UIInputViewController, MoteKeyHostContext {
    private var appState = AppState()
    private var heightProvider = KeyboardHeightProvider()

    override func viewDidLoad() {
        super.viewDidLoad()

        let rootView = MoteKeyRootView()
            .environmentObject(appState)
            .environmentObject(heightProvider)
            .environment(\.moteKeyContext, self)

        let hostingVC = UIHostingController(rootView: rootView)
        hostingVC.view.backgroundColor = .clear
        hostingVC.view.translatesAutoresizingMaskIntoConstraints = false

        addChild(hostingVC)
        view.addSubview(hostingVC.view)

        NSLayoutConstraint.activate([
            hostingVC.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingVC.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingVC.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingVC.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        hostingVC.didMove(toParent: self)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // キーボード高さをSwiftUI側に通知
        heightProvider.keyboardHeight = view.frame.height
    }

    // MoteKeyHostContext 準拠
    func insertText(_ text: String) {
        textDocumentProxy.insertText(text)
    }

    func clearMarkedText() {
        // azooKeyの変換中テキストをクリア
        // 実装はazooKeyのAPIに依存
    }

    func advanceToNextInputMode() {
        // iOS標準のキーボード切り替え
        super.advanceToNextInputMode()
    }

    var hasFullAccess: Bool {
        return super.hasFullAccess
    }
}
```

### テキスト挿入の完全フロー

```swift
// テキスト挿入時は必ずこの順序を守る
func safeInsertText(_ text: String, context: any MoteKeyHostContext) {
    // 1. 未確定テキスト（変換中）のクリア
    context.clearMarkedText()

    // 2. テキスト挿入（カーソル位置に追記）
    context.insertText(text)

    // 3. ハプティクス
    Haptics.medium()

    // 4. キャッシュクリア
    appState.reset()

    // 5. KBD-S-005へ戻る
    appState.transition(to: .keyboard)
}
```

---

## 4-3. App Group共有データスキーマ

```swift
// AppGroupKeys.swift（Shared Framework）
enum AppGroupKeys {
    static let suiteName = "group.com.motekey.shared"

    // テキストハビット
    static let textStyleRegistered  = "textStyleRegistered"
    static let textStyleSummary     = "textStyleSummary"      // サマリーテキスト（UI表示用）
    static let textStyleProfileData = "textStyleProfileData"  // JSONエンコード

    // リレーション
    static let relationRegistered   = "relationRegistered"
    static let relationProfileData  = "relationProfileData"   // JSONエンコード

    // キーボード設定
    static let setupConfigured      = "setupConfigured"

    // 最新フレーム（Broadcast Upload Extension が書き込む）
    static let latestFrameFileName  = "latest_frame.jpg"
}

// TextStyleProfile.swift（Shared Framework）
// ※ prompt_text_habit_analyze.md の出力フォーマットに準拠
struct ToneProfileDetails: Codable {
    let ending_patterns: String   // 語尾のクセ
    let emoji_usage: String       // 絵文字・記号の使い方
    let empathy_style: String     // 共感・リアクションの表現
    let suggestion_style: String  // 提案・誘いの言い方
    let message_length: String    // 文の長さと構成
    let colloquial_style: String  // 口語的表現・省略語
}

struct ToneProfile: Codable {
    let summary: String           // 口調を一言で表現
    let rules: [String]           // 生成時に適用するルール（最大10項目）
    let details: ToneProfileDetails
}

struct TextStyleProfile: Codable {
    let tone_profile: ToneProfile

    // ホストアプリ表示用サマリー（tone_profile.summary から取得）
    var summary: String { tone_profile.summary }
}

// RelationProfile.swift（Shared Framework）
struct RelationProfile: Codable {
    let nickname: String
    let relationshipType: String
    let datingStartDate: Date?
    let marriageDate: Date?
    let birthdayMonth: Int?
    let birthdayDay: Int?
    let cautionNote: String
}
```

---

## 4-4. 実装チェックリスト

### ホストアプリ

- [ ] `NavigationStack` が `HostRoute` enum を使ったタイプセーフなルーティングになっているか
- [ ] TextEditor（S-003-4）に ZStack でプレースホルダーが実装されているか
- [ ] S-003-4 の誕生日入力が `UIViewRepresentable` の月日PickerViewになっているか（年なし）
- [ ] S-003-4 の同意チェックボックスが未選択時に `登録する` ボタンを `.disabled(true)` にしているか
- [ ] S-004 のキーボード許可確認が `applicationDidBecomeActive` 通知で行われているか
- [ ] S-004 の「次へ」が `hasMotekeyEnabled && hasAcknowledgedScreenRecording` で制御されているか
- [ ] `UIApplication.open(settingsURL)` が `UIApplication.openSettingsURLString` を使っているか（プライベートURLスキーム不使用）
- [ ] App Group の suiteName が Extension と完全一致しているか
- [ ] `TextStyleProfile` / `RelationProfile` が `Codable` で適切にエンコード/デコードされているか
- [ ] S-002-LOADING でAPIタイムアウトのエラー処理（10秒）が実装されているか
- [ ] `CheckmarkAnimationView` が `@State` で `appeared` 管理されているか

### キーボード拡張

- [ ] Extension 内に `NavigationStack` / `sheet` / `fullScreenCover` が一切使われていないか
- [ ] ZStack の `zIndex` が定義書（20/30/40/50/60/70/100）通りになっているか
- [ ] `allowsHitTesting(false)` が opacity=0 の View に設定されているか
- [ ] `lineLimit(nil)` が S-008（FullTextCardView）に指定されているか
- [ ] テキスト挿入が `clearMarkedText()` → `insertText()` の順序になっているか
- [ ] スライダーが `generatedCandidates.isEmpty` 時に `.disabled(true)` + opacity 0.4 になっているか
- [ ] S-010 の「アプリを開いて設定する」が `extensionContext?.open(URL(...))` を使っているか
- [ ] キーボード高さ < 200pt で全文表示スライダーが機能制限されているか
- [ ] `BottomActionBarView.height` 定数（52pt）が他のView（ScrollView高さ計算）から参照されているか
- [ ] `@Published` 変数の更新が全て `@MainActor` または `await MainActor.run {}` で行われているか
- [ ] チップアニメーションの delay が `Double(index) * 0.05` になっているか
- [ ] `LoadingVeilView` の Timer が `.publish(...).autoconnect()` + `.onReceive` で管理されているか
- [ ] APIリクエストが `Task { await ... }` で管理され、Extension非アクティブ時にキャンセルされるか
- [ ] `URLSession` の `timeoutIntervalForRequest` が 10秒に設定されているか
- [ ] 外部フォント・外部画像ファイルが一切使われていないか（SF Symbols + システムフォントのみ）

---

*Document Version: 1.3*
*対象アプリ: モテキー*
*前提: 要件定義書 v1.7（requirements.md）*
*更新日: 2026-03-21*
