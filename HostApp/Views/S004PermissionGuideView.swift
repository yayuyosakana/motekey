import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
#if canImport(ReplayKit)
import ReplayKit
#endif

struct S004PermissionGuideView: View {
    @EnvironmentObject private var state: HostAppState

    @State private var hasMotekeyEnabled = false
    @State private var hasManuallyConfirmedKeyboardSetup = false
    @State private var hasAcknowledgedScreenRecording = false
    @State private var isScreenRecordingActive = false
    @State private var showError = false
    @State private var hasReturnedFromSettings = false
    @State private var didOpenSystemSettings = false
    private let recordingStatusTimer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()
    private let broadcastPickerTag = 0x4D4F5445 // "MOTE"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Spacer()
                    Image(systemName: "keyboard.badge.ellipsis")
                        .font(.system(size: 48))
                        .foregroundStyle(.pink)
                    Spacer()
                }

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
                    Text(HostCopy.S004.keyboardStep5)
                }
                .foregroundStyle(.secondary)

                Button(HostCopy.S004.openSettings) {
                    openSettings()
                }
                .buttonStyle(.bordered)

                Toggle(
                    HostCopy.S004.keyboardManualConfirmation,
                    isOn: $hasManuallyConfirmedKeyboardSetup
                )

                if !hasMotekeyEnabled {
                    Text(HostCopy.S004.keyboardDetectionFailedHint)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text(HostCopy.S004.sectionRecording)
                        .font(.subheadline.bold())
                    Text(HostCopy.S004.recordingStep1)
                    Text(HostCopy.S004.recordingStep2)
                    Text(HostCopy.S004.recordingStep3)
                    Text(HostCopy.S004.recordingStep4)
                    Text(HostCopy.S004.recordingStep5)
                }
                .foregroundStyle(.secondary)

                Button(HostCopy.S004.startRecordingButton) {
                    startScreenRecordingFromApp()
                }
                .buttonStyle(.borderedProminent)

                Text(isScreenRecordingActive
                     ? HostCopy.S004.recordingStatusActive
                     : HostCopy.S004.recordingStatusInactive)
                    .font(.caption)
                    .foregroundStyle(isScreenRecordingActive ? .green : .secondary)

                Toggle(HostCopy.S004.recordingAcknowledgement, isOn: $hasAcknowledgedScreenRecording)

                Button(HostCopy.S004.next) {
                    let keyboardReady = hasMotekeyEnabled || hasManuallyConfirmedKeyboardSetup
                    let screenRecordingReady = isScreenRecordingActive || hasAcknowledgedScreenRecording
                    state.updatePermissionFlags(
                        fullAccessGranted: keyboardReady,
                        screenRecordingAcknowledged: screenRecordingReady
                    )
                    state.navigationPath.append(HostRoute.keyboardComplete)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!((hasMotekeyEnabled || hasManuallyConfirmedKeyboardSetup)
                          && (isScreenRecordingActive || hasAcknowledgedScreenRecording)))

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
            hasAcknowledgedScreenRecording = state.savedScreenRecordingAcknowledgement()
            checkKeyboardPermission(updateErrorState: false)
            refreshScreenRecordingStatus()
        }
        .onChange(of: hasAcknowledgedScreenRecording) { _, value in
            state.updatePermissionFlags(screenRecordingAcknowledged: value)
        }
        .onReceive(recordingStatusTimer) { _ in
            refreshScreenRecordingStatus()
        }
#if canImport(UIKit)
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            let shouldUpdateError = didOpenSystemSettings
            hasReturnedFromSettings = hasReturnedFromSettings || shouldUpdateError
            checkKeyboardPermission(updateErrorState: shouldUpdateError)
            refreshScreenRecordingStatus()
            didOpenSystemSettings = false
        }
#endif
    }

    private func checkKeyboardPermission(updateErrorState: Bool) {
#if canImport(UIKit)
        hasMotekeyEnabled = state.isMotekeyEnabled(activeInputModes: UITextInputMode.activeInputModes)
        state.updatePermissionFlags(fullAccessGranted: hasMotekeyEnabled)
        showError = state.shouldShowKeyboardPermissionError(
            updateErrorState: updateErrorState,
            hasReturnedFromSettings: hasReturnedFromSettings,
            isMotekeyEnabled: hasMotekeyEnabled
        )
#else
        hasMotekeyEnabled = false
        state.updatePermissionFlags(fullAccessGranted: false)
        showError = updateErrorState
#endif
    }

    private func openSettings() {
#if canImport(UIKit)
        didOpenSystemSettings = true
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(settingsURL)
#endif
    }

    private func refreshScreenRecordingStatus() {
        let active = state.isScreenRecordingActive()
        isScreenRecordingActive = active
        if active && !hasAcknowledgedScreenRecording {
            hasAcknowledgedScreenRecording = true
        }
    }

    private func startScreenRecordingFromApp() {
#if canImport(UIKit) && canImport(ReplayKit)
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first,
              let hostView = windowScene.windows.first(where: \.isKeyWindow)?.rootViewController?.view else {
            return
        }

        let picker: RPSystemBroadcastPickerView
        if let existing = hostView.viewWithTag(broadcastPickerTag) as? RPSystemBroadcastPickerView {
            picker = existing
        } else {
            picker = RPSystemBroadcastPickerView(frame: CGRect(x: -1000, y: -1000, width: 1, height: 1))
            picker.tag = broadcastPickerTag
            hostView.addSubview(picker)
        }

        picker.preferredExtension = "com.motekey.app.broadcast"
        picker.showsMicrophoneButton = false
        hostView.layoutIfNeeded()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if let button = picker.subviews.compactMap({ $0 as? UIButton }).first {
                button.sendActions(for: .touchUpInside)
            }
        }
#endif
    }
}

struct S004CompleteView: View {
    @EnvironmentObject private var state: HostAppState

    var body: some View {
        VStack(spacing: 16) {
            CheckmarkAnimationView()
            Text(HostCopy.S004.completeHeadline)
                .font(.title3)
            Text(HostCopy.S004.completeSubheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Button(HostCopy.S004.viewTutorial) {
                HostHaptics.success()
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
                HostHaptics.success()
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
                    HostHaptics.success()
                    state.completeSetupAndReturnHome()
                }
            }
        }
    }
}
