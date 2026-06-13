import SwiftUI
#if canImport(UIKit) && canImport(ReplayKit)
import UIKit
import ReplayKit

/// 画面収録をユーザー操作で開始するための、実際に表示されるブロードキャストピッカー。
///
/// 以前は画面外に隠した `RPSystemBroadcastPickerView` の内部ボタンを
/// `sendActions(for: .touchUpInside)` で自動タップしていたが、iOS ではこの自動起動が
/// 不安定（しばしば何も起きない）。Apple 公式の導線どおり、ピッカーのボタンを
/// そのまま見せてユーザーにタップしてもらう。タップ→システムの開始確認→収録開始。
struct BroadcastPickerButton: UIViewRepresentable {
    let preferredExtension: String

    func makeUIView(context: Context) -> RPSystemBroadcastPickerView {
        let picker = RPSystemBroadcastPickerView(
            frame: CGRect(x: 0, y: 0, width: 60, height: 60)
        )
        picker.preferredExtension = preferredExtension
        picker.showsMicrophoneButton = false
        return picker
    }

    func updateUIView(_ uiView: RPSystemBroadcastPickerView, context: Context) {
        uiView.preferredExtension = preferredExtension
        uiView.showsMicrophoneButton = false
    }
}
#endif
