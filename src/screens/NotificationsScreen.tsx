import React, { useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  TouchableOpacity,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Card, Badge, SegmentedButtons } from 'react-native-paper';
import { MaterialCommunityIcons } from '@expo/vector-icons';
import { Colors, Spacing, BorderRadius, FontSizes, Shadows } from '../theme';
import { Notification } from '../types';

const notifications: Notification[] = [
  {
    id: '1',
    type: 'critical',
    title: 'Fall Detected',
    description: 'Sudden impact detected at 3:45 PM near Central Park',
    time: '2 hours ago',
    status: 'Critical',
    iconName: 'alert',
    color: Colors.danger,
  },
  {
    id: '2',
    type: 'warning',
    title: 'Prolonged Stillness',
    description: 'No movement detected for 30 minutes during active trip',
    time: '5 hours ago',
    status: 'Reviewed',
    iconName: 'pulse',
    color: Colors.warning,
  },
  {
    id: '3',
    type: 'critical',
    title: 'Manual SOS Trigger',
    description: 'Emergency button pressed by user',
    time: 'Yesterday',
    status: 'Resolved',
    iconName: 'phone',
    color: Colors.danger,
  },
  {
    id: '4',
    type: 'warning',
    title: 'Irregular Activity Pattern',
    description: 'Unusual movement detected during trip',
    time: 'Yesterday',
    status: 'Resolved',
    iconName: 'pulse',
    color: Colors.warning,
  },
  {
    id: '5',
    type: 'info',
    title: 'Trip Completed',
    description: 'Safe arrival confirmed at destination',
    time: '2 days ago',
    status: 'Resolved',
    iconName: 'map-marker',
    color: Colors.success,
  },
];

