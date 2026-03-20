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

            HStack(spacing: 8) {
                Button("再試行") { appState.retryFromFallback() }
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
