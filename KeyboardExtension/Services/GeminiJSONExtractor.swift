import Foundation

enum GeminiJSONExtractor {
    static func firstJSONObject(in text: String) -> String? {
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
}
