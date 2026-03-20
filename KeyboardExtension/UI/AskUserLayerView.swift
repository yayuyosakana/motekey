import SwiftUI

struct AskUserLayerView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(spacing: 12) {
            if let question = currentQuestion {
                Text("Step \(appState.currentQuestionIndex + 1)/3")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(question.text)
                    .font(.body)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 8) {
                    ForEach(Array(question.options.enumerated()), id: \.offset) { _, option in
                        Button(action: { appState.selectOption(option.value) }) {
                            Text(option.label)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 10)
                                .padding(.horizontal, 12)
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else {
                Text("質問を読み込み中...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(Color(white: 0.95))
    }

    private var currentQuestion: AskUserQuestion? {
        guard appState.currentQuestionIndex < appState.askUserQuestions.count else {
            return nil
        }
        return appState.askUserQuestions[appState.currentQuestionIndex]
    }
}
