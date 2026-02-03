/**
 * Location Helper Functions for Sentinel 360
 *
 * This file contains ready-to-use GPS functions.
 * GPS is NOT activated by default - you can enable it when needed.
 *
 * USAGE:
 * 1. Import the functions you need
 * 2. Call requestLocationPermissions() first
 * 3. Then use getCurrentLocation() or startLocationTracking()
 */

import * as Location from 'expo-location';
import { LocationData, LocationCoords } from '../types';

// Permission status type
type PermissionStatus = 'granted' | 'denied' | 'undetermined';

/**
 * Request location permissions from the user
 * Call this before using any location functions
 */
export async function requestLocationPermissions(): Promise<{
  foreground: PermissionStatus;
  background: PermissionStatus;
}> {
  try {
    // Request foreground permission first
    const { status: foregroundStatus } =
      await Location.requestForegroundPermissionsAsync();

    let backgroundStatus: PermissionStatus = 'undetermined';

    // Only request background if foreground was granted
    if (foregroundStatus === 'granted') {
      const { status: bgStatus } =
        await Location.requestBackgroundPermissionsAsync();
      backgroundStatus = bgStatus as PermissionStatus;
    }

    return {
      foreground: foregroundStatus as PermissionStatus,
      background: backgroundStatus,
    };
  } catch (error) {
    console.error('Error requesting location permissions:', error);
    return {
      foreground: 'denied',
      background: 'denied',
    };
  }
}

/**
 * Check current location permission status
 */
export async function checkLocationPermissions(): Promise<{
  foreground: PermissionStatus;
  background: PermissionStatus;
}> {
  try {
    const { status: foregroundStatus } =
      await Location.getForegroundPermissionsAsync();
    const { status: backgroundStatus } =
      await Location.getBackgroundPermissionsAsync();

    return {
      foreground: foregroundStatus as PermissionStatus,
      background: backgroundStatus as PermissionStatus,
    };
  } catch (error) {
    console.error('Error checking location permissions:', error);
    return {
      foreground: 'denied',
      background: 'denied',
    };
  }
}

/**
 * Get current location once
 * Returns null if permission denied or error occurs
 */
export async function getCurrentLocation(): Promise<LocationData | null> {
  try {
    const { status } = await Location.getForegroundPermissionsAsync();

    if (status !== 'granted') {
      console.warn('Location permission not granted');
      return null;
    }

    const location = await Location.getCurrentPositionAsync({
      accuracy: Location.Accuracy.High,
    });

    return {
      coords: {
        latitude: location.coords.latitude,
        longitude: location.coords.longitude,
        altitude: location.coords.altitude ?? undefined,
        accuracy: location.coords.accuracy ?? undefined,
        heading: location.coords.heading ?? undefined,
        speed: location.coords.speed ?? undefined,
      },
      timestamp: location.timestamp,
    };
  } catch (error) {
    console.error('Error getting current location:', error);
    return null;
  }
}

/**
 * Start watching location changes
 * Returns a subscription object - call .remove() to stop tracking
 */
export async function startLocationTracking(
  onLocationUpdate: (location: LocationData) => void,
  options?: {
    accuracy?: Location.Accuracy;
    distanceInterval?: number; // meters
    timeInterval?: number; // milliseconds
  }
): Promise<Location.LocationSubscription | null> {
  try {
    const { status } = await Location.getForegroundPermissionsAsync();

    if (status !== 'granted') {
      console.warn('Location permission not granted');
      return null;
    }

    const subscription = await Location.watchPositionAsync(
      {
        accuracy: options?.accuracy ?? Location.Accuracy.Balanced,
        distanceInterval: options?.distanceInterval ?? 10,
        timeInterval: options?.timeInterval ?? 5000,
      },
      (location) => {
        onLocationUpdate({
          coords: {
            latitude: location.coords.latitude,
            longitude: location.coords.longitude,
            altitude: location.coords.altitude ?? undefined,
            accuracy: location.coords.accuracy ?? undefined,
            heading: location.coords.heading ?? undefined,
            speed: location.coords.speed ?? undefined,
          },
          timestamp: location.timestamp,
        });
      }
    );

    return subscription;
  } catch (error) {
    console.error('Error starting location tracking:', error);
    return null;
  }
}

/**
 * Calculate distance between two coordinates in meters
 */
export function calculateDistance(
  coord1: LocationCoords,
  coord2: LocationCoords
): number {
  const R = 6371e3; // Earth's radius in meters
  const lat1Rad = (coord1.latitude * Math.PI) / 180;
  const lat2Rad = (coord2.latitude * Math.PI) / 180;
  const deltaLat = ((coord2.latitude - coord1.latitude) * Math.PI) / 180;
  const deltaLon = ((coord2.longitude - coord1.longitude) * Math.PI) / 180;

  const a =
    Math.sin(deltaLat / 2) * Math.sin(deltaLat / 2) +
    Math.cos(lat1Rad) *
      Math.cos(lat2Rad) *
      Math.sin(deltaLon / 2) *
      Math.sin(deltaLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

  return R * c;
}

/**
 * Format coordinates for display
 */
export function formatCoordinates(coords: LocationCoords): string {
  const latDir = coords.latitude >= 0 ? 'N' : 'S';
  const lonDir = coords.longitude >= 0 ? 'E' : 'W';

  return `${Math.abs(coords.latitude).toFixed(6)}° ${latDir}, ${Math.abs(coords.longitude).toFixed(6)}° ${lonDir}`;
}

/**
 * Get a simple address from coordinates (reverse geocoding)
 */
export async function getAddressFromCoords(
  coords: LocationCoords
): Promise<string | null> {
  try {
    const [address] = await Location.reverseGeocodeAsync({
      latitude: coords.latitude,
      longitude: coords.longitude,
    });

    if (address) {
      const parts = [
        address.street,
        address.city,
        address.region,
      ].filter(Boolean);
      return parts.join(', ');
    }

    return null;
  } catch (error) {
    console.error('Error reverse geocoding:', error);
    return null;
  }
}
