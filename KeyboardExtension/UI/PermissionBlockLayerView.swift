import SwiftUI

struct PermissionBlockLayerView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(spacing: 10) {
            Text("mote+AIを使うには権限が必要です")
                .font(.headline)

            Text(issueText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 8) {
                Button("再確認") { appState.retryAfterPermissionGrant() }
                    .buttonStyle(.borderedProminent)
                Button("キーボードへ") { appState.closePermissionBlock() }
                    .buttonStyle(.bordered)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(Color(white: 0.95))
    }

    private var issueText: String {
        switch appState.permissionIssue {
        case .none:
            return "必要な権限を確認してください。"
        case .fullAccessDenied:
            return "フルアクセスが未許可です。iOS設定で許可後に再実行してください。"
        case .screenRecordingDenied:
            return "画面収録が未開始です。Broadcast Extensionを開始してから再実行してください。"
        }
    }
}
