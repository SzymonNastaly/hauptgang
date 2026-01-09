import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="logout"
// Clears the service worker cache before logout to prevent
// cached recipes from persisting across user sessions
export default class extends Controller {
  clearCache() {
    // Send message to service worker to clear all cached content
    if ("serviceWorker" in navigator && navigator.serviceWorker.controller) {
      navigator.serviceWorker.controller.postMessage({ type: "CLEAR_CACHE" });
    }
    // Form submission continues normally after this
  }
}
