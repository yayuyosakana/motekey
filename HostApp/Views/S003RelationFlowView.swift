import SwiftUI

struct S003RelationFlowView: View {
    @EnvironmentObject private var state: HostAppState

    @State private var step: RelationStep = .nickname
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

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(stepTitle)
                .font(.caption)
                .foregroundStyle(.secondary)

            content

            Spacer()

            if step != .done {
                Button(step == .birthdayAndCaution ? "登録する" : "次へ") {
                    next()
                }
                .buttonStyle(.borderedProminent)
                .disabled(step == .birthdayAndCaution && !isAgreed)
            }
        }
        .padding()
        .navigationTitle("リレーションチェック")
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
            Text("パートナーの呼び名を教えてください")
                .font(.headline)
            TextField("ゆいちゃん、妻、など", text: $nickname)
                .textFieldStyle(.roundedBorder)
        case .relationship:
            Text("どんな関係ですか？")
                .font(.headline)
            Picker("関係性", selection: $relationshipType) {
                ForEach(RelationshipType.allCases) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.inline)
        case .datingDate:
            Text("付き合い始めたのはいつ？")
                .font(.headline)
            DatePicker("付き合い始めた日", selection: $datingStartDate, displayedComponents: .date)
                .datePickerStyle(.graphical)

            if relationshipType.requiresMarriageDate {
                Toggle("入籍日も追加", isOn: $includeMarriageDate)
                if includeMarriageDate {
                    DatePicker("入籍日", selection: $marriageDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                }
            }
        case .birthdayAndCaution:
            Text("誕生日と気をつけること")
                .font(.headline)
            Toggle("誕生日を登録する", isOn: $hasBirthday)
            if hasBirthday {
                HStack {
                    Picker("月", selection: $birthdayMonth) {
                        ForEach(1...12, id: \.self) { month in
                            Text("\(month)月").tag(month)
                        }
                    }
                    Picker("日", selection: $birthdayDay) {
                        ForEach(1...31, id: \.self) { day in
                            Text("\(day)日").tag(day)
                        }
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 120)
            }

            TextEditor(text: $cautionNote)
                .frame(height: 140)
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                }

            Toggle("入力内容と会話文脈がGemini APIに送信されることに同意する", isOn: $isAgreed)
        case .done:
            Text("登録完了")
                .font(.title2)
            Text("いつでも再編集できます")
                .foregroundStyle(.secondary)
            Button("ホームに戻る") {
                state.resetToHome()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var stepTitle: String {
        switch step {
        case .nickname: return "ステップ 1 / 4"
        case .relationship: return "ステップ 2 / 4"
        case .datingDate: return "ステップ 3 / 4"
        case .birthdayAndCaution: return "ステップ 4 / 4"
        case .done: return "完了"
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
            state.partnerNickname = nickname.isEmpty ? "パートナー" : nickname
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
