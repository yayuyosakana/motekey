# セットアップガイド

## 前提

このアプリはazooKeyをベースに開発します。
**コード（Swift）はAIが生成**しますが、以下のXcode GUI操作のみ手動が必要です。

---

## Step 1: Gemini APIキーの取得

1. [Google AI Studio](https://aistudio.google.com/) を開く
2. 右上「Get API key」→「Create API key」を4回実行して4キーを発行
3. 用途ごとにキーを対応付けて手元に保管

| 用途 | キー名（推奨ラベル） |
|------|----------------------|
| テキストハビット抽出 | `TEXT_HABIT` |
| 画面文脈抽出（Vision） | `VISION_CONTEXT` |
| アスクユーザー質問生成 | `ASK_USER_QUESTION` |
| 返信文生成 | `REPLY_GENERATION` |

---

## Step 2: azooKeyをforkしてclone

```bash
# GitHubでazooKey/azooKeyをforkした後
git clone https://github.com/YOUR_NAME/azooKey.git MoteKey
cd MoteKey
```

---

## Step 3: APIキーのセットアップ

```bash
# テンプレートをコピー
cp Config/Secrets.xcconfig.template Config/Secrets.xcconfig
```

`Config/Secrets.xcconfig` を開いてキーを貼り付け：

```
GEMINI_API_KEY_TEXT_HABIT = AIza...text-habit用...
GEMINI_API_KEY_VISION_CONTEXT = AIza...vision-context用...
GEMINI_API_KEY_ASK_USER_QUESTION = AIza...ask-user-question用...
GEMINI_API_KEY_REPLY_GENERATION = AIza...reply-generation用...
```

---

## Step 4: Xcodeでプロジェクトを開く

```bash
open azooKey.xcodeproj  # またはプロジェクト名に合わせる
```

---

## Step 5: Bundle IDの変更【Xcode GUI】

Xcodeの左ペインでプロジェクトルートを選択 → 各ターゲットの「Signing & Capabilities」タブで以下に変更：

| ターゲット | Bundle ID |
|------------|-----------|
| MainApp | `com.motekey.app` |
| Keyboard Extension | `com.motekey.app.keyboard` |
| Broadcast Extension | `com.motekey.app.broadcast` |

Teamは自分のApple IDを選択。

---

## Step 6: App Groupの設定【Xcode GUI】

以下の**3ターゲット全て**で同じ操作を行う：

1. ターゲットを選択 → 「Signing & Capabilities」タブ
2. 「+ Capability」→「App Groups」を追加
3. 「+」ボタンで `group.com.motekey.shared` を追加（3ターゲット全てで同じ名前）

---

## Step 7: xconfigをターゲットに適用【Xcode GUI】

LeftペインでプロジェクトルートNode → 「Info」タブ → 「Configurations」欄：

`Secrets.xcconfig` を以下の**全ターゲット・全Configuration**に設定：

| Configuration | ターゲット | 設定するxcconfig |
|--------------|------------|-----------------|
| Debug | MainApp | `Secrets` |
| Debug | Keyboard Extension | `Secrets` |
| Debug | Broadcast Extension | `Secrets` |
| Release | MainApp | `Secrets` |
| Release | Keyboard Extension | `Secrets` |
| Release | Broadcast Extension | `Secrets` |

> これでKeyboard ExtensionとBroadcast ExtensionのBundle.mainからもGemini APIキーが読めるようになります。

---

## Step 8: 各ターゲットのInfo.plistにAPIキーを追加【Xcode GUI】

**3ターゲット全てのInfo.plist**に以下のキーを追加：

| Key | Value |
|-----|-------|
| `GeminiAPIKeyTextHabit` | `$(GEMINI_API_KEY_TEXT_HABIT)` |
| `GeminiAPIKeyVisionContext` | `$(GEMINI_API_KEY_VISION_CONTEXT)` |
| `GeminiAPIKeyAskUserQuestion` | `$(GEMINI_API_KEY_ASK_USER_QUESTION)` |
| `GeminiAPIKeyReplyGeneration` | `$(GEMINI_API_KEY_REPLY_GENERATION)` |

操作: ターゲット選択 → 「Info」タブ → 「Custom iOS Target Properties」の「+」ボタン

---

## Step 9: Keyboard ExtensionのフルアクセスをON【Xcode GUI】

Keyboard Extensionターゲット → `Info.plist` で：

```
NSExtension > NSExtensionAttributes > RequestsOpenAccess = YES
```

---

## Step 10: ビルド確認

1. シミュレーター or 実機を選択
2. `Cmd + B` でビルド
3. エラーがなければOK

---

## Step 11: 実機でのキーボード許可（開発中の動作確認用）

1. アプリをインストール後、設定 → 一般 → キーボード → キーボードを追加 → MoteKey
2. 「フルアクセスを許可」をON
3. コントロールセンターからBroadcast（画面収録）を開始

---

## Xcodeなしでやること（AIが対応）

以下はAIがコードとして実装します：
- 全SwiftUIコード（オンボーディング画面）
- Keyboard Extension UI（azooKeyへのMoteKey機能追加）
- Broadcast Extension（RPBroadcastSampleHandler実装）
- Gemini APIクライアント
- App Groupデータ読み書きロジック
- システムプロンプトの組み込み

---

## トラブルシューティング

| 症状 | 原因 | 対処 |
|------|------|------|
| ビルドエラー: `GEMINI_API_KEY_* undefined` | xconfigがターゲットに未適用 | Step 7を確認 |
| Keyboard Extensionがキーを読めない | ExtensionのInfo.plistにキー未追加 | Step 8を確認 |
| App Group通信が動かない | 3ターゲットでApp Group IDが不一致 | Step 6を確認、IDを揃える |
| Extension起動時にクラッシュ | メモリ超過（50MB制限） | technical-design.mdを参照 |
