import Foundation
import MoteKeyConfig
import MoteKeyShared
import os

final class GeminiKeyboardRuntimeService: VisionContextExtracting, AskUserQuestionGenerating, ReplyGenerating {
    private static let logger = Logger(
        subsystem: "com.motekey.keyboard",
        category: "GeminiKeyboardRuntimeService"
    )

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

        let firstPayload = try await generateReplyPayload(prompt: prompt)
        if let candidates = validatedReplyCandidates(from: firstPayload) {
            return candidates
        }

        Self.logger.notice("Gemini reply candidates failed quality gate. Retrying once.")
        let retryPrompt = """
        \(prompt)

        追加指示:
        - 先ほどの禁止語チェックに抵触しない内容で再生成すること
        - 同じ文末の反復を避け、実行アクションを明確にすること
        """

        let secondPayload = try await generateReplyPayload(prompt: retryPrompt)
        guard let retryCandidates = validatedReplyCandidates(from: secondPayload) else {
            throw RuntimeError.invalidReplyResponse
        }
        return retryCandidates
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
        guard !apiKey.isEmpty else {
            Self.logger.error(
                "Gemini request blocked: missing API key for callType=\(String(describing: callType), privacy: .public)"
            )
            throw GeminiServiceError.missingAPIKey
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 10
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")

        let body = GeminiGenerateContentRequest(
            contents: [.init(parts: parts)],
            generationConfig: .init(
                responseMimeType: "application/json",
                temperature: generationTemperature(for: callType)
            )
        )
        request.httpBody = try encoder.encode(body)

        Self.logger.debug(
            "Gemini request start callType=\(String(describing: callType), privacy: .public)"
        )

        let data = try await requestWithSingleRetryIfRateLimited(request, callType: callType)
        return try parseResponseText(data: data)
    }

    private func requestWithSingleRetryIfRateLimited(
        _ request: URLRequest,
        callType: APIConfig.GeminiCallType
    ) async throws -> Data {
        let (firstData, firstResponse) = try await session.data(for: request)
        guard let firstHTTP = firstResponse as? HTTPURLResponse else {
            throw GeminiServiceError.emptyResponse
        }

        Self.logger.debug(
            "Gemini response status=\(firstHTTP.statusCode, privacy: .public) callType=\(String(describing: callType), privacy: .public)"
        )

        if (200..<300).contains(firstHTTP.statusCode) {
            return firstData
        }

        if firstHTTP.statusCode == 429 {
            Self.logger.notice(
                "Gemini rate limited, fail-fast for offline fallback. callType=\(String(describing: callType), privacy: .public)"
            )
            throw GeminiServiceError.invalidHTTPStatus(429)
        }

        Self.logger.error(
            "Gemini failed status=\(firstHTTP.statusCode, privacy: .public) callType=\(String(describing: callType), privacy: .public) body=\(Self.responseBodyPreview(firstData), privacy: .public)"
        )
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

    private func generateReplyPayload(prompt: String) async throws -> ReplyCandidatesPayload {
        let text = try await generateContent(
            callType: .replyGeneration,
            parts: [.init(text: prompt, inlineData: nil)]
        )
        let jsonText = try extractJSONObject(from: text)
        return try decoder.decode(ReplyCandidatesPayload.self, from: Data(jsonText.utf8))
    }

    private func validatedReplyCandidates(from payload: ReplyCandidatesPayload) -> [ReplyCandidate]? {
        guard payload.isValidForMVP else {
            return nil
        }

        let candidates = payload.chips
            .map { ReplyCandidate(text: normalizeReplyText($0.text)) }
            .filter { !$0.text.isEmpty }
            .filter { !containsForbiddenReplyPhrase($0.text) }

        guard GeminiSchemaConstraints.replyChipCountRange.contains(candidates.count) else {
            return nil
        }
        return candidates
    }

    private func normalizeReplyText(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func containsForbiddenReplyPhrase(_ text: String) -> Bool {
        let forbiddenSubstrings = [
            "了解",
            "任せる",
            "どっちでもいい",
            "の件",
            "パートナー"
        ]

        if forbiddenSubstrings.contains(where: { text.contains($0) }) {
            return true
        }

        let quotePattern = "「[^」]+」"
        if text.range(of: quotePattern, options: .regularExpression) != nil {
            return true
        }

        let okPattern = "(?i)\\bOK\\b"
        if text.range(of: okPattern, options: .regularExpression) != nil {
            return true
        }

        return false
    }

    private func generationTemperature(for callType: APIConfig.GeminiCallType) -> Double {
        switch callType {
        case .replyGeneration:
            return 0.55
        case .askUserQuestionGeneration:
            return 0.3
        case .textHabitAnalysis, .visionChatContextExtraction:
            return 0.2
        }
    }

    private static func responseBodyPreview(_ data: Data) -> String {
        guard !data.isEmpty else {
            return "<empty>"
        }

        let raw = String(data: data, encoding: .utf8) ?? "<non-utf8>"
        let singleLine = raw.replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
        if singleLine.count <= 240 {
            return singleLine
        }
        let end = singleLine.index(singleLine.startIndex, offsetBy: 240)
        return "\(singleLine[..<end])..."
    }
}
