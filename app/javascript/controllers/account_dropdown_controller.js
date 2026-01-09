import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="account-dropdown"
// Manages the account dropdown menu in the sidebar footer
export default class extends Controller {
  static targets = ["menu"];
  static values = {
    open: { type: Boolean, default: false }
  };

  // Toggle dropdown visibility
  toggle() {
    this.openValue = !this.openValue;
  }

  // Close the dropdown
  close() {
    this.openValue = false;
  }

  // Close when clicking outside the dropdown
  clickOutside(event) {
    if (!this.element.contains(event.target)) {
      this.close();
    }
  }

  // Reactive callback: runs automatically when openValue changes
  openValueChanged() {
    if (this.hasMenuTarget) {
      if (this.openValue) {
        this.menuTarget.classList.remove("hidden");
      } else {
        this.menuTarget.classList.add("hidden");
      }
    }
  }
}
