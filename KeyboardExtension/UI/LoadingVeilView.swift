import SwiftUI

struct LoadingVeilView: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
            VStack(spacing: 10) {
                ProgressView()
                Text("AIが返信候補を準備中...")
                    .font(.caption)
                    .foregroundStyle(.white)
            }
            .padding(16)
            .background(Color.black.opacity(0.45))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .ignoresSafeArea()
    }
}
