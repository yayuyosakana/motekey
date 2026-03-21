#if canImport(UIKit)
import UIKit
import ReplayKit

@MainActor
enum ScreenCaptureStarter {
    private static let preferredBroadcastExtension = "com.motekey.app.broadcast"
    private static let pickerTag = 0x4D4F5445 // "MOTE"

    static func requestSystemBroadcastStart(from hostView: UIView?) {
        guard let hostView else { return }

        let picker: RPSystemBroadcastPickerView
        if let existing = hostView.viewWithTag(pickerTag) as? RPSystemBroadcastPickerView {
            picker = existing
        } else {
            picker = RPSystemBroadcastPickerView(frame: CGRect(x: -1000, y: -1000, width: 1, height: 1))
            picker.tag = pickerTag
            hostView.addSubview(picker)
        }

        picker.preferredExtension = preferredBroadcastExtension
        picker.showsMicrophoneButton = false

        hostView.layoutIfNeeded()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if let startButton = picker.subviews.compactMap({ $0 as? UIButton }).first {
                startButton.sendActions(for: .touchUpInside)
            }
        }
    }
}
#endif
