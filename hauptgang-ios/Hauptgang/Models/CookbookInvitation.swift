import Foundation

/// Preview of an invitation from GET /api/v1/invitations/:token
struct CookbookInvitationPreview: Codable {
    let cookbookName: String
    let inviterEmail: String
    let expiresAt: Date
    let status: String
}

/// Response from creating an invitation via POST /api/v1/cookbooks/:id/invitations
struct CookbookInvitationResponse: Codable {
    let id: Int
    let token: String
    let inviteUrl: String
    let expiresAt: Date
}

/// Response from accepting an invitation via POST /api/v1/invitations/:token/accept
struct CookbookInvitationAcceptResponse: Codable {
    let cookbookId: Int
    let cookbookName: String
}

/// Request body for creating a shared cookbook
struct CreateCookbookRequest: Codable {
    let name: String
    let movePersonalRecipes: Bool
}
