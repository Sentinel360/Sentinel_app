// Navigation Types
export type RootStackParamList = {
  Auth: undefined;
  Main: undefined;
  TripTracking: undefined;
  Emergency: undefined;
};

export type AuthStackParamList = {
  Onboarding: undefined;
  Login: undefined;
};

export type MainTabParamList = {
  Home: undefined;
  Notifications: undefined;
  Analytics: undefined;
  Device: undefined;
  Settings: undefined;
};

// Screen Names
export type ScreenName =
  | 'Onboarding'
  | 'Login'
  | 'Home'
  | 'TripTracking'
  | 'Emergency'
  | 'Notifications'
  | 'Analytics'
  | 'Device'
  | 'Settings';

// Notification Types
export type NotificationType = 'critical' | 'warning' | 'info';
export type NotificationStatus = 'Critical' | 'Reviewed' | 'Resolved';

export interface Notification {
  id: string;
  type: NotificationType;
  title: string;
  description: string;
  time: string;
  status: NotificationStatus;
  iconName: string;
  color: string;
}

// Trip Event Types
export type TripEventType = 'start' | 'checkpoint' | 'anomaly' | 'end';

export interface TripEvent {
  id: string;
  time: string;
  type: TripEventType;
  message: string;
  iconName: string;
  color: string;
}

// Emergency Contact Types
export interface EmergencyContact {
  name: string;
  relation: string;
  phone: string;
}

// Device Status
export type DeviceStatus = 'connected' | 'disconnected' | 'connecting';

export interface DeviceInfo {
  name: string;
  serialNumber: string;
  batteryLevel: number;
  signalStrength: 'strong' | 'medium' | 'weak';
  firmwareVersion: string;
  connectionStatus: DeviceStatus;
  lastSync: string;
}

// Analytics Data
export interface WeeklyAnomalyData {
  day: string;
  anomalies: number;
}

export interface MotionActivityData {
  time: string;
  level: number;
}

export interface TripFrequencyData {
  month: string;
  trips: number;
}

// Settings
export interface SettingsSection {
  title: string;
  items: SettingsItem[];
}

export interface SettingsItem {
  iconName: string;
  label: string;
  action?: () => void;
  toggle?: boolean;
  value?: boolean;
  badge?: string;
}

// App State
export interface AppState {
  isAuthenticated: boolean;
  hasCompletedOnboarding: boolean;
  isDarkMode: boolean;
  emergencyActive: boolean;
}

// Onboarding Slides
export interface OnboardingSlide {
  iconName: string;
  title: string;
  description: string;
  color: string;
}

// Location Types (for GPS integration)
export interface LocationCoords {
  latitude: number;
  longitude: number;
  altitude?: number;
  accuracy?: number;
  heading?: number;
  speed?: number;
}

export interface LocationData {
  coords: LocationCoords;
  timestamp: number;
}
