import SwiftUI

struct KeyboardRuntimeRootView: View {
    @ObservedObject var appState: AppState
    private let baseKeyboardView: AnyView
    private let onAdvanceInputMode: () -> Void

    init(
        appState: AppState,
        onAdvanceInputMode: @escaping () -> Void = {}
    ) {
        self.appState = appState
        self.baseKeyboardView = AnyView(DefaultKeyboardBodyPlaceholderView())
        self.onAdvanceInputMode = onAdvanceInputMode
    }

    init<BaseKeyboard: View>(
        appState: AppState,
        onAdvanceInputMode: @escaping () -> Void = {},
        @ViewBuilder baseKeyboard: () -> BaseKeyboard
    ) {
        self.appState = appState
        self.baseKeyboardView = AnyView(baseKeyboard())
        self.onAdvanceInputMode = onAdvanceInputMode
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottom) {
                baseKeyboardView

                if appState.currentScreen == .stage {
                    StageLayerView(appState: appState)
                        .transition(.opacity)
                }

                if appState.currentScreen == .fullText {
                    FullTextLayerView(appState: appState)
                        .transition(.opacity)
                }

                if appState.currentScreen == .askUser {
                    AskUserLayerView(appState: appState)
                        .transition(.opacity)
                }

                if appState.currentScreen == .loading {
                    LoadingVeilView()
                        .transition(.opacity)
                }

                if appState.currentScreen == .fallback {
                    FallbackLayerView(appState: appState)
                        .transition(.opacity)
                }

                if appState.currentScreen == .permissionBlock {
                    PermissionBlockLayerView(appState: appState)
                        .transition(.opacity)
                }
            }

            BottomActionBarView(
                appState: appState,
                onAdvanceInputMode: onAdvanceInputMode
            )
        }
        .animation(.easeInOut(duration: 0.2), value: appState.currentScreen)
    }
}

private struct DefaultKeyboardBodyPlaceholderView: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("Keyboard Body")
                .font(.headline)
            Text("実機では azooKey の通常キーボードを配置")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(white: 0.96))
    }
}
