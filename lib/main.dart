import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

// Import screens
import 'screens/splash.dart';
import 'screens/admin-dash.dart';
import 'screens/driver-dash.dart';
import 'screens/pass-dash.dart';
import 'screens/role.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      initialRoute: "/",
      routes: {
        "/": (_) => const SplashScreen(),
        "/role": (_) => const SelectRolePage(),
        "/admin": (_) => const AdminDashboard(adminEmail: ""),
        "/driver": (_) => DriverDashboard(userEmail: ""),
        "/passenger": (_) => const PassengerPage(),
      },
    );
  }
}
