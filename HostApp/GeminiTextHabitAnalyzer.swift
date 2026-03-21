import Foundation
import MoteKeyConfig

struct GeminiTextHabitAnalyzer {
    enum AnalysisError: LocalizedError {
        case missingAPIKey
        case invalidResponse
        case rateLimited
        case serverError

        var errorDescription: String? {
            switch self {
            case .missingAPIKey:
                return "Gemini APIキーが未設定です。"
            case .invalidResponse:
                return "APIレスポンスの解析に失敗しました。"
            case .rateLimited:
                return "リクエストが混み合っています。時間を置いて再試行してください。"
            case .serverError:
                return "一時的にサービスを利用できません。"
            }
        }
    }

    private struct RequestBody: Encodable {
        let contents: [Content]
        let generationConfig: GenerationConfig
    }

    private struct Content: Encodable {
        let parts: [Part]
    }

    private struct Part: Encodable {
        let text: String
    }

    private struct GenerationConfig: Encodable {
        let temperature: Double
    }

    private struct GenerateContentResponse: Decodable {
        let candidates: [Candidate]?
    }

    private struct Candidate: Decodable {
        let content: CandidateContent?
    }

    private struct CandidateContent: Decodable {
        let parts: [CandidatePart]?
    }

    private struct CandidatePart: Decodable {
        let text: String?
    }

    private struct StructuredSummary: Decodable {
        struct ToneProfileSummary: Decodable {
            let summary: String?
        }

        let summary: String?
        let toneProfile: ToneProfileSummary?

        enum CodingKeys: String, CodingKey {
            case summary
            case toneProfile = "tone_profile"
        }
    }

    func analyze(samples: [String]) async throws -> TextStyleProfile {
        try await analyze(samples: samples, hasRetried: false)
    }

    private func analyze(samples: [String], hasRetried: Bool) async throws -> TextStyleProfile {
        let key = APIConfig.geminiAPIKey(for: .textHabitAnalysis)
        guard !key.isEmpty else {
            throw AnalysisError.missingAPIKey
        }

        let endpoint = APIConfig.geminiEndpoint(for: .textHabitAnalysis)
        guard let url = URL(string: "\(endpoint)?key=\(key)") else {
            throw AnalysisError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 10
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let prompt = buildPrompt(samples: samples)
        let body = RequestBody(
            contents: [Content(parts: [Part(text: prompt)])],
            generationConfig: GenerationConfig(temperature: 0.2)
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AnalysisError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            break
        case 429:
            if !hasRetried {
                try await Task.sleep(for: .seconds(2))
                return try await analyze(samples: samples, hasRetried: true)
            }
            throw AnalysisError.rateLimited
        case 500...599:
            throw AnalysisError.serverError
        default:
            throw AnalysisError.invalidResponse
        }

        let parsed = try JSONDecoder().decode(GenerateContentResponse.self, from: data)
        guard let text = parsed.candidates?
            .compactMap({ candidate in
                candidate.content?.parts?
                    .compactMap(\.text)
                    .joined(separator: "\n")
            })
            .compactMap({ $0.trimmingCharacters(in: .whitespacesAndNewlines) })
            .first(where: { !$0.isEmpty }) else {
            throw AnalysisError.invalidResponse
        }

        if let profile = Self.parseProfileResponseText(text) {
            return profile
        }

        throw AnalysisError.invalidResponse
    }

    static func parseProfileResponseText(_ text: String) -> TextStyleProfile? {
        if let jsonString = firstJSONObjectString(in: text),
           let jsonData = jsonString.data(using: .utf8),
           let profile = try? JSONDecoder().decode(TextStyleProfile.self, from: jsonData) {
            return profile
        }

        if let summary = parseSummaryFallback(from: text) {
            return .fallback(summary: summary)
        }

        return nil
    }

    static func firstJSONObjectString(in text: String) -> String? {
        var startIndex: String.Index?
        var depth = 0
        var isInsideString = false
        var isEscaping = false

        for index in text.indices {
            let char = text[index]

            if isInsideString {
                if isEscaping {
                    isEscaping = false
                    continue
                }
                if char == "\\" {
                    isEscaping = true
                    continue
                }
                if char == "\"" {
                    isInsideString = false
                }
                continue
            }

            if char == "\"" {
                isInsideString = true
                continue
            }

            if char == "{" {
                if startIndex == nil {
                    startIndex = index
                }
                depth += 1
                continue
            }

            if char == "}" {
                guard startIndex != nil else { continue }
                depth -= 1
                if depth == 0, let start = startIndex {
                    return String(text[start...index])
                }
            }
        }

        return nil
    }

    private static func parseSummaryFallback(from text: String) -> String? {
        if let jsonString = firstJSONObjectString(in: text),
           let jsonData = jsonString.data(using: .utf8),
           let structured = try? JSONDecoder().decode(StructuredSummary.self, from: jsonData) {
            if let toneSummary = structured.toneProfile?.summary?
                .trimmingCharacters(in: .whitespacesAndNewlines),
               !toneSummary.isEmpty {
                return toneSummary
            }

            if let summary = structured.summary?.trimmingCharacters(in: .whitespacesAndNewlines),
               !summary.isEmpty {
                return summary
            }

            return nil
        }

        if firstJSONObjectString(in: text) != nil {
            return nil
        }

        let plain = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return plain.isEmpty ? nil : plain
    }

    private func buildPrompt(samples: [String]) -> String {
        let sampleLines = samples.enumerated()
            .map { index, sample in "\(index + 1). \(sample)" }
            .joined(separator: "\n")

        return """
        あなたはユーザーの文章の口調を分析するAIです。

        以下はユーザーが実際にパートナーへ送ったメッセージのサンプルです。

        【サンプルデータ】
        \(sampleLines)

        ---

        上記のサンプルをもとに、次の6観点（語尾のクセ、絵文字・記号、共感表現、提案の言い方、文の長さ、口語表現）を分析し、
        JSONのみで出力してください。前置き、説明文、コードブロックは不要です。

        出力形式:
        {
          "tone_profile": {
            "summary": "口調を一言で表現した文",
            "rules": ["ルール1", "ルール2"],
            "details": {
              "ending_patterns": "...",
              "emoji_usage": "...",
              "empathy_style": "...",
              "suggestion_style": "...",
              "message_length": "...",
              "colloquial_style": "..."
            }
          }
        }
        """
    }
}
