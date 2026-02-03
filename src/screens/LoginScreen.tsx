import React, { useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  KeyboardAvoidingView,
  Platform,
  ScrollView,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Button, TextInput } from 'react-native-paper';
import { MaterialCommunityIcons } from '@expo/vector-icons';
import { Colors, Spacing, BorderRadius, FontSizes, Shadows } from '../theme';

interface LoginScreenProps {
  onLogin: () => void;
}

export function LoginScreen({ onLogin }: LoginScreenProps) {
  const [isLogin, setIsLogin] = useState(true);
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);

  const handleSubmit = () => {
    // In a real app, you would validate and authenticate here
    onLogin();
  };

  return (
    <SafeAreaView style={styles.container}>
      <KeyboardAvoidingView
        behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
        style={styles.keyboardView}
      >
        <ScrollView
          contentContainerStyle={styles.scrollContent}
          showsVerticalScrollIndicator={false}
          keyboardShouldPersistTaps="handled"
        >
          {/* Logo and Header */}
          <View style={styles.headerSection}>
            <View style={styles.logoContainer}>
              <MaterialCommunityIcons
                name="pulse"
                size={40}
                color="#FFFFFF"
              />
            </View>
            <Text style={styles.brandName}>Sentinel 360</Text>
            <Text style={styles.welcomeText}>
              {isLogin ? 'Welcome Back' : 'Create Account'}
            </Text>
            <Text style={styles.subText}>
              {isLogin
                ? 'Your AI safety companion is ready'
                : 'Join thousands of safely monitored trips'}
            </Text>
          </View>

          {/* Form */}
          <View style={styles.formSection}>
            <Text style={styles.label}>Email</Text>
            <TextInput
              mode="outlined"
              placeholder="you@example.com"
              value={email}
              onChangeText={setEmail}
              keyboardType="email-address"
              autoCapitalize="none"
              style={styles.input}
              outlineStyle={styles.inputOutline}
              left={
                <TextInput.Icon
                  icon="email-outline"
                  color={Colors.light.textSecondary}
                />
              }
            />

            <Text style={[styles.label, { marginTop: Spacing.lg }]}>
              Password
            </Text>
            <TextInput
              mode="outlined"
              placeholder="••••••••"
              value={password}
              onChangeText={setPassword}
              secureTextEntry={!showPassword}
              style={styles.input}
              outlineStyle={styles.inputOutline}
              left={
                <TextInput.Icon
                  icon="lock-outline"
                  color={Colors.light.textSecondary}
                />
              }
              right={
                <TextInput.Icon
                  icon={showPassword ? 'eye-off' : 'eye'}
                  onPress={() => setShowPassword(!showPassword)}
                  color={Colors.light.textSecondary}
                />
              }
            />

            {isLogin && (
              <TouchableOpacity style={styles.forgotPassword}>
                <Text style={styles.forgotPasswordText}>Forgot password?</Text>
              </TouchableOpacity>
            )}

            <Button
              mode="contained"
              onPress={handleSubmit}
              style={styles.submitButton}
              contentStyle={styles.submitButtonContent}
              labelStyle={styles.submitButtonLabel}
            >
              {isLogin ? 'Log In' : 'Sign Up'}
            </Button>
          </View>

          {/* Divider */}
          <View style={styles.divider}>
            <View style={styles.dividerLine} />
            <Text style={styles.dividerText}>or continue with</Text>
            <View style={styles.dividerLine} />
          </View>

          {/* Social Login */}
          <View style={styles.socialSection}>
            <Button
              mode="outlined"
              onPress={onLogin}
              style={styles.socialButton}
              contentStyle={styles.socialButtonContent}
              labelStyle={styles.socialButtonLabel}
              icon={() => (
                <MaterialCommunityIcons
                  name="google"
                  size={20}
                  color={Colors.light.text}
                />
              )}
            >
              Log in with Google
            </Button>

            <Button
              mode="outlined"
              onPress={onLogin}
              style={[styles.socialButton, { marginTop: Spacing.md }]}
              contentStyle={styles.socialButtonContent}
              labelStyle={styles.socialButtonLabel}
              icon={() => (
                <MaterialCommunityIcons
                  name="apple"
                  size={20}
                  color={Colors.light.text}
                />
              )}
            >
              Log in with Apple
            </Button>
          </View>

          {/* Toggle Login/Signup */}
          <View style={styles.toggleSection}>
            <Text style={styles.toggleText}>
              {isLogin ? "Don't have an account? " : 'Already have an account? '}
            </Text>
            <TouchableOpacity onPress={() => setIsLogin(!isLogin)}>
              <Text style={styles.toggleLink}>
                {isLogin ? 'Sign up' : 'Log in'}
              </Text>
            </TouchableOpacity>
          </View>
        </ScrollView>
      </KeyboardAvoidingView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: Colors.light.background,
  },
  keyboardView: {
    flex: 1,
  },
  scrollContent: {
    flexGrow: 1,
    paddingHorizontal: Spacing.lg,
  },
  headerSection: {
    alignItems: 'center',
    marginTop: Spacing.xxxl,
    marginBottom: Spacing.xxl,
  },
  logoContainer: {
    width: 80,
    height: 80,
    borderRadius: 40,
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: Spacing.lg,
    // Gradient simulation with solid color
    backgroundColor: Colors.primary,
    ...Shadows.xl,
  },
  brandName: {
    fontSize: FontSizes.xxl,
    fontWeight: '700',
    color: Colors.light.text,
    marginBottom: Spacing.sm,
  },
  welcomeText: {
    fontSize: FontSizes.xl,
    fontWeight: '600',
    color: Colors.light.text,
    marginBottom: Spacing.xs,
  },
  subText: {
    fontSize: FontSizes.md,
    color: Colors.light.textSecondary,
    textAlign: 'center',
  },
  formSection: {
    marginBottom: Spacing.lg,
  },
  label: {
    fontSize: FontSizes.sm,
    color: Colors.light.textSecondary,
    marginBottom: Spacing.sm,
    marginLeft: Spacing.xs,
  },
  input: {
    backgroundColor: Colors.light.surface,
  },
  inputOutline: {
    borderRadius: BorderRadius.md,
    borderColor: Colors.light.border,
  },
  forgotPassword: {
    alignSelf: 'flex-end',
    marginTop: Spacing.sm,
  },
  forgotPasswordText: {
    fontSize: FontSizes.sm,
    color: Colors.primary,
  },
  submitButton: {
    marginTop: Spacing.xl,
    borderRadius: BorderRadius.md,
    backgroundColor: Colors.primary,
  },
  submitButtonContent: {
    height: 56,
  },
  submitButtonLabel: {
    fontSize: FontSizes.lg,
    fontWeight: '600',
  },
  divider: {
    flexDirection: 'row',
    alignItems: 'center',
    marginVertical: Spacing.lg,
  },
  dividerLine: {
    flex: 1,
    height: 1,
    backgroundColor: Colors.light.border,
  },
  dividerText: {
    marginHorizontal: Spacing.md,
    fontSize: FontSizes.sm,
    color: Colors.light.textSecondary,
  },
  socialSection: {
    marginBottom: Spacing.xl,
  },
  socialButton: {
    borderRadius: BorderRadius.md,
    borderColor: Colors.light.border,
    borderWidth: 2,
    backgroundColor: Colors.light.surface,
  },
  socialButtonContent: {
    height: 56,
  },
  socialButtonLabel: {
    fontSize: FontSizes.md,
    color: Colors.light.text,
  },
  toggleSection: {
    flexDirection: 'row',
    justifyContent: 'center',
    marginBottom: Spacing.xl,
  },
  toggleText: {
    fontSize: FontSizes.md,
    color: Colors.light.textSecondary,
  },
  toggleLink: {
    fontSize: FontSizes.md,
    color: Colors.primary,
    fontWeight: '600',
  },
});
