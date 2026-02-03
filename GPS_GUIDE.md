# GPS Implementation Guide

This guide explains how to activate and use GPS location tracking in Sentinel 360.

## Overview

GPS/Location services are **pre-configured but not actively running** in this app. This is intentional to:
1. Avoid permission prompts during development
2. Save battery during testing
3. Let you decide when to enable tracking

## Quick Start

### 1. Import the helpers

```typescript
import {
  requestLocationPermissions,
  checkLocationPermissions,
  getCurrentLocation,
  startLocationTracking,
  calculateDistance,
  formatCoordinates,
  getAddressFromCoords,
} from '../utils/locationHelpers';
```

### 2. Request permissions first

```typescript
const requestPermissions = async () => {
  const { foreground, background } = await requestLocationPermissions();

  if (foreground === 'granted') {
    console.log('Foreground location granted!');
    // Can now use getCurrentLocation() and startLocationTracking()
  }

  if (background === 'granted') {
    console.log('Background location granted!');
    // Can track in background (iOS requires extra setup)
  }
};
```

### 3. Get current location once

```typescript
const getMyLocation = async () => {
  const location = await getCurrentLocation();

  if (location) {
    console.log('Latitude:', location.coords.latitude);
    console.log('Longitude:', location.coords.longitude);
    console.log('Accuracy:', location.coords.accuracy, 'meters');
  } else {
    console.log('Could not get location - check permissions');
  }
};
```

### 4. Start continuous tracking

```typescript
let locationSubscription = null;

const startTracking = async () => {
  locationSubscription = await startLocationTracking(
    (location) => {
      // Called every time location updates
      console.log('New location:', location.coords);

      // Update your state/UI here
      setCurrentLocation(location);
    },
    {
      accuracy: 'high', // 'low' | 'balanced' | 'high'
      distanceInterval: 10, // Update every 10 meters
      timeInterval: 5000, // Or every 5 seconds
    }
  );
};

const stopTracking = () => {
  if (locationSubscription) {
    locationSubscription.remove();
    locationSubscription = null;
  }
};
```

## Example: Trip Tracking Screen Integration

Here's how to add real GPS to the TripTrackingScreen:

```typescript
// In TripTrackingScreen.tsx

import { useState, useEffect, useRef } from 'react';
import {
  requestLocationPermissions,
  getCurrentLocation,
  startLocationTracking,
  calculateDistance,
} from '../utils/locationHelpers';
import { LocationData } from '../types';

export function TripTrackingScreen() {
  const [currentLocation, setCurrentLocation] = useState<LocationData | null>(null);
  const [totalDistance, setTotalDistance] = useState(0);
  const [locationHistory, setLocationHistory] = useState<LocationData[]>([]);
  const subscriptionRef = useRef<any>(null);
  const lastLocationRef = useRef<LocationData | null>(null);

  // Request permissions on mount
  useEffect(() => {
    requestLocationPermissions();
  }, []);

  // Start GPS when trip starts
  const handleStartTrip = async () => {
    // Get initial location
    const initialLocation = await getCurrentLocation();
    if (initialLocation) {
      setCurrentLocation(initialLocation);
      setLocationHistory([initialLocation]);
      lastLocationRef.current = initialLocation;
    }

    // Start continuous tracking
    subscriptionRef.current = await startLocationTracking(
      (location) => {
        setCurrentLocation(location);

        // Calculate distance from last point
        if (lastLocationRef.current) {
          const distance = calculateDistance(
            lastLocationRef.current.coords,
            location.coords
          );
          setTotalDistance(prev => prev + distance);
        }

        lastLocationRef.current = location;
        setLocationHistory(prev => [...prev, location]);
      },
      {
        distanceInterval: 10, // Update every 10 meters
      }
    );

    setIsTracking(true);
  };

  // Stop GPS when trip ends
  const handleEndTrip = () => {
    if (subscriptionRef.current) {
      subscriptionRef.current.remove();
      subscriptionRef.current = null;
    }
    setIsTracking(false);
  };

  // Cleanup on unmount
  useEffect(() => {
    return () => {
      if (subscriptionRef.current) {
        subscriptionRef.current.remove();
      }
    };
  }, []);

  // Display distance in UI
  const formatDistance = (meters: number) => {
    if (meters < 1000) {
      return `${Math.round(meters)} m`;
    }
    return `${(meters / 1000).toFixed(2)} km`;
  };

  return (
    // ... your UI
    <Text>Distance: {formatDistance(totalDistance)}</Text>
  );
}
```

