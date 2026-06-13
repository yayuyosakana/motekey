import SwiftUI

// MARK: - レイヤー

private enum KeyboardLayer {
    case kana
    case number
    case alphabet
}

// MARK: - 日本語フリックキーボード本体
//
// 要件 S-005 の「通常の日本語フリックキーボード（あかさたな配列）」＋予測変換バー。
// - かな: あかさたな 12 キーのフリック（タップ=中央 / 上下左右=い う え お 等）
// - 数字記号 / 英字(QWERTY) レイヤーへ切替可能
// - 濁点/半濁点/小文字トグル、句読点、空白、改行、削除
// 変換候補は `JapaneseConversionEngine`（既定は軽量版、azooKey 追加時は本物の変換）に委譲する。

struct JapaneseKeyboardView: View {
    let onInsert: (String) -> Void
    let onDeleteBackward: () -> Void
    let onAdvanceInputMode: () -> Void

    private let converter: any JapaneseConversionEngine

    @State private var layer: KeyboardLayer = .kana
    @State private var composingKana: String = ""
    @State private var isShiftEnabled: Bool = false

    init(
        onInsert: @escaping (String) -> Void,
        onDeleteBackward: @escaping () -> Void,
        onAdvanceInputMode: @escaping () -> Void = {},
        converter: any JapaneseConversionEngine = ConversionEngineProvider.shared
    ) {
        self.onInsert = onInsert
        self.onDeleteBackward = onDeleteBackward
        self.onAdvanceInputMode = onAdvanceInputMode
        self.converter = converter
    }

    var body: some View {
        VStack(spacing: 0) {
            PredictionBarView(candidates: predictionCandidates, onSelect: commitCandidate)
            GeometryReader { geometry in
                keyArea(height: geometry.size.height)
            }
        }
        .background(Color(white: 0.84))
    }

    // MARK: レイヤー描画

    @ViewBuilder
    private func keyArea(height: CGFloat) -> some View {
        let spacing: CGFloat = 5
        let rowHeight = max((height - spacing * 3) / 4, 28)
        switch layer {
        case .kana:
            kanaLayer(rowHeight: rowHeight, spacing: spacing)
        case .number:
            numberLayer(rowHeight: rowHeight, spacing: spacing)
        case .alphabet:
            alphabetLayer(rowHeight: rowHeight, spacing: spacing)
        }
    }

