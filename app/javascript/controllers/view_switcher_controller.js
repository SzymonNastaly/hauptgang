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
    console.log("connect() - Loaded from localStorage:", savedMode);
    if (savedMode && (savedMode === "grid" || savedMode === "list")) {
      this.modeValue = savedMode;
      console.log("connect() - Set modeValue to:", this.modeValue);
    }

    // Apply the current mode
    this.applyMode();
    console.log("connect() - Final mode after applyMode:", this.modeValue);

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

    if (this.modeValue === "grid") {
      this.gridButtonTarget.classList.add(...activeClasses);
      this.gridButtonTarget.classList.remove(...inactiveClasses);
      this.listButtonTarget.classList.remove(...activeClasses);
      this.listButtonTarget.classList.add(...inactiveClasses);
    } else {
      this.listButtonTarget.classList.add(...activeClasses);
      this.listButtonTarget.classList.remove(...inactiveClasses);
      this.gridButtonTarget.classList.remove(...activeClasses);
      this.gridButtonTarget.classList.add(...inactiveClasses);
    }
  }

  // Save preference to localStorage
  savePreference() {
    localStorage.setItem("recipeViewMode", this.modeValue);
  }

  // Stimulus value changed callback - automatically called when modeValue changes
  modeValueChanged() {
    console.log("modeValueChanged called, new mode:", this.modeValue);
    this.applyMode();

    // Only save if we're initialized (don't save during initial setup)
    if (this.initialized) {
      this.savePreference();
      console.log("Saved to localStorage:", localStorage.getItem("recipeViewMode"));
    } else {
      console.log("Skipped save (not initialized yet)");
    }
  }
}
