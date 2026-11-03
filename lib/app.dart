import 'package:flutter/material.dart';
import 'core/theme/app_colors.dart';
import 'screens/splash/splash_screen.dart';

class ClubbarApp extends StatelessWidget {
  const ClubbarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Clubbar',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.amareloCerveja),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.pretoBase,
          foregroundColor: AppColors.branco,
          centerTitle: true,
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}
