import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/home_screen.dart';
import 'screens/map_screen.dart';
import 'screens/ride_status_screen.dart';
import 'screens/emergency_screen.dart';
import 'screens/device_management_screen.dart';
import 'screens/profile_screen.dart';
// Uncomment below if you plan to use Firebase
// import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Uncomment if using Firebase
  // await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Capstone Final',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Poppins', // use Google Fonts later
      ),
      home: const OnboardingScreen(),
      routes: {
        '/onboarding': (context) => const OnboardingScreen(),
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
        '/map': (context) => const MapScreen(),
        '/ride_status': (context) => const RideStatusScreen(),
        '/emergency': (context) => const EmergencyScreen(),
        '/device': (context) => const DeviceManagementScreen(),
        '/profile': (context) => const ProfileScreen(),
      },
    );
  }
}
