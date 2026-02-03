// Sentinel 360 Design System
// Colors extracted from the original Figma design

export const Colors = {
  // Primary colors
  primary: '#4A6CF7',
  primaryDark: '#3A5CE7',
  primaryLight: '#6B8AFF',

  // Secondary/Accent colors
  success: '#6EDC9A',
  successDark: '#4ECB84',
  warning: '#F6C85F',
  warningDark: '#F4B944',
  danger: '#FF5A5F',
  dangerDark: '#E54448',
  purple: '#A78BFA',
  purpleDark: '#8B5CF6',

  // Light theme
  light: {
    background: '#F7F9FC',
    surface: '#FFFFFF',
    surfaceVariant: '#F3F4F6',
    text: '#111827',
    textSecondary: '#6B7280',
    textTertiary: '#9CA3AF',
    border: '#E5E7EB',
    divider: '#F3F4F6',
  },

  // Dark theme
  dark: {
    background: '#1C1E22',
    surface: '#1F2937',
    surfaceVariant: '#374151',
    text: '#FFFFFF',
    textSecondary: '#9CA3AF',
    textTertiary: '#6B7280',
    border: '#374151',
    divider: '#374151',
  },
};

export const Spacing = {
  xs: 4,
  sm: 8,
  md: 12,
  lg: 16,
  xl: 20,
  xxl: 24,
  xxxl: 32,
};

export const BorderRadius = {
  sm: 8,
  md: 12,
  lg: 16,
  xl: 20,
  xxl: 24,
  full: 9999,
};

export const FontSizes = {
  xs: 10,
  sm: 12,
  md: 14,
  lg: 16,
  xl: 18,
  xxl: 20,
  xxxl: 24,
  display: 32,
  hero: 48,
};

export const Shadows = {
  sm: {
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.1,
    shadowRadius: 2,
    elevation: 2,
  },
  md: {
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.15,
    shadowRadius: 4,
    elevation: 4,
  },
  lg: {
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.2,
    shadowRadius: 8,
    elevation: 8,
  },
  xl: {
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 8 },
    shadowOpacity: 0.25,
    shadowRadius: 16,
    elevation: 12,
  },
};

// Paper theme configuration for React Native Paper
export const getLightTheme = () => ({
  colors: {
    primary: Colors.primary,
    onPrimary: '#FFFFFF',
    primaryContainer: Colors.primaryLight,
    onPrimaryContainer: '#FFFFFF',
    secondary: Colors.success,
    onSecondary: '#FFFFFF',
    secondaryContainer: Colors.success,
    onSecondaryContainer: '#FFFFFF',
    tertiary: Colors.warning,
    onTertiary: '#000000',
    tertiaryContainer: Colors.warning,
    onTertiaryContainer: '#000000',
    error: Colors.danger,
    onError: '#FFFFFF',
    errorContainer: '#FFE5E5',
    onErrorContainer: Colors.danger,
    background: Colors.light.background,
    onBackground: Colors.light.text,
    surface: Colors.light.surface,
    onSurface: Colors.light.text,
    surfaceVariant: Colors.light.surfaceVariant,
    onSurfaceVariant: Colors.light.textSecondary,
    outline: Colors.light.border,
    outlineVariant: Colors.light.divider,
    shadow: '#000000',
    scrim: '#000000',
    inverseSurface: Colors.dark.surface,
    inverseOnSurface: Colors.dark.text,
    inversePrimary: Colors.primaryLight,
    elevation: {
      level0: 'transparent',
      level1: Colors.light.surface,
      level2: Colors.light.surface,
      level3: Colors.light.surface,
      level4: Colors.light.surface,
      level5: Colors.light.surface,
    },
    surfaceDisabled: 'rgba(0, 0, 0, 0.12)',
    onSurfaceDisabled: 'rgba(0, 0, 0, 0.38)',
    backdrop: 'rgba(0, 0, 0, 0.4)',
  },
});

export const getDarkTheme = () => ({
  colors: {
    primary: Colors.primary,
    onPrimary: '#FFFFFF',
    primaryContainer: Colors.primaryDark,
    onPrimaryContainer: '#FFFFFF',
    secondary: Colors.success,
    onSecondary: '#FFFFFF',
    secondaryContainer: Colors.successDark,
    onSecondaryContainer: '#FFFFFF',
    tertiary: Colors.warning,
    onTertiary: '#000000',
    tertiaryContainer: Colors.warningDark,
    onTertiaryContainer: '#000000',
    error: Colors.danger,
    onError: '#FFFFFF',
    errorContainer: 'rgba(255, 90, 95, 0.2)',
    onErrorContainer: Colors.danger,
    background: Colors.dark.background,
    onBackground: Colors.dark.text,
    surface: Colors.dark.surface,
    onSurface: Colors.dark.text,
    surfaceVariant: Colors.dark.surfaceVariant,
    onSurfaceVariant: Colors.dark.textSecondary,
    outline: Colors.dark.border,
    outlineVariant: Colors.dark.divider,
    shadow: '#000000',
    scrim: '#000000',
    inverseSurface: Colors.light.surface,
    inverseOnSurface: Colors.light.text,
    inversePrimary: Colors.primaryDark,
    elevation: {
      level0: 'transparent',
      level1: Colors.dark.surface,
      level2: Colors.dark.surface,
      level3: Colors.dark.surfaceVariant,
      level4: Colors.dark.surfaceVariant,
      level5: Colors.dark.surfaceVariant,
    },
    surfaceDisabled: 'rgba(255, 255, 255, 0.12)',
    onSurfaceDisabled: 'rgba(255, 255, 255, 0.38)',
    backdrop: 'rgba(0, 0, 0, 0.6)',
  },
});
