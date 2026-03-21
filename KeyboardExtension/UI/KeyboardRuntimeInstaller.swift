#if canImport(UIKit)
import UIKit
import SwiftUI

@MainActor
enum KeyboardRuntimeInstaller {
    static func makeAppState(
        context: any KeyboardRuntimeHostContext
    ) -> AppState? {
        return KeyboardRuntimeFactory.makeAppState(
            clearMarkedText: { [weak context] in
                context?.clearMarkedText()
            },
            insertText: { [weak context] text in
                context?.insertText(text)
            },
            hasFullAccess: { [weak context] in
                context?.hasFullAccess ?? false
            }
        )
    }

    static func makeAppState(
        in inputViewController: UIInputViewController,
        clearMarkedText: @escaping () -> Void = {}
    ) -> AppState? {
        KeyboardRuntimeFactory.makeAppState(
            clearMarkedText: clearMarkedText,
            insertText: { [weak inputViewController] text in
                inputViewController?.textDocumentProxy.insertText(text)
            },
            hasFullAccess: { [weak inputViewController] in
                inputViewController?.hasFullAccess ?? false
            },
            requestScreenCaptureStart: { [weak inputViewController] in
                ScreenCaptureStarter.requestSystemBroadcastStart(from: inputViewController?.view)
            }
        )
    }

    @discardableResult
    static func embed<BaseKeyboard: View>(
        into parent: UIInputViewController,
        appState: AppState,
        @ViewBuilder baseKeyboard: @escaping () -> BaseKeyboard
    ) -> UIHostingController<KeyboardRuntimeRootView> {
        let hostingController = UIHostingController(
            rootView: KeyboardRuntimeRootView(
                appState: appState,
                onAdvanceInputMode: {
                    parent.advanceToNextInputMode()
                },
                baseKeyboard: baseKeyboard
            )
        )
        hostingController.view.backgroundColor = .clear
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false

        parent.addChild(hostingController)
        parent.view.addSubview(hostingController.view)
        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(equalTo: parent.view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: parent.view.trailingAnchor),
            hostingController.view.topAnchor.constraint(equalTo: parent.view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: parent.view.bottomAnchor)
        ])
        hostingController.didMove(toParent: parent)

        return hostingController
    }
}
#endif
