import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'splash_screen.dart';
import 'package:firebase_database/firebase_database.dart';
import 'settings_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseDatabase.instance.databaseURL =
      "https://chessmate-4e542-default-rtdb.europe-west1.firebasedatabase.app/";

  runApp(
    ChangeNotifierProvider(
      create: (_) => SettingsProvider(),
      child: const ChessMateApp(),
    ),
  );
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
        scaffoldBackgroundColor: Colors.black,
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}
