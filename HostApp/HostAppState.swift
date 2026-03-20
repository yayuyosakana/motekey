import Foundation
import SwiftUI

@MainActor
final class HostAppState: ObservableObject {
    struct RelationDraft {
        var nickname: String
        var relationshipType: RelationshipType
        var datingStartDate: Date
        var includeMarriageDate: Bool
        var marriageDate: Date
        var hasBirthday: Bool
        var birthday: MonthDay
        var cautionNote: String
    }

    @Published var navigationPath = NavigationPath()

    @Published var textStyleRegistered = false
    @Published var textStyleSummary = ""
    @Published var textHabitAnswers: [Int: String] = [:]

    @Published var relationRegistered = false
    @Published var partnerNickname = ""
    @Published var relationshipType: RelationshipType = .unknown
    @Published var datingStartDate: Date?
    @Published var marriageDate: Date?
    @Published var partnerBirthday: MonthDay?
    @Published var cautionNote = ""

    @Published var setupConfigured = false

    private let store: AppGroupStore

    init(store: AppGroupStore = AppGroupStore()) {
        self.store = store
        loadFromAppGroup()
    }

    func loadFromAppGroup() {
        textStyleRegistered = store.isTextStyleRegistered()
        textStyleSummary = store.loadTextStyleSummary()
        relationRegistered = store.isRelationRegistered()
        setupConfigured = store.isSetupConfigured()

        if let relation = store.loadRelation() {
            partnerNickname = relation.partnerNickname
            relationshipType = relation.relationshipType
            datingStartDate = relation.datingStartDate
            marriageDate = relation.marriageDate
            partnerBirthday = relation.partnerBirthday
            cautionNote = relation.cautionNote
        }
    }

    func saveTextHabitSummary(_ summary: String) {
        let profile = TextStyleProfile(summary: summary, updatedAt: Date())
        store.saveTextStyle(profile)
        textStyleRegistered = true
        textStyleSummary = summary
    }

    func saveRelationProfile() {
        let nickname = partnerNickname.isEmpty ? HostCopy.Common.defaultPartnerName : partnerNickname
        let profile = RelationProfile(
            partnerNickname: nickname,
            relationshipType: relationshipType,
            datingStartDate: datingStartDate,
            marriageDate: marriageDate,
            partnerBirthday: partnerBirthday,
            cautionNote: cautionNote,
            updatedAt: Date()
        )
        store.saveRelation(profile)
        relationRegistered = true
    }

    func makeRelationDraft() -> RelationDraft {
        RelationDraft(
            nickname: partnerNickname,
            relationshipType: relationshipType,
            datingStartDate: datingStartDate ?? Date(),
            includeMarriageDate: marriageDate != nil,
            marriageDate: marriageDate ?? Date(),
            hasBirthday: partnerBirthday != nil,
            birthday: partnerBirthday ?? MonthDay(month: 1, day: 1),
            cautionNote: cautionNote
        )
    }

    func saveRelationDraft(_ draft: RelationDraft) {
        partnerNickname = draft.nickname.isEmpty ? HostCopy.Common.defaultPartnerName : draft.nickname
        relationshipType = draft.relationshipType
        datingStartDate = draft.datingStartDate
        marriageDate = draft.includeMarriageDate ? draft.marriageDate : nil
        partnerBirthday = draft.hasBirthday ? draft.birthday : nil
        cautionNote = draft.cautionNote
        saveRelationProfile()
    }

    func markSetupConfigured() {
        setupConfigured = true
        store.saveSetupConfigured(true)
    }

    func completeSetupAndReturnHome() {
        markSetupConfigured()
        resetToHome()
    }

    func resetToHome() {
        navigationPath = NavigationPath()
    }
}
