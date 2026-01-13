// lib/features/privacy/presentation/pages/privacy_page.dart

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:signature/signature.dart';

import '../../../visit/presentation/providers/visit_providers.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../shared/widgets/kiosk_scaffold.dart';

class PrivacyPage extends ConsumerStatefulWidget {
  const PrivacyPage({Key? key}) : super(key: key);

  @override
  ConsumerState<PrivacyPage> createState() => _PrivacyPageState();
}

class _PrivacyPageState extends ConsumerState<PrivacyPage> {
  bool _isItalian = true;
  bool _warningsAccepted = false;

  late final SignatureController _signatureController;

  @override
  void initState() {
    super.initState();
    _signatureController = SignatureController(
      penStrokeWidth: 3,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
    );
  }

  @override
  void dispose() {
    _signatureController.dispose();
    super.dispose();
  }

  static const String _privacyTextIt =
      'Il sottoscritto, preso atto dell’informativa sulla privacy Prot. # 41333801A17LTR_, '
      'resa per il trattamento dei dati personali ai sensi del Reg. EU 2016/679 GDPR, '
      'acconsente al trattamento dei dati personali di cui all’informativa stessa, ivi compresa '
      'la comunicazione nella misura necessaria per il perseguimento degli scopi relativi '
      'alla sicurezza.';

  static const String _privacyTextEn =
      'I have read and understood the information for privacy Prot. # 41333801A17LTR_, '
      'concerning the treatment of personal data according to EU Reg. 2016/679 GDPR and I agree '
      'to treatment of such personal information, including its distribution in the manner '
      'necessary to achieve the objectives of security.';

  static const List<String> _warningsIt = [
    'Esporre il tesserino personale in modo visibile per tutta la permanenza in azienda e segnalarne immediatamente lo smarrimento.',
    'La permanenza nei locali aziendali è consentita solo in presenza di dipendenti aziendali.',
    'Vietato riprodurre documenti aziendali in alcuna forma.',
    'Vietato introdurre fotocamere, telecamere, registratori, smartphone, ecc…',
    'Non è consentito fumare all’interno dello stabilimento.',
    'Custodire sotto la propria responsabilità oggetti personali ed acconsentire ai controlli da parte della vigilanza.',
    'I luoghi aziendali sono sottoposti a videosorveglianza.',
    'La connessione alla rete aziendale è vietata e dovrà essere espressamente autorizzata.',
  ];

  static const List<String> _warningsEn = [
    'Badge is personal and must be clearly exhibited during the stay inside the company and, in case of loss, immediately informed.',
    'Permanence inside company plant is submitted to the presence of company’s employees.',
    'It is forbidden to reproduce company’s documents in any way.',
    'It is forbidden to introduce cameras, videos, recorders, smartphones, etc…',
    'Smoking is not allowed within the company premises.',
    'The company is not responsible for unsupervised personal belongings and they can be checked by security staff, if needed.',
    'All areas are subjected to video surveillance.',
    'It is forbidden to connect to the company network, unless authorized.',
  ];

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(visitControllerProvider);
    final visit = state.currentVisit;

