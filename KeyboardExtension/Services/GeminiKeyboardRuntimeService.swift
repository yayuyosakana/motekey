import Foundation
import MoteKeyConfig
import MoteKeyShared

final class GeminiKeyboardRuntimeService: VisionContextExtracting, AskUserQuestionGenerating, ReplyGenerating {
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(session: URLSession = .shared) {
        self.session = session
        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()
    }

    func extractChatContext(imageData: Data) async throws -> String {
        let prompt = GeminiPromptFactory.visionPrompt()
        let text = try await generateContent(
            callType: .visionChatContextExtraction,
            parts: [
                .init(text: prompt, inlineData: nil),
                .init(
                    text: nil,
                    inlineData: .init(mimeType: "image/jpeg", data: imageData.base64EncodedString())
                )
            ]
        )

        let jsonText = try extractJSONObject(from: text)
        let payload = try decoder.decode(ChatContextPayload.self, from: Data(jsonText.utf8))
        guard payload.chat_detected else {
            throw GeminiServiceError.chatNotDetected
        }
        guard isValidVisionPayload(payload) else {
            throw GeminiServiceError.invalidJSONPayload
        }

        let normalized = try encoder.encode(payload)
        return String(decoding: normalized, as: UTF8.self)
    }

    func generateQuestions(context: AskUserContext) async throws -> [AskUserQuestion] {
        let prompt = GeminiPromptFactory.askUserPrompt(context: context)
        let text = try await generateContent(
            callType: .askUserQuestionGeneration,
            parts: [.init(text: prompt, inlineData: nil)]
        )

        let jsonText = try extractJSONObject(from: text)
        let payload = try decoder.decode(AskUserQuestionsPayload.self, from: Data(jsonText.utf8))
        guard isValidQuestionPayload(payload) else {
            throw RuntimeError.invalidQuestionResponse
        }

        return payload.questions.enumerated().map { index, question in
            AskUserQuestion(
                index: index,
                text: question.question,
                options: question.options.map { AskUserOption(label: $0.label, value: $0.value) }
            )
        }
    }

    func generateReplyCandidates(
        chatContext: String,
        answers: [Int: String],
        textStyleProfile: TextStyleProfile,
        relationProfile: RelationProfile
    ) async throws -> [ReplyCandidate] {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy-MM-dd"

        let prompt = GeminiPromptFactory.replyPrompt(
            chatContext: chatContext,
            answers: answers,
            textStyleProfile: textStyleProfile,
            relationProfile: relationProfile,
            todayDate: formatter.string(from: Date())
        )

        let text = try await generateContent(
            callType: .replyGeneration,
            parts: [.init(text: prompt, inlineData: nil)]
        )

        let jsonText = try extractJSONObject(from: text)
        let payload = try decoder.decode(ReplyCandidatesPayload.self, from: Data(jsonText.utf8))
        guard payload.isValidForMVP else {
            throw RuntimeError.invalidReplyResponse
        }
        let candidates = payload.chips
            .map { ReplyCandidate(text: $0.text.trimmingCharacters(in: .whitespacesAndNewlines)) }
            .filter { !$0.text.isEmpty }
        return candidates
    }

    private func extractJSONObject(from text: String) throws -> String {
        guard let jsonText = GeminiJSONExtractor.firstJSONObject(in: text) else {
            throw GeminiServiceError.invalidJSONPayload
        }
        return jsonText
    }

    private func generateContent(
        callType: APIConfig.GeminiCallType,
        parts: [GeminiGenerateContentRequest.Content.Part]
    ) async throws -> String {
        let endpoint = APIConfig.geminiEndpoint(for: callType)
        guard let url = URL(string: endpoint) else {
            throw GeminiServiceError.invalidURL
        }

        let apiKey = APIConfig.geminiAPIKey(for: callType)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 10
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")

        let body = GeminiGenerateContentRequest(
            contents: [.init(parts: parts)],
            generationConfig: .init(responseMimeType: "application/json", temperature: 0.2)
        )
        request.httpBody = try encoder.encode(body)

        let data = try await requestWithSingleRetryIfRateLimited(request)
        return try parseResponseText(data: data)
    }

    private func requestWithSingleRetryIfRateLimited(_ request: URLRequest) async throws -> Data {
        let (firstData, firstResponse) = try await session.data(for: request)
        guard let firstHTTP = firstResponse as? HTTPURLResponse else {
            throw GeminiServiceError.emptyResponse
        }

        if (200..<300).contains(firstHTTP.statusCode) {
            return firstData
        }

        if firstHTTP.statusCode == 429 {
            try await Task.sleep(nanoseconds: 2_000_000_000)
            let (retryData, retryResponse) = try await session.data(for: request)
            guard let retryHTTP = retryResponse as? HTTPURLResponse else {
                throw GeminiServiceError.emptyResponse
            }
            guard (200..<300).contains(retryHTTP.statusCode) else {
                throw GeminiServiceError.invalidHTTPStatus(retryHTTP.statusCode)
            }
            return retryData
        }

        throw GeminiServiceError.invalidHTTPStatus(firstHTTP.statusCode)
    }

    private func parseResponseText(data: Data) throws -> String {
        let decoded = try decoder.decode(GeminiGenerateContentResponse.self, from: data)
        let text = decoded.candidates?
            .compactMap { $0.content?.parts }
            .flatMap { $0 }
            .compactMap { $0.text }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let text, !text.isEmpty else {
            throw GeminiServiceError.emptyResponse
        }
        return text
    }

    private func isValidVisionPayload(_ payload: ChatContextPayload) -> Bool {
        if !payload.chat_detected {
            return payload.messages.isEmpty && payload.last_speaker == nil && payload.last_message == nil
        }

        guard !payload.messages.isEmpty else { return false }
        guard payload.messages.allSatisfy({ message in
            let text = message.text.trimmingCharacters(in: .whitespacesAndNewlines)
            return !text.isEmpty
        }) else {
            return false
        }

        guard payload.last_speaker != nil else { return false }
        guard let lastMessage = payload.last_message?.trimmingCharacters(in: .whitespacesAndNewlines),
              !lastMessage.isEmpty else {
            return false
        }
        return true
    }

    private func isValidQuestionPayload(_ payload: AskUserQuestionsPayload) -> Bool {
        guard payload.isValidForMVP else { return false }
        return payload.questions.allSatisfy { question in
            let questionText = question.question.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !questionText.isEmpty,
                  question.options.count == GeminiSchemaConstraints.askUserOptionCount
            else {
                return false
            }

            var seenValues = Set<String>()
            for option in question.options {
                let label = option.label.trimmingCharacters(in: .whitespacesAndNewlines)
                let value = option.value.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !label.isEmpty, !value.isEmpty else {
                    return false
                }
                guard isSnakeCaseIdentifier(value) else {
                    return false
                }
                guard seenValues.insert(value).inserted else {
                    return false
                }
            }
            return true
        }
    }

    private func isSnakeCaseIdentifier(_ value: String) -> Bool {
        let pattern = "^[a-z0-9]+(?:_[a-z0-9]+)*$"
        return value.range(of: pattern, options: .regularExpression) != nil
    }
}
