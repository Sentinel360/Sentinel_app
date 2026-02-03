import React from 'react';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import { AuthNavigator } from './AuthNavigator';
import { MainNavigator } from './MainNavigator';
import { TripTrackingScreen, EmergencyScreen } from '../screens';
import { RootStackParamList } from '../types';

const Stack = createNativeStackNavigator<RootStackParamList>();

interface RootNavigatorProps {
  isAuthenticated: boolean;
  hasCompletedOnboarding: boolean;
  isDarkMode: boolean;
  emergencyActive: boolean;
  onCompleteOnboarding: () => void;
  onLogin: () => void;
  onToggleDarkMode: () => void;
  onTriggerEmergency: () => void;
  onCancelEmergency: () => void;
  onConfirmEmergency: () => void;
}

export function RootNavigator({
  isAuthenticated,
  hasCompletedOnboarding,
  isDarkMode,
  emergencyActive,
  onCompleteOnboarding,
  onLogin,
  onToggleDarkMode,
  onTriggerEmergency,
  onCancelEmergency,
  onConfirmEmergency,
}: RootNavigatorProps) {
  return (
    <Stack.Navigator
      screenOptions={{
        headerShown: false,
        animation: 'slide_from_right',
      }}
    >
      {!isAuthenticated ? (
        <Stack.Screen name="Auth">
          {() => (
            <AuthNavigator
              hasCompletedOnboarding={hasCompletedOnboarding}
              onCompleteOnboarding={onCompleteOnboarding}
              onLogin={onLogin}
            />
          )}
        </Stack.Screen>
      ) : emergencyActive ? (
        <Stack.Screen
          name="Emergency"
          options={{
            animation: 'fade',
            gestureEnabled: false,
          }}
        >
          {() => (
            <EmergencyScreen
              onCancel={onCancelEmergency}
              onConfirm={onConfirmEmergency}
            />
          )}
        </Stack.Screen>
      ) : (
        <>
          <Stack.Screen name="Main">
            {() => (
              <MainNavigator
                isDarkMode={isDarkMode}
                onToggleDarkMode={onToggleDarkMode}
                onTriggerEmergency={onTriggerEmergency}
              />
            )}
          </Stack.Screen>
          <Stack.Screen
            name="TripTracking"
            options={{
              presentation: 'modal',
              animation: 'slide_from_bottom',
            }}
          >
            {() => (
              <TripTrackingScreen onTriggerEmergency={onTriggerEmergency} />
            )}
          </Stack.Screen>
        </>
      )}
    </Stack.Navigator>
  );
}
