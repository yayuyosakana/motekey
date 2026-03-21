import SwiftUI

struct StageLayerView: View {
    @ObservedObject var appState: AppState
    @State private var appearedIndices: Set<Int> = []

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(appState.generatedCandidates.enumerated()), id: \.offset) { index, candidate in
                    Button(action: { appState.insertCandidateAndReturnToKeyboard(candidate) }) {
                        Text(candidate.text)
                            .lineLimit(1)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.white)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .opacity(appearedIndices.contains(index) ? 1 : 0)
                    .offset(x: appearedIndices.contains(index) ? 0 : 20)
                    .animation(.spring(response: 0.35, dampingFraction: 0.8).delay(Double(index) * 0.05), value: appearedIndices)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .background(Color(white: 0.95))
        .onAppear(perform: animateChips)
        .onChange(of: appState.generatedCandidates.count) {
            animateChips()
        }
    }

    private func animateChips() {
        appearedIndices.removeAll()
        for index in appState.generatedCandidates.indices {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.05) {
                appearedIndices.insert(index)
            }
        }
    }
}
