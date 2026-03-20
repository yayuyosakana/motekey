import SwiftUI

struct FallbackLayerView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(spacing: 10) {
            Text("文脈抽出に失敗しました")
                .font(.headline)
            Text(reasonText)
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField("相手のメッセージを手入力", text: $appState.manualFallbackInput, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...5)

            if let validation = appState.manualFallbackValidationMessage {
                Text(validation)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 8) {
                Button("再試行") { appState.retryFromFallback() }
                    .buttonStyle(.borderedProminent)
                Button("手入力で続行") { appState.continueFromManualFallbackInput() }
                    .buttonStyle(.borderedProminent)
                Button("キーボードへ") { appState.closeFallback() }
                    .buttonStyle(.bordered)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(Color(white: 0.95))
    }

    private var reasonText: String {
        switch appState.fallbackReason {
        case .none:
            return "エラー内容は不明です。"
        case .imageCaptureFailed:
            return "画面キャプチャを取得できませんでした。"
        case .apiTimeout:
            return "APIがタイムアウトしました。"
        case .apiError:
            return "APIエラーが発生しました。"
        }
    }
}
