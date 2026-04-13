import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'firebase_options.dart';
import 'providers/theme_provider.dart';
import 'services/trip_manager.dart';
import 'screens/login_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/home_screen.dart';
import 'screens/map_screen_v2.dart';
import 'screens/emergency_screen.dart';
import 'screens/device_management_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/emergency_contacts_screen.dart';
import 'widgets/auth_wrapper.dart';
import 'screens/splash_screen.dart';
import 'screens/trip_history_screen.dart';
import 'screens/trip_detail_screen.dart';
import 'theme/app_theme.dart';
import 'app_keys.dart';
import 'widgets/wearable_sos_listener.dart';
import 'widgets/safety_check_listener.dart';
import 'services/trip_foreground_service.dart';
import 'services/notification_service.dart';

/// Handles FCM messages that arrive while the app is terminated or in the
/// background. Must be a top-level function annotated with vm:entry-point.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase is already initialised by the time this runs, but we call
  // ensureInitialized just in case the isolate is fresh.
  await Firebase.initializeApp();
  debugPrint('FCM background message: ${message.messageId}');
  // No UI work here — the Firestore escalation listener will pick it up
  // automatically once the user opens the app.
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint(
      "Warning: .env file not found. Ensure it exists and is added to assets in pubspec.yaml.",
    );
  }

  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS)) {
    await Firebase.initializeApp();
  } else {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  // Initialise the foreground service config (must be before startService is called).
  TripForegroundService.init();

  // Initialise local notifications (creates the Android channel).
  await NotificationService.init();

  // Register the background message handler before the app starts.
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Request notification permission (iOS requires explicit permission;
  // on Android 13+ this triggers the system prompt).
  await FirebaseMessaging.instance.requestPermission(
    alert: true,
    sound: true,
    badge: true,
  );

  // On iOS, show banners even while the app is in the foreground.
  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true,
    sound: true,
    badge: false,
  );

  // When the app is OPEN, Android suppresses FCM banners.
  // SafetyCheckListener already handles SAFETY_CHECK via its Firestore stream
  // (shows the undismissable dialog), so we only show a local banner for
  // non-SAFETY_CHECK messages here to avoid a double dialog.
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    final type = message.data['type'] ?? '';
    debugPrint('FCM foreground message [type=$type]: ${message.notification?.title}');

    // SAFETY_CHECK is handled by SafetyCheckListener dialog — skip banner.
    if (type == 'SAFETY_CHECK') return;

    final title = message.notification?.title;
    final body = message.notification?.body;
    if (title != null && body != null) {
      NotificationService.showSafetyCheck(
        title: title,
        body: body,
        attempt: 0, // ID=0 for non-safety-check local notifications
      );
    }
  });

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        StreamProvider<ActiveTripState>(
          create: (_) => TripManager().stateStream,
          initialData: TripManager().currentState,
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    return MaterialApp(
      title: 'Sentinel 360',
      navigatorKey: rootNavigatorKey,
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      debugShowCheckedModeBanner: false,
      themeMode: themeProvider.mode == AppThemeMode.dark
          ? ThemeMode.dark
          : themeProvider.mode == AppThemeMode.light
          ? ThemeMode.light
          : ThemeMode.system,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      builder: (context, child) => WearableSosListener(
        child: SafetyCheckListener(
          child: child ?? const SizedBox.shrink(),
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/auth': (context) => const AuthWrapper(),
        '/onboarding': (context) => const OnboardingScreen(),
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignupScreen(),
        '/home': (context) => const HomeScreen(),
        '/map': (context) => const MapScreen(),
        '/emergency': (context) => const EmergencyScreen(),
        '/device': (context) => const DeviceManagementScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/emergency_contacts': (context) => const EmergencyContactsScreen(),
        '/trip_history': (context) => const TripHistoryScreen(),
        '/trip_detail': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          final String? tripId = args is String ? args : null;
          if (tripId == null || tripId.isEmpty) {
            return Scaffold(
              appBar: AppBar(title: const Text('Trip')),
              body: const Center(
                child: Text('Missing or invalid trip ID'),
              ),
            );
          }
          return TripDetailScreen(tripId: tripId);
        },
      },
    );
  }
}
