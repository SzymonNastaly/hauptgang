import * as SecureStore from 'expo-secure-store';

const TOKEN_KEY = 'auth_token';
const TOKEN_EXPIRY_KEY = 'auth_token_expiry';

/**
 * Store auth token securely using SecureStore.
 */
export async function setToken(token: string, expiresAt: string): Promise<void> {
  await SecureStore.setItemAsync(TOKEN_KEY, token);
  await SecureStore.setItemAsync(TOKEN_EXPIRY_KEY, expiresAt);
}

/**
 * Get stored auth token.
 * Returns null if no token or if token is expired.
 */
export async function getToken(): Promise<string | null> {
  const token = await SecureStore.getItemAsync(TOKEN_KEY);
  const expiresAt = await SecureStore.getItemAsync(TOKEN_EXPIRY_KEY);

  if (!token || !expiresAt) {
    return null;
  }

  // Check if token is expired
  if (new Date(expiresAt) < new Date()) {
    await clearToken();
    return null;
  }

  return token;
}

/**
 * Clear stored auth token (logout).
 */
export async function clearToken(): Promise<void> {
  await SecureStore.deleteItemAsync(TOKEN_KEY);
  await SecureStore.deleteItemAsync(TOKEN_EXPIRY_KEY);
}

/**
 * Check if user is authenticated (has valid token).
 */
export async function isAuthenticated(): Promise<boolean> {
  const token = await getToken();
  return token !== null;
}
