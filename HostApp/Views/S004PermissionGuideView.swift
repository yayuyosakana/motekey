import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct S004PermissionGuideView: View {
    @EnvironmentObject private var state: HostAppState

    @State private var hasMotekeyEnabled = false
    @State private var hasAcknowledgedScreenRecording = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("キーボードと画面収録の準備をお願いします")
                    .font(.headline)

                Group {
                    Text("1. iOS設定でモテキーを追加し、フルアクセスを許可")
                    Text("2. コントロールセンターから画面収録を開始")
                    Text("3. LINEに戻ってモテキーを利用")
                }
                .foregroundStyle(.secondary)

                Button("設定を開く") {
                    openSettings()
                }
                .buttonStyle(.bordered)

                Toggle("画面収録の開始手順を確認した", isOn: $hasAcknowledgedScreenRecording)

                Button("次へ") {
                    state.navigationPath.append(HostRoute.keyboardComplete)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!(hasMotekeyEnabled && hasAcknowledgedScreenRecording))

                if !hasMotekeyEnabled {
                    Text("キーボードの追加が未完了です。設定後にアプリへ戻って再確認してください。")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .padding()
        }
        .navigationTitle("使用準備")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            checkKeyboardPermission()
        }
#if canImport(UIKit)
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            checkKeyboardPermission()
        }
#endif
    }

    private func checkKeyboardPermission() {
#if canImport(UIKit)
        hasMotekeyEnabled = UITextInputMode.activeInputModes.contains {
            ($0.primaryLanguage ?? "").localizedCaseInsensitiveContains("motekey")
        }
#else
        hasMotekeyEnabled = false
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
            Text("準備完了です")
                .font(.title3)
            Text("次にメッセージアプリでモテキーへ切り替える手順を確認します")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Button("使い方を見る") {
                state.navigationPath.append(HostRoute.tutorial)
            }
            .buttonStyle(.borderedProminent)

            Button("あとで") {
                state.markSetupConfigured()
                state.resetToHome()
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .navigationTitle("初期設定完了")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct S004TutorialView: View {
    @EnvironmentObject private var state: HostAppState

    var body: some View {
        List {
            Text("1. メッセージアプリを開く")
            Text("2. 入力欄をタップしてキーボードを表示")
            Text("3. 地球儀アイコンを長押し")
            Text("4. モテキーを選択")
            Text("5. mote+AI をタップして開始")
        }
        .navigationTitle("使い方")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("閉じる") {
                    state.markSetupConfigured()
                    state.resetToHome()
                }
            }
        }
    }
}
