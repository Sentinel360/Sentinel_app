import React, { useState, useCallback } from 'react';
import { StatusBar, useColorScheme } from 'react-native';
import { NavigationContainer, DefaultTheme, DarkTheme } from '@react-navigation/native';
import { SafeAreaProvider } from 'react-native-safe-area-context';
import { PaperProvider, MD3DarkTheme, MD3LightTheme } from 'react-native-paper';
import { RootNavigator } from './src/navigation';
import { getLightTheme, getDarkTheme, Colors } from './src/theme';

// Custom navigation themes
const CustomLightTheme = {
  ...DefaultTheme,
  colors: {
    ...DefaultTheme.colors,
    primary: Colors.primary,
    background: Colors.light.background,
    card: Colors.light.surface,
    text: Colors.light.text,
    border: Colors.light.border,
    notification: Colors.danger,
  },
};

const CustomDarkTheme = {
  ...DarkTheme,
  colors: {
    ...DarkTheme.colors,
    primary: Colors.primary,
    background: Colors.dark.background,
    card: Colors.dark.surface,
    text: Colors.dark.text,
    border: Colors.dark.border,
    notification: Colors.danger,
  },
};

// Custom Paper themes
const paperLightTheme = {
  ...MD3LightTheme,
  ...getLightTheme(),
};

const paperDarkTheme = {
  ...MD3DarkTheme,
  ...getDarkTheme(),
};

export default function App() {
  const systemColorScheme = useColorScheme();

  // App state
  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const [hasCompletedOnboarding, setHasCompletedOnboarding] = useState(false);
  const [isDarkMode, setIsDarkMode] = useState(systemColorScheme === 'dark');
  const [emergencyActive, setEmergencyActive] = useState(false);

  // Handlers
  const handleCompleteOnboarding = useCallback(() => {
    setHasCompletedOnboarding(true);
  }, []);

  const handleLogin = useCallback(() => {
    setIsAuthenticated(true);
  }, []);

  const handleToggleDarkMode = useCallback(() => {
    setIsDarkMode((prev) => !prev);
  }, []);

  const handleTriggerEmergency = useCallback(() => {
    setEmergencyActive(true);
  }, []);

  const handleCancelEmergency = useCallback(() => {
    setEmergencyActive(false);
  }, []);

  const handleConfirmEmergency = useCallback(() => {
    // Emergency confirmed - in a real app, you would:
    // 1. Send alerts to emergency contacts
    // 2. Share location
    // 3. Contact emergency services
    console.log('Emergency confirmed!');

    // Auto-dismiss after 3 seconds for demo
    setTimeout(() => {
      setEmergencyActive(false);
    }, 3000);
  }, []);

  // Select themes based on dark mode setting
  const navigationTheme = isDarkMode ? CustomDarkTheme : CustomLightTheme;
  const paperTheme = isDarkMode ? paperDarkTheme : paperLightTheme;

  return (
    <SafeAreaProvider>
      <PaperProvider theme={paperTheme}>
        <NavigationContainer theme={navigationTheme}>
          <StatusBar
            barStyle={isDarkMode ? 'light-content' : 'dark-content'}
            backgroundColor={
              isDarkMode ? Colors.dark.background : Colors.light.background
            }
          />
          <RootNavigator
            isAuthenticated={isAuthenticated}
            hasCompletedOnboarding={hasCompletedOnboarding}
            isDarkMode={isDarkMode}
            emergencyActive={emergencyActive}
            onCompleteOnboarding={handleCompleteOnboarding}
            onLogin={handleLogin}
            onToggleDarkMode={handleToggleDarkMode}
            onTriggerEmergency={handleTriggerEmergency}
            onCancelEmergency={handleCancelEmergency}
            onConfirmEmergency={handleConfirmEmergency}
          />
        </NavigationContainer>
      </PaperProvider>
    </SafeAreaProvider>
  );
}
