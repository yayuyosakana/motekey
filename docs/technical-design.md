# 技術設計書

## 1. 画像最適化設計

取得したフレームをフル解像度のままGemini Vision APIにかけるのではなく、文字が判別できるギリギリのサイズまでダウンスケールしてから解析に回す。

| 段階                          | 解像度                       | サイズ             | 備考                                  |
| ----------------------------- | ---------------------------- | ------------------ | ------------------------------------- |
| 元フレーム（CMSampleBuffer）  | 1170x2532（iPhone 14 Pro相当） | ~11.8MB（非圧縮RGBA） | Broadcast Extensionが受信             |
| 50%ダウンスケール             | 585x1266                     | ~3MB（非圧縮）      | LINEの文字は十分判読可能              |
| JPEG圧縮（quality: 0.7）     | 585x1266                     | **~100-150KB**     | App Groupに保存するファイル           |

**なぜ50%で十分か:** LINEのメッセージテキストは元画面で14-16pt程度。50%縮小後も7-8pt相当で、Gemini Vision APIの文字認識精度に影響しない。

---

## 2. メモリ設計

iOSではキーボードExtension・Broadcast Upload Extensionともにメモリ上限が**約50MB**。超過するとOSに即座にkillされる。

### 2.1 Broadcast Upload Extension のメモリ内訳

| 項目                          | メモリ使用量   | 方針                                                   |
| ----------------------------- | -------------- | ------------------------------------------------------ |
| ReplayKitランタイム           | ~5-10MB        | フレームワーク自体の使用量                             |
| CMSampleBuffer受信（一時）    | ~11.8MB        | 受信直後にautoreleasepool内で処理し即解放              |
| ダウンスケール処理（一時）    | ~3MB           | CGContext描画。autoreleasepool内で即解放               |
| JPEG Data生成（一時）         | ~0.1-0.15MB    | ファイル書き込み後に即解放                             |
| **ピーク合計**                | **~20-25MB**   | **50MB制限に対して余裕あり**                           |

#### Swiftコード: フレーム処理 + autoreleasepool

```swift
func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with type: RPSampleBufferType) {
    guard type == .video else { return }
    autoreleasepool {
        // 1. CMSampleBuffer → CIImage（~11.8MB、一時的）
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)

        // 2. 50%ダウンスケール（~3MB、一時的）
        let scaled = ciImage.transformed(by: CGAffineTransform(scaleX: 0.5, y: 0.5))

        // 3. JPEG圧縮（~100-150KB）→ ファイル書き込み
        let context = CIContext()
        if let jpegData = context.jpegRepresentation(of: scaled, colorSpace: scaled.colorSpace!) {
            try? jpegData.write(to: appGroupURL.appendingPathComponent("latest_frame.jpg"),
                                options: .atomic)
        }
        // autoreleasepool 終了時に ciImage, scaled, jpegData が即座に解放される
    }
}
```

### 2.2 キーボードExtension のメモリ内訳

| 項目                          | メモリ使用量   | 方針                                                   |
| ----------------------------- | -------------- | ------------------------------------------------------ |
| azooKeyベースUI               | ~20-30MB       | キーボード自体の描画                                   |
| フレーム画像読込（一時）      | ~0.1-0.15MB    | ダウンスケール済みJPEG。autoreleasepool内で即解放      |
| API通信（URLSession）         | ~2-5MB         | 標準使用量                                             |
| テキストデータ                | ~数KB          | 文脈・回答・生成結果すべてテキストのみ保持             |
| **ピーク合計**                | **~23-35MB**   | **50MB制限に対して余裕あり**                           |

#### Swiftコード: `mote+AI` タブ押下時

```swift
func onMoteAITabTapped() {
    autoreleasepool {
        let url = appGroupURL.appendingPathComponent("latest_frame.jpg")
        guard let imageData = try? Data(contentsOf: url) else {
            showManualInputFallback()  // フォールバック
            return
        }
        // imageData (~100-150KB) をGemini Vision APIに送信
        sendToGeminiVision(imageData: imageData) { result in
            // imageData はこのスコープ外で解放される
            switch result {
            case .success(let chatContext):
                self.proceedToAskUser(context: chatContext)
            case .failure:
                self.showManualInputFallback()  // フォールバック
            }
        }
    }
}
```

---

## 3. クラッシュ対策（3軸別）

### 3.1 軸1: Broadcast Upload Extension

