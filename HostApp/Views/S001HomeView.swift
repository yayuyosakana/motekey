import SwiftUI

struct S001HomeView: View {
    @EnvironmentObject private var state: HostAppState

    var body: some View {
        List {
            Section(HostCopy.S001.setupSectionTitle) {
                Button {
                    state.navigationPath.append(HostRoute.textHabit(questionIndex: 0))
                } label: {
                    row(title: HostCopy.S001.textHabitTitle, done: state.textStyleRegistered,
                        detail: state.textStyleSummary.isEmpty ? HostCopy.Common.notRegistered : state.textStyleSummary)
                }

                Button {
                    state.navigationPath.append(HostRoute.relation(step: .nickname))
                } label: {
                    row(title: HostCopy.S001.relationTitle, done: state.relationRegistered,
                        detail: state.partnerNickname.isEmpty ? HostCopy.Common.notRegistered : state.partnerNickname)
                }

                Button {
                    state.navigationPath.append(HostRoute.keyboardPermission)
                } label: {
                    row(title: HostCopy.S001.permissionTitle, done: state.setupConfigured,
                        detail: state.setupConfigured ? HostCopy.Common.configured : HostCopy.Common.notConfigured)
                }
            }
        }
        .navigationTitle(HostCopy.Common.appTitle)
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
