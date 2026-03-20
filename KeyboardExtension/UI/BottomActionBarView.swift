import SwiftUI

struct BottomActionBarView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        HStack(spacing: 8) {
            Button(action: { appState.handleBottomTabTap(.moteAI) }) {
                tabLabel(title: "mote+AI", isActive: appState.currentScreen == .askUser || appState.currentScreen == .loading)
            }
            .disabled(appState.isAIProcessing)

            Button(action: { appState.handleBottomTabTap(.keyboard) }) {
                tabLabel(title: "キーボード", isActive: appState.currentScreen == .keyboard || appState.currentScreen == .stage)
            }

            Button(action: { appState.handleBottomTabTap(.fullText) }) {
                tabLabel(title: "全文表示", isActive: appState.currentScreen == .fullText)
            }
            .disabled(!appState.canOpenFullText)
        }
        .padding(.horizontal, 12)
        .frame(height: 52)
        .background(Color(white: 0.92))
    }

    private func tabLabel(title: String, isActive: Bool) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(isActive ? Color.white : Color.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(isActive ? Color.pink : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
