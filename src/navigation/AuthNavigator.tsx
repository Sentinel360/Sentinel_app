import React from 'react';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import { OnboardingScreen, LoginScreen } from '../screens';
import { AuthStackParamList } from '../types';

const Stack = createNativeStackNavigator<AuthStackParamList>();

interface AuthNavigatorProps {
  hasCompletedOnboarding: boolean;
  onCompleteOnboarding: () => void;
  onLogin: () => void;
}

export function AuthNavigator({
  hasCompletedOnboarding,
  onCompleteOnboarding,
  onLogin,
}: AuthNavigatorProps) {
  return (
    <Stack.Navigator
      screenOptions={{
        headerShown: false,
        animation: 'slide_from_right',
      }}
      initialRouteName={hasCompletedOnboarding ? 'Login' : 'Onboarding'}
    >
      <Stack.Screen name="Onboarding">
        {() => <OnboardingScreen onComplete={onCompleteOnboarding} />}
      </Stack.Screen>
      <Stack.Screen name="Login">
        {() => <LoginScreen onLogin={onLogin} />}
      </Stack.Screen>
    </Stack.Navigator>
  );
}
