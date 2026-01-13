import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // TODO: Qui in futuro potrai inizializzare servizi, logging, ecc.

  runApp(
    const ProviderScope(
      // ProviderScope è il container principale di Riverpod
      child: KioskApp(),
    ),
  );
}
