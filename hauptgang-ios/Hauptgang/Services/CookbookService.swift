import Foundation
import os

/// Protocol for cookbook API operations - enables mocking in tests
protocol CookbookServiceProtocol: Sendable {
    func fetchCookbooks() async throws -> [Cookbook]
    func createCookbook(name: String, movePersonalRecipes: Bool) async throws -> Cookbook
    func deleteCookbook(id: Int) async throws
    func leaveCookbook(id: Int) async throws
    func createInvitation(cookbookId: Int) async throws -> CookbookInvitationResponse
    func fetchInvitationPreview(token: String) async throws -> CookbookInvitationPreview
    func acceptInvitation(token: String) async throws -> CookbookInvitationAcceptResponse
    func rejectInvitation(token: String) async throws
}

/// Handles all cookbook-related API calls
final class CookbookService: CookbookServiceProtocol, @unchecked Sendable {
    static let shared = CookbookService()

    private let api = APIClient.shared
    private let logger = Logger(subsystem: "app.hauptgang.ios", category: "CookbookService")

    private init() {}

    func fetchCookbooks() async throws -> [Cookbook] {
        self.logger.info("Fetching cookbooks")

        let cookbooks: [Cookbook] = try await api.request(
            endpoint: "cookbooks",
            method: .get,
            authenticated: true
        )

        self.logger.info("Fetched \(cookbooks.count) cookbooks")
        return cookbooks
    }

    func createCookbook(name: String, movePersonalRecipes: Bool) async throws -> Cookbook {
        self.logger.info("Creating shared cookbook: \(name)")

        let body = CreateCookbookRequest(name: name, movePersonalRecipes: movePersonalRecipes)

        let cookbook: Cookbook = try await api.request(
            endpoint: "cookbooks",
            method: .post,
            body: body,
            authenticated: true
        )

        self.logger.info("Created shared cookbook: \(cookbook.id)")
        return cookbook
    }

    func deleteCookbook(id: Int) async throws {
        self.logger.info("Deleting cookbook: \(id)")

        try await self.api.requestVoid(
            endpoint: "cookbooks/\(id)",
            method: .delete,
            authenticated: true
        )

        self.logger.info("Deleted cookbook: \(id)")
    }

    func leaveCookbook(id: Int) async throws {
        self.logger.info("Leaving cookbook: \(id)")

        try await self.api.requestVoid(
            endpoint: "cookbooks/\(id)/leave",
            method: .post,
            authenticated: true
        )

        self.logger.info("Left cookbook: \(id)")
    }

    func createInvitation(cookbookId: Int) async throws -> CookbookInvitationResponse {
        self.logger.info("Creating invitation for cookbook: \(cookbookId)")

        let response: CookbookInvitationResponse = try await api.request(
            endpoint: "cookbooks/\(cookbookId)/invitations",
            method: .post,
            authenticated: true
        )

        self.logger.info("Created invitation: \(response.token)")
        return response
    }

    func fetchInvitationPreview(token: String) async throws -> CookbookInvitationPreview {
        self.logger.info("Fetching invitation preview")

        return try await self.api.request(
            endpoint: "invitations/\(token)",
            method: .get,
            authenticated: true
        )
    }

    func acceptInvitation(token: String) async throws -> CookbookInvitationAcceptResponse {
        self.logger.info("Accepting invitation")

        let response: CookbookInvitationAcceptResponse = try await api.request(
            endpoint: "invitations/\(token)/accept",
            method: .post,
            authenticated: true
        )

        self.logger.info("Accepted invitation for cookbook: \(response.cookbookId)")
        return response
    }

    func rejectInvitation(token: String) async throws {
        self.logger.info("Rejecting invitation")

        try await self.api.requestVoid(
            endpoint: "invitations/\(token)/reject",
            method: .post,
            authenticated: true
        )

        self.logger.info("Rejected invitation")
    }
}
