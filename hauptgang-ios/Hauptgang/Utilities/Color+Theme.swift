import SwiftUI

extension Color {
    // MARK: - Brand Colors

    /// Primary warm brown - #8B5E34
    static let hauptgangPrimary = Color(red: 139/255, green: 94/255, blue: 52/255)

    /// Primary hover state - #7A5230
    static let hauptgangPrimaryHover = Color(red: 122/255, green: 82/255, blue: 48/255)

    // MARK: - Backgrounds

    /// Off-white background - #FDFBF7
    static let hauptgangBackground = Color(red: 253/255, green: 251/255, blue: 247/255)

    /// Card background - #FFFFFF
    static let hauptgangCard = Color.white

    /// Raised surface background - #F5F2EA (for cards without images, sidebars)
    static let hauptgangSurfaceRaised = Color(red: 245/255, green: 242/255, blue: 234/255)

    /// Subtle border - #E5E0D5
    static let hauptgangBorderSubtle = Color(red: 229/255, green: 224/255, blue: 213/255)

    // MARK: - Text Colors

    /// Primary text - #1F1F1F
    static let hauptgangTextPrimary = Color(red: 31/255, green: 31/255, blue: 31/255)

    /// Secondary text - #6B6B6B
    static let hauptgangTextSecondary = Color(red: 107/255, green: 107/255, blue: 107/255)

    /// Muted text - #9CA3AF
    static let hauptgangTextMuted = Color(red: 156/255, green: 163/255, blue: 175/255)

    // MARK: - Semantic Colors

    /// Error red - #DC2626
    static let hauptgangError = Color(red: 220/255, green: 38/255, blue: 38/255)

    /// Success green - #16A34A
    static let hauptgangSuccess = Color(red: 22/255, green: 163/255, blue: 74/255)

    /// Amber for favorites on dark backgrounds - #FBB424 (Tailwind amber-400)
    static let hauptgangAmber = Color(red: 251/255, green: 191/255, blue: 36/255)
}

// MARK: - Design Tokens

enum Theme {
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }

    enum CornerRadius {
        static let sm: CGFloat = 4
        static let md: CGFloat = 8
        static let lg: CGFloat = 12
        static let xl: CGFloat = 16
    }

    enum Shadow {
        static let sm = ShadowStyle(color: .black.opacity(0.05), radius: 2, y: 1)
        static let md = ShadowStyle(color: .black.opacity(0.1), radius: 4, y: 2)
    }

    struct ShadowStyle {
        let color: Color
        let radius: CGFloat
        let y: CGFloat
    }
}
