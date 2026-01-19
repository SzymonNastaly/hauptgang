# CORS configuration for mobile API
#
# Security note: We allow all origins ("*") for API routes. This is acceptable because:
# 1. The API uses Bearer token authentication, not cookies
# 2. Tokens are stored only in the mobile app (React Native/Expo), never in browsers
# 3. Without cookies, CORS restrictions provide no additional security - an attacker
#    would need the token regardless of origin, and tokens aren't accessible cross-origin
#
# If you add a web frontend that stores tokens in localStorage/sessionStorage,
# revisit this policy and restrict to specific origins.

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins "*"

    resource "/api/*",
      headers: :any,
      methods: [ :get, :post, :put, :patch, :delete, :options ]
  end
end
