import SwiftUI

struct TextHabitQuestion {
    let scenario: String
    let messages: [ChatMessage]
}

struct ChatMessage {
    let text: String
    let side: BubbleSide
}

enum BubbleSide {
    case leading
    case trailing
}

private let textHabitQuestions: [TextHabitQuestion] = [
    .init(scenario: "デート提案", messages: [
        .init(text: "今夜、どこか外食いかない？", side: .leading),
        .init(text: "いいよ！どこ行こうか", side: .trailing),
        .init(text: "決めていいよ！", side: .leading)
    ]),
    .init(scenario: "愚痴・共感", messages: [
        .init(text: "ちょっと悲しいことがあって、聞いてほしい", side: .leading)
    ]),
    .init(scenario: "仕事の愚痴", messages: [
        .init(text: "今日も残業だった…もう疲れた", side: .leading),
        .init(text: "お疲れ。大変だったね", side: .trailing),
        .init(text: "なんか頑張る気力もなくなってきた", side: .leading)
    ]),
    .init(scenario: "週末の予定", messages: [
        .init(text: "今週末、何する？", side: .leading),
        .init(text: "特に決めてないけど、どっか行く？", side: .trailing),
        .init(text: "うーん、家でのんびりでもいいかな", side: .leading)
    ]),
    .init(scenario: "ちょっとした喧嘩後", messages: [
        .init(text: "さっきはごめんね。言いすぎた", side: .leading)
    ]),
    .init(scenario: "不安な気持ち", messages: [
        .init(text: "最近、私のこと好き？", side: .leading)
    ]),
    .init(scenario: "体調不良", messages: [
        .init(text: "なんか頭痛がひどくて…", side: .leading),
        .init(text: "大丈夫？何かできることある？", side: .trailing),
        .init(text: "大丈夫だよ、心配してくれてありがと", side: .leading)
    ]),
    .init(scenario: "嬉しい報告", messages: [
        .init(text: "やった！仕事でめっちゃ褒められた！", side: .leading)
    ]),
    .init(scenario: "悩み相談", messages: [
        .init(text: "友達と最近うまくいってなくて…", side: .leading),
        .init(text: "何かあったの？", side: .trailing),
        .init(text: "向こうから急に冷たくなった気がして、理由もわからなくて不安", side: .leading)
    ]),
    .init(scenario: "趣味・買い物報告", messages: [
        .init(text: "かわいい服見つけたんだけど、ちょっと高くて迷ってる", side: .leading),
        .init(text: "いくらくらい？", side: .trailing),
        .init(text: "1万5千円…。似合うと思う？写真送る", side: .leading)
    ])
]

struct S002TextHabitFlowView: View {
    @EnvironmentObject private var state: HostAppState

    @State private var questionIndex: Int
    @State private var inputText = ""
    @State private var submittedReply: String?
    @State private var isSubmitting = false

    private let bottomAnchorID = "bottom-anchor"

    init(initialQuestionIndex: Int) {
        _questionIndex = State(initialValue: max(0, min(initialQuestionIndex, textHabitQuestions.count - 1)))
    }

