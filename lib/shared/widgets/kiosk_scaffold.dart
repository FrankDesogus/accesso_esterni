import 'package:flutter/material.dart';

class KioskScaffold extends StatelessWidget {
  const KioskScaffold({
    super.key,
    required this.child,
    this.title,
    this.showBack = false,
    this.onBack,
  });

  final Widget child;
  final String? title;

  // ✅ nuovi
  final bool showBack;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: title != null
          ? AppBar(
        title: Text(title!),
        centerTitle: true,

        // ✅ back “forzato” quando serve
        leading: showBack
            ? IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: onBack,
        )
            : null,

        // se metti leading manuale, evita che Flutter provi a metterne uno suo
        automaticallyImplyLeading: !showBack,
      )
          : null,
      body: SafeArea(child: child),
    );
  }
}