export function NotificationsScreen() {
  const [selectedTab, setSelectedTab] = useState('all');

  const getStatusStyle = (status: string) => {
    switch (status) {
      case 'Critical':
        return { backgroundColor: '#FEE2E2', color: '#B91C1C' };
      case 'Reviewed':
        return { backgroundColor: '#FEF3C7', color: '#B45309' };
      case 'Resolved':
        return { backgroundColor: '#D1FAE5', color: '#047857' };
      default:
        return { backgroundColor: '#F3F4F6', color: '#6B7280' };
    }
  };

  const filteredNotifications = notifications.filter((n) => {
    if (selectedTab === 'all') return true;
    if (selectedTab === 'critical') return n.type === 'critical';
    if (selectedTab === 'warnings') return n.type === 'warning';
    return true;
  });

  const criticalCount = notifications.filter((n) => n.type === 'critical').length;
  const warningsCount = notifications.filter((n) => n.type === 'warning').length;

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
            <Text style={styles.headerTitle}>Alerts & Notifications</Text>
            <View style={styles.placeholder} />
          </View>

          {/* Stats */}
          <View style={styles.statsRow}>
            <Card style={styles.statCard}>
              <Card.Content style={styles.statContent}>
                <Text style={styles.statValue}>{criticalCount}</Text>
                <Text style={styles.statLabel}>Critical</Text>
              </Card.Content>
            </Card>
            <Card style={styles.statCard}>
              <Card.Content style={styles.statContent}>
                <Text style={styles.statValue}>{warningsCount}</Text>
                <Text style={styles.statLabel}>Warning</Text>
              </Card.Content>
            </Card>
            <Card style={styles.statCard}>
              <Card.Content style={styles.statContent}>
                <Text style={styles.statValue}>{notifications.length}</Text>
                <Text style={styles.statLabel}>Total</Text>
              </Card.Content>
            </Card>
          </View>
        </View>

        {/* Tabs */}
        <View style={styles.mainContent}>
          <SegmentedButtons
            value={selectedTab}
            onValueChange={setSelectedTab}
            buttons={[
              { value: 'all', label: 'All' },
              { value: 'critical', label: 'Critical' },
              { value: 'warnings', label: 'Warnings' },
            ]}
            style={styles.segmentedButtons}
          />

          {/* Notifications List */}
          {filteredNotifications.length === 0 ? (
            <Card style={styles.emptyCard}>
              <Card.Content style={styles.emptyContent}>
                <MaterialCommunityIcons
                  name="alert"
                  size={48}
                  color={Colors.light.textTertiary}
                />
                <Text style={styles.emptyText}>No notifications</Text>
              </Card.Content>
            </Card>
          ) : (
            filteredNotifications.map((notification) => (
              <Card key={notification.id} style={styles.notificationCard}>
                <Card.Content style={styles.notificationContent}>
                  <View
                    style={[
                      styles.notificationIcon,
                      { backgroundColor: `${notification.color}20` },
                    ]}
                  >
                    <MaterialCommunityIcons
                      name={notification.iconName as any}
                      size={24}
                      color={notification.color}
                    />
                  </View>
                  <View style={styles.notificationText}>
                    <View style={styles.notificationHeader}>
                      <Text style={styles.notificationTitle}>
                        {notification.title}
                      </Text>
                      <Badge
                        style={[
                          styles.statusBadge,
                          {
                            backgroundColor: getStatusStyle(notification.status)
                              .backgroundColor,
                          },
                        ]}
                      >
                        <Text
                          style={{
                            color: getStatusStyle(notification.status).color,
                            fontSize: FontSizes.xs,
                          }}
                        >
                          {notification.status}
                        </Text>
                      </Badge>
                    </View>
                    <Text style={styles.notificationDescription}>
                      {notification.description}
                    </Text>
                    <View style={styles.timeRow}>
                      <MaterialCommunityIcons
                        name="clock-outline"
                        size={14}
                        color={Colors.light.textTertiary}
                      />
                      <Text style={styles.timeText}>{notification.time}</Text>
                    </View>
                  </View>
                </Card.Content>
              </Card>
            ))
          )}
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
  statsRow: {
    flexDirection: 'row',
    gap: Spacing.md,
  },
  statCard: {
    flex: 1,
    backgroundColor: 'rgba(255,255,255,0.1)',
    borderRadius: BorderRadius.md,
  },
  statContent: {
    alignItems: 'center',
    paddingVertical: Spacing.sm,
  },
  statValue: {
    fontSize: FontSizes.xxl,
    fontWeight: '700',
    color: '#FFFFFF',
  },
  statLabel: {
    fontSize: FontSizes.sm,
    color: 'rgba(255,255,255,0.8)',
  },
  mainContent: {
    paddingHorizontal: Spacing.lg,
    marginTop: -Spacing.md,
  },
  segmentedButtons: {
    backgroundColor: Colors.light.surface,
    borderRadius: BorderRadius.md,
    marginBottom: Spacing.lg,
    ...Shadows.lg,
  },
  emptyCard: {
    borderRadius: BorderRadius.lg,
    backgroundColor: Colors.light.surface,
    ...Shadows.lg,
  },
  emptyContent: {
    alignItems: 'center',
    paddingVertical: Spacing.xxl,
  },
  emptyText: {
    fontSize: FontSizes.md,
    color: Colors.light.textTertiary,
    marginTop: Spacing.md,
  },
  notificationCard: {
    borderRadius: BorderRadius.lg,
    marginBottom: Spacing.md,
    backgroundColor: Colors.light.surface,
    ...Shadows.lg,
  },
  notificationContent: {
    flexDirection: 'row',
  },
  notificationIcon: {
    width: 48,
    height: 48,
    borderRadius: BorderRadius.md,
    alignItems: 'center',
    justifyContent: 'center',
    marginRight: Spacing.md,
  },
  notificationText: {
    flex: 1,
  },
  notificationHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
    marginBottom: Spacing.sm,
  },
  notificationTitle: {
    fontSize: FontSizes.md,
    fontWeight: '600',
    color: Colors.light.text,
    flex: 1,
    marginRight: Spacing.sm,
  },
  statusBadge: {
    paddingHorizontal: Spacing.sm,
  },
  notificationDescription: {
    fontSize: FontSizes.sm,
    color: Colors.light.textSecondary,
    marginBottom: Spacing.sm,
    lineHeight: 20,
  },
  timeRow: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  timeText: {
    fontSize: FontSizes.sm,
    color: Colors.light.textTertiary,
    marginLeft: Spacing.xs,
  },
});
