import React from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  TouchableOpacity,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Card, Button, Badge, ProgressBar } from 'react-native-paper';
import { MaterialCommunityIcons } from '@expo/vector-icons';
import { useNavigation } from '@react-navigation/native';
import { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { Colors, Spacing, BorderRadius, FontSizes, Shadows } from '../theme';
import { RootStackParamList } from '../types';

type HomeScreenNavigationProp = NativeStackNavigationProp<RootStackParamList>;

interface HomeScreenProps {
  onTriggerEmergency: () => void;
}

export function HomeScreen({ onTriggerEmergency }: HomeScreenProps) {
  const navigation = useNavigation<HomeScreenNavigationProp>();

  const status = 'normal'; // normal | anomaly | emergency
  const lastCheck = '2 mins ago';
  const motionLevel = 'Normal';

  const statusConfig = {
    normal: {
      bgColor: Colors.success,
      text: 'All Systems Normal',
      iconName: 'pulse',
      textColor: '#FFFFFF',
    },
    anomaly: {
      bgColor: Colors.warning,
      text: 'Anomaly Detected',
      iconName: 'alert',
      textColor: '#1F2937',
    },
    emergency: {
      bgColor: Colors.danger,
      text: 'Emergency Active',
      iconName: 'alert',
      textColor: '#FFFFFF',
    },
  };

  const currentStatus = statusConfig[status as keyof typeof statusConfig];

  return (
    <SafeAreaView style={styles.container} edges={['top']}>
      <ScrollView
        style={styles.scrollView}
        showsVerticalScrollIndicator={false}
        contentContainerStyle={styles.scrollContent}
      >
        {/* Header with Gradient */}
        <View style={styles.headerGradient}>
          <View style={styles.headerContent}>
            <View>
              <Text style={styles.brandLabel}>Sentinel 360</Text>
              <Text style={styles.userName}>Sarah Johnson</Text>
            </View>
            <TouchableOpacity style={styles.bluetoothButton}>
              <MaterialCommunityIcons
                name="bluetooth"
                size={20}
                color="#FFFFFF"
              />
            </TouchableOpacity>
          </View>

          {/* Status Card */}
          <View style={[styles.statusCard, { backgroundColor: currentStatus.bgColor }]}>
            <View style={styles.statusHeader}>
              <View style={styles.statusIconRow}>
                <View style={styles.statusIconContainer}>
                  <MaterialCommunityIcons
                    name={currentStatus.iconName as any}
                    size={24}
                    color={currentStatus.textColor}
                  />
                </View>
                <View>
                  <Text style={[styles.statusTitle, { color: currentStatus.textColor }]}>
                    {currentStatus.text}
                  </Text>
                  <Text
                    style={[
                      styles.statusSubtitle,
                      { color: currentStatus.textColor, opacity: 0.9 },
                    ]}
                  >
                    Monitoring active
                  </Text>
                </View>
              </View>
              <Badge style={styles.liveBadge}>Live</Badge>
            </View>

            <View style={styles.healthSection}>
              <View style={styles.healthLabelRow}>
                <Text style={[styles.healthLabel, { color: currentStatus.textColor }]}>
                  System Health
                </Text>
                <Text style={[styles.healthValue, { color: currentStatus.textColor }]}>
                  98%
                </Text>
              </View>
              <ProgressBar
                progress={0.98}
                color="rgba(255,255,255,0.8)"
                style={styles.progressBar}
              />
            </View>
          </View>
        </View>

        {/* Main Content */}
        <View style={styles.mainContent}>
          {/* Device Status Panel */}
          <Card style={styles.card}>
            <Card.Content>
              <Text style={styles.cardTitle}>Device Status</Text>

              <View style={styles.deviceGrid}>
                <View style={styles.deviceItem}>
                  <View style={[styles.deviceIcon, { backgroundColor: '#EBF4FF' }]}>
                    <MaterialCommunityIcons
                      name="pulse"
                      size={24}
                      color={Colors.primary}
                    />
                  </View>
                  <View>
                    <Text style={styles.deviceLabel}>Motion</Text>
                    <Text style={styles.deviceValue}>{motionLevel}</Text>
                  </View>
                </View>

                <View style={styles.deviceItem}>
                  <View style={[styles.deviceIcon, { backgroundColor: '#E6FAF0' }]}>
                    <MaterialCommunityIcons
                      name="bluetooth"
                      size={24}
                      color={Colors.success}
                    />
                  </View>
                  <View>
                    <Text style={styles.deviceLabel}>Connection</Text>
                    <Text style={styles.deviceValue}>Connected</Text>
                  </View>
                </View>

                <View style={[styles.deviceItem, styles.deviceItemFull]}>
                  <View style={[styles.deviceIcon, { backgroundColor: '#F3E8FF' }]}>
                    <MaterialCommunityIcons
                      name="clock-outline"
                      size={24}
                      color="#8B5CF6"
                    />
                  </View>
                  <View>
                    <Text style={styles.deviceLabel}>Last Anomaly Check</Text>
                    <Text style={styles.deviceValue}>{lastCheck}</Text>
                  </View>
                </View>
              </View>
            </Card.Content>
          </Card>

          {/* Action Buttons */}
          <Button
            mode="contained"
            onPress={() => navigation.navigate('TripTracking')}
            style={styles.tripButton}
            contentStyle={styles.tripButtonContent}
            labelStyle={styles.tripButtonLabel}
            icon={() => (
              <View style={styles.tripButtonIcon}>
                <MaterialCommunityIcons name="play" size={20} color="#FFFFFF" />
              </View>
            )}
          >
            Start Trip Tracking
          </Button>

          <View style={styles.buttonGrid}>
            <Button
              mode="outlined"
              onPress={() => {}}
              style={styles.gridButton}
              contentStyle={styles.gridButtonContent}
              icon="history"
            >
              History
            </Button>
            <Button
              mode="outlined"
              onPress={() => {}}
              style={styles.gridButton}
              contentStyle={styles.gridButtonContent}
              icon="cog"
            >
              Device
            </Button>
          </View>

          {/* Emergency Card */}
          <Card style={styles.emergencyCard}>
            <Card.Content style={styles.emergencyContent}>
              <View style={styles.emergencyLeft}>
                <MaterialCommunityIcons
                  name="alert"
                  size={24}
                  color={Colors.danger}
                />
                <View style={styles.emergencyText}>
                  <Text style={styles.emergencyTitle}>Emergency SOS</Text>
                  <Text style={styles.emergencySubtitle}>Tap to trigger alert</Text>
                </View>
              </View>
              <Button
                mode="contained"
                onPress={onTriggerEmergency}
                buttonColor={Colors.danger}
                style={styles.sosButton}
              >
                SOS
              </Button>
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
    paddingBottom: 100, // Space for bottom nav
  },
  headerGradient: {
    backgroundColor: Colors.primary,
    paddingHorizontal: Spacing.lg,
    paddingTop: Spacing.lg,
    paddingBottom: Spacing.xxxl,
    borderBottomLeftRadius: BorderRadius.xxl,
    borderBottomRightRadius: BorderRadius.xxl,
  },
  headerContent: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: Spacing.xxl,
  },
  brandLabel: {
    fontSize: FontSizes.sm,
    color: 'rgba(255,255,255,0.8)',
    marginBottom: 4,
  },
  userName: {
    fontSize: FontSizes.xl,
    fontWeight: '700',
    color: '#FFFFFF',
  },
  bluetoothButton: {
    width: 48,
    height: 48,
    borderRadius: 24,
    backgroundColor: 'rgba(255,255,255,0.2)',
    alignItems: 'center',
    justifyContent: 'center',
  },
  statusCard: {
    borderRadius: BorderRadius.lg,
    padding: Spacing.lg,
    ...Shadows.xl,
  },
  statusHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
    marginBottom: Spacing.lg,
  },
  statusIconRow: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  statusIconContainer: {
    width: 48,
    height: 48,
    borderRadius: 24,
    backgroundColor: 'rgba(255,255,255,0.2)',
    alignItems: 'center',
    justifyContent: 'center',
    marginRight: Spacing.md,
  },
  statusTitle: {
    fontSize: FontSizes.lg,
    fontWeight: '700',
  },
  statusSubtitle: {
    fontSize: FontSizes.sm,
  },
  liveBadge: {
    backgroundColor: 'rgba(255,255,255,0.2)',
  },
  healthSection: {
    marginTop: Spacing.sm,
  },
  healthLabelRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginBottom: Spacing.sm,
  },
  healthLabel: {
    fontSize: FontSizes.sm,
    opacity: 0.9,
  },
  healthValue: {
    fontSize: FontSizes.sm,
    fontWeight: '600',
  },
  progressBar: {
    height: 8,
    borderRadius: 4,
    backgroundColor: 'rgba(255,255,255,0.2)',
  },
  mainContent: {
    paddingHorizontal: Spacing.lg,
    marginTop: -Spacing.lg,
  },
  card: {
    borderRadius: BorderRadius.lg,
    marginBottom: Spacing.lg,
    backgroundColor: Colors.light.surface,
    ...Shadows.lg,
  },
  cardTitle: {
    fontSize: FontSizes.lg,
    fontWeight: '700',
    color: Colors.light.text,
    marginBottom: Spacing.lg,
  },
  deviceGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
  },
  deviceItem: {
    flexDirection: 'row',
    alignItems: 'center',
    width: '50%',
    marginBottom: Spacing.lg,
  },
  deviceItemFull: {
    width: '100%',
  },
  deviceIcon: {
    width: 48,
    height: 48,
    borderRadius: BorderRadius.md,
    alignItems: 'center',
    justifyContent: 'center',
    marginRight: Spacing.md,
  },
  deviceLabel: {
    fontSize: FontSizes.sm,
    color: Colors.light.textSecondary,
  },
  deviceValue: {
    fontSize: FontSizes.md,
    fontWeight: '600',
    color: Colors.light.text,
  },
  tripButton: {
    borderRadius: BorderRadius.lg,
    marginBottom: Spacing.md,
    backgroundColor: Colors.primary,
  },
  tripButtonContent: {
    height: 64,
    justifyContent: 'flex-start',
    paddingLeft: Spacing.lg,
  },
  tripButtonLabel: {
    fontSize: FontSizes.lg,
    fontWeight: '600',
    marginLeft: Spacing.md,
  },
  tripButtonIcon: {
    width: 40,
    height: 40,
    borderRadius: 20,
    backgroundColor: 'rgba(255,255,255,0.2)',
    alignItems: 'center',
    justifyContent: 'center',
  },
  buttonGrid: {
    flexDirection: 'row',
    gap: Spacing.md,
    marginBottom: Spacing.lg,
  },
  gridButton: {
    flex: 1,
    borderRadius: BorderRadius.md,
    borderColor: Colors.light.border,
    borderWidth: 2,
    backgroundColor: Colors.light.surface,
  },
  gridButtonContent: {
    height: 56,
  },
  emergencyCard: {
    borderRadius: BorderRadius.lg,
    backgroundColor: '#FEF2F2',
    borderWidth: 2,
    borderColor: '#FECACA',
    marginBottom: Spacing.lg,
  },
  emergencyContent: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  emergencyLeft: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  emergencyText: {
    marginLeft: Spacing.md,
  },
  emergencyTitle: {
    fontSize: FontSizes.md,
    fontWeight: '600',
    color: Colors.light.text,
  },
  emergencySubtitle: {
    fontSize: FontSizes.sm,
    color: Colors.light.textSecondary,
  },
  sosButton: {
    borderRadius: BorderRadius.md,
  },
});
