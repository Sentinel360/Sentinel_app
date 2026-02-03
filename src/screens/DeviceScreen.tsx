import React, { useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Card, Button, Badge, ProgressBar, Switch } from 'react-native-paper';
import { MaterialCommunityIcons } from '@expo/vector-icons';
import { Colors, Spacing, BorderRadius, FontSizes, Shadows } from '../theme';

export function DeviceScreen() {
  const [autoSync, setAutoSync] = useState(true);
  const [backgroundActivity, setBackgroundActivity] = useState(true);
  const [lowPowerMode, setLowPowerMode] = useState(false);

  const batteryLevel = 78;
  const lastSync = '5 mins ago';
  const firmwareVersion = 'v2.4.1';

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
            <Text style={styles.headerTitle}>Device Management</Text>
            <View style={styles.placeholder} />
          </View>

          {/* Device Status Card */}
          <Card style={styles.deviceCard}>
            <Card.Content>
              <View style={styles.deviceHeader}>
                <View style={styles.deviceInfoRow}>
                  <View style={styles.deviceIconContainer}>
                    <MaterialCommunityIcons
                      name="bluetooth"
                      size={24}
                      color="#FFFFFF"
                    />
                  </View>
                  <View>
                    <Text style={styles.deviceName}>Sentinel 360 Band</Text>
                    <Text style={styles.deviceSerial}>SN: S360-2024-7842</Text>
                  </View>
                </View>
                <Badge style={styles.connectedBadge}>
                  <View style={styles.connectedDot} />
                  <Text style={styles.connectedText}>Connected</Text>
                </Badge>
              </View>

              <View style={styles.deviceStats}>
                <View style={styles.deviceStatItem}>
                  <View style={styles.deviceStatIcon}>
                    <MaterialCommunityIcons
                      name="battery"
                      size={16}
                      color="rgba(255,255,255,0.8)"
                    />
                    <Text style={styles.deviceStatLabel}>Battery</Text>
                  </View>
                  <Text style={styles.deviceStatValue}>{batteryLevel}%</Text>
                </View>

                <View style={styles.deviceStatItem}>
                  <View style={styles.deviceStatIcon}>
                    <MaterialCommunityIcons
                      name="wifi"
                      size={16}
                      color="rgba(255,255,255,0.8)"
                    />
                    <Text style={styles.deviceStatLabel}>Signal</Text>
                  </View>
                  <Text style={styles.deviceStatValue}>Strong</Text>
                </View>
              </View>
            </Card.Content>
          </Card>
        </View>

        {/* Main Content */}
        <View style={styles.mainContent}>
          {/* Battery Details */}
          <Card style={styles.card}>
            <Card.Content>
              <View style={styles.cardHeader}>
                <Text style={styles.cardTitle}>Battery Status</Text>
                <MaterialCommunityIcons
                  name="flash"
                  size={20}
                  color={Colors.warning}
                />
              </View>

              <View style={styles.batterySection}>
                <View style={styles.batteryLabelRow}>
                  <Text style={styles.batteryLabel}>Current Level</Text>
                  <Text style={styles.batteryValue}>{batteryLevel}%</Text>
                </View>
                <ProgressBar
                  progress={batteryLevel / 100}
                  color={Colors.success}
                  style={styles.batteryProgress}
                />

                <View style={styles.batteryGrid}>
                  <View style={styles.batteryGridItem}>
                    <Text style={styles.batteryGridLabel}>Estimated Time</Text>
                    <Text style={styles.batteryGridValue}>3 days 4 hrs</Text>
                  </View>
                  <View style={styles.batteryGridItem}>
                    <Text style={styles.batteryGridLabel}>Last Charged</Text>
                    <Text style={styles.batteryGridValue}>Yesterday</Text>
                  </View>
                </View>

                <View style={styles.healthBanner}>
                  <MaterialCommunityIcons
                    name="check-circle"
                    size={16}
                    color={Colors.primary}
                  />
                  <Text style={styles.healthText}>Battery health is excellent</Text>
                </View>
              </View>
            </Card.Content>
          </Card>

          {/* Sync Settings */}
          <Card style={styles.card}>
            <Card.Content>
              <View style={styles.cardHeader}>
                <Text style={styles.cardTitle}>Sync & Connection</Text>
                <Button
                  mode="outlined"
                  compact
                  icon="refresh"
                  style={styles.syncButton}
                >
                  Sync Now
                </Button>
              </View>

              <View style={styles.settingsSection}>
                <View style={styles.settingItem}>
                  <View>
                    <Text style={styles.settingTitle}>Auto Sync</Text>
                    <Text style={styles.settingSubtitle}>
                      Sync data automatically
                    </Text>
                  </View>
                  <Switch value={autoSync} onValueChange={setAutoSync} />
                </View>

                <View style={styles.settingItem}>
                  <View>
                    <Text style={styles.settingTitle}>Background Activity</Text>
                    <Text style={styles.settingSubtitle}>
                      Monitor in background
                    </Text>
                  </View>
                  <Switch
                    value={backgroundActivity}
                    onValueChange={setBackgroundActivity}
                  />
                </View>

                <View style={styles.settingItem}>
                  <View>
                    <Text style={styles.settingTitle}>Low Power Mode</Text>
                    <Text style={styles.settingSubtitle}>Extend battery life</Text>
                  </View>
                  <Switch value={lowPowerMode} onValueChange={setLowPowerMode} />
                </View>

                <View style={styles.divider} />

                <View style={styles.lastSyncRow}>
                  <Text style={styles.lastSyncLabel}>Last Sync</Text>
                  <Text style={styles.lastSyncValue}>{lastSync}</Text>
                </View>
              </View>
            </Card.Content>
          </Card>

          {/* Firmware */}
          <Card style={styles.card}>
            <Card.Content>
              <View style={styles.cardHeader}>
                <Text style={styles.cardTitle}>Firmware</Text>
                <Badge style={styles.upToDateBadge}>Up to date</Badge>
              </View>

              <View style={styles.firmwareSection}>
                <View style={styles.firmwareRow}>
                  <View>
                    <Text style={styles.firmwareLabel}>Current Version</Text>
                    <Text style={styles.firmwareValue}>{firmwareVersion}</Text>
                  </View>
                  <MaterialCommunityIcons
                    name="check-circle"
                    size={24}
                    color={Colors.success}
                  />
                </View>

                <View style={styles.autoUpdateBanner}>
                  <MaterialCommunityIcons
                    name="download"
                    size={20}
                    color={Colors.primary}
                  />
                  <View style={styles.autoUpdateText}>
                    <Text style={styles.autoUpdateTitle}>Auto-update Enabled</Text>
                    <Text style={styles.autoUpdateSubtitle}>
                      Your device will automatically update to the latest firmware
                      when available
                    </Text>
                  </View>
                </View>

                <Button mode="outlined" style={styles.checkUpdatesButton}>
                  Check for Updates
                </Button>
              </View>
            </Card.Content>
          </Card>

          {/* Device Info */}
          <Card style={styles.card}>
            <Card.Content>
              <Text style={styles.cardTitle}>Device Information</Text>

              <View style={styles.infoList}>
                <View style={styles.infoItem}>
                  <Text style={styles.infoLabel}>Model</Text>
                  <Text style={styles.infoValue}>Smart Band Pro</Text>
                </View>
                <View style={styles.infoItem}>
                  <Text style={styles.infoLabel}>Serial Number</Text>
                  <Text style={styles.infoValue}>SBP-2024-7842</Text>
                </View>
                <View style={styles.infoItem}>
                  <Text style={styles.infoLabel}>Firmware</Text>
                  <Text style={styles.infoValue}>{firmwareVersion}</Text>
                </View>
                <View style={styles.infoItem}>
                  <Text style={styles.infoLabel}>Bluetooth</Text>
                  <Text style={styles.infoValue}>5.2</Text>
                </View>
                <View style={[styles.infoItem, styles.infoItemLast]}>
                  <Text style={styles.infoLabel}>Warranty</Text>
                  <Text style={styles.infoValue}>Valid until Dec 2025</Text>
                </View>
              </View>
            </Card.Content>
          </Card>
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
    paddingBottom: Spacing.xxl,
    borderBottomLeftRadius: BorderRadius.xxl,
    borderBottomRightRadius: BorderRadius.xxl,
  },
  headerNav: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: Spacing.xl,
  },
  placeholder: {
    width: 40,
  },
  headerTitle: {
    fontSize: FontSizes.lg,
    fontWeight: '700',
    color: '#FFFFFF',
  },
  deviceCard: {
    backgroundColor: 'rgba(255,255,255,0.1)',
    borderRadius: BorderRadius.lg,
  },
  deviceHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
    marginBottom: Spacing.lg,
  },
  deviceInfoRow: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  deviceIconContainer: {
    width: 48,
    height: 48,
    borderRadius: 24,
    backgroundColor: 'rgba(255,255,255,0.2)',
    alignItems: 'center',
    justifyContent: 'center',
    marginRight: Spacing.md,
  },
  deviceName: {
    fontSize: FontSizes.lg,
    fontWeight: '600',
    color: '#FFFFFF',
  },
  deviceSerial: {
    fontSize: FontSizes.sm,
    color: 'rgba(255,255,255,0.7)',
  },
  connectedBadge: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: 'rgba(110, 220, 154, 0.2)',
    paddingHorizontal: Spacing.sm,
  },
  connectedDot: {
    width: 8,
    height: 8,
    borderRadius: 4,
    backgroundColor: '#6EDC9A',
    marginRight: Spacing.xs,
  },
  connectedText: {
    fontSize: FontSizes.xs,
    color: '#6EDC9A',
  },
  deviceStats: {
    flexDirection: 'row',
    gap: Spacing.lg,
  },
  deviceStatItem: {
    flex: 1,
    backgroundColor: 'rgba(255,255,255,0.1)',
    borderRadius: BorderRadius.sm,
    padding: Spacing.md,
  },
  deviceStatIcon: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: Spacing.xs,
  },
  deviceStatLabel: {
    fontSize: FontSizes.sm,
    color: 'rgba(255,255,255,0.8)',
    marginLeft: Spacing.xs,
  },
  deviceStatValue: {
    fontSize: FontSizes.xl,
    fontWeight: '700',
    color: '#FFFFFF',
  },
  mainContent: {
    paddingHorizontal: Spacing.lg,
    marginTop: -Spacing.md,
  },
  card: {
    borderRadius: BorderRadius.lg,
    marginBottom: Spacing.lg,
    backgroundColor: Colors.light.surface,
    ...Shadows.lg,
  },
  cardHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: Spacing.lg,
  },
  cardTitle: {
    fontSize: FontSizes.lg,
    fontWeight: '700',
    color: Colors.light.text,
  },
  batterySection: {
    gap: Spacing.md,
  },
  batteryLabelRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
  batteryLabel: {
    fontSize: FontSizes.sm,
    color: Colors.light.textSecondary,
  },
  batteryValue: {
    fontSize: FontSizes.sm,
    fontWeight: '600',
    color: Colors.light.text,
  },
  batteryProgress: {
    height: 12,
    borderRadius: 6,
  },
  batteryGrid: {
    flexDirection: 'row',
    borderTopWidth: 1,
    borderTopColor: Colors.light.border,
    paddingTop: Spacing.lg,
    marginTop: Spacing.sm,
  },
  batteryGridItem: {
    flex: 1,
  },
  batteryGridLabel: {
    fontSize: FontSizes.sm,
    color: Colors.light.textSecondary,
    marginBottom: Spacing.xs,
  },
  batteryGridValue: {
    fontSize: FontSizes.md,
    fontWeight: '500',
    color: Colors.light.text,
  },
  healthBanner: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#EBF4FF',
    borderRadius: BorderRadius.sm,
    padding: Spacing.md,
  },
  healthText: {
    fontSize: FontSizes.sm,
    color: Colors.primary,
    marginLeft: Spacing.sm,
  },
  syncButton: {
    borderRadius: BorderRadius.sm,
  },
  settingsSection: {
    gap: Spacing.lg,
  },
  settingItem: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  settingTitle: {
    fontSize: FontSizes.md,
    fontWeight: '500',
    color: Colors.light.text,
  },
  settingSubtitle: {
    fontSize: FontSizes.sm,
    color: Colors.light.textSecondary,
  },
  divider: {
    height: 1,
    backgroundColor: Colors.light.border,
  },
  lastSyncRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
  lastSyncLabel: {
    fontSize: FontSizes.sm,
    color: Colors.light.textSecondary,
  },
  lastSyncValue: {
    fontSize: FontSizes.sm,
    fontWeight: '500',
    color: Colors.light.text,
  },
  upToDateBadge: {
    backgroundColor: '#D1FAE5',
  },
  firmwareSection: {
    gap: Spacing.lg,
  },
  firmwareRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  firmwareLabel: {
    fontSize: FontSizes.md,
    fontWeight: '500',
    color: Colors.light.text,
  },
  firmwareValue: {
    fontSize: FontSizes.sm,
    color: Colors.light.textSecondary,
  },
  autoUpdateBanner: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    backgroundColor: Colors.light.surfaceVariant,
    borderRadius: BorderRadius.sm,
    padding: Spacing.lg,
  },
  autoUpdateText: {
    flex: 1,
    marginLeft: Spacing.md,
  },
  autoUpdateTitle: {
    fontSize: FontSizes.md,
    fontWeight: '500',
    color: Colors.light.text,
    marginBottom: Spacing.xs,
  },
  autoUpdateSubtitle: {
    fontSize: FontSizes.sm,
    color: Colors.light.textSecondary,
    lineHeight: 20,
  },
  checkUpdatesButton: {
    borderRadius: BorderRadius.md,
    borderColor: Colors.light.border,
    borderWidth: 2,
  },
  infoList: {
    marginTop: Spacing.lg,
  },
  infoItem: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    paddingVertical: Spacing.md,
    borderBottomWidth: 1,
    borderBottomColor: Colors.light.border,
  },
  infoItemLast: {
    borderBottomWidth: 0,
  },
  infoLabel: {
    fontSize: FontSizes.md,
    color: Colors.light.textSecondary,
  },
  infoValue: {
    fontSize: FontSizes.md,
    fontWeight: '500',
    color: Colors.light.text,
  },
});
