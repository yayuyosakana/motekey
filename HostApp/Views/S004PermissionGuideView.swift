import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct S004PermissionGuideView: View {
    @EnvironmentObject private var state: HostAppState

    @State private var hasMotekeyEnabled = false
    @State private var hasAcknowledgedScreenRecording = false
    @State private var showError = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("キーボードと画面収録の準備をお願いします")
                    .font(.headline)

                Text("`mote+AI` を使うために、キーボードの有効化と画面収録の開始が必要です")
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 8) {
                    Text("1. キーボードを有効にする")
                        .font(.subheadline.bold())
                    Text("1) iOSの設定アプリを開く")
                    Text("2) 一般 > キーボード > キーボード")
                    Text("3) 新しいキーボードを追加 > モテキー")
                    Text("4) モテキー > フルアクセスを許可 をオン")
                }
                .foregroundStyle(.secondary)

                Button("設定を開く") {
                    openSettings()
                }
                .buttonStyle(.bordered)

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("2. 画面収録を開始する")
                        .font(.subheadline.bold())
                    Text("1) コントロールセンターを開く")
                    Text("2) 画面収録を長押し")
                    Text("3) モテキーを選択して開始")
                    Text("4) LINEに戻る")
                }
                .foregroundStyle(.secondary)

                Toggle("画面収録の開始手順を確認した", isOn: $hasAcknowledgedScreenRecording)

                Button("次へ") {
                    state.navigationPath.append(HostRoute.keyboardComplete)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!(hasMotekeyEnabled && hasAcknowledgedScreenRecording))

                if showError {
                    Text("キーボードの追加またはフルアクセス許可が完了していないようです。")
                        .font(.caption)
                        .foregroundStyle(.red)

                    Button("もう一度設定を開く") {
                        openSettings()
                    }
                    .buttonStyle(.bordered)
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
        showError = !hasMotekeyEnabled
#else
        hasMotekeyEnabled = false
        showError = true
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
        VStack {
            List {
                Text("1. メッセージアプリを開く")
                Text("2. 入力欄をタップしてキーボードを表示")
                Text("3. 地球儀アイコンを長押し")
                Text("4. モテキーを選択")
                Text("5. mote+AI をタップして開始")
            }

            Button("はじめる") {
                state.markSetupConfigured()
                state.resetToHome()
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
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
