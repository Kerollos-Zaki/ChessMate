import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'splash_screen.dart'; //
import 'package:firebase_database/firebase_database.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Add this line to point to your specific Belgium server
  FirebaseDatabase.instance.databaseURL =
  "https://chessmate-4e542-default-rtdb.europe-west1.firebasedatabase.app/";

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