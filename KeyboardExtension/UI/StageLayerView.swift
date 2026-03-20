import SwiftUI

struct StageLayerView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(appState.generatedCandidates.enumerated()), id: \.offset) { _, candidate in
                    Button(action: { appState.insertChip(candidate) }) {
                        Text(candidate.text)
                            .lineLimit(1)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.white)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .background(Color(white: 0.95))
    }
}
