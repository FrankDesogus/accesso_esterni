import 'package:accesso_esterni/features/badge/presentation/pages/badge_checkout_scan_page.dart';
import 'package:flutter/material.dart';
import '../../features/visit/presentation/pages/visit_checkin_page.dart';
import '../../features/privacy/presentation/pages/privacy_page.dart';
import '../../features/badge/presentation/pages/badge_scan_page.dart';

class AppRouter {
  static const String initialRoute = '/visit/checkin';
  static const String privacyRoute = '/privacy';
  static const String badgeScanRoute = '/badge/scan';
  static const checkoutScanRoute = '/checkout-scan';


  /// Metodo centrale per generare le route dell'app.
  /// In futuro potrai espanderlo con tutte le schermate necessarie.
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case initialRoute:
        return MaterialPageRoute(
          builder: (_) => const VisitCheckInPage(),
          settings: settings,
        );
      case privacyRoute:
        return MaterialPageRoute(
          builder: (_) => const PrivacyPage(),
          settings: settings,
        );
      case badgeScanRoute: // 👈 NUOVO CASE
        return MaterialPageRoute(
          builder: (_) => const BadgeScanPage(),
          settings: settings,
        );
      case checkoutScanRoute: // 👈 NUOVO CASE
        return MaterialPageRoute(
          builder: (_) => const BadgeCheckoutScanPage(),
          settings: settings,
        );
      default:
      // Schermata di fallback se il nome rotta non è riconosciuto
        return MaterialPageRoute(
          builder: (_) => const VisitCheckInPage(),
          settings: settings,
        );
    }
  }
}
