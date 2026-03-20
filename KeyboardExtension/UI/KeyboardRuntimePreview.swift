import SwiftUI

#if DEBUG
struct KeyboardRuntimeRootView_Previews: PreviewProvider {
    static var previews: some View {
        KeyboardRuntimeRootView(appState: KeyboardRuntimeFactory.makeMockAppState())
            .frame(height: 320)
    }
}
#endif
