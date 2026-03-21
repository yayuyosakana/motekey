import Foundation
import ReplayKit
import CoreImage
import CoreMedia
import ImageIO
import MoteKeyShared
#if canImport(UIKit)
import UIKit
#endif

final class SampleHandler: RPBroadcastSampleHandler {
    private let appGroupID = AppGroupKeys.suiteName
    private let latestFrameFileName = AppGroupKeys.latestFrameFileName
    private let latestFramePasteboardName = AppGroupKeys.latestFramePasteboardName
    private let latestFramePasteboardType = AppGroupKeys.latestFramePasteboardType
    private let ciContext = CIContext(options: nil)
    private let minimumWriteInterval: TimeInterval = 0.35

    private var appGroupURL: URL?
    private var isProcessingFrame = false
    private var lastWriteAt = Date.distantPast

    override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {
        appGroupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID
        )
    }

    override func broadcastPaused() {}

    override func broadcastResumed() {}

    override func broadcastFinished() {}

    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        guard sampleBufferType == .video else { return }

        let now = Date()
        guard now.timeIntervalSince(lastWriteAt) >= minimumWriteInterval else { return }
        guard !isProcessingFrame else { return }

        isProcessingFrame = true

        autoreleasepool {
            defer { isProcessingFrame = false }
            guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

            let sourceImage = CIImage(cvPixelBuffer: imageBuffer)
            let scaledImage = sourceImage.transformed(by: CGAffineTransform(scaleX: 0.5, y: 0.5))
            let colorSpace = CGColorSpaceCreateDeviceRGB()

            guard let jpegData = ciContext.jpegRepresentation(
                of: scaledImage,
                colorSpace: colorSpace,
                options: [
                    CIImageRepresentationOption(rawValue: kCGImageDestinationLossyCompressionQuality as String): 0.7
                ]
            ) else { return }

            var didPersist = false
            if let appGroupURL {
                let frameURL = appGroupURL.appendingPathComponent(latestFrameFileName)
                do {
                    try jpegData.write(to: frameURL, options: .atomic)
                    didPersist = true
                } catch {
                    // App Groupが使えない場合は Pasteboard 経由へフォールバックする
                }
            }

            if persistToPasteboard(jpegData) {
                didPersist = true
            }

            if didPersist {
                lastWriteAt = now
            }
        }
    }

    private func persistToPasteboard(_ data: Data) -> Bool {
#if canImport(UIKit)
        let pasteboardName = UIPasteboard.Name(latestFramePasteboardName)
        guard let pasteboard = UIPasteboard(name: pasteboardName, create: true) else {
            return false
        }
        pasteboard.setData(data, forPasteboardType: latestFramePasteboardType)
        return true
#else
        return false
#endif
    }
}
