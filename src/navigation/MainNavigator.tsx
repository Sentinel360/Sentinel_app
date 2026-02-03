import React from 'react';
import { StyleSheet, View } from 'react-native';
import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';
import { MaterialCommunityIcons } from '@expo/vector-icons';
import {
  HomeScreen,
  NotificationsScreen,
  AnalyticsScreen,
  DeviceScreen,
  SettingsScreen,
} from '../screens';
import { MainTabParamList } from '../types';
import { Colors, FontSizes } from '../theme';

const Tab = createBottomTabNavigator<MainTabParamList>();

interface MainNavigatorProps {
  isDarkMode: boolean;
  onToggleDarkMode: () => void;
  onTriggerEmergency: () => void;
}

export function MainNavigator({
  isDarkMode,
  onToggleDarkMode,
  onTriggerEmergency,
}: MainNavigatorProps) {
  return (
    <Tab.Navigator
      screenOptions={({ route }) => ({
        headerShown: false,
        tabBarIcon: ({ focused, color }) => {
          let iconName: keyof typeof MaterialCommunityIcons.glyphMap;

          switch (route.name) {
            case 'Home':
              iconName = focused ? 'home' : 'home-outline';
              break;
            case 'Notifications':
              iconName = focused ? 'bell' : 'bell-outline';
              break;
            case 'Analytics':
              iconName = focused ? 'chart-bar' : 'chart-bar';
              break;
            case 'Device':
              iconName = focused ? 'bluetooth' : 'bluetooth';
              break;
            case 'Settings':
              iconName = focused ? 'cog' : 'cog-outline';
              break;
            default:
              iconName = 'circle';
          }

          return (
            <View style={styles.iconContainer}>
              <MaterialCommunityIcons name={iconName} size={22} color={color} />
              {route.name === 'Notifications' && (
                <View style={styles.notificationDot} />
              )}
            </View>
          );
        },
        tabBarActiveTintColor: Colors.primary,
        tabBarInactiveTintColor: Colors.light.textTertiary,
        tabBarStyle: {
          backgroundColor: isDarkMode
            ? Colors.dark.surface
            : Colors.light.surface,
          borderTopColor: isDarkMode
            ? Colors.dark.border
            : Colors.light.border,
          height: 80,
          paddingBottom: 16,
          paddingTop: 8,
        },
        tabBarLabelStyle: {
          fontSize: FontSizes.xs,
          fontWeight: '500',
        },
      })}
    >
      <Tab.Screen name="Home">
        {() => <HomeScreen onTriggerEmergency={onTriggerEmergency} />}
      </Tab.Screen>
      <Tab.Screen
        name="Notifications"
        component={NotificationsScreen}
        options={{ tabBarLabel: 'Alerts' }}
      />
      <Tab.Screen name="Analytics" component={AnalyticsScreen} />
      <Tab.Screen name="Device" component={DeviceScreen} />
      <Tab.Screen name="Settings">
        {() => (
          <SettingsScreen
            isDarkMode={isDarkMode}
            onToggleDarkMode={onToggleDarkMode}
          />
        )}
      </Tab.Screen>
    </Tab.Navigator>
  );
}

const styles = StyleSheet.create({
  iconContainer: {
    position: 'relative',
  },
  notificationDot: {
    position: 'absolute',
    top: -2,
    right: -4,
    width: 8,
    height: 8,
    borderRadius: 4,
    backgroundColor: Colors.danger,
  },
});
