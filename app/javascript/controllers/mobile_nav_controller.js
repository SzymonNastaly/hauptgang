import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="mobile-nav"
export default class extends Controller {
  static targets = ["searchBar", "searchIcon", "closeIcon"];
  static values = {
    searchOpen: { type: Boolean, default: false }
  };

  // Toggle search bar visibility
  toggleSearch() {
    this.searchOpenValue = !this.searchOpenValue;
  }

  // When searchOpen value changes, update the UI
  searchOpenValueChanged() {
    if (this.hasSearchBarTarget) {
      if (this.searchOpenValue) {
        this.searchBarTarget.classList.remove("hidden");
        this.searchBarTarget.classList.add("animate-in", "slide-in-from-top-2");
        // Focus the input
        const input = this.searchBarTarget.querySelector("input");
        if (input) {
          setTimeout(() => input.focus(), 100);
        }
      } else {
        this.searchBarTarget.classList.add("hidden");
        this.searchBarTarget.classList.remove("animate-in", "slide-in-from-top-2");
      }
    }
  }

  // Scroll to top when navigating
  scrollToTop() {
    window.scrollTo({ top: 0, behavior: "smooth" });
  }
}
