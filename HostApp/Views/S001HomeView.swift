import SwiftUI

struct S001HomeView: View {
    @EnvironmentObject private var state: HostAppState

    var body: some View {
        List {
            Section("初回セットアップ") {
                Button {
                    state.navigationPath.append(HostRoute.textHabit(questionIndex: 0))
                } label: {
                    row(title: "テキストハビットチェック", done: state.textStyleRegistered,
                        detail: state.textStyleSummary.isEmpty ? "未登録" : state.textStyleSummary)
                }

                Button {
                    state.navigationPath.append(HostRoute.relation(step: .nickname))
                } label: {
                    row(title: "リレーションチェック", done: state.relationRegistered,
                        detail: state.partnerNickname.isEmpty ? "未登録" : state.partnerNickname)
                }

                Button {
                    state.navigationPath.append(HostRoute.keyboardPermission)
                } label: {
                    row(title: "キーボード・画面収録設定", done: state.setupConfigured,
                        detail: state.setupConfigured ? "設定済み" : "未設定")
                }
            }
        }
        .navigationTitle("モテキー")
        .onAppear {
            state.loadFromAppGroup()
        }
    }

    private func row(title: String, done: Bool, detail: String) -> some View {
        HStack {
            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(done ? .green : .pink)
            VStack(alignment: .leading) {
                Text(title)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
