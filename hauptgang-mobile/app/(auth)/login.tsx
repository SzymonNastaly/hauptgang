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

export default function LoginScreen() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const { setAuthenticated } = useAuth();

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

  return (
    <KeyboardAvoidingView
      behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
      className="flex-1 bg-white dark:bg-gray-900"
    >
      <View className="flex-1 justify-center px-8">
        <View className="mb-12">
          <Text className="text-4xl font-bold text-gray-900 dark:text-white text-center">
            Hauptgang
          </Text>
          <Text className="text-gray-500 dark:text-gray-400 text-center mt-2">
            Sign in to your account
          </Text>
        </View>

        <View className="space-y-4">
          <View>
            <Text className="text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
              Email
            </Text>
            <TextInput
              className="w-full px-4 py-3 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-white"
              placeholder="you@example.com"
              placeholderTextColor="#9CA3AF"
              value={email}
              onChangeText={setEmail}
              autoCapitalize="none"
              autoCorrect={false}
              keyboardType="email-address"
              textContentType="emailAddress"
            />
          </View>

          <View className="mt-4">
            <Text className="text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
              Password
            </Text>
            <TextInput
              className="w-full px-4 py-3 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-white"
              placeholder="Enter your password"
              placeholderTextColor="#9CA3AF"
              value={password}
              onChangeText={setPassword}
              secureTextEntry
              textContentType="password"
            />
          </View>

          {loginMutation.error && (
            <View className="mt-4 p-3 bg-red-50 dark:bg-red-900/20 rounded-lg">
              <Text className="text-red-600 dark:text-red-400 text-center">
                {loginMutation.error.message}
              </Text>
            </View>
          )}

          <TouchableOpacity
            className={`mt-6 py-4 rounded-lg ${
              loginMutation.isPending
                ? 'bg-orange-400'
                : 'bg-orange-500 active:bg-orange-600'
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
