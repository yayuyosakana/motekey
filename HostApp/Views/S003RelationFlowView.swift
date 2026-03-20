import SwiftUI

struct S003RelationFlowView: View {
    @EnvironmentObject private var state: HostAppState

    @State private var step: RelationStep
    @State private var nickname: String = ""
    @State private var relationshipType: RelationshipType = .unknown
    @State private var datingStartDate = Date()
    @State private var includeMarriageDate = false
    @State private var marriageDate = Date()
    @State private var hasBirthday = false
    @State private var birthdayMonth = 1
    @State private var birthdayDay = 1
    @State private var cautionNote = ""
    @State private var isAgreed = false
    @State private var showDatingDatePicker = false
    @State private var showMarriageDatePicker = false

    init(initialStep: RelationStep = .nickname) {
        _step = State(initialValue: initialStep)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if step == .birthdayAndCaution {
                ScrollView {
                    birthdayAndCautionContent
                }
            } else {
                content
            }

            Spacer()

            if step != .done {
                Button(step == .birthdayAndCaution ? HostCopy.S003.register : HostCopy.S003.next) {
                    next()
                }
                .buttonStyle(.borderedProminent)
                .disabled(step == .birthdayAndCaution && !isAgreed)
            }
        }
        .padding()
        .navigationTitle(stepNavigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            applyDraft(state.makeRelationDraft())
        }
        .onChange(of: relationshipType) { _, newValue in
            if !newValue.requiresMarriageDate {
                includeMarriageDate = false
            }
        }
        .sheet(isPresented: $showDatingDatePicker) {
            datePickerSheet(
                title: HostCopy.S003.datingDateLabel,
                selection: $datingStartDate,
                onDone: { showDatingDatePicker = false }
            )
        }
        .sheet(isPresented: $showMarriageDatePicker) {
            datePickerSheet(
                title: HostCopy.S003.marriageDateLabel,
                selection: $marriageDate,
                onDone: { showMarriageDatePicker = false }
            )
        }
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .nickname:
            Text(HostCopy.S003.nicknamePrompt)
                .font(.headline)
            TextField(HostCopy.S003.nicknamePlaceholder, text: $nickname)
                .textFieldStyle(.roundedBorder)
            Button(HostCopy.S003.nicknameSkip) {
                nickname = ""
                step = .relationship
            }
            .buttonStyle(.bordered)
        case .relationship:
            Text(HostCopy.S003.relationPrompt)
                .font(.headline)

