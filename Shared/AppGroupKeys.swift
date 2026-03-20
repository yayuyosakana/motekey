import Foundation

public enum AppGroupKeys {
    public static let suiteName = "group.com.motekey.shared"

    // テキストハビット
    public static let textStyleRegistered = "textStyleRegistered"
    public static let textStyleSummary = "textStyleSummary"
    public static let textStyleProfileData = "textStyleProfileData"

    // リレーション
    public static let relationRegistered = "relationRegistered"
    public static let relationProfileData = "relationProfileData"

    // セットアップと権限
    public static let setupConfigured = "setupConfigured"
    public static let permissionFullAccessGranted = "permission.fullAccessGranted"
    public static let permissionScreenRecordingGranted = "permission.screenRecordingGranted"

    // Broadcast Extension で上書きする最新1フレーム
    public static let latestFrameFileName = "latest_frame.jpg"
}
