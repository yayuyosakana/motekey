import SwiftUI

/// キーボード拡張のルート。要件 S-005〜S-007 の重なり順を表現する。
///
/// 通常時（キーボード/ステージタブ）:
///   ┌ ステージバー（AI候補チップ・候補がある時だけ）
///   ├ 予測変換バー（キーボード本体に内蔵）
///   └ キーボード本体（フリック）
/// に下部タブ（mote+AI / キーボード / 全文表示）が付く。
///
/// mote+AI 質問・全文表示・ローディング・フォールバック・権限ブロックは、
/// キーボードを覆う全面オーバーレイとして表示する。
struct KeyboardRuntimeRootView: View {
    @ObservedObject var appState: AppState
    private let baseKeyboardView: AnyView
    private let onAdvanceInputMode: () -> Void

    init(
        appState: AppState,
        onAdvanceInputMode: @escaping () -> Void = {}
    ) {
        self.appState = appState
        self.baseKeyboardView = AnyView(
            JapaneseKeyboardView(onInsert: { _ in }, onDeleteBackward: {})
        )
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
            ZStack {
                VStack(spacing: 0) {
                    if showStageBar {
                        StageLayerView(appState: appState)
                            .transition(.opacity)
                    }
                    baseKeyboardView
                }

                overlayLayer
            }

            BottomActionBarView(
                appState: appState,
                onAdvanceInputMode: onAdvanceInputMode
            )
        }
        .animation(.easeInOut(duration: 0.2), value: appState.currentScreen)
    }

    /// ステージバーは「キーボード/ステージタブ」かつ候補がある時だけ重ねる。
    private var showStageBar: Bool {
        appState.isKeyboardTabActive && !appState.generatedCandidates.isEmpty
    }

    @ViewBuilder
    private var overlayLayer: some View {
        switch appState.currentScreen {
        case .askUser:
            fullCover { AskUserLayerView(appState: appState) }
        case .fullText:
            fullCover { FullTextLayerView(appState: appState) }
        case .fallback:
            fullCover { FallbackLayerView(appState: appState) }
        case .permissionBlock:
            fullCover { PermissionBlockLayerView(appState: appState) }
        case .loading:
            LoadingVeilView()
                .transition(.opacity)
        case .keyboard, .stage:
            EmptyView()
        }
    }

    @ViewBuilder
    private func fullCover<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color(white: 0.95))
            .transition(.opacity)
    }
}