    return KioskScaffold(
      title: _isItalian ? 'Informativa privacy' : 'Privacy notice',
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: visit == null
                ? _buildNoVisitContent(context)
                : _buildPrivacyContent(context, visit),
          ),
        ),
      ),
    );
  }

  Widget _buildNoVisitContent(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.info_outline,
          size: 64,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 16),
        Text(
          _isItalian ? 'Nessuna visita in corso' : 'No ongoing visit',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          _isItalian
              ? 'Per procedere con la privacy è necessario prima effettuare il check-in.'
              : 'To proceed with the privacy notice you first need to complete the check-in.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 48,
          child: ElevatedButton(
            onPressed: () {
              Navigator.of(context).pushNamedAndRemoveUntil(
                AppRouter.initialRoute,
                    (route) => false,
              );
            },
            child: Text(_isItalian ? 'Torna al check-in' : 'Back to check-in'),
          ),
        ),
      ],
    );
  }

  Widget _buildLanguageToggle() {
    return ToggleButtons(
      isSelected: [_isItalian, !_isItalian],
      onPressed: (index) {
        setState(() {
          _isItalian = (index == 0);
        });
      },
      borderRadius: BorderRadius.circular(20),
      constraints: const BoxConstraints(minHeight: 36, minWidth: 48),
      children: const [
        Padding(padding: EdgeInsets.symmetric(horizontal: 8.0), child: Text('IT')),
        Padding(padding: EdgeInsets.symmetric(horizontal: 8.0), child: Text('EN')),
      ],
    );
  }

  Widget _buildWarningsSection(BuildContext context) {
    final warnings = _isItalian ? _warningsIt : _warningsEn;
    final title = _isItalian ? 'Avvertenze' : 'Notice';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        ...warnings.map(
              (w) => Padding(
            padding: const EdgeInsets.only(bottom: 6.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('•  '),
                Expanded(child: Text(w, textAlign: TextAlign.justify)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPrivacyContent(BuildContext context, dynamic visit) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isItalian
                        ? 'Stai registrando la visita di:'
                        : 'You are registering the visit of:',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${visit.firstName} ${visit.lastName}',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  if (visit.reason != null && visit.reason!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      _isItalian ? 'Motivo: ${visit.reason}' : 'Reason: ${visit.reason}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 16),
            _buildLanguageToggle(),
          ],
        ),

        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 24),

        Text(
          _isItalian
              ? 'Consenso al trattamento dei dati personali'
              : 'Consent to treatment of personal information',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        Text(_isItalian ? _privacyTextIt : _privacyTextEn, textAlign: TextAlign.justify),
        const SizedBox(height: 24),

        _buildWarningsSection(context),
        const SizedBox(height: 24),

        CheckboxListTile(
          value: _warningsAccepted,
          onChanged: (value) {
            setState(() {
              _warningsAccepted = value ?? false;
            });
          },
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          title: Text(
            _isItalian
                ? 'Dichiaro di aver preso visione delle avvertenze riportate'
                : 'I declare that I have read and understood the above Notice',
          ),
        ),
        const SizedBox(height: 24),

        // ✅ FIRMA
        Text(
          _isItalian ? 'Firma del visitatore' : 'Visitor signature',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Container(
          height: 180,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade400),
          ),
          clipBehavior: Clip.antiAlias,
          child: Signature(
            controller: _signatureController,
            backgroundColor: Colors.transparent,
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => _signatureController.clear(),
            icon: const Icon(Icons.refresh),
            label: Text(_isItalian ? 'Cancella firma' : 'Clear signature'),
          ),
        ),
        const SizedBox(height: 32),

        SizedBox(
          height: 48,
          child: ElevatedButton(
            onPressed: _warningsAccepted
                ? () async {
              // 1) firma presente
              if (_signatureController.isEmpty) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      _isItalian
                          ? 'Per favore, inserisci la firma prima di continuare.'
                          : 'Please provide your signature before continuing.',
                    ),
                  ),
                );
                return;
              }

              // 2) export PNG
              final pngBytes = await _signatureController.toPngBytes();
              if (pngBytes == null || pngBytes.isEmpty) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      _isItalian
                          ? 'Impossibile esportare la firma. Riprova.'
                          : 'Unable to export signature. Please try again.',
                    ),
                  ),
                );
                return;
              }

              // 3) base64
              final signatureBase64 = base64Encode(pngBytes);

              // 4) salva su Odoo + consenso true
              final controller = ref.read(visitControllerProvider.notifier);
              await controller.acceptPrivacyWithSignature(
                signaturePngBase64: signatureBase64,
              );

              final state = ref.read(visitControllerProvider);
              if (state.errorMessage != null) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(state.errorMessage!)),
                );
                return;
              }

              // 5) prosegui flusso
              if (!context.mounted) return;
              Navigator.of(context).pushNamed(AppRouter.badgeScanRoute);
            }
                : null,
            child: Text(
              _isItalian ? 'Conferma privacy e continua' : 'Confirm privacy and continue',
            ),
          ),
        ),
      ],
    );
  }
}
