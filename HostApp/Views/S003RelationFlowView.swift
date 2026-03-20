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

    init(initialStep: RelationStep = .nickname) {
        _step = State(initialValue: initialStep)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            content

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
            nickname = state.partnerNickname
            relationshipType = state.relationshipType
            cautionNote = state.cautionNote
            if let birthday = state.partnerBirthday {
                hasBirthday = true
                birthdayMonth = birthday.month
                birthdayDay = birthday.day
            }
            if let date = state.datingStartDate {
                datingStartDate = date
            }
            if let mDate = state.marriageDate {
                includeMarriageDate = true
                marriageDate = mDate
            }
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
            Picker("relationship", selection: $relationshipType) {
                ForEach(RelationshipType.allCases) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.inline)
        case .datingDate:
            Text(HostCopy.S003.datingDatePrompt)
                .font(.headline)
            DatePicker(HostCopy.S003.datingDateLabel, selection: $datingStartDate, displayedComponents: .date)
                .datePickerStyle(.graphical)

            if relationshipType.requiresMarriageDate {
                Toggle(HostCopy.S003.marriageToggle, isOn: $includeMarriageDate)
                if includeMarriageDate {
                    DatePicker(HostCopy.S003.marriageDateLabel, selection: $marriageDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                }
            }
        case .birthdayAndCaution:
            Text(HostCopy.S003.birthdayAndCautionPrompt)
                .font(.headline)
            Toggle(HostCopy.S003.birthdayToggle, isOn: $hasBirthday)
            if hasBirthday {
                MonthDayPicker(month: $birthdayMonth, day: $birthdayDay)

                Button(HostCopy.S003.birthdaySkip) {
                    hasBirthday = false
                }
                .buttonStyle(.bordered)
            }

            ZStack(alignment: .topLeading) {
                TextEditor(text: $cautionNote)
                    .frame(height: 140)
                    .onChange(of: cautionNote) { newValue in
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

            Toggle(HostCopy.S003.agreement, isOn: $isAgreed)
        case .done:
            Text(HostCopy.S003.doneTitle)
                .font(.title2)
            Text(HostCopy.S003.doneMessage)
                .foregroundStyle(.secondary)
            Button(HostCopy.S003.backToHome) {
                state.resetToHome()
            }
            .buttonStyle(.borderedProminent)
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
            step = .birthdayAndCaution
        case .birthdayAndCaution:
            state.partnerNickname = nickname.isEmpty ? HostCopy.Common.defaultPartnerName : nickname
            state.relationshipType = relationshipType
            state.datingStartDate = datingStartDate
            state.marriageDate = includeMarriageDate ? marriageDate : nil
            state.partnerBirthday = hasBirthday ? MonthDay(month: birthdayMonth, day: birthdayDay) : nil
            state.cautionNote = cautionNote
            state.saveRelationProfile()
            step = .done
        case .done:
            break
        }
    }
}
