import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';
import 'providers/theme_provider.dart';
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

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
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
      debugShowCheckedModeBanner: false,
      themeMode: themeProvider.mode == AppThemeMode.dark
          ? ThemeMode.dark
          : themeProvider.mode == AppThemeMode.light
          ? ThemeMode.light
          : ThemeMode.system,
      theme: ThemeData.light(
        useMaterial3: false,
      ).copyWith(primaryColor: Colors.blue),
      darkTheme: ThemeData.dark(
        useMaterial3: false,
      ).copyWith(primaryColor: Colors.blue),
      initialRoute: '/',
      routes: {
        '/': (context) => const AuthWrapper(),
        '/onboarding': (context) => const OnboardingScreen(),
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignupScreen(),
        '/home': (context) => const HomeScreen(),
        '/map': (context) => const MapScreen(),
        '/emergency': (context) => const EmergencyScreen(),
        '/device': (context) => const DeviceManagementScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/emergency_contacts': (context) => const EmergencyContactsScreen(),
      },
    );
  }
}
