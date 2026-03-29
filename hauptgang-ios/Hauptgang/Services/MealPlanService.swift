import Foundation
import os

protocol MealPlanServiceProtocol: Sendable {
    func fetchMealPlans(cookbookId: Int, from: String, to: String) async throws -> [MealPlanDay]
    func addEntry(cookbookId: Int, date: String, recipeId: Int) async throws -> MealPlanDay
    func deleteEntry(id: Int) async throws
    func vote(entryId: Int) async throws -> MealPlanDay
    func unvote(entryId: Int) async throws -> MealPlanDay
    func select(cookbookId: Int, date: String, entryId: Int) async throws -> MealPlanDay
    func deselect(cookbookId: Int, date: String) async throws -> MealPlanDay
}

final class MealPlanService: MealPlanServiceProtocol, @unchecked Sendable {
    static let shared = MealPlanService()

    private let api = APIClient.shared
    private let logger = Logger(subsystem: "app.hauptgang.ios", category: "MealPlanService")

    private init() {}

    func fetchMealPlans(cookbookId: Int, from: String, to: String) async throws -> [MealPlanDay] {
        self.logger.info("Fetching meal plans from \(from) to \(to)")

        let plans: [MealPlanDay] = try await api.request(
            endpoint: "cookbooks/\(cookbookId)/meal_plans",
            method: .get,
            queryItems: [
                URLQueryItem(name: "from", value: from),
                URLQueryItem(name: "to", value: to)
            ],
            authenticated: true
        )

        self.logger.info("Fetched \(plans.count) meal plan days")
        return plans
    }

    func addEntry(cookbookId: Int, date: String, recipeId: Int) async throws -> MealPlanDay {
        self.logger.info("Adding entry for recipe \(recipeId) on \(date)")

        let request = MealPlanAddEntryRequest(recipeId: recipeId)
        return try await self.api.request(
            endpoint: "cookbooks/\(cookbookId)/meal_plans/\(date)/entries",
            method: .post,
            body: request,
            authenticated: true
        )
    }

    func deleteEntry(id: Int) async throws {
        self.logger.info("Deleting entry \(id)")

        try await self.api.requestVoid(
            endpoint: "meal_plan_entries/\(id)",
            method: .delete,
            authenticated: true
        )
    }

    func vote(entryId: Int) async throws -> MealPlanDay {
        self.logger.info("Voting for entry \(entryId)")

        return try await self.api.request(
            endpoint: "meal_plan_entries/\(entryId)/vote",
            method: .post,
            authenticated: true
        )
    }

    func unvote(entryId: Int) async throws -> MealPlanDay {
        self.logger.info("Unvoting entry \(entryId)")

        return try await self.api.request(
            endpoint: "meal_plan_entries/\(entryId)/vote",
            method: .delete,
            authenticated: true
        )
    }

    func select(cookbookId: Int, date: String, entryId: Int) async throws -> MealPlanDay {
        self.logger.info("Selecting entry \(entryId) for \(date)")

        let request = MealPlanSelectRequest(entryId: entryId)
        return try await self.api.request(
            endpoint: "cookbooks/\(cookbookId)/meal_plans/\(date)/select",
            method: .patch,
            body: request,
            authenticated: true
        )
    }

    func deselect(cookbookId: Int, date: String) async throws -> MealPlanDay {
        self.logger.info("Deselecting for \(date)")

        return try await self.api.request(
            endpoint: "cookbooks/\(cookbookId)/meal_plans/\(date)/select",
            method: .delete,
            authenticated: true
        )
    }
}
