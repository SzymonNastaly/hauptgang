import {
  View,
  Text,
  ScrollView,
  ActivityIndicator,
  Linking,
  TouchableOpacity,
  Alert,
  Platform,
} from 'react-native';
import { Image } from 'expo-image';
import { useLocalSearchParams, Stack } from 'expo-router';
import { useQuery } from '@tanstack/react-query';
import FontAwesome from '@expo/vector-icons/FontAwesome';
import * as Haptics from 'expo-haptics';
import { getRecipe, ApiRequestError } from '@/lib/api';

/**
 * Validate that a URL uses a safe scheme (http or https only).
 */
function isSafeUrl(url: string): boolean {
  try {
    const parsed = new URL(url);
    return parsed.protocol === 'http:' || parsed.protocol === 'https:';
  } catch {
    return false;
  }
}

/**
 * Safely open a URL after validating the scheme.
 */
async function openSafeUrl(url: string) {
  if (Platform.OS === 'ios') {
    await Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
  }
  if (isSafeUrl(url)) {
    Linking.openURL(url);
  } else {
    Alert.alert('Invalid URL', 'This link cannot be opened.');
  }
}

export default function RecipeDetailScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const recipeId = parseInt(id, 10);

  const {
    data: recipe,
    isLoading,
    error,
  } = useQuery({
    queryKey: ['recipe', recipeId],
    queryFn: () => getRecipe(recipeId),
    enabled: !isNaN(recipeId),
  });

  const formatTime = (minutes: number | null | undefined) => {
    if (!minutes) return null;
    if (minutes < 60) return `${minutes} min`;
    const hours = Math.floor(minutes / 60);
    const mins = minutes % 60;
    return mins > 0 ? `${hours}h ${mins}m` : `${hours}h`;
  };

  // Determine if error is a 404 (recipe not found)
  const isNotFound =
    isNaN(recipeId) ||
    (error instanceof ApiRequestError && error.statusCode === 404);

  if (isLoading) {
    return (
      <>
        <Stack.Screen options={{ title: 'Loading...' }} />
        <View className="flex-1 items-center justify-center bg-gray-50 dark:bg-gray-900">
          <ActivityIndicator size="large" color="#f97316" />
        </View>
      </>
    );
  }

  if (isNotFound) {
    return (
      <>
        <Stack.Screen options={{ title: 'Not Found' }} />
        <View className="flex-1 items-center justify-center bg-gray-50 dark:bg-gray-900 px-4">
          <FontAwesome name="question-circle" size={48} color="#9CA3AF" />
          <Text className="text-gray-500 dark:text-gray-400 text-center text-lg mt-4">
            Recipe not found
          </Text>
        </View>
      </>
    );
  }

  if (error || !recipe) {
    return (
      <>
        <Stack.Screen options={{ title: 'Error' }} />
        <View className="flex-1 items-center justify-center bg-gray-50 dark:bg-gray-900 px-4">
          <Text className="text-red-500 text-center">
            Failed to load recipe
          </Text>
        </View>
      </>
    );
  }

  return (
    <>
      <Stack.Screen
        options={{
          title: recipe.name,
          headerBackTitle: 'Recipes',
        }}
      />
      <ScrollView className="flex-1 bg-gray-50 dark:bg-gray-900" contentInsetAdjustmentBehavior="automatic">
        {recipe.cover_image_url ? (
          <Image
            source={{ uri: recipe.cover_image_url }}
            className="w-full h-64"
            contentFit="cover"
          />
        ) : (
          <View className="w-full h-48 bg-gray-200 dark:bg-gray-700 items-center justify-center">
            <FontAwesome name="cutlery" size={48} color="#9CA3AF" />
          </View>
        )}

        <View className="p-4">
          {/* Title and favorite */}
          <View className="flex-row items-start justify-between mb-4">
            <Text className="text-2xl font-bold text-gray-900 dark:text-white flex-1 mr-2">
              {recipe.name}
            </Text>
            {recipe.favorite && (
              <FontAwesome name="heart" size={24} color="#f97316" />
            )}
          </View>

          {/* Time and servings info */}
          <View className="flex-row flex-wrap gap-4 mb-6">
            {recipe.prep_time && (
              <View className="flex-row items-center">
                <FontAwesome name="hourglass-start" size={14} color="#6B7280" />
                <Text className="text-gray-600 dark:text-gray-400 ml-2">
                  Prep: {formatTime(recipe.prep_time)}
                </Text>
              </View>
            )}
            {recipe.cook_time && (
              <View className="flex-row items-center">
                <FontAwesome name="fire" size={14} color="#6B7280" />
                <Text className="text-gray-600 dark:text-gray-400 ml-2">
                  Cook: {formatTime(recipe.cook_time)}
                </Text>
              </View>
            )}
            {recipe.servings && (
              <View className="flex-row items-center">
                <FontAwesome name="users" size={14} color="#6B7280" />
                <Text className="text-gray-600 dark:text-gray-400 ml-2">
                  {recipe.servings} servings
                </Text>
              </View>
            )}
          </View>

          {/* Tags */}
          {recipe.tags.length > 0 && (
            <View className="flex-row flex-wrap gap-2 mb-6">
              {recipe.tags.map((tag) => (
                <View
                  key={tag.id}
                  className="bg-orange-100 dark:bg-orange-900/30 px-3 py-1 rounded-full"
                >
                  <Text className="text-orange-700 dark:text-orange-300 text-sm">
                    {tag.name}
                  </Text>
                </View>
              ))}
            </View>
          )}

          {/* Ingredients */}
          <View className="mb-6">
            <Text className="text-xl font-semibold text-gray-900 dark:text-white mb-3">
              Ingredients
            </Text>
            <View className="bg-white dark:bg-gray-800 rounded-xl p-4">
              {recipe.ingredients.map((ingredient, index) => (
                <View
                  key={index}
                  className={`flex-row items-start ${
                    index > 0 ? 'mt-2 pt-2 border-t border-gray-100 dark:border-gray-700' : ''
                  }`}
                >
                  <View className="w-2 h-2 rounded-full bg-orange-500 mt-1.5 mr-3" />
                  <Text className="text-gray-700 dark:text-gray-300 flex-1">
                    {ingredient}
                  </Text>
                </View>
              ))}
            </View>
          </View>

          {/* Instructions */}
          {recipe.instructions && (
            <View className="mb-6">
              <Text className="text-xl font-semibold text-gray-900 dark:text-white mb-3">
                Instructions
              </Text>
              <View className="bg-white dark:bg-gray-800 rounded-xl p-4">
                <Text className="text-gray-700 dark:text-gray-300 leading-6">
                  {recipe.instructions}
                </Text>
              </View>
            </View>
          )}

          {/* Notes */}
          {recipe.notes && (
            <View className="mb-6">
              <Text className="text-xl font-semibold text-gray-900 dark:text-white mb-3">
                Notes
              </Text>
              <View className="bg-yellow-50 dark:bg-yellow-900/20 rounded-xl p-4">
                <Text className="text-gray-700 dark:text-gray-300">
                  {recipe.notes}
                </Text>
              </View>
            </View>
          )}

          {/* Source URL */}
          {recipe.source_url && (
            <TouchableOpacity
              onPress={() => openSafeUrl(recipe.source_url!)}
              className="mb-6"
            >
              <View className="flex-row items-center">
                <FontAwesome name="external-link" size={14} color="#f97316" />
                <Text className="text-orange-500 ml-2 underline">
                  View original recipe
                </Text>
              </View>
            </TouchableOpacity>
          )}
        </View>
      </ScrollView>
    </>
  );
}
