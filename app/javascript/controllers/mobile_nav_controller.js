import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="mobile-nav"
export default class extends Controller {
  static targets = ["drawer", "backdrop"];
  static values = {
    sidebarOpen: { type: Boolean, default: false }
  };

  // Toggle sidebar drawer visibility
  toggleSidebar() {
    this.sidebarOpenValue = !this.sidebarOpenValue;
  }

  // Close sidebar drawer
  closeSidebar() {
    this.sidebarOpenValue = false;
  }

  // When sidebarOpen value changes, update the UI
  sidebarOpenValueChanged() {
    if (this.hasDrawerTarget && this.hasBackdropTarget) {
      if (this.sidebarOpenValue) {
        // Show drawer in DOM (remove hidden class)
        this.drawerTarget.classList.remove("hidden");
        this.drawerTarget.classList.add("flex");

        // Force a reflow to ensure the transition works
        this.drawerTarget.offsetHeight;

        // Slide drawer in
        this.drawerTarget.classList.remove("-translate-x-full");
        this.drawerTarget.classList.add("translate-x-0");

        // Show backdrop
        this.backdropTarget.classList.remove("pointer-events-none", "opacity-0");
        this.backdropTarget.classList.add("pointer-events-auto", "opacity-100");

        // Prevent body scroll
        document.body.style.overflow = "hidden";
      } else {
        // Slide drawer out
        this.drawerTarget.classList.remove("translate-x-0");
        this.drawerTarget.classList.add("-translate-x-full");

        // Hide backdrop
        this.backdropTarget.classList.remove("pointer-events-auto", "opacity-100");
        this.backdropTarget.classList.add("pointer-events-none", "opacity-0");

        // After animation completes, hide drawer from DOM
        setTimeout(() => {
          if (!this.sidebarOpenValue) {
            this.drawerTarget.classList.remove("flex");
            this.drawerTarget.classList.add("hidden");
          }
        }, 300); // Match transition duration

        // Restore body scroll
        document.body.style.overflow = "";
      }
    }
  }

  // Scroll to top when navigating
  scrollToTop() {
    window.scrollTo({ top: 0, behavior: "smooth" });
  }
}
