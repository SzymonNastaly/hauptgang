import {
  View,
  Text,
  FlatList,
  RefreshControl,
  ActivityIndicator,
} from 'react-native';
import { router, Href } from 'expo-router';
import { useQuery } from '@tanstack/react-query';
import { getRecipes } from '@/lib/api';
import RecipeCard from '@/components/RecipeCard';
import { brand, brandDark } from '@/constants/Colors';
import { useColorScheme } from '@/components/useColorScheme';

export default function RecipeListScreen() {
  const colorScheme = useColorScheme();
  const tintColor = colorScheme === 'dark' ? brandDark.primary : brand.primary;

  const {
    data: recipes,
    isLoading,
    error,
    refetch,
    isRefetching,
  } = useQuery({
    queryKey: ['recipes'],
    queryFn: () => getRecipes(),
  });

  if (isLoading) {
    return (
      <View className="flex-1 items-center justify-center bg-surface-base dark:bg-gray-950">
        <ActivityIndicator size="large" color={tintColor} />
      </View>
    );
  }

  if (error) {
    return (
      <View className="flex-1 items-center justify-center bg-surface-base dark:bg-gray-950 px-4">
        <Text className="text-red-500 text-center mb-4">
          Failed to load recipes
        </Text>
        <Text className="text-text-tertiary dark:text-gray-400 text-center">
          {error.message}
        </Text>
      </View>
    );
  }

  if (!recipes || recipes.length === 0) {
    return (
      <View className="flex-1 items-center justify-center bg-surface-base dark:bg-gray-950 px-4">
        <Text className="text-text-secondary dark:text-gray-400 text-center text-lg">
          No recipes yet
        </Text>
        <Text className="text-text-tertiary dark:text-gray-500 text-center mt-2">
          Add recipes from the web app to see them here
        </Text>
      </View>
    );
  }

  return (
    <View className="flex-1 bg-surface-base dark:bg-gray-950">
      <FlatList
        data={recipes}
        keyExtractor={(item) => item.id.toString()}
        renderItem={({ item }) => (
          <RecipeCard
            recipe={item}
            onPress={() => router.push(`/${item.id}` as Href)}
          />
        )}
        contentContainerStyle={{ padding: 16 }}
        contentInsetAdjustmentBehavior="automatic"
        ItemSeparatorComponent={() => <View className="h-3" />}
        refreshControl={
          <RefreshControl
            refreshing={isRefetching}
            onRefresh={() => refetch()}
            tintColor={tintColor}
          />
        }
      />
    </View>
  );
}
