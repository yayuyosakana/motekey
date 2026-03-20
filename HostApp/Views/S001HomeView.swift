import SwiftUI

struct S001HomeView: View {
    @EnvironmentObject private var state: HostAppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(HostCopy.S001.homeTitle)
                    .font(.title3.weight(.semibold))
                    .padding(.top, 8)
                Text(HostCopy.S001.homeSubtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Text(HostCopy.S001.setupSectionTitle)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)

                Button {
                    state.navigationPath.append(HostRoute.textHabit(questionIndex: 0))
                } label: {
                    card(
                        icon: "text.bubble",
                        title: HostCopy.S001.textHabitTitle,
                        done: state.textStyleRegistered,
                        detail: state.textStyleSummary.isEmpty ? HostCopy.Common.notRegistered : state.textStyleSummary
                    )
                }

                Button {
                    state.navigationPath.append(HostRoute.relation(step: .nickname))
                } label: {
                    card(
                        icon: "heart.text.square",
                        title: HostCopy.S001.relationTitle,
                        done: state.relationRegistered,
                        detail: state.partnerNickname.isEmpty ? HostCopy.Common.notRegistered : state.partnerNickname
                    )
                }

                Button {
                    state.navigationPath.append(HostRoute.keyboardPermission)
                } label: {
                    card(
                        icon: "keyboard",
                        title: HostCopy.S001.permissionTitle,
                        done: state.setupConfigured,
                        detail: state.setupConfigured ? HostCopy.Common.configured : HostCopy.Common.notConfigured
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .navigationTitle(HostCopy.Common.appTitle)
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(uiColor: .systemGroupedBackground))
        .onAppear {
            state.loadFromAppGroup()
        }
    }

    private func card(icon: String, title: String, done: Bool, detail: String) -> some View {
        HStack {
            Image(systemName: done ? "checkmark.circle.fill" : icon)
                .font(.title3)
                .foregroundStyle(done ? .green : .pink)
                .frame(width: 30)

            VStack(alignment: .leading) {
                Text(title).foregroundStyle(.primary)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
