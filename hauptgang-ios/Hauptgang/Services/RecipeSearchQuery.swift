import Foundation

enum RecipeSearchQuery {
    private static let synonymMap: [String: [String]] = [
        "scallion": ["green onion", "spring onion"],
        "chili": ["chile"],
        "chile": ["chili"],
        "coriander": ["cilantro"],
        "cilantro": ["coriander"],
        "garbanzo": ["chickpea"],
        "chickpea": ["garbanzo"],
        "aubergine": ["eggplant"],
        "eggplant": ["aubergine"],
        "courgette": ["zucchini"],
        "zucchini": ["courgette"],
        "capsicum": ["bell pepper"],
        "minced": ["ground"],
        "ground": ["minced"],
        "prawn": ["shrimp"],
        "shrimp": ["prawn"],
        "rocket": ["arugula"],
        "arugula": ["rocket"],
        "yogurt": ["yoghurt"],
        "yoghurt": ["yogurt"],
        "ketchup": ["catsup"],
        "bicarbonate": ["baking soda"],
        "soda": ["bicarbonate", "bicarb"]
    ]

    static func normalizedTokens(from raw: String) -> [String] {
        let normalized = raw
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()

        return normalized
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
    }

    static func expandedTokenVariants(from raw: String) -> [[[String]]] {
        let tokens = normalizedTokens(from: raw)
        guard !tokens.isEmpty else { return [] }

        return tokens.map { token in
            var variants: [[String]] = [[token]]

            if let synonyms = synonymMap[token] {
                let synonymTokens = synonyms.map { normalizedTokens(from: $0) }.filter { !$0.isEmpty }
                variants.append(contentsOf: synonymTokens)
            }

            return variants
        }
    }

    static func buildFTSQuery(from raw: String) -> String? {
        let groups = expandedTokenVariants(from: raw)
        guard !groups.isEmpty else { return nil }

        let clauses = groups.map { group in
            let variants = group.map { variant in
                if variant.count == 1 {
                    return "\(variant[0])*"
                }
                let terms = variant.map { "\($0)*" }
                return "(" + terms.joined(separator: " AND ") + ")"
            }
            return variants.joined(separator: " OR ")
        }

        return clauses.map { "(\($0))" }.joined(separator: " AND ")
    }
}
