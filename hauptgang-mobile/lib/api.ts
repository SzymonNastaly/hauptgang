import { router } from 'expo-router';
import { API_V1_URL } from './config';
import { getToken, clearToken, setToken } from './auth';
import type { components, operations } from './api-types';

// Re-export types for convenience
export type User = components['schemas']['User'];
export type RecipeListItem = components['schemas']['RecipeListItem'];
export type RecipeDetail = components['schemas']['RecipeDetail'];
export type Tag = components['schemas']['Tag'];
export type LoginRequest = components['schemas']['LoginRequest'];
export type LoginResponse = components['schemas']['LoginResponse'];
export type ApiError = components['schemas']['Error'];

/**
 * Custom error class that includes HTTP status code.
 */
export class ApiRequestError extends Error {
  constructor(
    message: string,
    public statusCode?: number
  ) {
    super(message);
    this.name = 'ApiRequestError';
  }
}

/**
 * Handle 401 responses globally - clear token and redirect to login.
 */
async function handleUnauthorized(): Promise<void> {
  await clearToken();
  router.replace('/(auth)/login');
}

/**
 * Safely parse JSON from a response, handling non-JSON responses gracefully.
 */
async function safeJsonParse<T>(response: Response): Promise<T | null> {
  const contentType = response.headers.get('Content-Type') || '';
  if (!contentType.includes('application/json')) {
    return null;
  }

  try {
    return await response.json();
  } catch {
    return null;
  }
}

/**
 * Make an authenticated API request.
 */
async function apiRequest<T>(
  path: string,
  options: RequestInit = {}
): Promise<T> {
  const token = await getToken();

  const headers: HeadersInit = {
    'Content-Type': 'application/json',
    ...options.headers,
  };

  if (token) {
    (headers as Record<string, string>)['Authorization'] = `Bearer ${token}`;
  }

  let response: Response;
  try {
    response = await fetch(`${API_V1_URL}${path}`, {
      ...options,
      headers,
    });
  } catch (error) {
    throw new ApiRequestError('Network request failed');
  }

  if (response.status === 401) {
    await handleUnauthorized();
    throw new ApiRequestError('Unauthorized', 401);
  }

  if (!response.ok) {
    const errorData = await safeJsonParse<ApiError>(response);
    const message = errorData?.error || `Request failed with status ${response.status}`;
    throw new ApiRequestError(message, response.status);
  }

  const data = await safeJsonParse<T>(response);
  if (data === null) {
    throw new ApiRequestError('Invalid response from server');
  }

  return data;
}

/**
 * Login and store the token.
 */
export async function login(
  email: string,
  password: string,
  deviceName?: string
): Promise<LoginResponse> {
  const body: LoginRequest = { email, password };
  if (deviceName) {
    body.device_name = deviceName;
  }

  let response: Response;
  try {
    response = await fetch(`${API_V1_URL}/session`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    });
  } catch (error) {
    throw new ApiRequestError('Network request failed');
  }

  if (!response.ok) {
    const errorData = await safeJsonParse<ApiError>(response);
    const message = errorData?.error || 'Login failed';
    throw new ApiRequestError(message, response.status);
  }

  const data = await safeJsonParse<LoginResponse>(response);
  if (data === null || !data.token) {
    throw new ApiRequestError('Invalid response from server');
  }

  await setToken(data.token, data.expires_at);
  return data;
}

/**
 * Logout and clear the token.
 */
export async function logout(): Promise<void> {
  try {
    await apiRequest('/session', { method: 'DELETE' });
  } catch {
    // Ignore errors - we want to clear the token anyway
  }
  await clearToken();
  router.replace('/(auth)/login');
}

/**
 * Get all recipes for the authenticated user.
 */
export async function getRecipes(
  favorites?: boolean
): Promise<RecipeListItem[]> {
  const params = favorites ? '?favorites=true' : '';
  return apiRequest<RecipeListItem[]>(`/recipes${params}`);
}

/**
 * Get a single recipe by ID.
 */
export async function getRecipe(id: number): Promise<RecipeDetail> {
  return apiRequest<RecipeDetail>(`/recipes/${id}`);
}

/**
 * Add a recipe to favorites.
 */
export async function addFavorite(
  recipeId: number
): Promise<{ id: number; favorite: boolean }> {
  return apiRequest(`/recipes/${recipeId}/favorite`, { method: 'PUT' });
}

/**
 * Remove a recipe from favorites.
 */
export async function removeFavorite(
  recipeId: number
): Promise<{ id: number; favorite: boolean }> {
  return apiRequest(`/recipes/${recipeId}/favorite`, { method: 'DELETE' });
}
