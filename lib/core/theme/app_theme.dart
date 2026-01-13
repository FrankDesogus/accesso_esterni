import 'package:flutter/material.dart';

class AppTheme {
  /// Costruisce il tema principale dell'app KIOSK.
  /// Qui puoi definire colori aziendali, font, dimensione pulsanti, ecc.
  static ThemeData buildTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primarySwatch: Colors.blue,
      scaffoldBackgroundColor: Colors.white,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      // TODO: personalizza tipografia e componenti (bottoni, textfield, ecc.)
    );
  }
}
