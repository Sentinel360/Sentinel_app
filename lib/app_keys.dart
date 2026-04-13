import 'package:flutter/material.dart';

/// Root [ScaffoldMessenger] for app-wide snack bars (e.g. wearable SOS ack).
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

/// Root [Navigator] key — lets widgets outside the tree show dialogs.
final GlobalKey<NavigatorState> rootNavigatorKey =
    GlobalKey<NavigatorState>();
