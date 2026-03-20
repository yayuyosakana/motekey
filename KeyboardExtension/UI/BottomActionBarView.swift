import SwiftUI

struct BottomActionBarView: View {
    @ObservedObject var appState: AppState
    let onAdvanceInputMode: () -> Void

    static let height: CGFloat = 52

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 12) {
                Button(action: onAdvanceInputMode) {
                    Image(systemName: "globe")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundStyle(.primary)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)

                Button(action: { appState.handleBottomTabTap(.moteAI) }) {
                    HStack(spacing: 4) {
                        if appState.isAIProcessing {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(.white)
                        } else {
                            Image(systemName: "sparkles")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        Text("mote+AI")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(height: 36)
                    .padding(.horizontal, 12)
                    .background(appState.currentScreen == .askUser ? Color.pink : Color.pink.opacity(0.85))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .disabled(appState.isAIProcessing)

                Spacer(minLength: 0)

                HStack(spacing: 0) {
                    sliderTab(title: "キーボード", tab: .keyboard, disabled: false)
                    sliderTab(title: "全文表示", tab: .fullText, disabled: !appState.canOpenFullText)
                }
                .padding(2)
                .background(Color.white.opacity(0.75))
                .clipShape(RoundedRectangle(cornerRadius: 9))
            }
            .padding(.horizontal, 12)
            .frame(height: Self.height)
        }
        .background(Color(white: 0.92))
    }

    @ViewBuilder
    private func sliderTab(title: String, tab: BottomTab, disabled: Bool) -> some View {
        let isSelected = tab == .fullText ? appState.isFullTextTabActive : appState.isKeyboardTabActive
        Button(action: {
            appState.handleBottomTabTap(tab)
        }) {
            Text(title)
                .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                .frame(minWidth: 52, minHeight: 26)
                .padding(.horizontal, 4)
                .background(
                    Group {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 7)
                                .fill(Color.white)
                        }
                    }
                )
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.4 : 1)
    }
}
