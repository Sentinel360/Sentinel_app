import React from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  Dimensions,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Card } from 'react-native-paper';
import { MaterialCommunityIcons } from '@expo/vector-icons';
import {
  LineChart,
  BarChart,
} from 'react-native-chart-kit';
import { Colors, Spacing, BorderRadius, FontSizes, Shadows } from '../theme';

const screenWidth = Dimensions.get('window').width - Spacing.lg * 2;

const weeklyAnomaliesData = {
  labels: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
  datasets: [{ data: [0, 2, 1, 0, 3, 1, 0] }],
};

const motionActivityData = {
  labels: ['00:00', '04:00', '08:00', '12:00', '16:00', '20:00'],
  datasets: [{ data: [10, 5, 45, 60, 75, 40] }],
};

const tripData = {
  labels: ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'],
  datasets: [{ data: [12, 15, 18, 14, 20, 22] }],
};

const chartConfig = {
  backgroundColor: Colors.light.surface,
  backgroundGradientFrom: Colors.light.surface,
  backgroundGradientTo: Colors.light.surface,
  decimalPlaces: 0,
  color: (opacity = 1) => `rgba(74, 108, 247, ${opacity})`,
  labelColor: () => Colors.light.textSecondary,
  style: {
    borderRadius: BorderRadius.md,
  },
  propsForDots: {
    r: '5',
    strokeWidth: '2',
    stroke: Colors.primary,
  },
};

