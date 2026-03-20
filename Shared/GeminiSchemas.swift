import Foundation

public enum GeminiSchemaConstraints: Sendable {
    public static let askUserQuestionCount = 3
    public static let askUserOptionCount = 3
    public static let replyChipCountRange = 2...5
}

public struct ChatContextPayload: Codable, Equatable, Sendable {
    public struct Message: Codable, Equatable, Sendable {
        public enum Speaker: String, Codable, Sendable {
            case partner
            case me
        }

        public let speaker: Speaker
        public let text: String
        public let date_label: String?
        public let time: String?

        public init(speaker: Speaker, text: String, date_label: String?, time: String?) {
            self.speaker = speaker
            self.text = text
            self.date_label = date_label
            self.time = time
        }
    }

    public let chat_detected: Bool
    public let app: String
    public let messages: [Message]
    public let last_speaker: Message.Speaker?
    public let last_message: String?

    public init(
        chat_detected: Bool,
        app: String,
        messages: [Message],
        last_speaker: Message.Speaker?,
        last_message: String?
    ) {
        self.chat_detected = chat_detected
        self.app = app
        self.messages = messages
        self.last_speaker = last_speaker
        self.last_message = last_message
    }
}

public struct AskUserQuestionsPayload: Codable, Equatable, Sendable {
    public struct Question: Codable, Equatable, Sendable {
        public struct Option: Codable, Equatable, Sendable {
            public let label: String
            public let value: String

            public init(label: String, value: String) {
                self.label = label
                self.value = value
            }
        }

        public let question: String
        public let options: [Option]

        public init(question: String, options: [Option]) {
            self.question = question
            self.options = options
        }
    }

    public let questions: [Question]

    public init(questions: [Question]) {
        self.questions = questions
    }

    public var isValidForMVP: Bool {
        questions.count == GeminiSchemaConstraints.askUserQuestionCount
            && questions.allSatisfy { $0.options.count == GeminiSchemaConstraints.askUserOptionCount }
    }
}

public struct ReplyCandidatesPayload: Codable, Equatable, Sendable {
    public struct Chip: Codable, Equatable, Sendable {
        public let text: String

        public init(text: String) {
            self.text = text
        }
    }

    public let chips: [Chip]

    public init(chips: [Chip]) {
        self.chips = chips
    }

    public var isValidForMVP: Bool {
        GeminiSchemaConstraints.replyChipCountRange.contains(chips.count)
            && chips.allSatisfy { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
}
