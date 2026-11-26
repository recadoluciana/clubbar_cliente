import 'package:material_ui/material_ui.dart';

import 'core/theme/app_colors.dart';
import 'screens/splash/splash_screen.dart';

class ClubbarApp extends StatelessWidget {
  const ClubbarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Clubbar',
      builder: (context, child) => MaterialUiCompatibilityBridge(child: child!),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.marromClubbar,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: AppColors.cremeFundo,
        cardTheme: const CardThemeData(
          color: AppColors.cremeCard,
          elevation: 0,
          margin: EdgeInsets.zero,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.marromClubbar,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(22)),
            ),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.marromClubbar,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(22)),
            ),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.pretoBase,
          foregroundColor: AppColors.branco,
          centerTitle: true,
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: AppColors.marromClubbar, width: 1.5),
          ),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}
