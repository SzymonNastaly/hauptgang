import Foundation

/// Represents a cookbook from GET /api/v1/cookbooks
struct Cookbook: Codable, Identifiable, Sendable {
    let id: Int
    let name: String
    let personal: Bool
    let recipeCount: Int
    let members: [CookbookMember]
}

/// A member of a cookbook
struct CookbookMember: Codable, Identifiable, Sendable {
    let id: Int
    let email: String
    let role: String
}
