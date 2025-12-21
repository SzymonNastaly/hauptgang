import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="view-switcher"
export default class extends Controller {
  static targets = ["gridView", "listView", "gridButton", "listButton"];
  static values = {
    mode: { type: String, default: "grid" }, // Default to grid view
  };

  connect() {
    // Load saved preference from localStorage
    const savedMode = localStorage.getItem("recipeViewMode");
    if (savedMode && (savedMode === "grid" || savedMode === "list")) {
      this.modeValue = savedMode;
    }

    // Apply the current mode
    this.applyMode();

    // Mark as initialized - now we can save preferences
    this.initialized = true;
  }

  // Action: Switch to grid view
  setGrid() {
    this.modeValue = "grid";
  }

  // Action: Switch to list view
  setList() {
    this.modeValue = "list";
  }

  // Apply the current view mode
  applyMode() {
    if (this.modeValue === "grid") {
      this.showGrid();
    } else {
      this.showList();
    }
    this.updateButtons();
  }

  // Show grid view, hide list view
  showGrid() {
    if (this.hasGridViewTarget) {
      this.gridViewTarget.classList.remove("hidden");

      // Trigger Masonry to fully recalculate layout after showing grid
      // Use requestAnimationFrame to ensure DOM has updated and is visible
      requestAnimationFrame(() => {
        const masonryElement = this.gridViewTarget.querySelector('[data-controller="masonry"]');
        if (masonryElement) {
          const masonryController = this.application.getControllerForElementAndIdentifier(
            masonryElement,
            "masonry"
          );
          if (masonryController) {
            // Call updateLayout() to recalculate widths and positions
            masonryController.updateLayout();
          }
        }
      });
    }
    if (this.hasListViewTarget) {
      this.listViewTarget.classList.add("hidden");
    }
  }

  // Show list view, hide grid view
  showList() {
    if (this.hasGridViewTarget) {
      this.gridViewTarget.classList.add("hidden");
    }
    if (this.hasListViewTarget) {
      this.listViewTarget.classList.remove("hidden");
    }
  }

  // Update button styles to reflect active state
  // Note: Updates ALL button sets (mobile + desktop)
  updateButtons() {
    if (!this.hasGridButtonTarget || !this.hasListButtonTarget) return;

    const activeClasses = [
      "bg-white",
      "dark:bg-gray-700",
      "shadow-sm",
      "text-gray-800",
      "dark:text-gray-100",
    ];
    const inactiveClasses = [
      "text-gray-400",
      "dark:text-gray-500",
      "hover:text-gray-600",
      "dark:hover:text-gray-400",
    ];

    // Update ALL grid buttons (plural targets)
    if (this.modeValue === "grid") {
      this.gridButtonTargets.forEach(btn => {
        btn.classList.add(...activeClasses);
        btn.classList.remove(...inactiveClasses);
      });
      this.listButtonTargets.forEach(btn => {
        btn.classList.remove(...activeClasses);
        btn.classList.add(...inactiveClasses);
      });
    } else {
      this.listButtonTargets.forEach(btn => {
        btn.classList.add(...activeClasses);
        btn.classList.remove(...inactiveClasses);
      });
      this.gridButtonTargets.forEach(btn => {
        btn.classList.remove(...activeClasses);
        btn.classList.add(...inactiveClasses);
      });
    }
  }

  // Save preference to localStorage
  savePreference() {
    localStorage.setItem("recipeViewMode", this.modeValue);
  }

  // Stimulus value changed callback - automatically called when modeValue changes
  modeValueChanged() {
    this.applyMode();

    // Only save if we're initialized (don't save during initial setup)
    if (this.initialized) {
      this.savePreference();
    }
  }
}
