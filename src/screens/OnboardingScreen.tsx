import React, { useState, useRef } from 'react';
import {
  View,
  Text,
  StyleSheet,
  Dimensions,
  ScrollView,
  TouchableOpacity,
  NativeSyntheticEvent,
  NativeScrollEvent,
} from 'react-native';
import { useNavigation } from '@react-navigation/native';
import { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Button } from 'react-native-paper';
import { MaterialCommunityIcons } from '@expo/vector-icons';
import { Colors, Spacing, BorderRadius, FontSizes } from '../theme';
import { AuthStackParamList, OnboardingSlide } from '../types';

const { width } = Dimensions.get('window');

interface OnboardingScreenProps {
  onComplete: () => void;
}

const slides: OnboardingSlide[] = [
  {
    iconName: 'pulse',
    title: 'AI-Powered Motion Detection',
    description:
      'Your wearable device detects falls, impacts, prolonged stillness, and sudden movements in real-time.',
    color: Colors.primary,
  },
  {
    iconName: 'shield-check',
    title: 'Instant Emergency Response',
    description:
      'Automatic alerts to emergency contacts when critical motion anomalies are detected.',
    color: Colors.success,
  },
  {
    iconName: 'map-marker',
    title: 'Safe Trip Tracking',
    description:
      'Track your journeys with real-time monitoring and location sharing for peace of mind.',
    color: Colors.primary,
  },
  {
    iconName: 'bell',
    title: 'Stay Connected & Protected',
    description:
      'Enable notifications, Bluetooth, and location to get the most out of your safety companion.',
    color: Colors.warning,
  },
];

export function OnboardingScreen({ onComplete }: OnboardingScreenProps) {
  const navigation =
    useNavigation<NativeStackNavigationProp<AuthStackParamList>>();
  const [currentSlide, setCurrentSlide] = useState(0);
  const scrollViewRef = useRef<ScrollView>(null);

  const handleScroll = (event: NativeSyntheticEvent<NativeScrollEvent>) => {
    const slideIndex = Math.round(event.nativeEvent.contentOffset.x / width);
    setCurrentSlide(slideIndex);
  };

  const handleNext = () => {
    if (currentSlide < slides.length - 1) {
      scrollViewRef.current?.scrollTo({
        x: (currentSlide + 1) * width,
        animated: true,
      });
      setCurrentSlide(currentSlide + 1);
    } else {
      onComplete();
      navigation.replace('Login');
    }
  };

  const handleSkip = () => {
    onComplete();
    navigation.replace('Login');
  };

  return (
    <SafeAreaView style={styles.container}>
      {/* Header */}
      <View style={styles.header}>
        <Text style={styles.brandText}>Sentinel 360</Text>
        {currentSlide < slides.length - 1 && (
          <TouchableOpacity onPress={handleSkip}>
            <Text style={styles.skipText}>Skip</Text>
          </TouchableOpacity>
        )}
      </View>

      {/* Slides */}
      <ScrollView
        ref={scrollViewRef}
        horizontal
        pagingEnabled
        showsHorizontalScrollIndicator={false}
        onMomentumScrollEnd={handleScroll}
        scrollEventThrottle={16}
      >
        {slides.map((slide, index) => (
          <View key={index} style={styles.slide}>
            {/* Icon Circle */}
            <View
              style={[
                styles.iconCircle,
                { backgroundColor: `${slide.color}20` },
              ]}
            >
              <MaterialCommunityIcons
                name={slide.iconName as any}
                size={64}
                color={slide.color}
              />
            </View>

            {/* Text Content */}
            <Text style={styles.title}>{slide.title}</Text>
            <Text style={styles.description}>{slide.description}</Text>

            {/* Decorative Elements */}
            <View style={styles.decorativeRow}>
              <View style={styles.decorativeBox}>
                <MaterialCommunityIcons
                  name="pulse"
                  size={24}
                  color={Colors.primary}
                />
              </View>
              <View style={styles.decorativeLine} />
              <View style={styles.decorativeBox}>
                <MaterialCommunityIcons
                  name="cellphone"
                  size={24}
                  color={Colors.success}
                />
              </View>
            </View>
          </View>
        ))}
      </ScrollView>

      {/* Bottom Section */}
      <View style={styles.bottomSection}>
        {/* Dots Indicator */}
        <View style={styles.dotsContainer}>
          {slides.map((_, index) => (
            <View
              key={index}
              style={[
                styles.dot,
                {
                  width: currentSlide === index ? 24 : 8,
                  backgroundColor:
                    currentSlide === index ? Colors.primary : '#D1D5DB',
                },
              ]}
            />
          ))}
        </View>

        {/* Next Button */}
        <Button
          mode="contained"
          onPress={handleNext}
          style={styles.nextButton}
          contentStyle={styles.nextButtonContent}
          labelStyle={styles.nextButtonLabel}
        >
          {currentSlide === slides.length - 1 ? 'Get Started' : 'Next'}
        </Button>
      </View>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: Colors.light.background,
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingHorizontal: Spacing.lg,
    paddingVertical: Spacing.md,
  },
  brandText: {
    fontSize: FontSizes.lg,
    fontWeight: '600',
    color: Colors.light.text,
  },
  skipText: {
    fontSize: FontSizes.md,
    color: Colors.light.textSecondary,
  },
  slide: {
    width,
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: Spacing.xxl,
  },
  iconCircle: {
    width: 128,
    height: 128,
    borderRadius: 64,
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: Spacing.xxxl,
  },
  title: {
    fontSize: FontSizes.xxl,
    fontWeight: '700',
    color: Colors.light.text,
    textAlign: 'center',
    marginBottom: Spacing.lg,
  },
  description: {
    fontSize: FontSizes.lg,
    color: Colors.light.textSecondary,
    textAlign: 'center',
    lineHeight: 24,
    paddingHorizontal: Spacing.lg,
  },
  decorativeRow: {
    flexDirection: 'row',
    alignItems: 'center',
    marginTop: Spacing.xxxl,
  },
  decorativeBox: {
    backgroundColor: Colors.light.surface,
    padding: Spacing.md,
    borderRadius: BorderRadius.lg,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 4,
  },
  decorativeLine: {
    width: 2,
    height: 32,
    marginHorizontal: Spacing.md,
    backgroundColor: Colors.primary,
  },
  bottomSection: {
    paddingHorizontal: Spacing.lg,
    paddingBottom: Spacing.lg,
  },
  dotsContainer: {
    flexDirection: 'row',
    justifyContent: 'center',
    alignItems: 'center',
    marginBottom: Spacing.lg,
  },
  dot: {
    height: 8,
    borderRadius: 4,
    marginHorizontal: 4,
  },
  nextButton: {
    borderRadius: BorderRadius.lg,
    backgroundColor: Colors.primary,
  },
  nextButtonContent: {
    height: 56,
  },
  nextButtonLabel: {
    fontSize: FontSizes.lg,
    fontWeight: '600',
  },
});
