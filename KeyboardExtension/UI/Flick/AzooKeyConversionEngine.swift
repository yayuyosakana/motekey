#if canImport(KanaKanjiConverterModuleWithDefaultDictionary)
import Foundation
import KanaKanjiConverterModuleWithDefaultDictionary

/// azooKey の `KanaKanjiConverter`（バンドル辞書版）を用いた本物のかな漢字変換エンジン。
///
/// `JapaneseConversionEngine` を満たすため、`ConversionEngineProvider` が
/// パッケージ追加時に自動でこちらを採用する（未追加時は `BuiltinKanaConverter`）。
/// 既定トレイト（Zenzai 無効）で動かすため llama.cpp / Cxx interop は不要。
/// 統合手順は `docs/azookey-integration.md` を参照。
final class AzooKeyConversionEngine: JapaneseConversionEngine {
    private let converter = KanaKanjiConverter.withDefaultDictionary()
    private let options: ConvertRequestOptions

    init() {
        let workDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("motekey-kkc", isDirectory: true)
        try? FileManager.default.createDirectory(at: workDirectory, withIntermediateDirectories: true)

        options = ConvertRequestOptions(
            N_best: 8,
            requireJapanesePrediction: .autoMix,
            requireEnglishPrediction: .disabled,
            keyboardLanguage: .ja_JP,
            learningType: .nothing,
            memoryDirectoryURL: workDirectory,
            sharedContainerURL: workDirectory,
            textReplacer: .empty,
            specialCandidateProviders: nil,
            metadata: .init(versionString: "MoteKey")
        )
    }

    func candidates(for reading: String) -> [String] {
        let trimmed = reading.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        var composing = ComposingText()
        composing.insertAtCursorPosition(trimmed, inputStyle: .direct)
        let result = converter.requestCandidates(composing, options: options)

        var seen = Set<String>()
        var output: [String] = []

        func append(_ text: String) {
            guard !text.isEmpty, seen.insert(text).inserted else { return }
            output.append(text)
        }

        for candidate in result.mainResults {
            append(candidate.text)
            if output.count >= 12 { break }
        }
        // 変換が空でも最低限の候補を返す保険。
        append(trimmed)
        append(JapaneseText.toKatakana(trimmed))
        return output
    }
}
#endif
