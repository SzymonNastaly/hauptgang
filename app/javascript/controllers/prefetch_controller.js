import { Controller } from "@hotwired/stimulus"

// Prefetch controller: Triggers caching of all recipe URLs in the service worker
// Usage: <div data-controller="prefetch" data-prefetch-urls-value='["/recipes/1", "/recipes/2"]'>
//
// This controller waits for the service worker to be ready, then sends all URLs
// to be cached. The service worker will skip URLs that are already cached.
export default class extends Controller {
  static values = { urls: Array }

  connect() {
    this.prefetchRecipes()
  }

  prefetchRecipes() {
    // Only run if service workers are supported
    if (!("serviceWorker" in navigator)) return

    // Wait for service worker to be ready
    navigator.serviceWorker.ready.then((registration) => {
      // Send prefetch message to service worker
      if (registration.active) {
        registration.active.postMessage({
          type: "PREFETCH_RECIPES",
          urls: this.urlsValue
        })
      }
    })
  }
}