            VStack(spacing: 8) {
                ForEach(RelationshipType.allCases) { type in
                    Button {
                        relationshipType = type
                    } label: {
                        HStack {
                            Text(type.rawValue)
                            Spacer()
                            if relationshipType == type {
                                Image(systemName: "checkmark.circle.fill")
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(relationshipType == type ? Color.pink.opacity(0.2) : Color(.secondarySystemBackground))
                        .foregroundStyle(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
        case .datingDate:
            Text(HostCopy.S003.datingDatePrompt)
                .font(.headline)

            dateDisplayButton(
                title: HostCopy.S003.datingDateLabel,
                value: formattedDate(datingStartDate)
            ) {
                showDatingDatePicker = true
            }

            if relationshipType.requiresMarriageDate {
                Text(HostCopy.S003.marriageNote)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    choiceChip(
                        title: HostCopy.S003.datingOnly,
                        isSelected: !includeMarriageDate
                    ) {
                        includeMarriageDate = false
                    }

                    choiceChip(
                        title: HostCopy.S003.marriageToggle,
                        isSelected: includeMarriageDate
                    ) {
                        includeMarriageDate = true
                    }
                }

                if includeMarriageDate {
                    dateDisplayButton(
                        title: HostCopy.S003.marriageDateLabel,
                        value: formattedDate(marriageDate)
                    ) {
                        showMarriageDatePicker = true
                    }
                }
            }
        case .birthdayAndCaution:
            EmptyView()
        case .done:
            VStack(alignment: .center, spacing: 12) {
                CheckmarkAnimationView()
                Text(HostCopy.S003.doneTitle)
                    .font(.title2)
                Text(HostCopy.S003.doneMessage)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Button(HostCopy.S003.backToHome) {
                    state.resetToHome()
                }
                .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var birthdayAndCautionContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(HostCopy.S003.birthdayAndCautionPrompt)
                .font(.headline)
            Text(HostCopy.S003.birthdayDescription)
                .font(.caption)
                .foregroundStyle(.secondary)

            Toggle(HostCopy.S003.birthdayToggle, isOn: $hasBirthday)
            if hasBirthday {
                MonthDayPicker(month: $birthdayMonth, day: $birthdayDay)

                Button(HostCopy.S003.birthdaySkip) {
                    hasBirthday = false
                }
                .buttonStyle(.bordered)
            }

            Divider()

            Text(HostCopy.S003.cautionPrompt)
                .font(.headline)
            Text(HostCopy.S003.cautionDescription)
                .font(.caption)
                .foregroundStyle(.secondary)

            ZStack(alignment: .topLeading) {
                TextEditor(text: $cautionNote)
                    .frame(height: 140)
                    .onChange(of: cautionNote) { _, newValue in
                        if newValue.count > 200 {
                            cautionNote = String(newValue.prefix(200))
                        }
                    }

                if cautionNote.isEmpty {
                    Text(HostCopy.S003.cautionPlaceholder)
                        .foregroundStyle(.secondary)
                        .font(.callout)
                        .padding(.top, 8)
                        .padding(.leading, 4)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            }

            HStack {
                Spacer()
                Text("\(cautionNote.count)/200")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button(HostCopy.S003.cautionSkip) {
                cautionNote = ""
            }
            .buttonStyle(.bordered)

            Divider()

            Toggle(HostCopy.S003.agreement, isOn: $isAgreed)
        }
    }

    private var stepNavigationTitle: String {
        switch step {
        case .nickname: return HostCopy.S003.step1
        case .relationship: return HostCopy.S003.step2
        case .datingDate: return HostCopy.S003.step3
        case .birthdayAndCaution: return HostCopy.S003.step4
        case .done: return HostCopy.S003.doneTitle
        }
    }

    private func next() {
        switch step {
        case .nickname:
            step = .relationship
        case .relationship:
            step = .datingDate
        case .datingDate:
            if !relationshipType.requiresMarriageDate {
                includeMarriageDate = false
            }
            step = .birthdayAndCaution
        case .birthdayAndCaution:
            state.saveRelationDraft(
                .init(
                    nickname: nickname,
                    relationshipType: relationshipType,
                    datingStartDate: datingStartDate,
                    includeMarriageDate: includeMarriageDate,
                    marriageDate: marriageDate,
                    hasBirthday: hasBirthday,
                    birthday: MonthDay(month: birthdayMonth, day: birthdayDay),
                    cautionNote: cautionNote
                )
            )
            step = .done
        case .done:
            break
        }
    }

    private func applyDraft(_ draft: HostAppState.RelationDraft) {
        nickname = draft.nickname
        relationshipType = draft.relationshipType
        datingStartDate = draft.datingStartDate
        includeMarriageDate = draft.includeMarriageDate
        marriageDate = draft.marriageDate
        hasBirthday = draft.hasBirthday
        birthdayMonth = draft.birthday.month
        birthdayDay = draft.birthday.day
        cautionNote = draft.cautionNote
    }

    private func choiceChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(isSelected ? Color.pink : Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private func dateDisplayButton(title: String, value: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.headline)
                    .foregroundStyle(.pink)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy年 M月 d日"
        return formatter.string(from: date)
    }

    private func datePickerSheet(title: String, selection: Binding<Date>, onDone: @escaping () -> Void) -> some View {
        VStack(spacing: 12) {
            Text(title)
                .font(.headline)
            DatePicker("", selection: selection, displayedComponents: .date)
                .datePickerStyle(.wheel)
                .labelsHidden()
            Button("決定") {
                onDone()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .presentationDetents([.height(320)])
    }
}
