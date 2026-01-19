import { Pressable } from 'react-native';
import { Stack } from 'expo-router/stack';
import { SymbolView } from 'expo-symbols';
import * as Haptics from 'expo-haptics';
import { useAuth } from '@/lib/AuthContext';
import { logout } from '@/lib/api';

function LogoutButton() {
  const { setAuthenticated } = useAuth();

  const handleLogout = async () => {
    await Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    setAuthenticated(false);
    await logout();
  };

  return (
    <Pressable onPress={handleLogout} style={{ marginRight: 15 }}>
      <SymbolView
        name="rectangle.portrait.and.arrow.right"
        size={22}
        tintColor="gray"
      />
    </Pressable>
  );
}

export default function RecipesLayout() {
  return (
    <Stack
      screenOptions={{
        headerLargeTitle: true,
        headerBackButtonDisplayMode: 'minimal',
      }}
    >
      <Stack.Screen
        name="index"
        options={{
          title: 'Recipes',
          headerRight: () => <LogoutButton />,
        }}
      />
      <Stack.Screen
        name="[id]"
        options={{
          headerLargeTitle: false,
        }}
      />
    </Stack>
  );
}
