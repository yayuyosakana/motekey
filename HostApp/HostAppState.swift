import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

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
        saveTextHabitProfile(.fallback(summary: summary, updatedAt: Date()))
    }

    func saveTextHabitProfile(_ profile: TextStyleProfile) {
        store.saveTextStyle(profile)
        textStyleRegistered = true
        textStyleSummary = profile.summary
    }

    func beginTextHabitRegistration() {
        textHabitAnswers = [:]
    }

    func clearTextHabitAnswers() {
        textHabitAnswers = [:]
    }

    func orderedNonEmptyTextHabitAnswers(questionCount: Int) -> [String] {
        guard questionCount > 0 else { return [] }
        return (0..<questionCount).compactMap { index in
            guard let raw = textHabitAnswers[index] else { return nil }
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
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

    func updatePermissionFlags(
        fullAccessGranted: Bool? = nil,
        screenRecordingAcknowledged: Bool? = nil
    ) {
        store.savePermissionFlags(
            fullAccessGranted: fullAccessGranted,
            screenRecordingGranted: screenRecordingAcknowledged
        )
    }

    func savedScreenRecordingAcknowledgement() -> Bool {
        store.loadPermissionFlags().screenRecordingGranted ?? false
    }

    func isScreenRecordingActive() -> Bool {
        store.hasRecentCapturedFrame()
    }

    func completeSetupAndReturnHome() {
        markSetupConfigured()
        resetToHome()
    }

    #if canImport(UIKit)
    func isMotekeyEnabled(activeInputModes: [UITextInputMode]) -> Bool {
        activeInputModes.contains { inputMode in
            let primaryLanguage = (inputMode.primaryLanguage ?? "").lowercased()
            guard !primaryLanguage.isEmpty else { return false }
            return HostCopy.S004.keyboardIdentifierHints.contains { hint in
                primaryLanguage.contains(hint.lowercased())
            }
        }
    }

    func shouldShowKeyboardPermissionError(
        updateErrorState: Bool,
        hasReturnedFromSettings: Bool,
        isMotekeyEnabled: Bool
    ) -> Bool {
        updateErrorState && hasReturnedFromSettings && !isMotekeyEnabled
    }
    #endif

    func resetToHome() {
        navigationPath = NavigationPath()
    }
}
