import Foundation
import SwiftUI

@MainActor
final class HostAppState: ObservableObject {
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
        let nickname = partnerNickname.isEmpty ? "パートナー" : partnerNickname
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

    func markSetupConfigured() {
        setupConfigured = true
        store.saveSetupConfigured(true)
    }

    func resetToHome() {
        navigationPath = NavigationPath()
    }
}
