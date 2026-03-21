import SwiftUI

struct FullTextLayerView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        GeometryReader { geometry in
            if geometry.size.height < 200 {
                VStack {
                    Spacer()
                    Text("横向きでは全文表示を利用できません")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
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
                                    appState.insertCandidateAndReturnToKeyboard(candidate)
                                }) {
                                    HStack(alignment: .top, spacing: 8) {
                                        Text("\(index + 1).")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text(candidate.text)
                                            .font(.body)
                                            .lineLimit(nil)
                                            .fixedSize(horizontal: false, vertical: true)
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
            }
        }
        .background(Color(white: 0.95))
    }
}
