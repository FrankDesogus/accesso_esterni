import 'package:flutter/material.dart';

/// Scaffold base da riutilizzare in tutte le schermate del KIOSK.
/// Puoi aggiungere logo aziendale, footer, sfondo, ecc.
class KioskScaffold extends StatelessWidget {
  const KioskScaffold({
    super.key,
    required this.child,
    this.title,
  });

  final Widget child;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: title != null
          ? AppBar(
        title: Text(title!),
        centerTitle: true,
      )
          : null,
      body: SafeArea(
        child: child,
      ),
    );
  }
}
