import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../shared/widgets/kiosk_scaffold.dart';
import '../../../visit/presentation/providers/visit_providers.dart';

class BadgeCheckoutScanPage extends ConsumerStatefulWidget {
  const BadgeCheckoutScanPage({super.key});

  @override
  ConsumerState<BadgeCheckoutScanPage> createState() => _BadgeCheckoutScanPageState();
}

class _BadgeCheckoutScanPageState extends ConsumerState<BadgeCheckoutScanPage> {
  final MobileScannerController _scannerController = MobileScannerController();
  bool _isProcessing = false;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _handleDetect(BarcodeCapture capture) async {
    if (!mounted || _isProcessing) return;
    if (capture.barcodes.isEmpty) return;

    final code = capture.barcodes.first.rawValue?.trim();
    if (code == null || code.isEmpty) return;

    setState(() => _isProcessing = true);

    try {
      await _scannerController.stop();

      final controller = ref.read(visitControllerProvider.notifier);
      await controller.checkOutByBadgeCode(badgeCode: code);

      if (!mounted) return;
      final s = ref.read(visitControllerProvider);

      if (s.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.errorMessage!)),
        );

        setState(() => _isProcessing = false);
        await _scannerController.start();
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Uscita registrata. Badge liberato.')),
      );

      Future.delayed(const Duration(seconds: 3), () {
        if (!mounted) return;
        Navigator.of(context).pushNamedAndRemoveUntil(
          AppRouter.initialRoute,
              (route) => false,
        );
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore: $e')),
      );

      setState(() => _isProcessing = false);
      try {
        await _scannerController.start();
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = ref.watch(visitControllerProvider);

    return KioskScaffold(
      title: 'Registra uscita',
      child: Column(
        children: [
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'Inquadra il QR del badge per registrare l’uscita e liberare il badge.',
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Stack(
              children: [
                MobileScanner(
                  controller: _scannerController,
                  onDetect: _handleDetect,
                ),
                Align(
                  alignment: Alignment.center,
                  child: Container(
                    width: 260,
                    height: 260,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_isProcessing || st.isLoading)
            const Padding(
              padding: EdgeInsets.only(bottom: 16.0),
              child: CircularProgressIndicator(),
            )
          else
            const SizedBox(height: 32),
        ],
      ),
    );
  }
}
