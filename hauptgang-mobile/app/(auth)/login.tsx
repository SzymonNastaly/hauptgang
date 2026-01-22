import { useState } from 'react';
import {
  View,
  Text,
  TextInput,
  TouchableOpacity,
  KeyboardAvoidingView,
  Platform,
  ActivityIndicator,
} from 'react-native';
import { router } from 'expo-router';
import { useMutation } from '@tanstack/react-query';
import { login } from '@/lib/api';
import { useAuth } from '@/lib/AuthContext';
import { brand, brandDark } from '@/constants/Colors';
import { useColorScheme } from '@/components/useColorScheme';

export default function LoginScreen() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const { setAuthenticated } = useAuth();
  const colorScheme = useColorScheme();

  const loginMutation = useMutation({
    mutationFn: () => login(email, password, 'Hauptgang Mobile'),
    onSuccess: () => {
      setAuthenticated(true);
      router.replace('/(tabs)');
    },
  });

  const handleLogin = () => {
    if (!email.trim() || !password.trim()) {
      return;
    }
    loginMutation.mutate();
  };

  const tintColor = colorScheme === 'dark' ? brandDark.primary : brand.primary;
  const placeholderColor = colorScheme === 'dark' ? '#6B7280' : '#9B9B9B';

  return (
    <KeyboardAvoidingView
      behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
      className="flex-1 bg-surface-base dark:bg-gray-950"
    >
      <View className="flex-1 justify-center px-8">
        <View className="mb-12">
          <Text className="text-4xl font-bold text-text-primary dark:text-gray-100 text-center font-serif">
            Hauptgang
          </Text>
          <Text className="text-text-secondary dark:text-gray-400 text-center mt-2">
            Sign in to your account
          </Text>
        </View>

        <View className="space-y-4">
          <View>
            <Text className="text-sm font-medium text-text-secondary dark:text-gray-300 mb-2">
              Email
            </Text>
            <TextInput
              className="w-full px-4 py-3 border border-border-subtle dark:border-gray-700 rounded-lg bg-surface-overlay dark:bg-gray-800 text-text-primary dark:text-gray-100"
              placeholder="you@example.com"
              placeholderTextColor={placeholderColor}
              value={email}
              onChangeText={setEmail}
              autoCapitalize="none"
              autoCorrect={false}
              keyboardType="email-address"
              textContentType="emailAddress"
            />
          </View>

          <View className="mt-4">
            <Text className="text-sm font-medium text-text-secondary dark:text-gray-300 mb-2">
              Password
            </Text>
            <TextInput
              className="w-full px-4 py-3 border border-border-subtle dark:border-gray-700 rounded-lg bg-surface-overlay dark:bg-gray-800 text-text-primary dark:text-gray-100"
              placeholder="Enter your password"
              placeholderTextColor={placeholderColor}
              value={password}
              onChangeText={setPassword}
              secureTextEntry
              textContentType="password"
            />
          </View>

          {loginMutation.error && (
            <View className="mt-4 p-3 bg-red-50 dark:bg-red-900/20 rounded-lg border border-red-200 dark:border-red-800">
              <Text className="text-red-600 dark:text-red-400 text-center">
                {loginMutation.error.message}
              </Text>
            </View>
          )}

          <TouchableOpacity
            className={`mt-6 py-4 rounded-lg ${
              loginMutation.isPending
                ? 'bg-brand-primary-light dark:bg-amber-600'
                : 'bg-brand-primary dark:bg-amber-700 active:bg-brand-primary-dark dark:active:bg-amber-800'
            }`}
            onPress={handleLogin}
            disabled={loginMutation.isPending}
          >
            {loginMutation.isPending ? (
              <ActivityIndicator color="white" />
            ) : (
              <Text className="text-white text-center font-semibold text-lg">
                Sign In
              </Text>
            )}
          </TouchableOpacity>
        </View>
      </View>
    </KeyboardAvoidingView>
  );
}
