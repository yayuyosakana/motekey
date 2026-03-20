import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct S004PermissionGuideView: View {
    @EnvironmentObject private var state: HostAppState

    @State private var hasMotekeyEnabled = false
    @State private var hasAcknowledgedScreenRecording = false
    @State private var showError = false
    @State private var hasReturnedFromSettings = false

    private let keyboardIdentifierHints: [String] = [
        "motekey",
        "com.motekey.app.keyboard",
        "com.motekey.app"
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(HostCopy.S004.prepHeadline)
                    .font(.headline)

                Text(HostCopy.S004.prepSubheadline)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 8) {
                    Text(HostCopy.S004.sectionKeyboard)
                        .font(.subheadline.bold())
                    Text(HostCopy.S004.keyboardStep1)
                    Text(HostCopy.S004.keyboardStep2)
                    Text(HostCopy.S004.keyboardStep3)
                    Text(HostCopy.S004.keyboardStep4)
                }
                .foregroundStyle(.secondary)

                Button(HostCopy.S004.openSettings) {
                    openSettings()
                }
                .buttonStyle(.bordered)

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text(HostCopy.S004.sectionRecording)
                        .font(.subheadline.bold())
                    Text(HostCopy.S004.recordingStep1)
                    Text(HostCopy.S004.recordingStep2)
                    Text(HostCopy.S004.recordingStep3)
                    Text(HostCopy.S004.recordingStep4)
                }
                .foregroundStyle(.secondary)

                Toggle(HostCopy.S004.recordingAcknowledgement, isOn: $hasAcknowledgedScreenRecording)

                Button(HostCopy.S004.next) {
                    state.navigationPath.append(HostRoute.keyboardComplete)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!(hasMotekeyEnabled && hasAcknowledgedScreenRecording))

                if showError {
                    Text(HostCopy.S004.permissionError)
                        .font(.caption)
                        .foregroundStyle(.red)

                    Button(HostCopy.S004.reopenSettings) {
                        openSettings()
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
        }
        .navigationTitle(HostCopy.S004.preparationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            checkKeyboardPermission(updateErrorState: false)
        }
#if canImport(UIKit)
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            hasReturnedFromSettings = true
            checkKeyboardPermission(updateErrorState: true)
        }
#endif
    }

    private func checkKeyboardPermission(updateErrorState: Bool) {
#if canImport(UIKit)
        hasMotekeyEnabled = UITextInputMode.activeInputModes.contains {
            let primaryLanguage = ($0.primaryLanguage ?? "").lowercased()
            return keyboardIdentifierHints.contains { hint in
                primaryLanguage.contains(hint.lowercased())
            }
        }
        showError = updateErrorState && hasReturnedFromSettings && !hasMotekeyEnabled
#else
        hasMotekeyEnabled = false
        showError = updateErrorState
#endif
    }

    private func openSettings() {
#if canImport(UIKit)
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(settingsURL)
#endif
    }
}

struct S004CompleteView: View {
    @EnvironmentObject private var state: HostAppState

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.green)
            Text(HostCopy.S004.completeHeadline)
                .font(.title3)
            Text(HostCopy.S004.completeSubheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Button(HostCopy.S004.viewTutorial) {
                state.navigationPath.append(HostRoute.tutorial)
            }
            .buttonStyle(.borderedProminent)

            Button(HostCopy.S004.later) {
                state.completeSetupAndReturnHome()
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .navigationTitle(HostCopy.S004.completeTitle)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct S004TutorialView: View {
    @EnvironmentObject private var state: HostAppState

    var body: some View {
        VStack {
            List {
                Text(HostCopy.S004.tutorialStep1)
                Text(HostCopy.S004.tutorialStep2)
                Text(HostCopy.S004.tutorialStep3)
                Text(HostCopy.S004.tutorialStep4)
                Text(HostCopy.S004.tutorialStep5)
            }

            Button(HostCopy.S004.start) {
                state.completeSetupAndReturnHome()
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .navigationTitle(HostCopy.S004.tutorialTitle)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(HostCopy.S004.close) {
                    state.completeSetupAndReturnHome()
                }
            }
        }
    }
}
