import Foundation

enum AppGroupKeys {
    static let suiteName = "group.com.motekey.shared"

    // テキストハビット
    static let textStyleRegistered = "textStyleRegistered"
    static let textStyleSummary = "textStyleSummary"
    static let textStyleProfileData = "textStyleProfileData"

    // リレーション
    static let relationRegistered = "relationRegistered"
    static let relationProfileData = "relationProfileData"

    // セットアップと権限
    static let setupConfigured = "setupConfigured"
    static let permissionFullAccessGranted = "permission.fullAccessGranted"
    static let permissionScreenRecordingGranted = "permission.screenRecordingGranted"

    // Broadcast Extension で上書きする最新1フレーム
    static let latestFrameFileName = "latest_frame.jpg"
}
