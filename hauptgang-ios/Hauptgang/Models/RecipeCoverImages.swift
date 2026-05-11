import Foundation

struct RecipeCoverImages: Codable {
    let thumb: String?
    let card: String?
    let hero: String?

    init(thumb: String? = nil, card: String? = nil, hero: String? = nil) {
        self.thumb = thumb
        self.card = card
        self.hero = hero
    }

    func thumbnailURL(fallback legacyURL: String?) -> String? {
        self.thumb ?? legacyURL ?? self.card ?? self.hero
    }

    func cardURL(fallback legacyURL: String?) -> String? {
        self.card ?? legacyURL ?? self.hero ?? self.thumb
    }

    func heroURL(fallback legacyURL: String?) -> String? {
        self.hero ?? legacyURL ?? self.card ?? self.thumb
    }
}
