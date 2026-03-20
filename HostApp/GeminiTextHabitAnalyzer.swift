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
        let summary: String
    }

    func analyze(samples: [String]) async throws -> String {
        try await analyze(samples: samples, hasRetried: false)
    }

    private func analyze(samples: [String], hasRetried: Bool) async throws -> String {
        let key = APIConfig.geminiAPIKey(for: .textHabitAnalysis)
        guard !key.isEmpty else {
            throw AnalysisError.missingAPIKey
        }

        guard let url = URL(string: "\(APIConfig.geminiTextEndpoint)?key=\(key)") else {
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
            .first?
            .content?
            .parts?
            .first?
            .text?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else {
            throw AnalysisError.invalidResponse
        }

        if let structured = try? JSONDecoder().decode(StructuredSummary.self, from: Data(text.utf8)) {
            return structured.summary
        }
        return text
    }

    private func buildPrompt(samples: [String]) -> String {
        let sampleLines = samples.enumerated()
            .map { index, sample in "\(index + 1). \(sample)" }
            .joined(separator: "\n")

        return """
        次の返信サンプルから、語尾・口調・文の長さ・絵文字傾向を簡潔に要約してください。
        出力は日本語1文、最大80文字。

        返信サンプル:
        \(sampleLines)
        """
    }
}
