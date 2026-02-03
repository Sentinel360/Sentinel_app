import React, { useState, useEffect, useRef } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  TouchableOpacity,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Card, Button, Badge } from 'react-native-paper';
import { MaterialCommunityIcons } from '@expo/vector-icons';
import { useNavigation } from '@react-navigation/native';
import { Colors, Spacing, BorderRadius, FontSizes, Shadows } from '../theme';
import { TripEvent } from '../types';

interface TripTrackingScreenProps {
  onTriggerEmergency: () => void;
}

export function TripTrackingScreen({ onTriggerEmergency }: TripTrackingScreenProps) {
  const navigation = useNavigation();
  const [isTracking, setIsTracking] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [duration, setDuration] = useState(0);
  const [events, setEvents] = useState<TripEvent[]>([]);
  const intervalRef = useRef<NodeJS.Timeout | null>(null);

  useEffect(() => {
    if (isTracking && !isPaused) {
      intervalRef.current = setInterval(() => {
        setDuration((d) => d + 1);
      }, 1000);
    } else {
      if (intervalRef.current) {
        clearInterval(intervalRef.current);
      }
    }
    return () => {
      if (intervalRef.current) {
        clearInterval(intervalRef.current);
      }
    };
  }, [isTracking, isPaused]);

  const formatTime = (seconds: number): string => {
    const hrs = Math.floor(seconds / 3600);
    const mins = Math.floor((seconds % 3600) / 60);
    const secs = seconds % 60;
    return `${hrs.toString().padStart(2, '0')}:${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
  };

  const handleStart = () => {
    setIsTracking(true);
    setEvents([
      {
        id: Date.now().toString(),
        time: new Date().toLocaleTimeString(),
        type: 'start',
        message: 'Trip started',
        iconName: 'play',
        color: Colors.primary,
      },
    ]);
  };

  const handlePause = () => {
    setIsPaused(!isPaused);
  };

  const handleEnd = () => {
    setIsTracking(false);
    setIsPaused(false);
    setEvents((prev) => [
      ...prev,
      {
        id: Date.now().toString(),
        time: new Date().toLocaleTimeString(),
        type: 'end',
        message: 'Trip ended safely',
        iconName: 'check-circle',
        color: Colors.success,
      },
    ]);
  };

  const simulateAnomaly = () => {
    setEvents((prev) => [
      ...prev,
      {
        id: Date.now().toString(),
        time: new Date().toLocaleTimeString(),
        type: 'anomaly',
        message: 'Sudden movement detected',
        iconName: 'alert',
        color: Colors.warning,
      },
    ]);
  };

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
            <TouchableOpacity
              style={styles.backButton}
              onPress={() => navigation.goBack()}
            >
              <MaterialCommunityIcons
                name="arrow-left"
                size={20}
                color="#FFFFFF"
              />
            </TouchableOpacity>
            <Text style={styles.headerTitle}>Trip Tracking</Text>
            <View style={styles.placeholder} />
          </View>

          {/* Timer Display */}
          <View style={styles.timerSection}>
            <Text style={styles.timerText}>{formatTime(duration)}</Text>
            <Text style={styles.timerStatus}>
              {isTracking
                ? isPaused
                  ? 'Paused'
                  : 'Tracking in progress'
                : 'Ready to start'}
            </Text>
          </View>

          {/* Control Buttons */}
          <View style={styles.controlButtons}>
            {!isTracking ? (
              <TouchableOpacity
                style={styles.playButton}
                onPress={handleStart}
              >
                <MaterialCommunityIcons
                  name="play"
                  size={32}
                  color={Colors.primary}
                />
              </TouchableOpacity>
            ) : (
              <>
                <TouchableOpacity
                  style={styles.controlButton}
                  onPress={handlePause}
                >
                  <MaterialCommunityIcons
                    name={isPaused ? 'play' : 'pause'}
                    size={24}
                    color="#FFFFFF"
                  />
                </TouchableOpacity>
                <TouchableOpacity
                  style={styles.stopButton}
                  onPress={handleEnd}
                >
                  <MaterialCommunityIcons
                    name="stop"
                    size={24}
                    color={Colors.primary}
                  />
                </TouchableOpacity>
              </>
            )}
          </View>
        </View>

        {/* Main Content */}
        <View style={styles.mainContent}>
          {/* Stats Cards */}
          <View style={styles.statsGrid}>
            <Card style={styles.statCard}>
              <Card.Content style={styles.statContent}>
                <MaterialCommunityIcons
                  name="pulse"
                  size={24}
                  color={Colors.primary}
                />
                <Text style={styles.statLabel}>Motion</Text>
                <Text style={styles.statValue}>Active</Text>
              </Card.Content>
            </Card>

            <Card style={styles.statCard}>
              <Card.Content style={styles.statContent}>
                <MaterialCommunityIcons
                  name="map-marker"
                  size={24}
                  color={Colors.success}
                />
                <Text style={styles.statLabel}>Distance</Text>
                <Text style={styles.statValue}>2.4 km</Text>
              </Card.Content>
            </Card>

            <Card style={styles.statCard}>
              <Card.Content style={styles.statContent}>
                <MaterialCommunityIcons
                  name="clock-outline"
                  size={24}
                  color="#8B5CF6"
                />
                <Text style={styles.statLabel}>Checkpoints</Text>
                <Text style={styles.statValue}>3</Text>
              </Card.Content>
            </Card>
          </View>

          {/* Map Preview */}
          <Card style={styles.card}>
            <Card.Content>
              <View style={styles.cardHeader}>
                <Text style={styles.cardTitle}>Live Location</Text>
                <Badge style={styles.sharingBadge}>Sharing</Badge>
              </View>
              <View style={styles.mapPlaceholder}>
                <MaterialCommunityIcons
                  name="map-marker"
                  size={48}
                  color={Colors.primary}
                />
              </View>
            </Card.Content>
          </Card>

          {/* Timeline */}
          <Card style={styles.card}>
            <Card.Content>
              <View style={styles.cardHeader}>
                <Text style={styles.cardTitle}>Trip Timeline</Text>
                {isTracking && (
                  <TouchableOpacity onPress={simulateAnomaly}>
                    <Text style={styles.simulateText}>Simulate Event</Text>
                  </TouchableOpacity>
                )}
              </View>

              {events.length === 0 ? (
                <View style={styles.emptyTimeline}>
                  <MaterialCommunityIcons
                    name="clock-outline"
                    size={32}
                    color={Colors.light.textTertiary}
                  />
                  <Text style={styles.emptyText}>
                    Start a trip to see timeline events
                  </Text>
                </View>
              ) : (
                <View style={styles.timeline}>
                  {events.map((event) => (
                    <View key={event.id} style={styles.timelineItem}>
                      <View
                        style={[
                          styles.timelineIcon,
                          { backgroundColor: `${event.color}20` },
                        ]}
                      >
                        <MaterialCommunityIcons
                          name={event.iconName as any}
                          size={20}
                          color={event.color}
                        />
                      </View>
                      <View style={styles.timelineText}>
                        <Text style={styles.timelineMessage}>{event.message}</Text>
                        <Text style={styles.timelineTime}>{event.time}</Text>
                      </View>
                    </View>
                  ))}
                </View>
              )}
            </Card.Content>
          </Card>

          {/* Emergency Button */}
          {isTracking && (
            <Button
              mode="contained"
              onPress={onTriggerEmergency}
              buttonColor={Colors.danger}
              style={styles.emergencyButton}
              contentStyle={styles.emergencyButtonContent}
              icon="alert"
            >
              Trigger Emergency
            </Button>
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
    paddingBottom: Spacing.xxxl,
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
  backButton: {
    width: 40,
    height: 40,
    borderRadius: 20,
    backgroundColor: 'rgba(255,255,255,0.2)',
    alignItems: 'center',
    justifyContent: 'center',
  },
  headerTitle: {
    fontSize: FontSizes.lg,
    fontWeight: '700',
    color: '#FFFFFF',
  },
  placeholder: {
    width: 40,
  },
  timerSection: {
    alignItems: 'center',
    marginBottom: Spacing.xl,
  },
  timerText: {
    fontSize: 48,
    fontWeight: '300',
    color: '#FFFFFF',
    fontVariant: ['tabular-nums'],
  },
  timerStatus: {
    fontSize: FontSizes.md,
    color: 'rgba(255,255,255,0.8)',
    marginTop: Spacing.sm,
  },
  controlButtons: {
    flexDirection: 'row',
    justifyContent: 'center',
    alignItems: 'center',
    gap: Spacing.lg,
  },
  playButton: {
    width: 80,
    height: 80,
    borderRadius: 40,
    backgroundColor: '#FFFFFF',
    alignItems: 'center',
    justifyContent: 'center',
    ...Shadows.xl,
  },
  controlButton: {
    width: 64,
    height: 64,
    borderRadius: 32,
    backgroundColor: 'rgba(255,255,255,0.2)',
    alignItems: 'center',
    justifyContent: 'center',
  },
  stopButton: {
    width: 64,
    height: 64,
    borderRadius: 32,
    backgroundColor: '#FFFFFF',
    alignItems: 'center',
    justifyContent: 'center',
    ...Shadows.xl,
  },
  mainContent: {
    paddingHorizontal: Spacing.lg,
    marginTop: -Spacing.lg,
  },
  statsGrid: {
    flexDirection: 'row',
    gap: Spacing.md,
    marginBottom: Spacing.lg,
  },
  statCard: {
    flex: 1,
    borderRadius: BorderRadius.lg,
    backgroundColor: Colors.light.surface,
    ...Shadows.lg,
  },
  statContent: {
    alignItems: 'center',
    paddingVertical: Spacing.md,
  },
  statLabel: {
    fontSize: FontSizes.sm,
    color: Colors.light.textSecondary,
    marginTop: Spacing.sm,
  },
  statValue: {
    fontSize: FontSizes.md,
    fontWeight: '600',
    color: Colors.light.text,
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
  sharingBadge: {
    backgroundColor: '#E6FAF0',
  },
  simulateText: {
    fontSize: FontSizes.xs,
    color: Colors.light.textTertiary,
  },
  mapPlaceholder: {
    height: 160,
    borderRadius: BorderRadius.md,
    backgroundColor: '#EBF4FF',
    alignItems: 'center',
    justifyContent: 'center',
  },
  emptyTimeline: {
    alignItems: 'center',
    paddingVertical: Spacing.xxl,
  },
  emptyText: {
    fontSize: FontSizes.md,
    color: Colors.light.textTertiary,
    marginTop: Spacing.sm,
  },
  timeline: {
    gap: Spacing.lg,
  },
  timelineItem: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  timelineIcon: {
    width: 40,
    height: 40,
    borderRadius: 20,
    alignItems: 'center',
    justifyContent: 'center',
    marginRight: Spacing.md,
  },
  timelineText: {
    flex: 1,
  },
  timelineMessage: {
    fontSize: FontSizes.md,
    fontWeight: '500',
    color: Colors.light.text,
  },
  timelineTime: {
    fontSize: FontSizes.sm,
    color: Colors.light.textSecondary,
  },
  emergencyButton: {
    borderRadius: BorderRadius.md,
  },
  emergencyButtonContent: {
    height: 56,
  },
});
