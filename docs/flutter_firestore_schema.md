# Flutter Firestore Schema Contract

This document is the app-side source of truth for Sentinel360 telemetry writes
and live risk reads.

## 1) Trip Document

Path: `trips/{tripId}`

Required at trip start:

- `userId`: string
- `driver_id`: string
- `vehicle_type`: string
- `status`: `"active"` | `"completed"`
- `origin`: `{ lat: number, lon: number }`
- `destination`: `{ lat: number, lon: number }`
- `destinationName`: string
- `startedAt`: server timestamp
- `source`: `"PHONE"` | `"IOT"`

Compatibility fields kept by app:

- `originGeo`: GeoPoint
- `destinationGeo`: GeoPoint

Trip end updates:

- `status`: `"completed"`
- `endedAt`: server timestamp
- `duration`: number (seconds)

## 2) Sensor Event Input

Path: `trips/{tripId}/sensor_data/{eventId}`

The app writes one event per document (1Hz target), not batch blobs.

Required:

- `trip_id`: string
- `timestamp`: number (epoch ms)
- `source`: `"PHONE"` | `"IOT"`
- `gps.lat`: number
- `gps.lon`: number
- `gps.speed`: number (km/h)
- `acceleration.x`: number

Recommended:

- `acceleration.y`, `acceleration.z`
- `gyro.x`, `gyro.y`, `gyro.z`
- `gps.accuracy`
- `gps.speed_accuracy`
- `gps.heading`, `gps.bearing`
- `gps.altitude`
- `gps.vertical_speed`
- `is_moving`: boolean
- `activity`: string

Auxiliary:

- `userId`: string
- `ingested_at`: server timestamp

## 3) Live Risk Output

Path: `trips/{tripId}/current_state/latest`

Instant fields:

- `riskScore`
- `riskLevel`
- `riskColor`
- `explanation`
- `activeSensor`

Trip-level policy fields:

- `overallRiskLevel`
- `overallUnsafe`
- `policy.totalWindows`
- `policy.highWindows`
- `policy.highRatio`
- `policy.consecutiveHigh`
- `policy.maxConsecutiveHigh`
- `policy.lastHighTimestamp`
- `policy.latchedHighUntil`
- `policy.overallUnsafe`
- `policy.overallLevel`
- `policy.reason`

## 4) Alerts

Path: `trips/{tripId}/alerts/{alertId}`

Expected for escalations/SOS:

- `timestamp`
- `riskScore`
- `reason`
- `actions` (array)
- `resolved` (boolean)
