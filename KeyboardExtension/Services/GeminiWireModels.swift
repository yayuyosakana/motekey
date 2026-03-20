import Foundation

struct GeminiGenerateContentRequest: Encodable {
    struct Content: Encodable {
        struct Part: Encodable {
            let text: String?
            let inlineData: InlineData?

            struct InlineData: Encodable {
                let mimeType: String
                let data: String
            }
        }

        let parts: [Part]
    }

    struct GenerationConfig: Encodable {
        let responseMimeType: String?
        let temperature: Double?
    }

    let contents: [Content]
    let generationConfig: GenerationConfig?
}

struct GeminiGenerateContentResponse: Decodable {
    struct Candidate: Decodable {
        struct Content: Decodable {
            struct Part: Decodable {
                let text: String?
            }

            let parts: [Part]?
        }

        let content: Content?
    }

    let candidates: [Candidate]?
}

enum GeminiServiceError: Error {
    case invalidURL
    case invalidHTTPStatus(Int)
    case emptyResponse
    case invalidJSONPayload
    case chatNotDetected
}
