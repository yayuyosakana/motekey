import SwiftUI

struct TextHabitQuestion {
    let scenario: String
    let partnerMessage: String
}

private let textHabitQuestions: [TextHabitQuestion] = [
    .init(scenario: "デート提案", partnerMessage: "今夜、どこか外食いかない？"),
    .init(scenario: "愚痴・共感", partnerMessage: "ちょっと悲しいことがあって、聞いてほしい"),
    .init(scenario: "仕事の愚痴", partnerMessage: "今日も残業だった…もう疲れた"),
    .init(scenario: "週末の予定", partnerMessage: "今週末、何する？"),
    .init(scenario: "ちょっとした喧嘩後", partnerMessage: "さっきはごめんね。言いすぎた"),
    .init(scenario: "不安な気持ち", partnerMessage: "最近、私のこと好き？"),
    .init(scenario: "体調不良", partnerMessage: "なんか頭痛がひどくて…"),
    .init(scenario: "嬉しい報告", partnerMessage: "やった！仕事でめっちゃ褒められた！"),
    .init(scenario: "悩み相談", partnerMessage: "友達と最近うまくいってなくて…"),
    .init(scenario: "趣味・買い物報告", partnerMessage: "かわいい服見つけたんだけど、ちょっと高くて迷ってる")
]

struct S002TextHabitFlowView: View {
    @EnvironmentObject private var state: HostAppState

    @State private var questionIndex: Int
    @State private var inputText = ""

    init(initialQuestionIndex: Int) {
        _questionIndex = State(initialValue: max(0, min(initialQuestionIndex, textHabitQuestions.count - 1)))
    }

    var body: some View {
        let question = textHabitQuestions[questionIndex]

        VStack(alignment: .leading, spacing: 16) {
            Text("\(questionIndex + 1)/10 シチュエーション")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(question.scenario)
                .font(.headline)

            Text(question.partnerMessage)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            TextField("返信を入力...", text: $inputText, axis: .vertical)
                .textFieldStyle(.roundedBorder)

            Button("送信") {
                submitAnswer()
            }
            .buttonStyle(.borderedProminent)
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

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
            }
        }
    }

    private func submitAnswer() {
        state.textHabitAnswers[questionIndex] = inputText
        inputText = ""

        if questionIndex + 1 < textHabitQuestions.count {
            questionIndex += 1
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

    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("テキストハビットを解析中...")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .navigationTitle("解析中")
        .task {
            guard !started else { return }
            started = true
            try? await Task.sleep(for: .seconds(1))

            let nonEmptyAnswers = state.textHabitAnswers
                .values
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            let summary: String
            if nonEmptyAnswers.isEmpty {
                summary = "入力なし（後で再登録可能）"
            } else {
                summary = "登録済み（\(nonEmptyAnswers.count)件のサンプル）"
            }

            state.saveTextHabitSummary(summary)
            state.resetToHome()
        }
    }
}
