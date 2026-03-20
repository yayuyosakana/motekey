import Foundation

enum GeminiJSONExtractor {
    static func firstJSONObject(in text: String) -> String? {
        var startIndex: String.Index?
        var depth = 0

        for index in text.indices {
            let char = text[index]
            if char == "{" {
                if startIndex == nil {
                    startIndex = index
                }
                depth += 1
            } else if char == "}" {
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
