// Service Worker for Hauptgang PWA
// Implements cache-first strategy for offline recipe access

const CACHE_VERSION = "v6"
const CACHE_NAME = `hauptgang-${CACHE_VERSION}`

// Static assets to cache on install
// These are the core files needed for the app shell
const STATIC_ASSETS = [
  "/",
  "/manifest.json"
]

// Install event: Cache static assets
// This runs once when the service worker is first registered
self.addEventListener("install", (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => {
      return cache.addAll(STATIC_ASSETS)
    })
  )
  // Take control immediately without waiting for page reload
  self.skipWaiting()
})

// Activate event: Clean up old caches
// This runs when a new service worker takes over
self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys().then((keys) => {
      return Promise.all(
        keys
          .filter((key) => key.startsWith("hauptgang-") && key !== CACHE_NAME)
          .map((key) => caches.delete(key))
      )
    })
  )
  // Take control of all pages immediately
  self.clients.claim()
})

// Fetch event: Stale-while-revalidate with conditional requests (ETag)
// Return cache immediately for fast loads, use ETag to check if update needed
// If server returns 304 Not Modified, cache is still valid (saves bandwidth)
// If server returns 200, update cache for next visit
self.addEventListener("fetch", (event) => {
  const request = event.request

  // Only handle GET requests (can't cache POST, PATCH, DELETE)
  if (request.method !== "GET") return

  // Skip image requests (user chose not to cache images)
  if (request.destination === "image") return

  // Skip requests to external domains (like esm.sh for masonry)
  const url = new URL(request.url)
  if (url.origin !== self.location.origin) return

  // Use URL string for cache matching (ignores headers that differ on reload)
  const cacheKey = request.url

  event.respondWith(
    caches.match(cacheKey).then((cachedResponse) => {
      // Build fetch options with conditional headers (Safari-compatible)
      const fetchOptions = {
        method: request.method,
        headers: new Headers(request.headers),
        credentials: request.credentials,
        cache: "no-cache"  // Ensure we actually hit the server
      }

      // Add conditional headers if we have a cached response
      if (cachedResponse) {
        const etag = cachedResponse.headers.get("ETag")
        const lastModified = cachedResponse.headers.get("Last-Modified")
        if (etag) fetchOptions.headers.set("If-None-Match", etag)
        if (lastModified) fetchOptions.headers.set("If-Modified-Since", lastModified)
      }

      // Background fetch with conditional headers
      // Use URL string + options instead of new Request() for Safari compatibility
      const fetchPromise = fetch(request.url, fetchOptions)
        .then((networkResponse) => {
          // 304 Not Modified = cache is still valid, no update needed
          if (networkResponse.status === 304) {
            return cachedResponse
          }

          // 200 OK = content changed, update cache for next visit
          if (networkResponse.status === 200) {
            const responseToCache = networkResponse.clone()
            caches.open(CACHE_NAME).then((cache) => {
              cache.put(cacheKey, responseToCache)
            })
          }
          return networkResponse
        })
        .catch(() => {
          // Network failed - return null, we'll use cache or show error
          return null
        })

      // Return cached response immediately if available (fast!)
      if (cachedResponse) {
        return cachedResponse
      }

      // No cache - must wait for network
      return fetchPromise.then((networkResponse) => {
        if (networkResponse) {
          return networkResponse
        }
        // Network failed and nothing in cache
        return new Response("Offline - content not available", {
          status: 503,
          statusText: "Service Unavailable"
        })
      })
    })
  )
})

// Message event: Handle messages from the app
self.addEventListener("message", (event) => {
  if (!event.data) return

  // Handle per-recipe cache invalidation
  // When a recipe is updated, the app sends this message to delete just that URL
  if (event.data.type === "INVALIDATE_RECIPE") {
    const url = event.data.url
    if (url) {
      caches.open(CACHE_NAME).then((cache) => {
        cache.delete(url)
      })
    }
    return
  }

  // Handle prefetch requests from the prefetch controller
  // The controller sends a list of recipe URLs to cache
  if (event.data.type === "PREFETCH_RECIPES") {
    const urls = event.data.urls || []

    caches.open(CACHE_NAME).then((cache) => {
      urls.forEach((url) => {
        // Check if already cached before fetching
        cache.match(url).then((cached) => {
          if (!cached) {
            fetch(url)
              .then((response) => {
                if (response && response.status === 200) {
                  cache.put(url, response)
                }
              })
              .catch(() => {
                // Silently fail - will try again on next visit
              })
          }
        })
      })
    })
  }
})
