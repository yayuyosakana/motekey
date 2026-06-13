import Foundation

// MARK: - Flick model

/// フリックの方向。`nil` はタップ（中央）を表す。
enum FlickDirection {
    case up
    case down
    case left
    case right
}

/// 1キー分のフリック割り当て（中央 + 上下左右）。
struct FlickKey: Identifiable {
    let id: String
    let center: String
    let up: String?
    let down: String?
    let left: String?
    let right: String?

    init(
        _ center: String,
        up: String? = nil,
        down: String? = nil,
        left: String? = nil,
        right: String? = nil
    ) {
        self.id = center
        self.center = center
        self.up = up
        self.down = down
        self.left = left
        self.right = right
    }

    /// 指定方向に対応する文字を返す。割り当てが無い方向は中央文字にフォールバックする。
    func character(for direction: FlickDirection?) -> String {
        guard let direction else { return center }
        switch direction {
        case .up: return up ?? center
        case .down: return down ?? center
        case .left: return left ?? center
        case .right: return right ?? center
        }
    }
}

// MARK: - かな配列（あかさたな / フリック）

enum KanaFlickLayout {
    /// あ行〜ら行（3行 × 3列）。各キーは タップ=あ, 左=い, 上=う, 右=え, 下=お の規則。
    static let upperRows: [[FlickKey]] = [
        [
            FlickKey("あ", up: "う", down: "お", left: "い", right: "え"),
            FlickKey("か", up: "く", down: "こ", left: "き", right: "け"),
            FlickKey("さ", up: "す", down: "そ", left: "し", right: "せ")
        ],
        [
            FlickKey("た", up: "つ", down: "と", left: "ち", right: "て"),
            FlickKey("な", up: "ぬ", down: "の", left: "に", right: "ね"),
            FlickKey("は", up: "ふ", down: "ほ", left: "ひ", right: "へ")
        ],
        [
            FlickKey("ま", up: "む", down: "も", left: "み", right: "め"),
            FlickKey("や", up: "ゆ", down: "よ", left: "（", right: "）"),
            FlickKey("ら", up: "る", down: "ろ", left: "り", right: "れ")
        ]
    ]

    /// 最下段の わ 行キー。
    static let waKey = FlickKey("わ", up: "ん", down: "ー", left: "を", right: "〜")

    /// 最下段の 句読点キー。
    static let punctuationKey = FlickKey("、", up: "？", down: "…", left: "。", right: "！")
}

// MARK: - 濁点 / 半濁点 / 小文字トグル

enum DakutenCycle {
    /// 同一キーで循環させる文字グループ。タップごとに次へ進む。
    private static let groups: [[String]] = [
        ["か", "が"], ["き", "ぎ"], ["く", "ぐ"], ["け", "げ"], ["こ", "ご"],
        ["さ", "ざ"], ["し", "じ"], ["す", "ず"], ["せ", "ぜ"], ["そ", "ぞ"],
        ["た", "だ"], ["ち", "ぢ"], ["つ", "っ", "づ"], ["て", "で"], ["と", "ど"],
        ["は", "ば", "ぱ"], ["ひ", "び", "ぴ"], ["ふ", "ぶ", "ぷ"], ["へ", "べ", "ぺ"], ["ほ", "ぼ", "ぽ"],
        ["あ", "ぁ"], ["い", "ぃ"], ["う", "ぅ", "ゔ"], ["え", "ぇ"], ["お", "ぉ"],
        ["や", "ゃ"], ["ゆ", "ゅ"], ["よ", "ょ"], ["わ", "ゎ"]
    ]

    private static let nextMap: [String: String] = {
        var map: [String: String] = [:]
        for group in groups {
            for (offset, value) in group.enumerated() {
                let next = group[(offset + 1) % group.count]
                map[value] = next
            }
        }
        return map
    }()

    /// 濁点/半濁点/小文字の循環で次の文字を返す。対象外なら `nil`。
    static func next(for character: String) -> String? {
        nextMap[character]
    }
}

// MARK: - かな判定 / カタカナ変換

enum JapaneseText {
    /// 変換対象（連続したかな入力）として扱える 1 文字かどうか。
    static func isComposingKana(_ text: String) -> Bool {
        let scalars = Array(text.unicodeScalars)
        guard scalars.count == 1, let scalar = scalars.first else { return false }
        let value = scalar.value
        // ひらがなブロック（ぁ〜ゖ） + 長音記号「ー」
        return (0x3041...0x3096).contains(value) || value == 0x30FC
    }

    /// ひらがな文字列をカタカナへ変換する。
    static func toKatakana(_ text: String) -> String {
        var result = ""
        for scalar in text.unicodeScalars {
            if (0x3041...0x3096).contains(scalar.value),
               let katakana = Unicode.Scalar(scalar.value + 0x60) {
                result.unicodeScalars.append(katakana)
            } else {
                result.unicodeScalars.append(scalar)
            }
        }
        return result
    }
}

// MARK: - 変換エンジンのシーム（azooKey 差し替えポイント）

/// かな読みから変換候補を返すエンジン。
///
/// MVP では `BuiltinKanaConverter`（辞書なしの軽量版）を使う。
/// azooKey 本格統合時は、このプロトコルを満たすラッパーを実装して差し替える。
/// 詳細な手順は `docs/azookey-integration.md` を参照。
protocol JapaneseConversionEngine {
    /// 読み（ひらがな）に対する変換候補。先頭ほど優先度が高い。
    func candidates(for reading: String) -> [String]
}

/// 辞書を持たない軽量コンバータ。読みそのもの・カタカナなどの素朴な候補を返す。
/// azooKey 統合前のデフォルト実装。
struct BuiltinKanaConverter: JapaneseConversionEngine {
    func candidates(for reading: String) -> [String] {
        let trimmed = reading.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        var results: [String] = []
        func append(_ value: String) {
            guard !value.isEmpty, !results.contains(value) else { return }
            results.append(value)
        }

        append(trimmed)
        append(JapaneseText.toKatakana(trimmed))
        return results
    }
}

/// 変換エンジンの生成口。
///
/// azooKey の `KanaKanjiConverterModuleWithDefaultDictionary` をプロジェクトに追加すると
/// `AzooKeyConversionEngine`（`AzooKeyConversionEngine.swift`／`#if canImport` ガード付き）が
/// 有効になり、本物のかな漢字変換へ自動的に切り替わる。未追加時は軽量版にフォールバックする。
/// 統合手順は `docs/azookey-integration.md` を参照。
enum ConversionEngineProvider {
    /// プロセス内で 1 度だけ生成して共有する（辞書ロードは高コストなため）。
    static let shared: any JapaneseConversionEngine = makeEngine()

    private static func makeEngine() -> any JapaneseConversionEngine {
        #if canImport(KanaKanjiConverterModuleWithDefaultDictionary)
        return AzooKeyConversionEngine()
        #else
        return BuiltinKanaConverter()
        #endif
    }
}