    var body: some View {
        let question = textHabitQuestions[questionIndex]

        VStack(alignment: .leading, spacing: 16) {
            Text("\(questionIndex + 1)/10 シチュエーション")
                .font(.caption)
                .foregroundStyle(.secondary)

            ProgressView(value: Double(questionIndex + 1), total: 10)
                .tint(.pink)

            Text(question.scenario)
                .font(.headline)

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(Array(question.messages.enumerated()), id: \.offset) { _, message in
                            bubbleRow(text: message.text, side: message.side)
                        }

                        if let submittedReply {
                            bubbleRow(text: submittedReply, side: .trailing)
                                .transition(.opacity)
                        }

                        Color.clear
                            .frame(height: 1)
                            .id(bottomAnchorID)
                    }
                    .onAppear {
                        scrollToBottom(proxy: proxy, animated: false)
                    }
                    .onChange(of: submittedReply) { _ in
                        scrollToBottom(proxy: proxy, animated: true)
                    }
                    .onChange(of: questionIndex) { _ in
                        scrollToBottom(proxy: proxy, animated: false)
                    }
                }
            }

            TextField("返信を入力...", text: $inputText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .disabled(isSubmitting)

            Button("送信") {
                Task {
                    await submitAnswer()
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)

            Spacer()
        }
        .padding()
        .navigationTitle("テキストハビットチェック")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("スキップ") {
                    skipAllAndAnalyze()
                }
                .disabled(isSubmitting)
            }
        }
    }

    private func bubbleRow(text: String, side: BubbleSide) -> some View {
        HStack {
            if side == .trailing {
                Spacer(minLength: 40)
            }
            Text(text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(side == .leading ? Color(.secondarySystemBackground) : Color.pink)
                .foregroundStyle(side == .leading ? Color.primary : Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            if side == .leading {
                Spacer(minLength: 40)
            }
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy, animated: Bool) {
        if animated {
            withAnimation {
                proxy.scrollTo(bottomAnchorID, anchor: .bottom)
            }
        } else {
            proxy.scrollTo(bottomAnchorID, anchor: .bottom)
        }
    }

    @MainActor
    private func submitAnswer() async {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isSubmitting = true
        state.textHabitAnswers[questionIndex] = trimmed
        submittedReply = trimmed
        inputText = ""

        // 仕様に合わせて返信バブルを短時間表示してから次へ遷移する。
        try? await Task.sleep(for: .milliseconds(300))

        if questionIndex + 1 < textHabitQuestions.count {
            questionIndex += 1
            submittedReply = nil
            isSubmitting = false
        } else {
            state.navigationPath.append(HostRoute.textHabitLoading)
        }
    }

    private func skipAllAndAnalyze() {
        for index in textHabitQuestions.indices {
            if state.textHabitAnswers[index] == nil {
                state.textHabitAnswers[index] = ""
            }
        }
        state.navigationPath.append(HostRoute.textHabitLoading)
    }
}

struct S002TextHabitLoadingView: View {
    @EnvironmentObject private var state: HostAppState
    @State private var started = false
    @State private var isAnalyzing = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 12) {
            if isAnalyzing {
                ProgressView()
                Text("テキストハビットを解析中...")
                    .font(.body)
                    .foregroundStyle(.secondary)
            } else if let errorMessage {
                Text(errorMessage)
                    .font(.body)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)

                HStack(spacing: 12) {
                    Button("もう一度試す") {
                        Task {
                            await startAnalysis()
                        }
                    }
                    .buttonStyle(.borderedProminent)

                    Button("スキップ") {
                        state.saveTextHabitSummary("入力なし（後で再登録可能）")
                        state.resetToHome()
                    }
                    .buttonStyle(.bordered)
                }
            } else {
                EmptyView()
            }
        }
        .navigationTitle("解析中")
        .task {
            guard !started else { return }
            started = true
            await startAnalysis()
        }
    }

    @MainActor
    private func startAnalysis() async {
        isAnalyzing = true
        errorMessage = nil

        let nonEmptyAnswers = state.textHabitAnswers
            .values
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if nonEmptyAnswers.isEmpty {
            state.saveTextHabitSummary("入力なし（後で再登録可能）")
            state.resetToHome()
            return
        }

        do {
            let summary = try await GeminiTextHabitAnalyzer().analyze(samples: nonEmptyAnswers)
            state.saveTextHabitSummary(summary)
            state.resetToHome()
        } catch {
            if let localizedError = error as? LocalizedError, let description = localizedError.errorDescription {
                errorMessage = description
            } else {
                errorMessage = "解析に失敗しました。時間を置いて再試行してください。"
            }
            isAnalyzing = false
        }
    }
}
