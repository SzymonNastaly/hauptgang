/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    "./app/**/*.{js,jsx,ts,tsx}",
    "./components/**/*.{js,jsx,ts,tsx}",
  ],
  presets: [require("nativewind/preset")],
  theme: {
    extend: {
      colors: {
        brand: {
          primary: "#8B5E34",
          "primary-dark": "#6B4826",
          "primary-light": "#A57A52",
        },
        surface: {
          base: "#FDFBF7",
          raised: "#F5F2EA",
          overlay: "#FFFFFF",
        },
        border: {
          subtle: "#E5E0D5",
          medium: "#D5CABF",
        },
        text: {
          primary: "#1F1F1F",
          secondary: "#6B6B6B",
          tertiary: "#9B9B9B",
        },
      },
      fontFamily: {
        // iOS: System fonts (SF Pro / New York)
        // Android: Roboto / Noto Serif
        sans: ["System", "Roboto", "ui-sans-serif", "sans-serif"],
        serif: ["ui-serif", "Georgia", "serif"],
      },
    },
  },
  plugins: [],
};
