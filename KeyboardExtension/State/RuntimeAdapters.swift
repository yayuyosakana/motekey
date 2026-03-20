import Foundation

struct FileLatestFrameLoader: LatestFrameLoading {
    let frameURL: URL

    func loadLatestFrameData() throws -> Data {
        try Data(contentsOf: frameURL)
    }
}

struct InMemoryProfileStore: ProfileStore {
    let textStyleProfile: TextStyleProfile
    let relationProfile: RelationProfile

    func loadTextStyleProfile() -> TextStyleProfile {
        textStyleProfile
    }

    func loadRelationProfile() -> RelationProfile {
        relationProfile
    }
}

final class TextDocumentComposeProxy: ComposeTextProxy {
    private let insertHandler: (String) -> Void

    init(insertHandler: @escaping (String) -> Void) {
        self.insertHandler = insertHandler
    }

    func insertText(_ text: String) {
        insertHandler(text)
    }
}