    @ViewBuilder
    private func kanaLayer(rowHeight: CGFloat, spacing: CGFloat) -> some View {
        HStack(spacing: spacing) {
            leftFunctionColumn(rowHeight: rowHeight, spacing: spacing, active: .kana)

            VStack(spacing: spacing) {
                ForEach(Array(KanaFlickLayout.upperRows.enumerated()), id: \.offset) { pair in
                    HStack(spacing: spacing) {
                        ForEach(pair.element) { key in
                            FlickKeyView(key: key, onEmit: emit)
                                .frame(maxWidth: .infinity)
                                .frame(height: rowHeight)
                        }
                    }
                }
                HStack(spacing: spacing) {
                    FunctionKeyView(title: "小゛゜", action: applyDakuten)
                        .frame(maxWidth: .infinity)
                        .frame(height: rowHeight)
                    FlickKeyView(key: KanaFlickLayout.waKey, onEmit: emit)
                        .frame(maxWidth: .infinity)
                        .frame(height: rowHeight)
                    FlickKeyView(key: KanaFlickLayout.punctuationKey, onEmit: emit)
                        .frame(maxWidth: .infinity)
                        .frame(height: rowHeight)
                }
            }

            rightFunctionColumn(rowHeight: rowHeight, spacing: spacing)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func numberLayer(rowHeight: CGFloat, spacing: CGFloat) -> some View {
        let rows: [[String]] = [
            ["1", "2", "3"],
            ["4", "5", "6"],
            ["7", "8", "9"],
            [".", "0", ","]
        ]
        HStack(spacing: spacing) {
            leftFunctionColumn(rowHeight: rowHeight, spacing: spacing, active: .number)

            VStack(spacing: spacing) {
                ForEach(Array(rows.enumerated()), id: \.offset) { pair in
                    HStack(spacing: spacing) {
                        ForEach(pair.element, id: \.self) { value in
                            TapKeyView(label: value) { emit(value) }
                                .frame(maxWidth: .infinity)
                                .frame(height: rowHeight)
                        }
                    }
                }
            }

            rightFunctionColumn(rowHeight: rowHeight, spacing: spacing)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func alphabetLayer(rowHeight: CGFloat, spacing: CGFloat) -> some View {
        let row0 = ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"]
        let row1 = ["a", "s", "d", "f", "g", "h", "j", "k", "l"]
        let row2 = ["z", "x", "c", "v", "b", "n", "m"]

        VStack(spacing: spacing) {
            HStack(spacing: spacing) {
                ForEach(row0, id: \.self) { letter in
                    TapKeyView(label: displayLetter(letter)) { emitAlphabet(letter) }
                        .frame(maxWidth: .infinity)
                        .frame(height: rowHeight)
                }
            }
            HStack(spacing: spacing) {
                ForEach(row1, id: \.self) { letter in
                    TapKeyView(label: displayLetter(letter)) { emitAlphabet(letter) }
                        .frame(maxWidth: .infinity)
                        .frame(height: rowHeight)
                }
            }
            HStack(spacing: spacing) {
                FunctionKeyView(systemImage: isShiftEnabled ? "shift.fill" : "shift") {
                    isShiftEnabled.toggle()
                }
                .frame(width: 42)
                .frame(height: rowHeight)
                ForEach(row2, id: \.self) { letter in
                    TapKeyView(label: displayLetter(letter)) { emitAlphabet(letter) }
                        .frame(maxWidth: .infinity)
                        .frame(height: rowHeight)
                }
                FunctionKeyView(systemImage: "delete.left", action: deleteBackward)
                    .frame(width: 42)
                    .frame(height: rowHeight)
            }
            HStack(spacing: spacing) {
                FunctionKeyView(title: "123") { switchLayer(.number) }
                    .frame(width: 46)
                    .frame(height: rowHeight)
                FunctionKeyView(title: "あ") { switchLayer(.kana) }
                    .frame(width: 46)
                    .frame(height: rowHeight)
                FunctionKeyView(title: "空白", action: insertSpace)
                    .frame(maxWidth: .infinity)
                    .frame(height: rowHeight)
                FunctionKeyView(title: "改行") { onInsert("\n") }
                    .frame(width: 80)
                    .frame(height: rowHeight)
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
    }

    // MARK: 共通の左右ファンクション列

    @ViewBuilder
    private func leftFunctionColumn(rowHeight: CGFloat, spacing: CGFloat, active: KeyboardLayer) -> some View {
        VStack(spacing: spacing) {
            FunctionKeyView(title: "☆123", isActive: active == .number) { switchLayer(.number) }
                .frame(height: rowHeight)
            FunctionKeyView(title: "ABC", isActive: active == .alphabet) { switchLayer(.alphabet) }
                .frame(height: rowHeight)
            FunctionKeyView(title: "あいう", isActive: active == .kana) { switchLayer(.kana) }
                .frame(height: rowHeight)
            FunctionKeyView(systemImage: "globe", action: onAdvanceInputMode)
                .frame(height: rowHeight)
        }
        .frame(width: 46)
    }

    @ViewBuilder
    private func rightFunctionColumn(rowHeight: CGFloat, spacing: CGFloat) -> some View {
        VStack(spacing: spacing) {
            FunctionKeyView(systemImage: "delete.left", action: deleteBackward)
                .frame(height: rowHeight)
            FunctionKeyView(title: "空白", action: insertSpace)
                .frame(height: rowHeight)
            FunctionKeyView(title: composingKana.isEmpty ? "改行" : "確定", action: returnOrConfirm)
                .frame(maxHeight: .infinity)
        }
        .frame(width: 56)
    }

    // MARK: 予測変換

    private var predictionCandidates: [String] {
        guard !composingKana.isEmpty else { return [] }
        return converter.candidates(for: composingKana)
    }

    private func commitCandidate(_ candidate: String) {
        let removeCount = composingKana.count
        for _ in 0..<removeCount {
            onDeleteBackward()
        }
        onInsert(candidate)
        composingKana = ""
    }

    // MARK: 入力ハンドリング

    private func emit(_ text: String) {
        if JapaneseText.isComposingKana(text) {
            composingKana += text
            onInsert(text)
        } else {
            composingKana = ""
            onInsert(text)
        }
    }

    private func emitAlphabet(_ lower: String) {
        composingKana = ""
        onInsert(isShiftEnabled ? lower.uppercased() : lower)
    }

    private func displayLetter(_ lower: String) -> String {
        isShiftEnabled ? lower.uppercased() : lower
    }

    private func applyDakuten() {
        guard let last = composingKana.last,
              let next = DakutenCycle.next(for: String(last)) else {
            return
        }
        onDeleteBackward()
        onInsert(next)
        composingKana.removeLast()
        composingKana += next
    }

    private func deleteBackward() {
        if !composingKana.isEmpty {
            composingKana.removeLast()
        }
        onDeleteBackward()
    }

    private func insertSpace() {
        composingKana = ""
        onInsert(layer == .kana ? "　" : " ")
    }

    private func returnOrConfirm() {
        if composingKana.isEmpty {
            onInsert("\n")
        } else {
            composingKana = ""
        }
    }

    private func switchLayer(_ target: KeyboardLayer) {
        composingKana = ""
        if target != .alphabet {
            isShiftEnabled = false
        }
        layer = target
    }
}

// MARK: - フリックキー（1 キー）

private struct FlickKeyView: View {
    let key: FlickKey
    let onEmit: (String) -> Void

    @State private var dragDirection: FlickDirection?
    @State private var isPressing: Bool = false

    private let threshold: CGFloat = 22

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(isPressing ? Color.accentColor.opacity(0.25) : Color.white)
            Text(displayCharacter)
                .font(.system(size: 22))
                .foregroundStyle(.primary)
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    isPressing = true
                    dragDirection = direction(for: value.translation)
                }
                .onEnded { value in
                    onEmit(key.character(for: direction(for: value.translation)))
                    isPressing = false
                    dragDirection = nil
                }
        )
    }

    private var displayCharacter: String {
        isPressing ? key.character(for: dragDirection) : key.center
    }

    private func direction(for translation: CGSize) -> FlickDirection? {
        if abs(translation.width) < threshold && abs(translation.height) < threshold {
            return nil
        }
        if abs(translation.width) > abs(translation.height) {
            return translation.width > 0 ? .right : .left
        } else {
            return translation.height > 0 ? .down : .up
        }
    }
}

// MARK: - タップキー（数字・英字）

private struct TapKeyView: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white)
                Text(label)
                    .font(.system(size: 20))
                    .foregroundStyle(.primary)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - ファンクションキー

private struct FunctionKeyView: View {
    var title: String? = nil
    var systemImage: String? = nil
    var isActive: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(isActive ? Color.accentColor.opacity(0.35) : Color(white: 0.78))
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 18))
                        .foregroundStyle(.primary)
                } else {
                    Text(title ?? "")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.primary)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 予測変換バー

private struct PredictionBarView: View {
    let candidates: [String]
    let onSelect: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(candidates.enumerated()), id: \.offset) { _, candidate in
                    Button { onSelect(candidate) } label: {
                        Text(candidate)
                            .font(.system(size: 16))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.white)
                            .clipShape(Capsule())
                            .foregroundStyle(.primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 38)
        .frame(maxWidth: .infinity)
        .background(Color(white: 0.9))
    }
}

#if DEBUG
struct JapaneseKeyboardView_Previews: PreviewProvider {
    static var previews: some View {
        JapaneseKeyboardView(
            onInsert: { _ in },
            onDeleteBackward: {}
        )
        .frame(height: 260)
    }
}
#endif
