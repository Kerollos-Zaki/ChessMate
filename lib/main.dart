import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'splash_screen.dart'; //

void main() async {
  // Ensures Flutter framework is ready before calling native code (Firebase)
  WidgetsFlutterBinding.ensureInitialized();

  // Initializes Firebase using the configurations in your firebase_options.dart
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform, //
  );

  runApp(const ChessMateApp());
}

class ChessMateApp extends StatelessWidget {
  const ChessMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ChessMate',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black, // Matches your UI design
        useMaterial3: true,
      ),
      // Starts the application flow with the Splash Screen
      home: const SplashScreen(),
    );
  }
}