import 'package:flutter/material.dart';
import 'package:frier_cost/settings_page.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:google_fonts/google_fonts.dart';
import 'analysis_page.dart';
import 'dashboard_page.dart';
import 'ingredient_page.dart';
import 'inventory_page.dart';
import 'sales_page.dart';
import 'auth_gate.dart';

class FriedChickenCostApp extends StatelessWidget {
  const FriedChickenCostApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fried Chicken Cost Analysis',
      theme: ThemeData(
        primaryColor: Color(0xFF2E7D32), // Green 800
        colorScheme: ColorScheme.light(
          primary: Color(0xFF2E7D32),
          secondary: Color(0xFFF57C00),
          surface: Colors.white,
          error: Color(0xFFD32F2F),
        ),
        textTheme: GoogleFonts.poppinsTextTheme().copyWith(
          bodyMedium: GoogleFonts.roboto(color: Color(0xFF212121)),
          bodySmall: GoogleFonts.roboto(color: Color(0xFF757575)),
          titleLarge: GoogleFonts.poppins(),
          headlineSmall: GoogleFonts.poppins(),
          titleMedium: GoogleFonts.poppins(),
          labelMedium: GoogleFonts.robotoMono(),
        ),
        cardTheme: CardTheme(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFF2E7D32),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: Color(0xFF2E7D32),
            side: BorderSide(color: Color(0xFF2E7D32)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        dataTableTheme: DataTableThemeData(
          headingRowColor: WidgetStateProperty.all(Color(0xFFFAFAFA)),
          dataRowColor: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.selected)
                ? Color(0xFFFAFAFA)
                : Colors.white;
          }),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.white,
          indicatorColor: Color(0xFF2E7D32).withValues(alpha:  0.1),
          labelTextStyle: WidgetStateProperty.all(
            GoogleFonts.poppins(fontSize: 12, color: Color(0xFF757575)),
          ),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            return IconThemeData(
              color: states.contains(WidgetState.selected)
                  ? Color(0xFF2E7D32)
                  : Color(0xFF757575),
            );
          }),
        ),
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
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
