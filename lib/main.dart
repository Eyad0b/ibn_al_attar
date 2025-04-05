import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:ibn_al_attar/core/constants/app_colors.dart';
import 'package:ibn_al_attar/data/repositories/storage_repository.dart';
import 'package:ibn_al_attar/features/auth/login_screen.dart';
import 'package:ibn_al_attar/features/admin_panel/admin_panel_screen.dart';

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
    return MultiProvider(
      providers: [
        Provider(create: (_) => StorageRepository()),
      ],
      child: MaterialApp(
        title: 'Ibn Al-Attar',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.primary,
            primary: AppColors.primary,
            secondary: AppColors.secondary,
          ),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          floatingActionButtonTheme: const FloatingActionButtonThemeData(
            backgroundColor: AppColors.primary,
          ),
        ),
        home: StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            return snapshot.hasData && snapshot.data?.email == 'admin@ibnalattar.com'
                ? const AdminPanelScreen()
                : const LoginScreen();
          },
        ),
      ),
    );
  }
}