| クラッシュ要因       | 発生条件                           | 対策                                                                    |
| -------------------- | ---------------------------------- | ----------------------------------------------------------------------- |
| メモリ超過           | CMSampleBufferが解放されずに蓄積   | `autoreleasepool`で毎フレーム即時解放。ダウンスケールで中間データ量を削減 |
| ディスク書き込み失敗 | App Group領域の空き容量不足        | `.atomic`オプションで書き込み。失敗時はスキップし次フレームで再試行      |
| フレーム処理の遅延   | 処理がフレームレートに追いつかない | 処理中フラグで制御し、処理中の新規フレームはスキップ                    |
| Extension停止        | OSがバックグラウンドリソースを回収 | キーボード側でフレーム取得失敗時に手入力フォールバックを提供            |

#### Swiftコード: フレームスキップパターン

```swift
// 処理中は新しいフレームを無視し、メモリ蓄積を防止
private var isProcessing = false

func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with type: RPSampleBufferType) {
    guard type == .video, !isProcessing else { return }
    isProcessing = true
    autoreleasepool {
        // ... ダウンスケール & JPEG保存処理 ...
    }
    isProcessing = false
}
```

### 3.2 軸2: キーボードExtension（iOS側）

| クラッシュ要因             | 発生条件                          | 対策                                                                 |
| -------------------------- | --------------------------------- | -------------------------------------------------------------------- |
| メモリ超過（50MB）         | 画像データやAPIレスポンスの解放漏れ | `autoreleasepool`で画像読込を囲む。テキスト以外のデータは即座に解放  |
| App Groupファイル読込失敗  | Broadcast Extensionが停止/未起動  | ファイル存在チェック → 失敗時は手入力フォールバックUI表示            |
| ネットワークタイムアウト   | Wi-Fi/モバイル通信の不安定        | URLSessionのtimeoutIntervalを10秒に設定。タイムアウト時はリトライ表示 |
| UIKit描画の過負荷          | チップUIの大量描画                | 生成するチップ数を最大5個に制限                                      |

### 3.3 軸3: Gemini Vision API（外部サービス側）

| クラッシュ要因      | 発生条件                             | 対策                                                                          |
| ------------------- | ------------------------------------ | ----------------------------------------------------------------------------- |
| APIタイムアウト     | サーバー負荷・ネットワーク遅延       | 10秒タイムアウト設定。超過時はフォールバック（手入力 or リトライ）             |
| レート制限（429）   | 短時間に大量リクエスト               | 2秒待機後にリトライ（1回のみ）。Q1〜Q3は1回のAPI呼び出しで一括生成するためレート制限リスクは低い |
| 不正レスポンス      | APIが期待と異なるJSON構造を返す      | レスポンスのバリデーション。パース失敗時は汎用的な質問にフォールバック        |
| APIキー無効/期限切れ | キーの失効                           | エラーハンドリングで「一時的にサービスが利用できません」と表示                |
| 画像解析失敗        | フレームがぼやけている/LINE画面でない | チャットが検出できなかった場合、手入力フォールバック                          |

---

## 4. フォールバック設計

すべてのエラーは最終的に「手入力フォールバック」に収束する。

```
正常フロー:
  `mote+AI`タブ押下 → フレーム取得 → Gemini Vision → チャット文脈取得 → Q1〜Q3一括生成 → Q1〜Q3回答(ローカル) → 返信生成
                          ↓失敗             ↓失敗                        ↓失敗                                   ↓失敗
フォールバック:   手入力UI表示 ←── 手入力UI表示                    リトライ                               リトライ

手入力UI:
  キーボード上にテキスト入力欄を表示し、ユーザーに相手のメッセージを簡単に入力してもらう。
  → 以降のアスクユーザーインプット〜返信生成は通常通り動作
```

### フォールバック発動条件まとめ

| 段階                 | 発動条件                                 | フォールバック先                |
| -------------------- | ---------------------------------------- | ------------------------------- |
| フレーム取得         | ファイルが存在しない / 読込エラー        | 手入力UI                        |
| Gemini Vision API    | タイムアウト / 解析失敗 / チャット未検出 | 手入力UI                        |
| アスクユーザーQ1〜Q3一括生成 | タイムアウト / パースエラー        | リトライボタン / 汎用質問       |
| 返信文生成           | タイムアウト / パースエラー              | リトライボタン                  |
