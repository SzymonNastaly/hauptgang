import { Controller } from "@hotwired/stimulus"

// Cache invalidation controller: Tells the service worker to delete specific URLs from cache
// Usage: <div data-controller="cache-invalidate" data-cache-invalidate-url-value="/recipes/123">
//
// This is triggered via flash after recipe create/update/destroy.
// The SW will delete the recipe URL AND the /recipes index (since titles appear there too).
export default class extends Controller {
  static values = { url: String }

  connect() {
    this.invalidateCache()
  }

  invalidateCache() {
    // Only run if service workers are supported and we have a URL
    if (!("serviceWorker" in navigator) || !this.urlValue) return

    // Wait for service worker to be ready
    navigator.serviceWorker.ready.then((registration) => {
      if (registration.active) {
        // Invalidate the specific recipe
        registration.active.postMessage({
          type: "INVALIDATE_RECIPE",
          url: this.urlValue
        })

        // Also invalidate the edit page
        registration.active.postMessage({
          type: "INVALIDATE_RECIPE",
          url: `${this.urlValue}/edit`
        })

        // Also invalidate the recipes index (titles appear there too)
        registration.active.postMessage({
          type: "INVALIDATE_RECIPE",
          url: `${window.location.origin}/recipes`
        })
      }
    })
  }
}
