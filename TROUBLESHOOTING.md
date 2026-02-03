# Troubleshooting Guide

## Common Issues and Solutions

### 1. "Unable to resolve module" errors

**Problem**: Metro bundler can't find a module.

**Solutions**:
```bash
# Clear cache and restart
npx expo start -c

# If that doesn't work, delete node_modules and reinstall
rm -rf node_modules
npm install
npx expo start -c
```

### 2. "Requiring unknown module" error

**Problem**: Module not properly installed.

**Solution**:
```bash
# Install with legacy peer deps flag
npm install --legacy-peer-deps
```

### 3. Metro bundler stuck or slow

**Problem**: Metro bundler hangs or takes forever.

**Solutions**:
```bash
# Kill the process and restart with cleared cache
# Press Ctrl+C to stop, then:
npx expo start -c

# Or reset Metro cache specifically
npx expo start --clear
```

### 4. "Worklet" or "Reanimated" errors

**Problem**: react-native-reanimated errors (shouldn't happen in this project).

**Check**: Ensure you're running the correct project. This project does NOT use reanimated.

**If you accidentally installed it**:
```bash
npm uninstall react-native-reanimated
```

### 5. App crashes on startup

**Problem**: App immediately crashes when opened.

**Solutions**:
1. Check your phone has Expo Go installed (latest version)
2. Ensure you're on the same WiFi network as your computer
3. Try running with tunnel mode:
```bash
npx expo start --tunnel
```

### 6. QR code not working

**Problem**: Phone won't scan the QR code.

**Solutions**:
1. **iOS**: Use the native Camera app, not Expo Go
2. **Android**: Use Expo Go app to scan
3. Try typing the URL manually in Expo Go
4. Use tunnel mode for cross-network:
```bash
npx expo start --tunnel
```

### 7. "Network request failed" error

**Problem**: App can't connect to Metro bundler.

**Solutions**:
1. Check both devices are on the same WiFi
2. Check your firewall isn't blocking port 19000
3. Try tunnel mode:
```bash
npx expo start --tunnel
```

### 8. Package version conflicts

**Problem**: npm shows peer dependency warnings.

**Solution**:
```bash
# Install with legacy peer deps
npm install --legacy-peer-deps

# Or use force flag (less safe)
npm install --force
```

### 9. TypeScript errors

**Problem**: IDE shows TypeScript errors.

**Solutions**:
1. Restart your IDE (VS Code: Cmd+Shift+P > "Developer: Reload Window")
2. Ensure TypeScript extension is installed
3. Check tsconfig.json exists

### 10. Chart not rendering

**Problem**: Charts in Analytics screen are blank.

**Solutions**:
1. Charts need a fixed width - ensure the component has proper dimensions
2. Check that react-native-svg is installed:
```bash
npm install react-native-svg
```

### 11. Icons not showing

**Problem**: MaterialCommunityIcons appear as boxes or blank.

**Solutions**:
1. Usually fixes itself after reload
2. Try force reloading:
```bash
npx expo start -c
```

### 12. Dark mode not switching

**Problem**: Dark mode toggle doesn't change colors.

**Solution**: The theme is managed at the app level. Check that:
1. You're using the theme props in your components
2. StatusBar component is properly configured

### 13. Navigation not working

**Problem**: Tapping tabs or buttons doesn't navigate.

**Solutions**:
1. Check NavigationContainer wraps everything
2. Ensure navigation prop is passed correctly
3. Verify screen names match exactly

### 14. Keyboard covers input

**Problem**: Keyboard hides text inputs.

**Solution**: The LoginScreen uses KeyboardAvoidingView. If issues persist:
```tsx
<KeyboardAvoidingView
  behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
  style={{ flex: 1 }}
>
  {/* Your content */}
</KeyboardAvoidingView>
```

### 15. Safe area issues

**Problem**: Content goes under notch or home indicator.

**Solution**: Use SafeAreaView from react-native-safe-area-context:
```tsx
import { SafeAreaView } from 'react-native-safe-area-context';

<SafeAreaView style={{ flex: 1 }} edges={['top']}>
  {/* Your content */}
</SafeAreaView>
```

## Still Having Issues?

### Reset Everything
```bash
# Nuclear option - reset everything
rm -rf node_modules
rm -rf .expo
rm package-lock.json
npm cache clean --force
npm install
npx expo start -c
```

### Check Expo SDK Compatibility
Ensure all packages are compatible with SDK 54:
```bash
npx expo-doctor
```

### Check for Updates
```bash
npm outdated
npx expo install --check
```

### Debug Mode
Run with verbose logging:
```bash
DEBUG=expo:* npx expo start
```

### Get Help
- [Expo Documentation](https://docs.expo.dev)
- [Expo Forums](https://forums.expo.dev)
- [React Navigation Docs](https://reactnavigation.org/docs/getting-started)
- [React Native Paper Docs](https://callstack.github.io/react-native-paper)
