import { Pressable } from 'react-native';
import { NativeTabs, Icon, Label } from 'expo-router/unstable-native-tabs';
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
      <Icon sf="rectangle.portrait.and.arrow.right" />
    </Pressable>
  );
}

export default function MainLayout() {
  return (
    <NativeTabs>
      <NativeTabs.Trigger name="(recipes)">
        <Icon sf="book" />
        <Label>Recipes</Label>
      </NativeTabs.Trigger>
    </NativeTabs>
  );
}
