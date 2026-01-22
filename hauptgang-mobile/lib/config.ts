import { Platform } from 'react-native';
import Constants from 'expo-constants';

/**
 * Get the API base URL based on the current platform and environment.
 *
 * Priority:
 * 1. EXPO_PUBLIC_API_BASE_URL environment variable (set in .env or app.config.js)
 * 2. Platform-specific defaults for development
 * 3. Production URL
 *
 * Development networking:
 * - Android Emulator: 10.0.2.2 maps to host localhost
 * - iOS Simulator: localhost works directly
 * - Physical device: requires EXPO_PUBLIC_API_BASE_URL with LAN IP or tunnel
 */
function getApiBaseUrl(): string {
  // Check for environment variable first (works for all platforms)
  const envUrl = process.env.EXPO_PUBLIC_API_BASE_URL;
  if (envUrl) {
    return envUrl;
  }

  const isEmulator = !Constants.expoConfig?.extra?.isDevice;

  if (__DEV__) {
    if (Platform.OS === 'android') {
      // Android emulator uses 10.0.2.2 to reach host's localhost
      return 'http://10.0.2.2:3000';
    }
    if (Platform.OS === 'ios' && isEmulator) {
      // iOS Simulator can reach localhost directly
      return 'http://localhost:3000';
    }
    // Physical device - requires EXPO_PUBLIC_API_BASE_URL to be set
    // Example: EXPO_PUBLIC_API_BASE_URL=http://192.168.1.100:3000
    return 'http://localhost:3000';
  }

  // Production URL
  return 'https://cook.hauptgang.app';
}

export const API_BASE_URL = getApiBaseUrl();
export const API_V1_URL = `${API_BASE_URL}/api/v1`;
