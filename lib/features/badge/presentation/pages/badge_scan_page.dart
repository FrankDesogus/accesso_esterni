// lib/features/badge/presentation/pages/badge_scan_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../shared/widgets/kiosk_scaffold.dart';
import '../../../visit/presentation/providers/visit_providers.dart';

class BadgeScanPage extends ConsumerStatefulWidget {
  const BadgeScanPage({super.key});

  @override
  ConsumerState<BadgeScanPage> createState() => _BadgeScanPageState();
}

class _BadgeScanPageState extends ConsumerState<BadgeScanPage> {
  final MobileScannerController _scannerController = MobileScannerController();
  bool _isProcessing = false;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _handleBarcodeDetection(BarcodeCapture capture) async {
    if (!mounted || _isProcessing) return;
    if (capture.barcodes.isEmpty) return;

    final rawValue = capture.barcodes.first.rawValue?.trim();
    if (rawValue == null || rawValue.isEmpty) return;

    final badgeCode = rawValue;

    setState(() => _isProcessing = true);

    try {
      await _scannerController.stop();

      final controller = ref.read(visitControllerProvider.notifier);
      await controller.assignBadgeAndCheckIn(badgeCode: badgeCode);

      if (!mounted) return;

      final state = ref.read(visitControllerProvider);
      if (state.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(state.errorMessage!)),
        );

        setState(() => _isProcessing = false);
        await _scannerController.start();
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Badge registrato con successo!')),
      );

      Future.delayed(const Duration(seconds: 3), () {
        if (!mounted) return;
        Navigator.of(context).pushNamedAndRemoveUntil(
          AppRouter.initialRoute,
              (route) => false,
        );
      });
    } catch (e) {
      // Errori tipo stop/start scanner o eccezioni non gestite
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore: $e')),
      );

      setState(() => _isProcessing = false);

      // prova a riavviare lo scanner
      try {
        await _scannerController.start();
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final visitState = ref.watch(visitControllerProvider);
    final hasVisit = visitState.currentVisit != null;

    return KioskScaffold(
      title: 'Associa il tuo badge',
      child: hasVisit
          ? Column(
        children: [
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'Inquadra il QR code del badge che ti è stato consegnato '
                  'per associarlo alla tua visita.',
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Stack(
              children: [
                MobileScanner(
                  controller: _scannerController,
                  onDetect: _handleBarcodeDetection,
                ),
                Align(
                  alignment: Alignment.center,
                  child: Container(
                    width: 260,
                    height: 260,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white,
                        width: 3,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_isProcessing)
            const Padding(
              padding: EdgeInsets.only(bottom: 16.0),
              child: CircularProgressIndicator(),
            )
          else
            const SizedBox(height: 32),
        ],
      )
          : Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Nessuna visita in corso.\n'
                    'Torna alla schermata iniziale per iniziare un nuovo check-in.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    AppRouter.initialRoute,
                        (route) => false,
                  );
                },
                child: const Text('Torna alla home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
