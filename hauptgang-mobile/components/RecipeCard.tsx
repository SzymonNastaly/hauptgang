import { View, Text, TouchableOpacity, Platform } from 'react-native';
import { Image } from 'expo-image';
import FontAwesome from '@expo/vector-icons/FontAwesome';
import * as Haptics from 'expo-haptics';
import type { RecipeListItem } from '@/lib/api';
import { brand, brandDark } from '@/constants/Colors';
import { useColorScheme } from '@/components/useColorScheme';

interface RecipeCardProps {
  recipe: RecipeListItem;
  onPress: () => void;
}

export default function RecipeCard({ recipe, onPress }: RecipeCardProps) {
  const colorScheme = useColorScheme();
  const accentColor = colorScheme === 'dark' ? brandDark.primary : brand.primary;
  const iconColor = colorScheme === 'dark' ? '#6B7280' : '#9B9B9B';

  const handlePress = () => {
    if (Platform.OS === 'ios') {
      Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    }
    onPress();
  };

  const formatTime = (minutes: number | null | undefined) => {
    if (!minutes) return null;
    if (minutes < 60) return `${minutes}m`;
    const hours = Math.floor(minutes / 60);
    const mins = minutes % 60;
    return mins > 0 ? `${hours}h ${mins}m` : `${hours}h`;
  };

  const totalTime =
    (recipe.prep_time || 0) + (recipe.cook_time || 0) || null;

  return (
    <TouchableOpacity
      onPress={handlePress}
      activeOpacity={0.7}
      className="bg-surface-overlay dark:bg-gray-800 rounded-xl overflow-hidden shadow-sm border border-border-subtle dark:border-gray-700"
    >
      {recipe.cover_image_url ? (
        <Image
          source={{ uri: recipe.cover_image_url }}
          className="w-full h-40"
          contentFit="cover"
        />
      ) : (
        <View className="w-full h-40 bg-surface-raised dark:bg-gray-700 items-center justify-center">
          <FontAwesome name="cutlery" size={32} color={iconColor} />
        </View>
      )}

      <View className="p-4">
        <View className="flex-row items-start justify-between">
          <Text
            className="text-lg font-bold text-text-primary dark:text-gray-100 flex-1 mr-2 font-serif"
            numberOfLines={2}
          >
            {recipe.name}
          </Text>
          {recipe.favorite && (
            <FontAwesome name="heart" size={18} color={accentColor} />
          )}
        </View>

        {totalTime && (
          <View className="flex-row items-center mt-2">
            <FontAwesome name="clock-o" size={14} color={iconColor} />
            <Text className="text-text-tertiary dark:text-gray-400 ml-1.5 text-sm">
              {formatTime(totalTime)}
            </Text>
          </View>
        )}
      </View>
    </TouchableOpacity>
  );
}
