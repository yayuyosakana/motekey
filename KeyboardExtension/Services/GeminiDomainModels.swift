import Foundation

struct VisionChatContextResponse: Codable {
    struct Message: Codable {
        let speaker: String
        let text: String
        let date_label: String?
        let time: String?
    }

    let chat_detected: Bool
    let app: String?
    let messages: [Message]
    let last_speaker: String?
    let last_message: String?
}

struct AskUserQuestionsResponse: Decodable {
    struct Question: Decodable {
        struct Option: Decodable {
            let label: String
            let value: String
        }

        let question: String
        let options: [Option]
    }

    let questions: [Question]
}

struct ReplyCandidatesResponse: Decodable {
    struct Chip: Decodable {
        let text: String
    }

    let chips: [Chip]
}
