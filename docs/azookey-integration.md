# azooKey 変換エンジン統合メモ

モテキーのフリックキーボードは、かな漢字変換を **azooKey の `AzooKeyKanaKanjiConverter`**（バンドル辞書版）に委譲している。本書はその統合内容と差し替え手順をまとめる。

## 方針（採用したのは「変換エンジンのみ統合」）

- キーボードUI（あかさたなフリック配列・ステージバー・予測変換バー）は自作（`KeyboardExtension/UI/Flick/`）。
- かな漢字変換だけ azooKey の `KanaKanjiConverterModuleWithDefaultDictionary` を使う。
- azooKey 本体のキーボードUI（`KeyboardViews`）や Zenzai（ニューラル変換 / llama.cpp）は**使っていない**。
  - パッケージの **既定トレイトは `enabledTraits: []`** なので、`Zenzai` / `ZenzaiCPU` は無効。
  - したがって llama.cpp・Cxx interop・gguf モデルは不要で、ビルドは軽い。

## 依存関係（`project.yml`）

```yaml
packages:
  AzooKeyKanaKanjiConverter:
    url: https://github.com/azooKey/AzooKeyKanaKanjiConverter
    revision: fb11f1da84af322adec8a1b45888dc4a6d87e328   # azooKey 本体と同じ revision

targets:
  MoteKeyKeyboardExtension:
    dependencies:
      - package: AzooKeyKanaKanjiConverter
        product: KanaKanjiConverterModuleWithDefaultDictionary
```

`project.yml` を編集したら必ず再生成する:

```bash
xcodegen generate
```

## コードの差し替えポイント（シーム）

変換エンジンはプロトコルで抽象化してある:

- `JapaneseInputCore.swift`
  - `protocol JapaneseConversionEngine { func candidates(for reading: String) -> [String] }`
  - `BuiltinKanaConverter` … 辞書なしの軽量版（かな / カタカナのみ）。
  - `ConversionEngineProvider.shared` … 実行時に 1 度だけ生成して共有する。
    ```swift
    #if canImport(KanaKanjiConverterModuleWithDefaultDictionary)
    return AzooKeyConversionEngine()   // パッケージがある時は本物の変換
    #else
    return BuiltinKanaConverter()      // 無い時は軽量版にフォールバック
    #endif
    ```
- `AzooKeyConversionEngine.swift`（`#if canImport(...)` ガード付き）
  - `KanaKanjiConverter.withDefaultDictionary()` で辞書込み変換器を生成。
  - `ComposingText` に読みを入れ、`requestCandidates(_:options:)` の `mainResults[].text` を候補として返す。

> パッケージを外すと `canImport` が偽になり、自動的に `BuiltinKanaConverter` に戻る（ビルドは壊れない）。

## 使っている変換 API（この revision 時点）

```swift
import KanaKanjiConverterModuleWithDefaultDictionary

let converter = KanaKanjiConverter.withDefaultDictionary()   // 辞書はバンドルから自動ロード
var composing = ComposingText()
composing.insertAtCursorPosition("へんかん", inputStyle: .direct)

let options = ConvertRequestOptions(
    N_best: 8,
    requireJapanesePrediction: .autoMix,
    requireEnglishPrediction: .disabled,
    keyboardLanguage: .ja_JP,
    learningType: .nothing,
    memoryDirectoryURL: <書き込み可能なURL>,
    sharedContainerURL: <書き込み可能なURL>,
    textReplacer: .empty,
    specialCandidateProviders: nil,
    metadata: .init(versionString: "MoteKey")
)
let result = converter.requestCandidates(composing, options: options)
let texts = result.mainResults.map(\.text)
```

注意:
- この revision の `ConvertRequestOptions` に `dictionaryResourceURL` は無い（辞書は `withDefaultDictionary` 側が持つ）。`requireJapanesePrediction` は `Bool` ではなく `PredictionMode` enum。古い README/サンプルとは差があるので、revision を上げる際は `ConvertRequestOptions.swift` を確認すること。
- `KanaKanjiConverter` は `@MainActor` ではない（任意スレッドから呼べる）。MVP では入力毎にメインスレッドで同期呼び出ししている。重くなる場合はデバウンス/バックグラウンド化を検討。

## さらに本格化したい場合（将来）

- 学習を有効化: `learningType: .inputAndOutput` + App Group 内の書き込み可能ディレクトリを `memoryDirectoryURL` に。
- 絵文字・記号変換: `textReplacer: .withDefaultEmojiDictionary()`。
- Zenzai（ニューラル変換）: パッケージtrait `ZenzaiCPU` を有効化し gguf モデルを同梱。Cxx interop が必要になりビルドが重くなる。azooKey 本体（`/Users/yu/projects/hackathon/MoteKey`）の `Keyboard/Display/InputManager.swift` が実装の参考になる。
