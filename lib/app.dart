import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frier_cost/settings_page.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:google_fonts/google_fonts.dart';
import 'analysis_page.dart';
import 'dashboard_page.dart';
import 'ingredient_page.dart';
import 'inventory_page.dart';
import 'sales_page.dart';
import 'auth_gate.dart';

class FriedChickenCostApp extends ConsumerWidget {
  const FriedChickenCostApp({super.key});

  @override
   Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);

    return MaterialApp(
      title: 'Fried Chicken Cost Analysis',
      // theme: ThemeData(
      //   primaryColor: Color(0xFF2E7D32), // Green 800
      //   colorScheme: ColorScheme.light(
      //     primary: Color(0xFF2E7D32),
      //     secondary: Color(0xFFF57C00),
      //     surface: Colors.white,
      //     error: Color(0xFFD32F2F),
      //   ),
      //   textTheme: GoogleFonts.poppinsTextTheme().copyWith(
      //     bodyMedium: GoogleFonts.roboto(color: Color(0xFF212121)),
      //     bodySmall: GoogleFonts.roboto(color: Color(0xFF757575)),
      //     titleLarge: GoogleFonts.poppins(),
      //     headlineSmall: GoogleFonts.poppins(),
      //     titleMedium: GoogleFonts.poppins(),
      //     labelMedium: GoogleFonts.robotoMono(),
      //   ),
      //   cardTheme: CardTheme(
      //     elevation: 2,
      //     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      //   ),
      //   elevatedButtonTheme: ElevatedButtonThemeData(
      //     style: ElevatedButton.styleFrom(
      //       backgroundColor: Color(0xFF2E7D32),
      //       foregroundColor: Colors.white,
      //       shape: RoundedRectangleBorder(
      //         borderRadius: BorderRadius.circular(8),
      //       ),
      //     ),
      //   ),
      //   outlinedButtonTheme: OutlinedButtonThemeData(
      //     style: OutlinedButton.styleFrom(
      //       foregroundColor: Color(0xFF2E7D32),
      //       side: BorderSide(color: Color(0xFF2E7D32)),
      //       shape: RoundedRectangleBorder(
      //         borderRadius: BorderRadius.circular(8),
      //       ),
      //     ),
      //   ),
      //   dataTableTheme: DataTableThemeData(
      //     headingRowColor: WidgetStateProperty.all(Color(0xFFFAFAFA)),
      //     dataRowColor: WidgetStateProperty.resolveWith((states) {
      //       return states.contains(WidgetState.selected)
      //           ? Color(0xFFFAFAFA)
      //           : Colors.white;
      //     }),
      //   ),
      //   navigationBarTheme: NavigationBarThemeData(
      //     backgroundColor: Colors.white,
      //     indicatorColor: Color(0xFF2E7D32).withValues(alpha:  0.1),
      //     labelTextStyle: WidgetStateProperty.all(
      //       GoogleFonts.poppins(fontSize: 12, color: Color(0xFF757575)),
      //     ),
      //     iconTheme: WidgetStateProperty.resolveWith((states) {
      //       return IconThemeData(
      //         color: states.contains(WidgetState.selected)
      //             ? Color(0xFF2E7D32)
      //             : Color(0xFF757575),
      //       );
      //     }),
      //   ),
      //   visualDensity: VisualDensity.adaptivePlatformDensity,
      // ),
       theme: _lightTheme,
      darkTheme: _darkTheme,
      themeMode: themeMode,
      builder: (context, child) => ResponsiveBreakpoints.builder(
        child: child!,
        breakpoints: [
          Breakpoint(start: 0, end: 600, name: MOBILE),
          Breakpoint(start: 601, end: 1200, name: TABLET),
          Breakpoint(start: 1201, end: 1920, name: DESKTOP),
          Breakpoint(start: 1921, end: double.infinity, name: '4K'),
        ],
      ),
      home: AuthGate(),
      routes: {
        '/dashboard': (context) => DashboardPage(),
        '/inventory': (context) => InventoryPage(),
        '/sales': (context) => SalesPage(),
        '/analysis': (context) => AnalysisPage(),
        '/ingredients': (context) => IngredientPage(),
        '/settings': (context) => SettingsPage(),
      },
    );
  }
}
class AppColors {
  static const Color primary = Color(0xFF5E35B1);
  static const Color primaryLight = Color(0xFF9162E4);
  static const Color primaryDark = Color(0xFF3C1F8B);
  static const Color secondary = Color(0xFF26A69A);
  static const Color background = Color(0xFFF6F8FF);
  static const Color backgroundDark = Color(0xFF121212);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color cardDark = Color(0xFF1E1E1E);
  static const Color error = Color(0xFFD32F2F);
  static const Color success = Color(0xFF388E3C);
  static const Color textLight = Color(0xFF2E384D);
  static const Color textDark = Color(0xFFE0E0E0);
  static const Color textSecondaryLight = Color(0xFF6F7FAF);
  static const Color textSecondaryDark = Color(0xFF9E9E9E);
}
ThemeData _lightTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.light(
    primary: AppColors.primary,
    secondary: AppColors.secondary,
    error: AppColors.error,
    surface: AppColors.cardLight,
  ),
  textTheme: GoogleFonts.interTextTheme(),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      foregroundColor: Colors.white,
      backgroundColor: AppColors.primary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      padding: const EdgeInsets.symmetric(vertical: 16),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: AppColors.primary.withOpacity(0.3)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: AppColors.primary.withOpacity(0.3)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: AppColors.primary, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: AppColors.error, width: 1),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    labelStyle: TextStyle(color: AppColors.textSecondaryLight),
    prefixIconColor: AppColors.primary,
    suffixIconColor: AppColors.primary,
  ),
  cardTheme: CardTheme(
    elevation: 2,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    surfaceTintColor: Colors.white,
    color: AppColors.cardLight,
    shadowColor: AppColors.primary.withOpacity(0.1),
  ),
  scaffoldBackgroundColor: AppColors.background,
  snackBarTheme: SnackBarThemeData(
    behavior: SnackBarBehavior.floating,
    backgroundColor: AppColors.textLight,
    contentTextStyle: TextStyle(color: Colors.white),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  ),
);

ThemeData _darkTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.dark(
    primary: AppColors.primaryLight,
    secondary: AppColors.secondary,
    error: AppColors.error,
    surface: AppColors.cardDark,
  ),
  textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      foregroundColor: Colors.white,
      backgroundColor: AppColors.primaryLight,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      padding: const EdgeInsets.symmetric(vertical: 16),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: AppColors.cardDark,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: AppColors.primaryLight.withOpacity(0.3)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: AppColors.primaryLight.withOpacity(0.3)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: AppColors.primaryLight, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: AppColors.error, width: 1),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    labelStyle: TextStyle(color: AppColors.textSecondaryDark),
    prefixIconColor: AppColors.primaryLight,
    suffixIconColor: AppColors.primaryLight,
  ),
  cardTheme: CardTheme(
    elevation: 4,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    surfaceTintColor: AppColors.cardDark,
    color: AppColors.cardDark,
    shadowColor: Colors.black.withOpacity(0.3),
  ),
  scaffoldBackgroundColor: AppColors.backgroundDark,
  snackBarTheme: SnackBarThemeData(
    behavior: SnackBarBehavior.floating,
    backgroundColor: AppColors.cardDark,
    contentTextStyle: TextStyle(color: AppColors.textDark),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  ),
);