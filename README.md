# Sentinel 360 Mobile

A React Native mobile application for AI-powered safety monitoring, converted from the original Figma web design.

## Features

- **Onboarding Flow**: 4-slide introduction to the app
- **Authentication**: Login/signup with social options
- **Home Dashboard**: Real-time safety status and device monitoring
- **Trip Tracking**: Timer-based journey tracking with timeline events
- **Emergency Alerts**: Countdown emergency system with contact notification
- **Notifications Center**: Tabbed alert management (Critical/Warning/Info)
- **Analytics & Insights**: Charts showing motion patterns and trip frequency
- **Device Management**: Battery, sync, and firmware settings
- **Settings**: Profile, notifications, and app preferences
- **Dark Mode**: Full dark theme support

## Tech Stack

- **Expo SDK 54** - Cross-platform development
- **React Native 0.76** - Mobile UI framework
- **React Navigation 7** - Navigation (Stack + Bottom Tabs)
- **React Native Paper** - Material Design 3 components
- **React Native Chart Kit** - Data visualization
- **React Native Maps** - Map integration (configured)
- **Expo Location** - GPS services (configured, not active)
- **TypeScript** - Type safety throughout

## Project Structure

```
sentinel360-mobile/
├── App.tsx                 # Main app entry point
├── app.json               # Expo configuration
├── package.json           # Dependencies
├── tsconfig.json          # TypeScript config
├── babel.config.js        # Babel config (NO reanimated!)
├── assets/                # App icons and splash screen
│   └── README.md          # Icon creation guide
├── src/
│   ├── navigation/        # Navigation setup
│   │   ├── AuthNavigator.tsx
│   │   ├── MainNavigator.tsx
│   │   ├── RootNavigator.tsx
│   │   └── index.ts
│   ├── screens/           # All screen components
│   │   ├── OnboardingScreen.tsx
│   │   ├── LoginScreen.tsx
│   │   ├── HomeScreen.tsx
│   │   ├── TripTrackingScreen.tsx
│   │   ├── EmergencyScreen.tsx
│   │   ├── NotificationsScreen.tsx
│   │   ├── AnalyticsScreen.tsx
│   │   ├── DeviceScreen.tsx
│   │   ├── SettingsScreen.tsx
│   │   └── index.ts
│   ├── utils/             # Helper functions
│   │   └── locationHelpers.ts
│   ├── theme.ts           # Design system (colors, spacing)
│   └── types.ts           # TypeScript definitions
└── docs/
    ├── START_HERE.md      # Quick start guide
    ├── TROUBLESHOOTING.md # Common issues
    └── GPS_GUIDE.md       # GPS implementation guide
```

## Installation

### Prerequisites
- Node.js 18 or higher
- npm or yarn
- Expo Go app on your mobile device

### Steps

1. **Navigate to project directory**
```bash
cd sentinel360-mobile
```

2. **Install dependencies**
```bash
npm install
```

3. **Create app icons** (optional - see assets/README.md)

4. **Start the development server**
```bash
npx expo start -c
```

5. **Open on your device**
- Scan the QR code with your phone's camera (iOS) or Expo Go app (Android)

## Development

### Available Scripts

```bash
# Start with cache cleared
npx expo start -c

# Start for iOS
npx expo start --ios

# Start for Android
npx expo start --android

# Start for web
npx expo start --web
```

### Navigation Structure

```
RootNavigator
├── AuthNavigator (when not authenticated)
│   ├── Onboarding
│   └── Login
├── Emergency (modal, when emergency active)
└── MainNavigator (when authenticated)
    ├── Home (Tab)
    ├── Notifications (Tab)
    ├── Analytics (Tab)
    ├── Device (Tab)
    ├── Settings (Tab)
    └── TripTracking (Stack - modal)
```

## Design System

### Colors
```typescript
primary: '#4A6CF7'    // Blue
success: '#6EDC9A'    // Green
warning: '#F6C85F'    // Yellow
danger: '#FF5A5F'     // Red
purple: '#A78BFA'     // Purple
```

### Light Theme
- Background: #F7F9FC
- Surface: #FFFFFF
- Text: #111827

### Dark Theme
- Background: #1C1E22
- Surface: #1F2937
- Text: #FFFFFF

## GPS Integration

GPS is pre-configured but not actively running. To enable:

```typescript
import {
  requestLocationPermissions,
  getCurrentLocation,
  startLocationTracking
} from './src/utils/locationHelpers';

// Request permissions
const permissions = await requestLocationPermissions();

// Get current location once
const location = await getCurrentLocation();

// Start continuous tracking
const subscription = await startLocationTracking((location) => {
  console.log('New location:', location);
});

// Stop tracking when done
subscription?.remove();
```

See `GPS_GUIDE.md` for detailed implementation.

## Important Notes

### No react-native-reanimated
This project intentionally does NOT use react-native-reanimated to avoid worklet errors in Expo Go. All animations use React Native's built-in Animated API or simple state changes.

### Expo Go Compatible
All packages are chosen to work with Expo Go without requiring custom native code or ejecting.

### SDK 54 Verified
All package versions are verified to be compatible with Expo SDK 54.

## Building for Production

```bash
# Build for iOS
eas build --platform ios

# Build for Android
eas build --platform android

# Build both
eas build --platform all
```

Note: You'll need an Expo account and EAS CLI for production builds.

## License

MIT License - Feel free to use this code for your projects.

## Credits

Original design from Figma export.
Converted to React Native with Expo.
