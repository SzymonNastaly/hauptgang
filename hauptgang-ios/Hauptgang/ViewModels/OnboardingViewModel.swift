import Foundation
import SwiftUI

/// Drives the pre-signup onboarding flow: three questions followed by embedded auth.
///
/// Answers are kept in memory and POSTed to the backend once at the end (best-effort),
/// keyed by the RevenueCat anonymous app user ID. The device id is also saved to
/// UserDefaults so `AuthService` can include it on the next signup/login request,
/// letting the server link the anonymous answers to the new user record.
@MainActor
final class OnboardingViewModel: ObservableObject {
    // MARK: - Steps

    enum Step: Int {
        case household
        case saveToday
        case diet
        case auth

        var isQuestion: Bool { self != .auth }

        var progressIndex: Int {
            switch self {
            case .household: 0
            case .saveToday: 1
            case .diet, .auth: 2
            }
        }

        static var questionCount: Int { 3 }
    }

    // MARK: - Published state

    @Published var step: Step
    @Published var householdSize: HouseholdSize?
    @Published var saveTodaySelections: Set<SaveTodayOption> = []
    @Published var dietSelections: Set<DietOption> = []

    // MARK: - Dependencies

    private let service: OnboardingService
    private let deviceId: String

    init(service: OnboardingService = .shared, deviceId: String = OnboardingService.currentDeviceId()) {
        self.service = service
        self.deviceId = deviceId
        self.step = OnboardingService.hasReachedAuthenticationStep() ? .auth : .household
    }

    // MARK: - Flow control

    var canAdvance: Bool {
        switch self.step {
        case .household: self.householdSize != nil
        case .saveToday: !self.saveTodaySelections.isEmpty
        case .diet: true // dietary preferences are always optional — "None" is implied
        case .auth: false
        }
    }

    /// Advance to the next step. When leaving the last question, submit the answers
    /// best-effort and persist enough state to resume at the onboarding auth screen.
    func advance() {
        if self.step == .diet {
            self.submitAnswers()
            self.prepareForAuthentication()
        }
        guard let next = Step(rawValue: self.step.rawValue + 1) else { return }
        withAnimation(.easeInOut(duration: 0.25)) {
            self.step = next
        }
    }

    func goBack() {
        guard let prev = Step(rawValue: self.step.rawValue - 1) else { return }
        withAnimation(.easeInOut(duration: 0.25)) { self.step = prev }
    }

    // MARK: - Completion

    /// Persist the device id for the next auth request and remember to resume at the
    /// onboarding auth screen until the user successfully authenticates or skips.
    func prepareForAuthentication() {
        OnboardingService.storeDeviceIdForAuth(self.deviceId)
        OnboardingService.markAuthStepReached()
    }

    /// Mark onboarding as completed so we don't re-show it on next launch.
    func markCompleted() {
        self.finishOnboarding()
    }

    /// Skip the flow without recording any answers. Still marks onboarding as done so
    /// we don't badger them on the next launch.
    func skip() {
        self.finishOnboarding()
    }

    private func finishOnboarding() {
        OnboardingService.clearAuthStepReached()
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: OnboardingService.completedAtDefaultsKey)
    }

    // MARK: - Submission

    private func submitAnswers() {
        let payload = self.currentAnswers
        let id = self.deviceId
        let service = self.service
        Task {
            await service.submit(deviceId: id, answers: payload)
        }
    }

    private var currentAnswers: [String: AnyCodable] {
        var dict: [String: AnyCodable] = [:]
        if let household = self.householdSize {
            dict["household_size"] = AnyCodable(household.serverValue)
        }
        if !self.saveTodaySelections.isEmpty {
            dict["save_today"] = AnyCodable(self.saveTodaySelections.map(\.serverValue).sorted())
        }
        // diet is recorded even when empty — empty array means "no restrictions"
        dict["diet"] = AnyCodable(self.dietSelections.map(\.serverValue).sorted())
        return dict
    }

}

// MARK: - Answer option enums

enum HouseholdSize: String, CaseIterable, Identifiable {
    case one, two, threeOrFour, fiveOrMore

    var id: String { self.rawValue }

    var label: String {
        switch self {
        case .one: "Just me"
        case .two: "2"
        case .threeOrFour: "3–4"
        case .fiveOrMore: "5+"
        }
    }

    /// Numeric value sent to the server. We pick the lower bound for ranges; it's only
    /// used as a default serving multiplier so the rough value is fine.
    var serverValue: Int {
        switch self {
        case .one: 1
        case .two: 2
        case .threeOrFour: 3
        case .fiveOrMore: 5
        }
    }

}

enum SaveTodayOption: String, CaseIterable, Identifiable {
    case screenshots, browserBookmarks, notes, paprika, cookbooks, dontSave

    var id: String { self.rawValue }

    var label: String {
        switch self {
        case .screenshots: "Screenshots"
        case .browserBookmarks: "Browser bookmarks"
        case .notes: "Notes app"
        case .paprika: "Paprika / Crouton / etc."
        case .cookbooks: "Physical cookbooks"
        case .dontSave: "I don't, I forget them"
        }
    }

    var serverValue: String {
        switch self {
        case .screenshots: "screenshots"
        case .browserBookmarks: "browser_bookmarks"
        case .notes: "notes"
        case .paprika: "recipe_apps"
        case .cookbooks: "cookbooks"
        case .dontSave: "dont_save"
        }
    }
}

enum DietOption: String, CaseIterable, Identifiable {
    case vegetarian, vegan, glutenFree, pescatarian, halal, kosher, lactoseFree

    var id: String { self.rawValue }

    var label: String {
        switch self {
        case .vegetarian: "Vegetarian"
        case .vegan: "Vegan"
        case .glutenFree: "Gluten-free"
        case .pescatarian: "Pescatarian"
        case .halal: "Halal"
        case .kosher: "Kosher"
        case .lactoseFree: "Lactose-free"
        }
    }

    var serverValue: String { self.rawValue }
}