export function AnalyticsScreen() {
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
            <Text style={styles.headerTitle}>Analytics & Insights</Text>
            <View style={styles.calendarButton}>
              <MaterialCommunityIcons
                name="calendar"
                size={20}
                color="#FFFFFF"
              />
            </View>
          </View>
          <Text style={styles.headerSubtitle}>Weekly Health Summary</Text>
        </View>

        <View style={styles.mainContent}>
          {/* Summary Cards */}
          <View style={styles.summaryGrid}>
            <Card style={[styles.summaryCard, styles.primaryCard]}>
              <Card.Content style={styles.summaryContent}>
                <View style={styles.summaryIconRow}>
                  <View style={styles.summaryIconBg}>
                    <MaterialCommunityIcons
                      name="pulse"
                      size={16}
                      color="#FFFFFF"
                    />
                  </View>
                  <Text style={styles.summaryLabel}>Avg. Motion</Text>
                </View>
                <Text style={styles.summaryValue}>45</Text>
                <Text style={styles.summarySubValue}>activity level</Text>
              </Card.Content>
            </Card>

            <Card style={[styles.summaryCard, styles.successCard]}>
              <Card.Content style={styles.summaryContent}>
                <View style={styles.summaryIconRow}>
                  <View style={styles.summaryIconBg}>
                    <MaterialCommunityIcons
                      name="trending-up"
                      size={16}
                      color="#FFFFFF"
                    />
                  </View>
                  <Text style={styles.summaryLabel}>Trips</Text>
                </View>
                <Text style={styles.summaryValue}>18</Text>
                <Text style={styles.summarySubValue}>this week</Text>
              </Card.Content>
            </Card>

            <Card style={[styles.summaryCard, styles.warningCard]}>
              <Card.Content style={styles.summaryContent}>
                <View style={styles.summaryIconRow}>
                  <View style={styles.summaryIconBg}>
                    <MaterialCommunityIcons
                      name="alert"
                      size={16}
                      color="#FFFFFF"
                    />
                  </View>
                  <Text style={styles.summaryLabel}>Anomalies</Text>
                </View>
                <Text style={styles.summaryValue}>7</Text>
                <Text style={styles.summarySubValue}>this week</Text>
              </Card.Content>
            </Card>

            <Card style={[styles.summaryCard, styles.purpleCard]}>
              <Card.Content style={styles.summaryContent}>
                <View style={styles.summaryIconRow}>
                  <View style={styles.summaryIconBg}>
                    <MaterialCommunityIcons
                      name="shield-check"
                      size={16}
                      color="#FFFFFF"
                    />
                  </View>
                  <Text style={styles.summaryLabel}>Safety Score</Text>
                </View>
                <Text style={styles.summaryValue}>94</Text>
                <Text style={styles.summarySubValue}>out of 100</Text>
              </Card.Content>
            </Card>
          </View>

          {/* Weekly Anomalies Chart */}
          <Card style={styles.chartCard}>
            <Card.Content>
              <View style={styles.chartHeader}>
                <Text style={styles.chartTitle}>Weekly Anomalies</Text>
                <View style={styles.legendRow}>
                  <View style={[styles.legendDot, { backgroundColor: Colors.warning }]} />
                  <Text style={styles.legendText}>Detected Events</Text>
                </View>
              </View>
              <BarChart
                data={weeklyAnomaliesData}
                width={screenWidth - Spacing.lg * 2}
                height={180}
                chartConfig={{
                  ...chartConfig,
                  color: () => Colors.warning,
                }}
                style={styles.chart}
                showValuesOnTopOfBars
                fromZero
                yAxisLabel=""
                yAxisSuffix=""
              />
            </Card.Content>
          </Card>

          {/* Motion Activity Chart */}
          <Card style={styles.chartCard}>
            <Card.Content>
              <View style={styles.chartHeader}>
                <Text style={styles.chartTitle}>Motion Activity Pattern</Text>
                <View style={styles.legendRow}>
                  <View style={[styles.legendDot, { backgroundColor: Colors.primary }]} />
                  <Text style={styles.legendText}>24h Activity</Text>
                </View>
              </View>
              <LineChart
                data={motionActivityData}
                width={screenWidth - Spacing.lg * 2}
                height={180}
                chartConfig={chartConfig}
                style={styles.chart}
                bezier
              />
            </Card.Content>
          </Card>

          {/* Trip Frequency Chart */}
          <Card style={styles.chartCard}>
            <Card.Content>
              <View style={styles.chartHeader}>
                <Text style={styles.chartTitle}>Trip Frequency</Text>
                <View style={styles.legendRow}>
                  <View style={[styles.legendDot, { backgroundColor: Colors.success }]} />
                  <Text style={styles.legendText}>Monthly Trips</Text>
                </View>
              </View>
              <LineChart
                data={tripData}
                width={screenWidth - Spacing.lg * 2}
                height={180}
                chartConfig={{
                  ...chartConfig,
                  color: () => Colors.success,
                }}
                style={styles.chart}
                bezier
              />
            </Card.Content>
          </Card>

          {/* Insights */}
          <Card style={styles.insightCard}>
            <Card.Content style={styles.insightContent}>
              <View style={[styles.insightIcon, { backgroundColor: '#D1FAE5' }]}>
                <MaterialCommunityIcons
                  name="trending-up"
                  size={20}
                  color="#047857"
                />
              </View>
              <View style={styles.insightText}>
                <Text style={styles.insightTitle}>Fewer Anomalies</Text>
                <Text style={styles.insightDescription}>
                  Motion anomaly detections decreased by 35% compared to last week
                </Text>
              </View>
            </Card.Content>
          </Card>

          <Card style={styles.insightCard}>
            <Card.Content style={styles.insightContent}>
              <View style={[styles.insightIcon, { backgroundColor: '#DBEAFE' }]}>
                <MaterialCommunityIcons
                  name="pulse"
                  size={20}
                  color="#1D4ED8"
                />
              </View>
              <View style={styles.insightText}>
                <Text style={styles.insightTitle}>Consistent Activity</Text>
                <Text style={styles.insightDescription}>
                  You've maintained regular motion patterns throughout the week
                </Text>
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
    marginBottom: Spacing.md,
  },
  placeholder: {
    width: 40,
  },
  headerTitle: {
    fontSize: FontSizes.lg,
    fontWeight: '700',
    color: '#FFFFFF',
  },
  calendarButton: {
    width: 40,
    height: 40,
    borderRadius: 20,
    backgroundColor: 'rgba(255,255,255,0.2)',
    alignItems: 'center',
    justifyContent: 'center',
  },
  headerSubtitle: {
    fontSize: FontSizes.md,
    color: 'rgba(255,255,255,0.9)',
    textAlign: 'center',
  },
  mainContent: {
    paddingHorizontal: Spacing.lg,
    marginTop: -Spacing.md,
  },
  summaryGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: Spacing.md,
    marginBottom: Spacing.lg,
  },
  summaryCard: {
    width: (screenWidth - Spacing.md) / 2,
    borderRadius: BorderRadius.lg,
    ...Shadows.lg,
  },
  primaryCard: {
    backgroundColor: Colors.primary,
  },
  successCard: {
    backgroundColor: Colors.success,
  },
  warningCard: {
    backgroundColor: Colors.warning,
  },
  purpleCard: {
    backgroundColor: Colors.purple,
  },
  summaryContent: {
    paddingVertical: Spacing.md,
  },
  summaryIconRow: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: Spacing.sm,
  },
  summaryIconBg: {
    width: 32,
    height: 32,
    borderRadius: BorderRadius.sm,
    backgroundColor: 'rgba(255,255,255,0.2)',
    alignItems: 'center',
    justifyContent: 'center',
    marginRight: Spacing.sm,
  },
  summaryLabel: {
    fontSize: FontSizes.sm,
    color: 'rgba(255,255,255,0.8)',
  },
  summaryValue: {
    fontSize: FontSizes.xxxl,
    fontWeight: '700',
    color: '#FFFFFF',
  },
  summarySubValue: {
    fontSize: FontSizes.sm,
    color: 'rgba(255,255,255,0.7)',
  },
  chartCard: {
    borderRadius: BorderRadius.lg,
    marginBottom: Spacing.lg,
    backgroundColor: Colors.light.surface,
    ...Shadows.lg,
  },
  chartHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: Spacing.md,
  },
  chartTitle: {
    fontSize: FontSizes.lg,
    fontWeight: '700',
    color: Colors.light.text,
  },
  legendRow: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  legendDot: {
    width: 12,
    height: 12,
    borderRadius: 6,
    marginRight: Spacing.xs,
  },
  legendText: {
    fontSize: FontSizes.sm,
    color: Colors.light.textSecondary,
  },
  chart: {
    marginVertical: Spacing.sm,
    borderRadius: BorderRadius.md,
  },
  insightCard: {
    borderRadius: BorderRadius.lg,
    marginBottom: Spacing.md,
    backgroundColor: Colors.light.surface,
    ...Shadows.md,
  },
  insightContent: {
    flexDirection: 'row',
    alignItems: 'flex-start',
  },
  insightIcon: {
    width: 40,
    height: 40,
    borderRadius: BorderRadius.sm,
    alignItems: 'center',
    justifyContent: 'center',
    marginRight: Spacing.md,
  },
  insightText: {
    flex: 1,
  },
  insightTitle: {
    fontSize: FontSizes.md,
    fontWeight: '600',
    color: Colors.light.text,
    marginBottom: Spacing.xs,
  },
  insightDescription: {
    fontSize: FontSizes.sm,
    color: Colors.light.textSecondary,
    lineHeight: 20,
  },
});
