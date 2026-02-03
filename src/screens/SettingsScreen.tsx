import React, { useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  TouchableOpacity,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Card, Button, Avatar, Switch, Badge } from 'react-native-paper';
import { MaterialCommunityIcons } from '@expo/vector-icons';
import { Colors, Spacing, BorderRadius, FontSizes, Shadows } from '../theme';

interface SettingsScreenProps {
  isDarkMode: boolean;
  onToggleDarkMode: () => void;
}

interface SettingsItem {
  iconName: string;
  label: string;
  toggle?: boolean;
  value?: boolean;
  onToggle?: (value: boolean) => void;
  badge?: string;
}

interface SettingsSection {
  title: string;
  items: SettingsItem[];
}

export function SettingsScreen({
  isDarkMode,
  onToggleDarkMode,
}: SettingsScreenProps) {
  const [pushNotifications, setPushNotifications] = useState(true);
  const [emergencyAlerts, setEmergencyAlerts] = useState(true);
  const [tripReminders, setTripReminders] = useState(false);

  const settingsSections: SettingsSection[] = [
    {
      title: 'Account',
      items: [
        { iconName: 'account', label: 'Edit Profile' },
        { iconName: 'shield-check', label: 'Privacy & Security' },
        { iconName: 'lock', label: 'Change Password' },
      ],
    },
    {
      title: 'Emergency Contacts',
      items: [
        { iconName: 'phone', label: 'Manage Contacts', badge: '3' },
        { iconName: 'map-marker', label: 'Share Location Settings' },
      ],
    },
    {
      title: 'Notifications',
      items: [
        {
          iconName: 'bell',
          label: 'Push Notifications',
          toggle: true,
          value: pushNotifications,
          onToggle: setPushNotifications,
        },
        {
          iconName: 'bell-alert',
          label: 'Emergency Alerts',
          toggle: true,
          value: emergencyAlerts,
          onToggle: setEmergencyAlerts,
        },
        {
          iconName: 'bell-outline',
          label: 'Trip Reminders',
          toggle: true,
          value: tripReminders,
          onToggle: setTripReminders,
        },
      ],
    },
    {
      title: 'Support',
      items: [
        { iconName: 'help-circle', label: 'Help Center' },
        { iconName: 'shield-lock', label: 'Data Privacy Policy' },
      ],
    },
  ];

  return (
    <SafeAreaView style={styles.container} edges={['top']}>
      <ScrollView
        style={styles.scrollView}
        showsVerticalScrollIndicator={false}
        contentContainerStyle={styles.scrollContent}
      >
        {/* Header */}
        <View style={styles.headerGradient}>
          <View style={styles.headerNav}>
            <View style={styles.placeholder} />
            <Text style={styles.headerTitle}>Settings</Text>
            <View style={styles.placeholder} />
          </View>

          {/* Profile Section */}
          <View style={styles.profileSection}>
            <Avatar.Text
              size={96}
              label="SJ"
              style={styles.avatar}
              labelStyle={styles.avatarLabel}
            />
            <Text style={styles.profileName}>Sarah Johnson</Text>
            <Text style={styles.profileEmail}>sarah.johnson@email.com</Text>
          </View>
        </View>

        {/* Main Content */}
        <View style={styles.mainContent}>
          {/* Theme Toggle */}
          <Card style={styles.themeCard}>
            <Card.Content style={styles.themeContent}>
              <View style={styles.themeLeft}>
                <MaterialCommunityIcons
                  name={isDarkMode ? 'weather-night' : 'weather-sunny'}
                  size={24}
                  color={isDarkMode ? Colors.primary : Colors.warning}
                />
                <View style={styles.themeText}>
                  <Text style={styles.themeTitle}>Dark Mode</Text>
                  <Text style={styles.themeSubtitle}>
                    {isDarkMode ? 'Enabled' : 'Disabled'}
                  </Text>
                </View>
              </View>
              <Switch value={isDarkMode} onValueChange={onToggleDarkMode} />
            </Card.Content>
          </Card>

          {/* Settings Sections */}
          {settingsSections.map((section, sectionIndex) => (
            <View key={section.title} style={styles.sectionContainer}>
              <Text style={styles.sectionTitle}>{section.title}</Text>
              <Card style={styles.sectionCard}>
                {section.items.map((item, itemIndex) => (
                  <View key={item.label}>
                    <TouchableOpacity
                      style={styles.settingItem}
                      disabled={item.toggle}
                    >
                      <View style={styles.settingLeft}>
                        <View style={styles.settingIcon}>
                          <MaterialCommunityIcons
                            name={item.iconName as any}
                            size={20}
                            color={Colors.primary}
                          />
                        </View>
                        <Text style={styles.settingLabel}>{item.label}</Text>
                      </View>
                      <View style={styles.settingRight}>
                        {item.badge && (
                          <Badge style={styles.settingBadge}>{item.badge}</Badge>
                        )}
                        {item.toggle ? (
                          <Switch
                            value={item.value}
                            onValueChange={item.onToggle}
                          />
                        ) : (
                          <MaterialCommunityIcons
                            name="chevron-right"
                            size={20}
                            color={Colors.light.textTertiary}
                          />
                        )}
                      </View>
                    </TouchableOpacity>
                    {itemIndex < section.items.length - 1 && (
                      <View style={styles.divider} />
                    )}
                  </View>
                ))}
              </Card>
            </View>
          ))}

          {/* Logout Button */}
          <Button
            mode="outlined"
            onPress={() => {}}
            style={styles.logoutButton}
            contentStyle={styles.logoutButtonContent}
            labelStyle={styles.logoutButtonLabel}
            icon="logout"
          >
            Log Out
          </Button>

          {/* App Version */}
          <View style={styles.versionSection}>
            <Text style={styles.versionText}>Sentinel 360 v1.2.0</Text>
            <Text style={styles.copyrightText}>
              © 2025 Sentinel Technologies
            </Text>
          </View>
        </View>
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: Colors.light.background,
  },
  scrollView: {
    flex: 1,
  },
  scrollContent: {
    paddingBottom: 100,
  },
  headerGradient: {
    backgroundColor: Colors.primary,
    paddingHorizontal: Spacing.lg,
    paddingTop: Spacing.lg,
    paddingBottom: Spacing.xxxl + Spacing.lg,
    borderBottomLeftRadius: BorderRadius.xxl,
    borderBottomRightRadius: BorderRadius.xxl,
  },
  headerNav: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: Spacing.xxl,
  },
  placeholder: {
    width: 40,
  },
  headerTitle: {
    fontSize: FontSizes.lg,
    fontWeight: '700',
    color: '#FFFFFF',
  },
  profileSection: {
    alignItems: 'center',
  },
  avatar: {
    backgroundColor: '#FFFFFF',
    marginBottom: Spacing.lg,
    borderWidth: 4,
    borderColor: 'rgba(255,255,255,0.2)',
  },
  avatarLabel: {
    color: Colors.primary,
    fontSize: FontSizes.xxl,
    fontWeight: '700',
  },
  profileName: {
    fontSize: FontSizes.xl,
    fontWeight: '700',
    color: '#FFFFFF',
    marginBottom: Spacing.xs,
  },
  profileEmail: {
    fontSize: FontSizes.sm,
    color: 'rgba(255,255,255,0.8)',
  },
  mainContent: {
    paddingHorizontal: Spacing.lg,
    marginTop: -Spacing.lg,
  },
  themeCard: {
    borderRadius: BorderRadius.lg,
    marginBottom: Spacing.lg,
    backgroundColor: Colors.light.surface,
    ...Shadows.lg,
  },
  themeContent: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  themeLeft: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  themeText: {
    marginLeft: Spacing.md,
  },
  themeTitle: {
    fontSize: FontSizes.md,
    fontWeight: '500',
    color: Colors.light.text,
  },
  themeSubtitle: {
    fontSize: FontSizes.sm,
    color: Colors.light.textSecondary,
  },
  sectionContainer: {
    marginBottom: Spacing.lg,
  },
  sectionTitle: {
    fontSize: FontSizes.md,
    fontWeight: '600',
    color: Colors.light.text,
    marginBottom: Spacing.md,
    marginLeft: Spacing.xs,
  },
  sectionCard: {
    borderRadius: BorderRadius.lg,
    backgroundColor: Colors.light.surface,
    overflow: 'hidden',
    ...Shadows.lg,
  },
  settingItem: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: Spacing.md,
    paddingHorizontal: Spacing.lg,
  },
  settingLeft: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  settingIcon: {
    width: 40,
    height: 40,
    borderRadius: BorderRadius.md,
    backgroundColor: Colors.light.surfaceVariant,
    alignItems: 'center',
    justifyContent: 'center',
    marginRight: Spacing.md,
  },
  settingLabel: {
    fontSize: FontSizes.md,
    color: Colors.light.text,
  },
  settingRight: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: Spacing.sm,
  },
  settingBadge: {
    backgroundColor: Colors.primary,
  },
  divider: {
    height: 1,
    backgroundColor: Colors.light.border,
    marginHorizontal: Spacing.lg,
  },
  logoutButton: {
    borderRadius: BorderRadius.md,
    borderColor: '#FECACA',
    borderWidth: 2,
    marginBottom: Spacing.lg,
  },
  logoutButtonContent: {
    height: 56,
  },
  logoutButtonLabel: {
    fontSize: FontSizes.md,
    color: Colors.danger,
  },
  versionSection: {
    alignItems: 'center',
    paddingBottom: Spacing.xl,
  },
  versionText: {
    fontSize: FontSizes.sm,
    color: Colors.light.textTertiary,
  },
  copyrightText: {
    fontSize: FontSizes.xs,
    color: Colors.light.textTertiary,
    marginTop: Spacing.xs,
  },
});
