# アーキテクチャ設計書

## 1. アプリ構成

モテキーは1つのHost Appと2つのApp Extensionで構成される。

> 補足: S-002「テキストハビットチェック」と S-003「リレーションチェック」の参考画像は検討用モックであり、完成UIではない。画面名と責務の定義は [requirements.md](../requirements.md) を正とする。

```
モテキー.app
├── アプリ本体 (Host App)
│   ├── オンボーディング画面（SwiftUI）
│   │   ├── S-001: アプリトップ画面
│   │   ├── S-002: テキストハビットチェック画面
│   │   ├── S-003: リレーションチェック画面
│   │   └── S-004: キーボード許可 & 画面収録開始画面
│   ├── テキストハビット登録 → App Groupに保存
│   ├── リレーション登録 → App Groupに保存
│   └── キーボード許可 & 画面収録開始の案内
│
├── キーボードExtension (Custom Keyboard)
│   ├── azooKeyベースの通常キーボード（S-005: キーボードタブ）
│   ├── `mote+AI` タブ押下 → App Groupから最新フレーム取得
│   ├── Gemini Vision API呼び出し → チャット文脈抽出
│   ├── Gemini API呼び出し → アスクユーザーQ1〜Q3一括生成（S-006: mote+AIタブ）
│   ├── Gemini API呼び出し → 返信文生成
│   └── ステージUI（S-007: キーボードタブ上のステージバー / 全文表示タブ）
│
└── Broadcast Upload Extension (ReplayKit)
    ├── 画面収録フレーム（CMSampleBuffer）を受信
    ├── 50%ダウンスケール + JPEG圧縮（~100-150KB）
    └── 最新1フレームをApp Groupに上書き保存
```

## 2. データフロー

### 2.1 オンボーディングフロー（初回のみ）

```
ユーザー入力（返信サンプル等）
  → アプリ本体
  → Gemini API（テキストハビット抽出）
  → テキストスタイル情報（テキスト）
  → App Group (UserDefaults) に保存

ユーザー入力（リレーション情報）
  → アプリ本体
  → App Group (UserDefaults) に保存
```

### 2.2 キーボード使用時フロー（毎回）

```
                   Broadcast Upload Extension
                   │ (常時稼働)
                   │ CMSampleBuffer受信
                   │  → 50%ダウンスケール
                   │  → JPEG圧縮 (~100-150KB)
                   │  → App Group に上書き保存
                   ▼
┌─────────────────────────────────────────────────────────┐
│  キーボードExtension                                     │
│                                                         │
│  ① `mote+AI` タブのボタン押下                             │
│     → App Groupから最新フレーム(JPEG)を読込               │
│     → Gemini Vision APIに送信                            │
│     → 構造化チャット文脈（JSON）を受信                    │
│     → フレーム画像を即座に破棄                            │
│                                                         │
│  ② アスクユーザーインプット（1回API / mote+AIタブ）        │
│     Gemini API(チャット文脈) → Q1〜Q3一括生成              │
│     Q1表示 → 回答（API呼び出しなし）                       │
│     Q2表示 → 回答（API呼び出しなし）                       │
│     Q3表示 → 回答（API呼び出しなし）                       │
│     ※質問フロー中に `キーボード` タブへ切替時は中断し、      │
│       ローカル質問状態と進行中Taskを破棄/キャンセルする      │
│                                                         │
│  ③ 返信文生成                                            │
│     Gemini API(文脈+Q1~Q3回答+ハビット+リレーション+today_date+SP) │
│     → 返信メッセージ（チップ形式で複数）                  │
│                                                         │
│  ④ ステージ表示（キーボードタブ / 全文表示タブ）          │
│     → チップをタップ順で入力欄へ反映 → 手編集 → 送信      │
│     ※`全文表示` は候補確認/選択の表示面であり送信面ではない │
└─────────────────────────────────────────────────────────┘
                                                    │
                 App Group (UserDefaults)            │
                 ├── テキストハビット情報 ──────読込──┤
                 └── リレーション情報 ────────読込──┘
```

## 3. Extension間データ共有設計

すべてのデータ共有は **App Groups**（`group.com.motekey.shared`）を経由する。

| データ項目           | 保存方式                | 書き込み元          | 読み込み元          | 更新頻度           |
| -------------------- | ----------------------- | ------------------- | ------------------- | ------------------ |
| テキストハビット情報 | UserDefaults (App Group) | アプリ本体          | キーボードExtension | 初回 + ユーザー変更時 |
| リレーション情報     | UserDefaults (App Group) | アプリ本体          | キーボードExtension | 初回 + ユーザー変更時 |
| 最新画面フレーム     | ファイル（1枚上書き）    | Broadcast Extension | キーボードExtension | 常時（毎フレーム）  |
| システムプロンプト   | アプリバンドル内         | —（組み込み済み）   | キーボードExtension | —（静的）          |

### App Group ファイル構成

```
group.com.motekey.shared/
├── Library/Preferences/
│   └── group.com.motekey.shared.plist  ← UserDefaults（ハビット・リレーション情報）
└── latest_frame.jpg                     ← 最新画面フレーム（~100-150KB、常時上書き）
```

## 4. 技術スタック一覧

| カテゴリ              | 技術                                   | 用途                                                      |
| --------------------- | -------------------------------------- | --------------------------------------------------------- |
| 言語                  | Swift                                  | アプリ本体・キーボードExtension・Broadcast Extensionすべて |
| UIフレームワーク      | SwiftUI                                | アプリ本体のオンボーディング画面（S-001〜S-004）          |
| キーボードUI          | UIKit (Custom Keyboard Extension)      | azooKeyベースのキーボードUI（S-005〜S-007）               |
| 画面収録              | ReplayKit (Broadcast Upload Extension) | LINE画面を含む全画面フレームのキャプチャ                  |
| 画像処理              | Core Image (CIContext, CIImage)        | Broadcast Extension内でのダウンスケール・JPEG圧縮         |
| Extension間データ共有 | App Groups                             | 3つのExtension間のデータ共有                              |
| データ保存            | UserDefaults (App Group)               | テキストハビット・リレーション情報のローカル保存           |
| ネットワーク通信      | URLSession                             | Gemini APIへのHTTPリクエスト                               |
| 外部API               | Gemini API / Gemini Vision API         | テキスト生成・画像解析                                    |
| ベースキーボード      | azooKey (OSS)                          | カスタムキーボードのベース実装                            |
