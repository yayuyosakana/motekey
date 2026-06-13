# モテキー (MoteKey)

> "了解"を、"ありがとう"に変えるキーボード

**GDGoC Japan Hackathon 制作作品 / AI賞・開催地賞・LGTM賞 受賞**

LINE返信のすれ違いを、キーボード上の生成AIで減らす iOS 向けコミュニケーション支援プロダクトです。

## 基本情報

- プロジェクト名: **モテキー**
- ハッカソン: **GDGoC Japan Hackathon**
- 受賞: **AI賞 / 開催地賞 / LGTM賞**
- ロゴ: 現在準備中（リポジトリ内に正式ロゴ未配置）
- 一言説明（エレベーターピッチ）:
  - **「了解」で終わらせないために、相手文脈・関係性・あなたの口調を統合して、送信前の候補文を瞬時に提案するAIキーボード。**
- 発表スライド:
  - [Canva スライド](https://www.canva.com/design/DAHEhnR71ZQ/OlnjqD3CWWz-IzfFMoSTrA/edit?utm_content=DAHEhnR71ZQ&utm_campaign=designshare&utm_medium=link2&utm_source=sharebutton)
- デモURL: 準備中
- デモ動画: 準備中
- スクリーンショット:

### 画面例

| S-002 テキストハビットチェック | S-003 リレーションチェック |
| --- | --- |
| ![S-002](docs/screen-transitions/text_habit_check.png) | ![S-003](docs/screen-transitions/partner_relationship.png) |

| S-006 mote+AI（質問UI） | S-005 キーボード（ステージバー） |
| --- | --- |
| ![S-006](docs/screen-transitions/mote+AI_choice.png) | ![S-005](docs/screen-transitions/keyboard_stage_messeage.png) |

## プロジェクト概要

### Why（解決する課題・背景）

- LINEの即時コミュニケーションでは、短い返信や配慮不足で関係が悪化しやすい。
- 特に「相手の感情を読み切れない」「事実確認が漏れる」ことで、不要な摩擦が発生する。
- 本プロジェクトは、返信時の判断負担を下げて、関係維持・改善を支援する。

### What（解決策・アプローチ）

- Host Appでユーザーの口調（テキストハビット）と関係情報を初回登録。
- Keyboard Extension上の `mote+AI` 実行時に、最新1フレームの画面文脈をGemini Vision APIで抽出。
- 追加質問（3問3択）を1回のAPI呼び出しで生成し、回答を統合して返信候補を複数チップで提示。
- チップをタップした順でLINE入力欄へ反映し、ユーザーが手編集して既存送信UIで送信。

### ターゲットユーザー

- パートナー（彼女/妻など）とのLINE返信で、配慮不足による衝突を減らしたい男性ユーザー。

## 機能・特徴

### 主要機能

- 画面コンテキスト取得（Broadcast最新フレーム + Gemini Vision API）
- アスクユーザーインプット（3問3択、分岐なし、一括生成）
- ステージ提案（返信候補チップの表示と入力欄反映）
- テキストハビット登録（語尾・口調の抽出）
- リレーション登録（関係性・注意事項の保存）
- キーボード許可/画面収録開始のガイド

### 差別化ポイント

- **入力前提を自動抽出**: 画面キャプチャから会話文脈を機械的に取り込む。
- **質問の待ち時間を最小化**: 3問を1リクエストで返し、質問間のネットワーク待機なし。
- **送信導線を壊さない**: 専用送信UIを作らず、既存のLINE入力/送信フローを維持。
- **MVPでも安全側に倒す設計**: 失敗時は手入力フォールバックへ収束。

## 技術スタック

### 使用言語・フレームワーク

- Swift 5.10
- SwiftUI（Host Appオンボーディング）
- UIKit + Custom Keyboard Extension（キーボード実行面）
- ReplayKit（Broadcast Upload Extension）
- Core Image（フレーム縮小・JPEG圧縮）
- URLSession（API通信）

### 外部API・サービス

- Gemini API（テキストハビット抽出 / 質問生成 / 返信生成）
- Gemini Vision API（チャット文脈抽出）
- azooKey `AzooKeyKanaKanjiConverter`（フリックキーボードのかな漢字変換エンジン）

### インフラ構成（簡易）

- iOS Host App + Keyboard Extension + Broadcast Upload Extension の3ターゲット構成
- App Groups（`group.com.motekey.shared`）で共有
  - `UserDefaults`: テキストハビット・リレーション
  - `latest_frame.jpg`: 最新1フレーム（上書き保持）

## セットアップ・使い方

### 必要な環境・前提条件

- macOS 14+
- Xcode（iOS 17 / Swift 5.10 相当）
- Gemini APIキー（用途別4キー推奨）

### インストール手順

```bash
git clone https://github.com/yayuyosakana/motekey.git
cd motekey
cp Config/Secrets.xcconfig.template Config/Secrets.xcconfig
```

`Config/Secrets.xcconfig` にAPIキーを設定します。

### 環境変数の設定（`.env` ではなく `xcconfig`）

`Config/Secrets.xcconfig`:

```xcconfig
GEMINI_API_KEY_TEXT_HABIT = <YOUR_KEY>
GEMINI_API_KEY_VISION_CONTEXT = <YOUR_KEY>
GEMINI_API_KEY_ASK_USER_QUESTION = <YOUR_KEY>
GEMINI_API_KEY_REPLY_GENERATION = <YOUR_KEY>

# 任意（後方互換）
GEMINI_API_KEY = <OPTIONAL_FALLBACK_KEY>
```

### 起動方法

基盤モジュールのビルド/テスト確認:

```bash
make bootstrap-check
# または
./scripts/bootstrap_check.sh
```

アプリ本体（Host App + Keyboard Extension + Broadcast Extension）のビルド:

```bash
xcodegen generate          # project.yml から MoteKey.xcodeproj を生成
open MoteKey.xcodeproj      # Xcode で MoteKeyHostApp スキームを実行
```

> Xcode 26 系では iOS プラットフォームが別ダウンロードのことがあります。未導入なら
> `xcodebuild -downloadPlatform iOS` で取得してください。

補足:

- キーボード本体は **あかさたなフリック入力** を自作実装（`KeyboardExtension/UI/Flick/`）。かな漢字変換は **azooKey の `AzooKeyKanaKanjiConverter`** に委譲しています（[`docs/azookey-integration.md`](docs/azookey-integration.md)）。
- 要件と実装の対応は [`docs/requirements-traceability.md`](docs/requirements-traceability.md) を参照。
- 実機でのキーボード有効化・Broadcast設定の手順は [`docs/setup-guide.md`](docs/setup-guide.md) を参照してください。

## ハッカソン固有（審査員向け）

### 受賞結果

- GDGoC Japan Hackathon にて **AI賞 / 開催地賞 / LGTM賞** を受賞
- 発表スライド:
  - [Canva スライド](https://www.canva.com/design/DAHEhnR71ZQ/OlnjqD3CWWz-IzfFMoSTrA/edit?utm_content=DAHEhnR71ZQ&utm_campaign=designshare&utm_medium=link2&utm_source=sharebutton)

### ハッカソンテーマとの関連性

- 生成AIを使って「日常コミュニケーションの摩擦」を減らす実課題解決型プロジェクト。
- 返信文そのものだけでなく、返信に必要な前提情報の収集（質問設計）までAIで補助する。

### 制作期間

- ハッカソン期間内のMVP実装（要件定義上は**数時間で構築可能な範囲**を前提）。

### 工夫した点・苦労した点

- iOSキーボード拡張のメモリ上限（約50MB）を前提に、画像を50%縮小 + JPEG圧縮（100-150KB）で運用。
- 質問生成を1回のAPI呼び出しに集約し、UXの待機時間と失敗点を削減。
- 失敗時は手入力フォールバックに統一し、デモ時の停止リスクを抑制。

### 今後の展望

- 正式UIデザイン（S-002/S-003モックからの確定反映）
- 実運用ログを踏まえたプロンプト/スキーマ改善
- 候補品質評価指標の導入（採用率、編集率、再生成率など）

## 関連ドキュメント

- [requirements.md](requirements.md)
- [docs/UI_guid_user_journey.md](docs/UI_guid_user_journey.md)
- [docs/architecture.md](docs/architecture.md)
- [docs/api-design.md](docs/api-design.md)
- [docs/technical-design.md](docs/technical-design.md)
- [docs/setup-guide.md](docs/setup-guide.md)
