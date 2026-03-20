import SwiftUI

struct FullTextLayerView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("全文表示")
                    .font(.headline)
                Spacer()
                Button("ステージへ") {
                    appState.showStage()
                }
                .font(.caption)
            }

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(Array(appState.generatedCandidates.enumerated()), id: \.offset) { index, candidate in
                        Button(action: {
                            appState.insertChip(candidate)
                            appState.showStage()
                        }) {
                            HStack(alignment: .top, spacing: 8) {
                                Text("\(index + 1).")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(candidate.text)
                                    .font(.body)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(10)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(12)
        .background(Color(white: 0.95))
    }
}