## Example: Emergency Screen Integration

For the emergency screen, you might want to share location:

```typescript
// In EmergencyScreen.tsx

import { useState, useEffect } from 'react';
import {
  getCurrentLocation,
  getAddressFromCoords,
  formatCoordinates,
} from '../utils/locationHelpers';

export function EmergencyScreen() {
  const [location, setLocation] = useState<string>('Getting location...');
  const [coords, setCoords] = useState<string>('');

  useEffect(() => {
    const getLocation = async () => {
      const loc = await getCurrentLocation();

      if (loc) {
        setCoords(formatCoordinates(loc.coords));

        const address = await getAddressFromCoords(loc.coords);
        setLocation(address || 'Unknown location');
      } else {
        setLocation('Location unavailable');
      }
    };

    getLocation();
  }, []);

  return (
    // ... your UI
    <Text>Current location: {location}</Text>
    <Text>Coordinates: {coords}</Text>
  );
}
```

## Accuracy Levels

Expo Location provides different accuracy levels:

```typescript
import * as Location from 'expo-location';

// Options for startLocationTracking
{
  accuracy: Location.Accuracy.Lowest,      // ~3000m, lowest battery
  accuracy: Location.Accuracy.Low,         // ~1000m
  accuracy: Location.Accuracy.Balanced,    // ~100m, default
  accuracy: Location.Accuracy.High,        // ~10m
  accuracy: Location.Accuracy.Highest,     // ~1m, highest battery
  accuracy: Location.Accuracy.BestForNavigation, // Best + compass
}
```

## Battery Considerations

| Setting | Accuracy | Battery Impact | Use Case |
|---------|----------|----------------|----------|
| Lowest | ~3km | Minimal | Background presence |
| Low | ~1km | Low | City-level tracking |
| Balanced | ~100m | Moderate | General navigation |
| High | ~10m | High | Active trip tracking |
| Highest | ~1m | Very High | Precise positioning |

## Permissions Explained

### Foreground Permission
- Allows tracking while app is open
- Required for basic functionality
- Usually granted easily

### Background Permission
- Allows tracking when app is in background
- Required for continuous trip monitoring
- Harder to get approved (App Store review)
- iOS requires special background modes

## Testing Location

### In Expo Go
Location works in Expo Go on real devices. For simulators:
- **iOS Simulator**: Features > Location > Custom Location
- **Android Emulator**: Extended Controls > Location

### Mock Locations
For testing, you can mock locations:

```typescript
// Create mock location data
const mockLocation: LocationData = {
  coords: {
    latitude: 40.7128,
    longitude: -74.0060,
    accuracy: 10,
  },
  timestamp: Date.now(),
};
```

## Troubleshooting

### "Location permission denied"
1. Check device settings > Apps > Sentinel 360 > Permissions
2. Request permissions again in the app
3. User may have previously denied - must enable manually

### "Location unavailable"
1. Check GPS is enabled on device
2. Try going outside (GPS doesn't work well indoors)
3. Wait a few seconds for GPS lock

### "Inaccurate location"
1. Use higher accuracy setting
2. Wait for GPS lock (can take 30+ seconds)
3. Check device isn't in airplane mode

### Battery draining fast
1. Use lower accuracy when possible
2. Increase distanceInterval
3. Stop tracking when not needed
4. Use timeInterval instead of continuous updates

## Best Practices

1. **Always check permissions** before accessing location
2. **Show loading state** while getting initial location
3. **Handle errors gracefully** (denied permissions, GPS off)
4. **Stop tracking when done** to save battery
5. **Use appropriate accuracy** for your use case
6. **Test on real devices** (simulators have limitations)
7. **Inform users** why you need their location
