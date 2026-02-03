import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  Linking,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Button, Card } from 'react-native-paper';
import { MaterialCommunityIcons } from '@expo/vector-icons';
import { Colors, Spacing, BorderRadius, FontSizes } from '../theme';
import { EmergencyContact } from '../types';

interface EmergencyScreenProps {
  onCancel: () => void;
  onConfirm: () => void;
}

const emergencyContacts: EmergencyContact[] = [
  { name: 'John Doe', relation: 'Emergency Contact', phone: '+1234567890' },
  { name: 'Jane Smith', relation: 'Family', phone: '+1234567891' },
  { name: 'Local Emergency', relation: '911', phone: '911' },
];

export function EmergencyScreen({ onCancel, onConfirm }: EmergencyScreenProps) {
  const [countdown, setCountdown] = useState(10);
  const [isConfirmed, setIsConfirmed] = useState(false);

  useEffect(() => {
    if (countdown > 0 && !isConfirmed) {
      const timer = setTimeout(() => setCountdown(countdown - 1), 1000);
      return () => clearTimeout(timer);
    } else if (countdown === 0 && !isConfirmed) {
      handleConfirm();
    }
  }, [countdown, isConfirmed]);

  const handleConfirm = () => {
    setIsConfirmed(true);
    onConfirm();
  };

  const handleCall = (phone: string) => {
    Linking.openURL(`tel:${phone}`);
  };

  if (isConfirmed) {
    return (
      <SafeAreaView style={styles.confirmedContainer}>
        <View style={styles.confirmedContent}>
          <View style={styles.confirmedIconContainer}>
            <MaterialCommunityIcons
              name="check-circle"
              size={64}
              color={Colors.success}
            />
          </View>
          <Text style={styles.confirmedTitle}>Emergency Confirmed</Text>
          <Text style={styles.confirmedSubtitle}>Help is on the way</Text>
          <Text style={styles.confirmedDescription}>
            Your emergency contacts have been notified and your location is being
            shared.
          </Text>
        </View>
      </SafeAreaView>
    );
  }

  return (
    <SafeAreaView style={styles.container}>
      {/* Pulsing Background Effect - simplified without animation library */}
      <View style={styles.pulseBackground} />

      {/* Content */}
      <View style={styles.content}>
        {/* Top Section */}
        <View style={styles.topSection}>
          {/* Alert Icon */}
          <View style={styles.alertIconWrapper}>
            <View style={styles.alertIconContainer}>
              <MaterialCommunityIcons
                name="alert"
                size={64}
                color={Colors.danger}
              />
            </View>
          </View>

          <Text style={styles.title}>Emergency Alert</Text>
          <Text style={styles.subtitle}>
            Emergency services will be contacted in
          </Text>

          {/* Countdown */}
          <Text style={styles.countdown}>{countdown}</Text>

          <Text style={styles.locationText}>
            Your location is being shared with emergency contacts
          </Text>

          {/* Location Indicator */}
          <View style={styles.locationRow}>
            <MaterialCommunityIcons
              name="map-marker"
              size={16}
              color="rgba(255,255,255,0.9)"
            />
            <Text style={styles.locationLabel}>
              Current location: Downtown Area
            </Text>
          </View>
        </View>

        {/* Emergency Contacts */}
        <Card style={styles.contactsCard}>
          <Card.Content>
            <Text style={styles.contactsTitle}>Notifying</Text>
            <View style={styles.contactsList}>
              {emergencyContacts.map((contact, index) => (
                <View key={index} style={styles.contactItem}>
                  <View>
                    <Text style={styles.contactName}>{contact.name}</Text>
                    <Text style={styles.contactRelation}>{contact.relation}</Text>
                  </View>
                  <TouchableOpacity
                    style={styles.callButton}
                    onPress={() => handleCall(contact.phone)}
                  >
                    <MaterialCommunityIcons
                      name="phone"
                      size={18}
                      color="#FFFFFF"
                    />
                  </TouchableOpacity>
                </View>
              ))}
            </View>
          </Card.Content>
        </Card>

        {/* Action Buttons */}
        <View style={styles.actionButtons}>
          <Button
            mode="contained"
            onPress={handleConfirm}
            style={styles.confirmButton}
            contentStyle={styles.buttonContent}
            labelStyle={styles.confirmButtonLabel}
            buttonColor="#FFFFFF"
            icon="check-circle"
          >
            Confirm Emergency Now
          </Button>

          <Button
            mode="outlined"
            onPress={onCancel}
            style={styles.cancelButton}
            contentStyle={styles.buttonContent}
            labelStyle={styles.cancelButtonLabel}
            icon="close"
          >
            Cancel Alert - I'm Safe
          </Button>
        </View>

        {/* Instructions */}
        <Text style={styles.instructions}>
          Stay calm. Help is on the way. If you can, move to a safe location.
        </Text>
      </View>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: Colors.danger,
  },
  pulseBackground: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: '#DC2626',
    opacity: 0.3,
  },
  content: {
    flex: 1,
    paddingHorizontal: Spacing.lg,
    justifyContent: 'space-between',
  },
  topSection: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  alertIconWrapper: {
    position: 'relative',
    marginBottom: Spacing.xxl,
  },
  alertIconContainer: {
    width: 128,
    height: 128,
    borderRadius: 64,
    backgroundColor: '#FFFFFF',
    alignItems: 'center',
    justifyContent: 'center',
  },
  title: {
    fontSize: FontSizes.xxxl,
    fontWeight: '700',
    color: '#FFFFFF',
    marginBottom: Spacing.lg,
  },
  subtitle: {
    fontSize: FontSizes.lg,
    color: 'rgba(255,255,255,0.9)',
    marginBottom: Spacing.xxl,
  },
  countdown: {
    fontSize: 80,
    fontWeight: '200',
    color: '#FFFFFF',
    marginBottom: Spacing.xxl,
    fontVariant: ['tabular-nums'],
  },
  locationText: {
    fontSize: FontSizes.md,
    color: 'rgba(255,255,255,0.8)',
    textAlign: 'center',
    marginBottom: Spacing.lg,
  },
  locationRow: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  locationLabel: {
    fontSize: FontSizes.sm,
    color: 'rgba(255,255,255,0.9)',
    marginLeft: Spacing.xs,
  },
  contactsCard: {
    backgroundColor: 'rgba(255,255,255,0.1)',
    borderRadius: BorderRadius.lg,
    marginBottom: Spacing.lg,
  },
  contactsTitle: {
    fontSize: FontSizes.lg,
    fontWeight: '600',
    color: '#FFFFFF',
    marginBottom: Spacing.md,
  },
  contactsList: {
    gap: Spacing.sm,
  },
  contactItem: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    backgroundColor: 'rgba(255,255,255,0.1)',
    borderRadius: BorderRadius.md,
    padding: Spacing.md,
  },
  contactName: {
    fontSize: FontSizes.md,
    fontWeight: '500',
    color: '#FFFFFF',
  },
  contactRelation: {
    fontSize: FontSizes.sm,
    color: 'rgba(255,255,255,0.7)',
  },
  callButton: {
    width: 40,
    height: 40,
    borderRadius: 20,
    backgroundColor: 'rgba(255,255,255,0.2)',
    alignItems: 'center',
    justifyContent: 'center',
  },
  actionButtons: {
    gap: Spacing.md,
    marginBottom: Spacing.lg,
  },
  confirmButton: {
    borderRadius: BorderRadius.lg,
  },
  cancelButton: {
    borderRadius: BorderRadius.lg,
    borderColor: 'rgba(255,255,255,0.3)',
    borderWidth: 2,
    backgroundColor: 'rgba(255,255,255,0.1)',
  },
  buttonContent: {
    height: 64,
  },
  confirmButtonLabel: {
    fontSize: FontSizes.lg,
    fontWeight: '600',
    color: Colors.danger,
  },
  cancelButtonLabel: {
    fontSize: FontSizes.lg,
    fontWeight: '600',
    color: '#FFFFFF',
  },
  instructions: {
    fontSize: FontSizes.sm,
    color: 'rgba(255,255,255,0.7)',
    textAlign: 'center',
    marginBottom: Spacing.lg,
  },
  // Confirmed state styles
  confirmedContainer: {
    flex: 1,
    backgroundColor: Colors.success,
    justifyContent: 'center',
    alignItems: 'center',
    padding: Spacing.lg,
  },
  confirmedContent: {
    alignItems: 'center',
  },
  confirmedIconContainer: {
    width: 128,
    height: 128,
    borderRadius: 64,
    backgroundColor: '#FFFFFF',
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: Spacing.xl,
  },
  confirmedTitle: {
    fontSize: FontSizes.xxxl,
    fontWeight: '700',
    color: '#FFFFFF',
    marginBottom: Spacing.lg,
  },
  confirmedSubtitle: {
    fontSize: FontSizes.xl,
    color: 'rgba(255,255,255,0.9)',
    marginBottom: Spacing.xxl,
  },
  confirmedDescription: {
    fontSize: FontSizes.md,
    color: 'rgba(255,255,255,0.8)',
    textAlign: 'center',
    lineHeight: 24,
  },
});
