// Hauptgang Design System Colors

export const brand = {
  primary: "#8B5E34",
  primaryDark: "#6B4826",
  primaryLight: "#A57A52",
};

export const brandDark = {
  primary: "#B45309", // amber-700
  primaryHover: "#92400E", // amber-800
  accent: "#F59E0B", // amber-500
  focusRing: "#D97706", // amber-600
};

export default {
  light: {
    text: "#1F1F1F",
    textSecondary: "#6B6B6B",
    textTertiary: "#9B9B9B",
    background: "#FDFBF7",
    surface: "#FFFFFF",
    surfaceRaised: "#F5F2EA",
    tint: brand.primary,
    borderSubtle: "#E5E0D5",
    borderMedium: "#D5CABF",
    tabIconDefault: "#9B9B9B",
    tabIconSelected: brand.primary,
  },
  dark: {
    text: "#F3F4F6", // gray-100
    textSecondary: "#9CA3AF", // gray-400
    textTertiary: "#6B7280", // gray-500
    background: "#030712", // gray-950
    surface: "#1F2937", // gray-800
    surfaceRaised: "#111827", // gray-900
    tint: brandDark.primary,
    borderSubtle: "#374151", // gray-700
    borderMedium: "#1F2937", // gray-800
    tabIconDefault: "#6B7280",
    tabIconSelected: brandDark.primary,
  },
};
