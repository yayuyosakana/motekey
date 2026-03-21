import SwiftUI

private let textHabitQuestions = HostCopy.S002.scenarios

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
            Text("\(questionIndex + 1)/\(textHabitQuestions.count) シチュエーション")
                .font(.caption)
                .foregroundStyle(.secondary)

            ProgressView(value: Double(questionIndex + 1), total: Double(textHabitQuestions.count))
                .tint(.pink)

            Text(question.title)
                .font(.headline)

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(Array(question.messages.enumerated()), id: \.offset) { _, message in
                            bubbleRow(text: message.text, isUserSide: message.isUserSide)
                        }

                        if let submittedReply {
                            bubbleRow(text: submittedReply, isUserSide: true)
                                .transition(.opacity)
                        }

                        Color.clear
                            .frame(height: 1)
                            .id(bottomAnchorID)
                    }
                    .onAppear {
                        scrollToBottom(proxy: proxy, animated: false)
                    }
                    .onChange(of: submittedReply) { _, _ in
                        scrollToBottom(proxy: proxy, animated: true)
                    }
                    .onChange(of: questionIndex) { _, _ in
                        scrollToBottom(proxy: proxy, animated: false)
                    }
                }
            }

            TextField(HostCopy.S002.placeholderReplyInput, text: $inputText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .disabled(isSubmitting)

            Button(HostCopy.S002.send) {
                Task {
                    await submitAnswer()
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)

            Spacer()
        }
        .padding()
        .navigationTitle(HostCopy.S002.navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(HostCopy.S002.skip) {
                    skipAllAndAnalyze()
                }
                .disabled(isSubmitting)
            }
        }
    }

    private func bubbleRow(text: String, isUserSide: Bool) -> some View {
        HStack {
            if isUserSide {
                Spacer(minLength: 40)
            }
            Text(text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(isUserSide ? Color.pink : Color(.secondarySystemBackground))
                .foregroundStyle(isUserSide ? Color.white : Color.primary)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            if !isUserSide {
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
        HostHaptics.light()
        state.textHabitAnswers[questionIndex] = trimmed
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            submittedReply = trimmed
        }
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
            state.textHabitAnswers[index] = ""
        }
        state.navigationPath.append(HostRoute.textHabitLoading)
    }
}

struct S002TextHabitLoadingView: View {
    @EnvironmentObject private var state: HostAppState
    @State private var started = false
    @State private var isAnalyzing = false
    @State private var errorMessage: String?
    @State private var loadingInput = ""

    private var loadingQuestion: S002ScenarioCopy {
        textHabitQuestions[textHabitQuestions.count - 1]
    }

    private var loadingReply: String? {
        guard let raw = state.textHabitAnswers[textHabitQuestions.count - 1] else {
            return nil
        }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("\(textHabitQuestions.count)/\(textHabitQuestions.count) シチュエーション")
                .font(.caption)
                .foregroundStyle(.secondary)

            ProgressView(value: Double(textHabitQuestions.count), total: Double(textHabitQuestions.count))
                .tint(.pink)

            Text(loadingQuestion.title)
                .font(.headline)

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(Array(loadingQuestion.messages.enumerated()), id: \.offset) { _, message in
                        bubbleRow(text: message.text, isUserSide: message.isUserSide)
                    }

                    if let loadingReply {
                        bubbleRow(text: loadingReply, isUserSide: true)
                    }
                }
            }

            TextField(HostCopy.S002.placeholderReplyInput, text: $loadingInput, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .disabled(true)

            Button(HostCopy.S002.send) {}
                .buttonStyle(.borderedProminent)
                .disabled(true)

            Spacer()
        }
        .opacity(0.5)
        .disabled(true)
        .overlay {
            loadingOverlay
        }
        .padding()
        .navigationTitle(HostCopy.S002.loadingTitle)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard !started else { return }
            started = true
            await startAnalysis()
        }
    }

    private var loadingOverlay: some View {
        if isAnalyzing || errorMessage != nil {
            ZStack {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()

                VStack(spacing: 12) {
                    if isAnalyzing {
                        ProgressView()
                        Text(HostCopy.S002.loadingMessage)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    } else if let errorMessage {
                        Text(errorMessage)
                            .font(.body)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)

                        HStack(spacing: 12) {
                            Button(HostCopy.S002.retry) {
                                Task {
                                    await startAnalysis()
                                }
                            }
                            .buttonStyle(.borderedProminent)

                            Button(HostCopy.S002.skip) {
                                state.saveTextHabitSummary(HostCopy.S002.emptySummary)
                                state.clearTextHabitAnswers()
                                state.resetToHome()
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
                .padding(16)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 20)
            }
        }
    }

    private func bubbleRow(text: String, isUserSide: Bool) -> some View {
        HStack {
            if isUserSide {
                Spacer(minLength: 40)
            }
            Text(text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(isUserSide ? Color.pink : Color(.secondarySystemBackground))
                .foregroundStyle(isUserSide ? Color.white : Color.primary)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            if !isUserSide {
                Spacer(minLength: 40)
            }
        }
    }

    @MainActor
    private func startAnalysis() async {
        isAnalyzing = true
        errorMessage = nil

        let nonEmptyAnswers = state.orderedNonEmptyTextHabitAnswers(questionCount: textHabitQuestions.count)

        if nonEmptyAnswers.isEmpty {
            state.saveTextHabitProfile(.fallback(summary: HostCopy.S002.emptySummary))
            state.clearTextHabitAnswers()
            state.resetToHome()
            return
        }

        do {
            let profile = try await GeminiTextHabitAnalyzer().analyze(samples: nonEmptyAnswers)
            state.saveTextHabitProfile(profile)
            state.clearTextHabitAnswers()
            state.resetToHome()
        } catch {
            HostHaptics.error()
            if let localizedError = error as? LocalizedError, let description = localizedError.errorDescription {
                errorMessage = description
            } else {
                errorMessage = HostCopy.S002.errorFallback
            }
            isAnalyzing = false
        }
    }
}
