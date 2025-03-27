import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:ibn_al_attar/login_screen.dart';
import 'package:ibn_al_attar/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: const FirebaseOptions(
        apiKey: "AIzaSyBzGrnMRQx1Uuxfj6bQE1jd0jmGfGIllK8",
        authDomain: "iyad-adnan.firebaseapp.com",
        projectId: "iyad-adnan",
        storageBucket: "iyad-adnan.firebasestorage.app",
        messagingSenderId: "653887959133",
        appId: "1:653887959133:web:6b90263e494a44b25dddb4",
        measurementId: "G-B3ZEX57NBR"
    ),
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Store Management',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}
