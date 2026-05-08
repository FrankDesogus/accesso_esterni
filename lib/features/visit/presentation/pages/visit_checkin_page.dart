import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/visit_providers.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../shared/widgets/kiosk_scaffold.dart';
import '../../../../core/config/app_config.dart';
import '../../../../shared/utils/document_key.dart';

enum _HomeMode { none, checkin }

class SelectionOption {
  final String value; // ✅ VALUE reale della selection (es: Carta_Identità)
  final String label; // ✅ testo mostrato in UI (es: Carta d'Identità)
  const SelectionOption({required this.value, required this.label});
}

class VisitCheckInPage extends ConsumerStatefulWidget {
  const VisitCheckInPage({Key? key}) : super(key: key);

  @override
  ConsumerState<VisitCheckInPage> createState() => _VisitCheckInPageState();
}

class _VisitCheckInPageState extends ConsumerState<VisitCheckInPage> {
  // =========================
  // DEBUG FLAGS
  // =========================
  static const bool _debugVisitors = true;

  _HomeMode _mode = _HomeMode.none;

  final _formKey = GlobalKey<FormState>();

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _reasonController = TextEditingController();
  final _companyController = TextEditingController();
  final _docNumberController = TextEditingController();

  // ✅ TITOLO (Sig., Sig.na, Dott., Ing, ...)
  static const List<String> _titleOptions = [
    'Sig.',
    'Sig.ra',
    'Sig.na',
    'Dott.',
    'Dott.ssa',
    'Ing.',
    'Avv.',
    'Prof.',
    'Prof.ssa',
  ];
  String? _titleValue;

  // ✅ MOTIVO VISITA: dropdown + textbox solo se "Altro"
  static const List<String> _reasonOptions = [
    'Colloquio',
    'Direzione Generale',
    'Direzione Stabilimento',
    'Direzione Acquisti',
    'Direzione Tecnica',
    'Direzione Di Produzione',
    'Officina Meccanica',
    'Amministrazione',
    // aggiungi qui altre opzioni...
    'Altro',
  ];
  String? _reasonSelected;

  // ✅ Scadenza documento (opzionale)
  DateTime? _docExpiry;

  // ✅ VISITOR AUTOCOMPLETE (fix più probabile: controller corretto di Autocomplete)
  TextEditingController? _visitorFieldController; // sarà quello fornito da Autocomplete
  bool _visitorListenerAttached = false;

  Timer? _visitorDebounce;
  List<_VisitorOption> _visitorSuggestions = const [];
  bool _loadingVisitors = false;
  String? _visitorsError;

  // ✅ DOC TYPES
  List<SelectionOption> _docTypeOptions = const [];
  bool _loadingDocTypes = false;
  String? _docTypesError;

  // ✅ Selected VALUE da inviare a Odoo
  String? _docTypeValue;

  // ✅ HOSTS
  List<_HostOption> _hosts = const [];
  bool _loadingHosts = false;
  String? _hostsError;

  int? _selectedHostId;
  String? _selectedHostName;

  String? _hostsDomainDebug;

  // ⚠️ Campi reali (dal tuo flow)
  static const String _modelVisitor = 'x_visitatori';
  static const String _fieldVisitor = 'x_studio_tipo_di_documento';

  static const String _modelVisit = 'x_visite';
  static const String _fieldVisit = 'x_studio_tipo_di_documento_visita';

  @override
  void initState() {
    super.initState();
    debugPrint('[VisitCheckInPage] initState CALLED');

    Future.microtask(() async {
      await _loadDocTypeOptions();
      await _loadHosts();
    });
  }

  @override
  void dispose() {
    _visitorDebounce?.cancel();

    _firstNameController.dispose();
    _lastNameController.dispose();
    _reasonController.dispose();
    _companyController.dispose();
    _docNumberController.dispose();
    super.dispose();
  }

  // ---------------------------
  // DEBUG HELPERS
  // ---------------------------
  String _hexCodepoints(String s) => s.runes
      .map((r) => 'U+${r.toRadixString(16).toUpperCase().padLeft(4, '0')}')
      .join(' ');

  void _logOption(SelectionOption o, String tag) {
    debugPrint('$tag value="${o.value}" label="${o.label}"');
    debugPrint('$tag value cps: ${_hexCodepoints(o.value)}');
    debugPrint('$tag label cps: ${_hexCodepoints(o.label)}');
  }

  void _resetFormUi() {
    // reset visitor autocomplete
    _visitorDebounce?.cancel();
    _visitorFieldController?.clear();
    _visitorSuggestions = const [];
    _visitorsError = null;
    _loadingVisitors = false;

    _firstNameController.clear();
    _lastNameController.clear();
    _reasonController.clear();
    _companyController.clear();
    _docNumberController.clear();

    _titleValue = null;

    // ✅ reset motivo visita
    _reasonSelected = null;

    _docExpiry = null;

    _docTypeValue = null;

    _selectedHostId = null;
    _selectedHostName = null;
  }

  // ---------------------------
  // VISITOR SEARCH (AUTOCOMPLETE)
  // ---------------------------
  void _ensureVisitorListener(TextEditingController textController) {
    // Attacca una sola volta un listener al controller di Autocomplete.
    // Questo è il FIX più probabile: Autocomplete deve ascoltare il SUO controller.
    if (_visitorListenerAttached && identical(_visitorFieldController, textController)) return;

    _visitorFieldController = textController;
    if (_debugVisitors) {
      debugPrint('[VISITOR] field controller attached (hash=${textController.hashCode})');
    }

    if (!_visitorListenerAttached) {
      _visitorListenerAttached = true;
      textController.addListener(() {
        final v = textController.text;
        _onVisitorSearchChanged(v);
      });
    }
  }

  void _onVisitorSearchChanged(String value) {
    final q = value.trim();

    if (_debugVisitors) {
      debugPrint('[VISITOR] onChanged="$q" (len=${q.length})');
    }

    _visitorDebounce?.cancel();

    if (q.isEmpty) {
      if (!mounted) return;
      setState(() {
        _visitorSuggestions = const [];
        _visitorsError = null;
        _loadingVisitors = false;
      });
      return;
    }

    _visitorDebounce = Timer(const Duration(milliseconds: 350), () {
      _searchVisitors(q);
    });
  }

  Future<void> _searchVisitors(String query) async {
    final q = query.trim();
    if (q.length < 2) {
      if (!mounted) return;
      setState(() {
        _visitorSuggestions = const [];
        _visitorsError = null;
        _loadingVisitors = false;
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _loadingVisitors = true;
      _visitorsError = null;
    });

    try {
      final odoo = ref.read(odooClientProvider);

      final normalizedDoc = normalizeDocNumber(q);

      final domain = [
        '|',
        '|',
        ['x_studio_nome', 'ilike', q],
        ['x_studio_cognome', 'ilike', q],
        ['x_studio_numero_documento', 'ilike', normalizedDoc.isEmpty ? q : normalizedDoc],
      ];

      if (_debugVisitors) {
        debugPrint('[VISITOR] searchRead model=${AppConfig.visitorModel} domain=$domain');
      }

      final res = await odoo.searchRead(
        model: AppConfig.visitorModel, // tipicamente 'x_visitatori'
        domain: domain,
        fields: const [
          'id',
          'x_studio_nome',
          'x_studio_cognome',
          'x_studio_tipo_di_documento',
          'x_studio_numero_documento',
          // ✅ nuovi campi (devono esistere su x_visitatori)
          'x_studio_societa',
          'x_studio_titolo',
          'x_studio_scadenza_documento',
        ],
        limit: 20,
      );

      if (_debugVisitors) {
        debugPrint('[VISITOR] res.length=${res.length}');
        if (res.isNotEmpty) {
          debugPrint('[VISITOR] res.first=${res.first}');
        }
      }

      final list = <_VisitorOption>[];
      for (final row in res) {
        final id = row['id'];
        if (id is! int) continue;

        final nome = (row['x_studio_nome'] ?? '').toString().trim();
        final cognome = (row['x_studio_cognome'] ?? '').toString().trim();
        if (nome.isEmpty && cognome.isEmpty) continue;

        list.add(_VisitorOption(
          id: id,
          nome: nome,
          cognome: cognome,
          docTipoValue: row['x_studio_tipo_di_documento']?.toString().trim(),
          docNumero: row['x_studio_numero_documento']?.toString().trim(),
          company: row['x_studio_societa']?.toString().trim(),
          title: row['x_studio_titolo']?.toString().trim(),
          docExpiry: _parseOdooDate(row['x_studio_scadenza_documento']), // ✅ AGGIUNTO
        ));
      }

      list.sort((a, b) => a.display.toLowerCase().compareTo(b.display.toLowerCase()));

      if (!mounted) return;
      setState(() {
        _visitorSuggestions = list;
        _loadingVisitors = false;
      });

      if (_debugVisitors) {
        debugPrint('[VISITOR] suggestions.length=${list.length}');
        for (var i = 0; i < list.length && i < 5; i++) {
          debugPrint('[VISITOR] sugg[$i]=${list[i].display}');
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingVisitors = false;
        _visitorsError = e.toString();
        _visitorSuggestions = const [];
      });

      if (_debugVisitors) {
        debugPrint('[VISITOR] ERROR: $e');
      }
    }
  }

  void _applyVisitorAutofill(_VisitorOption v) {
    if (_debugVisitors) {
      debugPrint('[VISITOR] APPLY AUTOFILL -> ${v.display}');
    }

    _firstNameController.text = v.nome;
    _lastNameController.text = v.cognome;

    // ✅ Società
    if (v.company != null && v.company!.trim().isNotEmpty) {
      _companyController.text = v.company!.trim();
    }

    // ✅ Titolo
    if (v.title != null && v.title!.trim().isNotEmpty) {
      final t = v.title!.trim();
      final exists = _titleOptions.any((x) => x == t);
      setState(() => _titleValue = exists ? t : null);
    }
    if (v.docExpiry != null) {
      setState(() => _docExpiry = v.docExpiry);
    }


    final tipo = v.docTipoValue;
    if (tipo != null && tipo.isNotEmpty) {
      final exists = _docTypeOptions.any((o) => o.value == tipo);
      if (exists) {
        setState(() => _docTypeValue = tipo);
      } else if (_debugVisitors) {
        debugPrint('[VISITOR] docTipoValue "$tipo" not found in _docTypeOptions');
      }
    }

    final num = v.docNumero;
    if (num != null && num.isNotEmpty) {
      _docNumberController.text = num;
    }
  }

  // ---------------------------
  // DOC TYPES
  // ---------------------------
  Future<List<SelectionOption>> _loadSelectionViaFieldsGet({
    required String model,
    required String fieldName,
  }) async {
    final odoo = ref.read(odooClientProvider);

    debugPrint('[DOC_TYPES] fields_get START model=$model field=$fieldName');

    final fields = await odoo.fieldsGet(
      model: model,
      fieldNames: [fieldName],
      attributes: const ['selection', 'type', 'string', 'required', 'readonly'],
    ).timeout(const Duration(seconds: 15));

    final fieldInfo = fields[fieldName];
    if (fieldInfo is! Map) {
      throw Exception('fields_get: fieldInfo non valido per $model.$fieldName');
    }

    debugPrint('[DOC_TYPES] $model.$fieldName type=${fieldInfo['type']} string="${fieldInfo['string']}"');

    final selection = fieldInfo['selection'];
    if (selection is! List) {
      throw Exception(
        'fields_get: selection non valida per $model.$fieldName (got ${selection.runtimeType})',
      );
    }

    debugPrint('[DOC_TYPES] $model.$fieldName selection RAW len=${selection.length}');
    for (var i = 0; i < selection.length && i < 30; i++) {
      debugPrint('[DOC_TYPES] $model.$fieldName selection[$i]=${selection[i]}');
    }

    final options = <SelectionOption>[];
    for (final item in selection) {
      if (item is List && item.length >= 2) {
        final value = item[0]?.toString().trim() ?? '';
        final label = item[1]?.toString().trim() ?? '';
        if (value.isEmpty || label.isEmpty) continue;
        options.add(SelectionOption(value: value, label: label));
      }
    }

    options.sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));

    debugPrint('[DOC_TYPES] $model.$fieldName parsed count=${options.length}');
    for (var i = 0; i < options.length && i < 5; i++) {
      _logOption(options[i], '[DOC_TYPES][SAMPLE][$model.$fieldName][$i]');
    }

    debugPrint('[DOC_TYPES] fields_get END model=$model field=$fieldName');
    return options;
  }

  Future<void> _loadDocTypeOptions() async {
    debugPrint('[DOC_TYPES] ===== LOAD START =====');

    setState(() {
      _loadingDocTypes = true;
      _docTypesError = null;
    });

    try {
      final visitor = await _loadSelectionViaFieldsGet(model: _modelVisitor, fieldName: _fieldVisitor);
      final visit = await _loadSelectionViaFieldsGet(model: _modelVisit, fieldName: _fieldVisit);

      final visitorValues = visitor.map((o) => o.value).toSet();
      final visitValues = visit.map((o) => o.value).toSet();
      final sameValues = visitorValues.length == visitValues.length && visitorValues.containsAll(visitValues);

      debugPrint('[DOC_TYPES] compare values visitor vs visit -> same=$sameValues');
      if (!sameValues) {
        debugPrint('[DOC_TYPES] WARNING: values differ. visitor=$visitorValues visit=$visitValues');
      }

      final options = visit;
      final stillExists = _docTypeValue != null && options.any((o) => o.value == _docTypeValue);

      setState(() {
        _docTypeOptions = options;
        _loadingDocTypes = false;
        if (!stillExists) _docTypeValue = null;
      });

      debugPrint('[DOC_TYPES] ===== LOAD END OK ===== options=${options.length}');
    } catch (e) {
      setState(() {
        _docTypeOptions = const [];
        _loadingDocTypes = false;
        _docTypesError = e.toString();
        _docTypeValue = null;
      });

      debugPrint('[DOC_TYPES] ===== LOAD END ERROR ===== $e');
    }
  }

  // ---------------------------
  // HOSTS
  // ---------------------------
  Future<void> _loadHosts() async {
    debugPrint('[HOSTS] START');

    setState(() {
      _loadingHosts = true;
      _hostsError = null;
      _hostsDomainDebug = null;
    });

    try {
      final odoo = ref.read(odooClientProvider);

      final cAll = await odoo.searchCount(model: 'hr.employee', domain: []);
      final cWithUser = await odoo.searchCount(
        model: 'hr.employee',
        domain: const [
          ['user_id', '!=', false],
        ],
      );
      debugPrint('[HOSTS] count all=$cAll withUser=$cWithUser');

      const domainStrict = [
        ['active', '=', true],
        ['user_id', '!=', false],
      ];

      var res = await odoo.searchRead(
        model: 'hr.employee',
        domain: domainStrict,
        fields: const ['id', 'name', 'user_id'],
        limit: 0,
      );

      debugPrint('[HOSTS] searchRead(strict) rows=${res.length}');

      if (res.isEmpty && cWithUser > 0) {
        const domainFallback = [
          ['user_id', '!=', false],
        ];

        debugPrint('[HOSTS] strict returned 0 but withUser=$cWithUser. Retrying WITHOUT active filter...');
        res = await odoo.searchRead(
          model: 'hr.employee',
          domain: domainFallback,
          fields: const ['id', 'name', 'user_id'],
          limit: 0,
        );

        debugPrint('[HOSTS] searchRead(fallback) rows=${res.length}');
        _hostsDomainDebug = domainFallback.toString();
      } else {
        _hostsDomainDebug = domainStrict.toString();
      }

      final hosts = <_HostOption>[];
      for (final row in res) {
        final id = row['id'];
        final name = row['name'];
        if (id is int && name is String && name.trim().isNotEmpty) {
          hosts.add(_HostOption(id: id, name: name.trim()));
        }
      }

      hosts.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      final stillExists = _selectedHostId != null && hosts.any((h) => h.id == _selectedHostId);

      setState(() {
        _hosts = hosts;
        _loadingHosts = false;

        if (!stillExists) {
          _selectedHostId = null;
          _selectedHostName = null;
        }
      });

      debugPrint('[HOSTS] END OK hosts=${hosts.length} domain=$_hostsDomainDebug');
    } catch (e) {
      setState(() {
        _hosts = const [];
        _loadingHosts = false;
        _hostsError = e.toString();
      });
      debugPrint('[HOSTS] END ERROR: $e');
    }
  }

  void _setSelectedHost(_HostOption host) {
    setState(() {
      _selectedHostId = host.id;
      _selectedHostName = host.name;
    });
  }

  void _clearSelectedHost() {
    setState(() {
      _selectedHostId = null;
      _selectedHostName = null;
    });
  }

  // ---------------------------
  // SUBMIT
  // ---------------------------
  Future<void> _onSubmitCheckIn() async {
    final form = _formKey.currentState;
    if (form == null) return;
    if (!form.validate()) return;

    final controller = ref.read(visitControllerProvider.notifier);

    final opt = _docTypeOptions.firstWhere(
          (o) => o.value == _docTypeValue,
      orElse: () => const SelectionOption(value: '<NULL_OR_NOT_FOUND>', label: '<NULL_OR_NOT_FOUND>'),
    );

    debugPrint('========== [CHECKIN SUBMIT] ==========');
    debugPrint('[CHECKIN] docTypeValue="$_docTypeValue" docTypeLabel="${opt.label}"');
    debugPrint('[CHECKIN] docTypeValue cps: ${_hexCodepoints(_docTypeValue ?? '')}');
    debugPrint('[CHECKIN] hostName="$_selectedHostName"');
    debugPrint('=====================================');

    await controller.createVisit(
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      title: _titleValue,
      reason: _reasonController.text.trim().isEmpty ? null : _reasonController.text.trim(),
      company: _companyController.text.trim().isEmpty ? null : _companyController.text.trim(),
      docType: _docTypeValue,
      docNumber: _docNumberController.text.trim().isEmpty ? null : _docNumberController.text.trim(),
      docExpiry: _docExpiry,
      hostName: (_selectedHostName == null || _selectedHostName!.trim().isEmpty) ? null : _selectedHostName!.trim(),
    );
  }

  String _formatUiDate(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yyyy = d.year.toString();
    return '$dd/$mm/$yyyy';
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(visitControllerProvider, (previous, next) {
      if (!mounted) return;

      debugPrint(
        '[VisitCheckInPage] state changed: '
            'currentVisit=${next.currentVisit?.id}, '
            'isLoading=${next.isLoading}, '
            'error=${next.errorMessage}',
      );

      if (next.errorMessage != null && next.errorMessage != previous?.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.errorMessage!)),
        );
      }

      final prevId = previous?.currentVisit?.id;
      final nextId = next.currentVisit?.id;
      final createdNewVisit = nextId != null && nextId != prevId;

      if (_mode == _HomeMode.checkin && createdNewVisit && next.errorMessage == null) {
        debugPrint('[VisitCheckInPage] Navigo verso Privacy...');
        Navigator.of(context).pushNamed(AppRouter.privacyRoute);
      }
    });

    final state = ref.watch(visitControllerProvider);

    return KioskScaffold(
      title: 'Benvenuto',
      showBack: _mode == _HomeMode.checkin,
      onBack: () {
        _resetFormUi(); // già esiste nel file
        setState(() => _mode = _HomeMode.none);
      },
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 650),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Accesso visitatori',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 56,
                        child: ElevatedButton(
                          onPressed: state.isLoading
                              ? null
                              : () {
                            _resetFormUi();
                            setState(() => _mode = _HomeMode.checkin);
                          },
                          child: const Text(
                            'ENTRATA',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: SizedBox(
                        height: 56,
                        child: ElevatedButton(
                          onPressed: state.isLoading
                              ? null
                              : () {
                            ref.read(visitControllerProvider.notifier).reset();
                            Navigator.of(context).pushNamed(AppRouter.checkoutScanRoute);
                          },
                          child: const Text(
                            'USCITA',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (_mode != _HomeMode.checkin)
                  Padding(
                    padding: const EdgeInsets.only(top: 12.0),
                    child: Text(
                      'Seleziona ENTRATA per registrare una nuova visita\n'
                          'oppure USCITA per registrare l’uscita tramite badge.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                if (_mode == _HomeMode.checkin) ...[
                  const SizedBox(height: 12),
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ✅ VISITATORE ABITUALE
                        Autocomplete<_VisitorOption>(
                          displayStringForOption: (o) => o.display,
                          optionsBuilder: (TextEditingValue value) {
                            final q = value.text.trim().toLowerCase();
                            if (q.isEmpty) return const Iterable<_VisitorOption>.empty();

                            final filtered = _visitorSuggestions.where((v) => v.display.toLowerCase().contains(q));

                            if (_debugVisitors) {
                              debugPrint('[VISITOR] optionsBuilder q="$q" suggestions=${_visitorSuggestions.length}');
                            }

                            return filtered;
                          },
                          onSelected: (opt) {
                            if (_debugVisitors) {
                              debugPrint('[VISITOR] onSelected -> ${opt.display}');
                            }
                            _applyVisitorAutofill(opt);
                            FocusScope.of(context).unfocus();
                          },
                          fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
                            _ensureVisitorListener(textController);

                            return TextFormField(
                              controller: textController,
                              focusNode: focusNode,
                              enabled: !state.isLoading,
                              decoration: InputDecoration(
                                labelText: 'Visitatore abituale (opzionale)',
                                border: const OutlineInputBorder(),
                                prefixIcon: const Icon(Icons.badge_outlined),
                                helperText: 'Digita nome/cognome o numero documento (min 2 caratteri).',
                                suffixIcon: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (_loadingVisitors)
                                      const Padding(
                                        padding: EdgeInsets.all(12.0),
                                        child: SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        ),
                                      ),
                                    if (textController.text.trim().isNotEmpty)
                                      IconButton(
                                        tooltip: 'Svuota',
                                        icon: const Icon(Icons.clear),
                                        onPressed: state.isLoading
                                            ? null
                                            : () {
                                          textController.clear();
                                          setState(() {
                                            _visitorSuggestions = const [];
                                            _visitorsError = null;
                                            _loadingVisitors = false;
                                          });
                                          focusNode.requestFocus();
                                        },
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        if (_visitorsError != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Errore ricerca visitatori:\n$_visitorsError',
                            style: const TextStyle(color: Colors.red),
                          ),
                        ],
                        const SizedBox(height: 16),

                        // ✅ TITOLO (opzionale)
                        DropdownButtonFormField<String>(
                          value: _titleValue,
                          isExpanded: true,
                          items: _titleOptions
                              .map((t) => DropdownMenuItem<String>(
                            value: t,
                            child: Text(t),
                          ))
                              .toList(),
                          onChanged: state.isLoading ? null : (v) => setState(() => _titleValue = v),
                          decoration: const InputDecoration(
                            labelText: 'Titolo (opzionale)',
                            border: OutlineInputBorder(),
                          ),
                          validator: (_) => null,
                        ),
                        const SizedBox(height: 16),

                        TextFormField(
                          controller: _firstNameController,
                          decoration: const InputDecoration(labelText: 'Nome *', border: OutlineInputBorder()),
                          textInputAction: TextInputAction.next,
                          validator: (value) => (value == null || value.trim().isEmpty) ? 'Inserisci il nome' : null,
                        ),
                        const SizedBox(height: 16),

                        TextFormField(
                          controller: _lastNameController,
                          decoration: const InputDecoration(labelText: 'Cognome *', border: OutlineInputBorder()),
                          textInputAction: TextInputAction.next,
                          validator: (value) =>
                          (value == null || value.trim().isEmpty) ? 'Inserisci il cognome' : null,
                        ),
                        const SizedBox(height: 16),

                        TextFormField(
                          controller: _companyController,
                          decoration: const InputDecoration(labelText: 'Società', border: OutlineInputBorder()),
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 16),

                        // HOST
                        if (_loadingHosts) ...[
                          const Text('Carico persone da visitare...'),
                          const SizedBox(height: 8),
                          const LinearProgressIndicator(),
                          const SizedBox(height: 16),
                        ] else if (_hostsError != null) ...[
                          Text(
                            'Errore caricamento persone da visitare:\n$_hostsError',
                            style: const TextStyle(color: Colors.red),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(onPressed: _loadHosts, child: const Text('Riprova')),
                          const SizedBox(height: 16),
                        ] else if (_hosts.isNotEmpty) ...[
                          _HostAutocompleteFormField(
                            labelText: 'Persona da visitare (solo utenti)',
                            hosts: _hosts,
                            enabled: !state.isLoading,
                            selectedHostId: _selectedHostId,
                            selectedHostName: _selectedHostName,
                            onSelected: (host) => _setSelectedHost(host),
                            onClearSelection: _clearSelectedHost,
                            onRefresh: _loadHosts,
                          ),
                          const SizedBox(height: 16),
                        ],

                        // DOC TYPES dropdown
                        if (_loadingDocTypes) ...[
                          const Text('Carico tipi documento...'),
                          const SizedBox(height: 8),
                          const LinearProgressIndicator(),
                          const SizedBox(height: 16),
                        ] else if (_docTypesError != null) ...[
                          Text(
                            'Errore caricamento tipi documento:\n$_docTypesError',
                            style: const TextStyle(color: Colors.red),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(onPressed: _loadDocTypeOptions, child: const Text('Riprova')),
                          const SizedBox(height: 16),
                        ] else if (_docTypeOptions.isEmpty) ...[
                          InputDecorator(
                            decoration: const InputDecoration(labelText: 'Tipo documento', border: OutlineInputBorder()),
                            child: Row(
                              children: [
                                const Expanded(child: Text('Nessun tipo documento disponibile')),
                                const SizedBox(width: 8),
                                ElevatedButton.icon(
                                  onPressed: _loadDocTypeOptions,
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Ricarica'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ] else ...[
                          DropdownButtonFormField<String>(
                            value: _docTypeValue,
                            isExpanded: true,
                            items: _docTypeOptions
                                .map((opt) => DropdownMenuItem<String>(
                              value: opt.value,
                              child: Text(opt.label, overflow: TextOverflow.ellipsis),
                            ))
                                .toList(),
                            onChanged: state.isLoading ? null : (v) => setState(() => _docTypeValue = v),
                            decoration: const InputDecoration(labelText: 'Tipo documento', border: OutlineInputBorder()),
                          ),
                          const SizedBox(height: 16),
                        ],

                        TextFormField(
                          controller: _docNumberController,
                          decoration: const InputDecoration(labelText: 'Numero documento', border: OutlineInputBorder()),
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 16),

                        // ✅ SCADENZA DOCUMENTO (opzionale)
                        InkWell(
                          onTap: state.isLoading
                              ? null
                              : () async {
                            final now = DateTime.now();
                            final initial = _docExpiry ?? now;
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: initial,
                              firstDate: DateTime(now.year - 10),
                              lastDate: DateTime(now.year + 20),
                            );
                            if (picked != null && mounted) {
                              setState(() => _docExpiry = picked);
                            }
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Scadenza documento (opzionale)',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.event),
                            ),
                            child: Text(
                              _docExpiry == null ? 'Tocca per selezionare una data' : _formatUiDate(_docExpiry!),
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // ✅ MOTIVO DELLA VISITA: dropdown + textbox solo se "Altro"
                        DropdownButtonFormField<String>(
                          value: _reasonSelected,
                          isExpanded: true,
                          items: _reasonOptions
                              .map((opt) => DropdownMenuItem<String>(
                            value: opt,
                            child: Text(opt, overflow: TextOverflow.ellipsis),
                          ))
                              .toList(),
                          onChanged: state.isLoading
                              ? null
                              : (v) {
                            setState(() {
                              _reasonSelected = v;

                              if (v == null) {
                                _reasonController.clear();
                                return;
                              }

                              if (v == 'Altro') {
                                // mostra textbox: non precompilare
                                _reasonController.clear();
                              } else {
                                // scelta standard: salva direttamente l'opzione
                                _reasonController.text = v;
                              }
                            });
                          },
                          decoration: const InputDecoration(
                            labelText: 'Motivo della visita (opzionale)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        if (_reasonSelected == 'Altro') ...[
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _reasonController,
                            enabled: !state.isLoading,
                            decoration: const InputDecoration(
                              labelText: 'Specifica il motivo',
                              border: OutlineInputBorder(),
                            ),
                            maxLines: 2,
                          ),
                        ],
                        const SizedBox(height: 24),

                        SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed: state.isLoading ? null : _onSubmitCheckIn,
                            child: state.isLoading
                                ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                                : const Text('Procedi alla privacy'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Autocomplete “kiosk friendly”
class _HostAutocompleteFormField extends StatefulWidget {
  final String labelText;
  final List<_HostOption> hosts;
  final bool enabled;

  final int? selectedHostId;
  final String? selectedHostName;

  final ValueChanged<_HostOption> onSelected;
  final VoidCallback onClearSelection;
  final VoidCallback onRefresh;

  const _HostAutocompleteFormField({
    required this.labelText,
    required this.hosts,
    required this.enabled,
    required this.selectedHostId,
    required this.selectedHostName,
    required this.onSelected,
    required this.onClearSelection,
    required this.onRefresh,
  });

  @override
  State<_HostAutocompleteFormField> createState() => _HostAutocompleteFormFieldState();
}

class _HostAutocompleteFormFieldState extends State<_HostAutocompleteFormField> {
  String _currentText = '';

  @override
  Widget build(BuildContext context) {
    return Autocomplete<_HostOption>(
      displayStringForOption: (o) => o.name,
      optionsBuilder: (TextEditingValue value) {
        final q = value.text.trim().toLowerCase();
        if (q.isEmpty) return widget.hosts;
        return widget.hosts.where((h) => h.name.toLowerCase().contains(q));
      },
      onSelected: (opt) {
        widget.onSelected(opt);
        setState(() => _currentText = opt.name);
      },
      fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
        final parentName = widget.selectedHostName;
        if (parentName != null && parentName.trim().isNotEmpty && textController.text != parentName) {
          textController.text = parentName;
          _currentText = parentName;
        }

        return TextFormField(
          controller: textController,
          focusNode: focusNode,
          enabled: widget.enabled,
          decoration: InputDecoration(
            labelText: widget.labelText,
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.person_search),
            helperText: widget.selectedHostId == null
                ? 'Tocca e digita per cercare, oppure scorri la lista.'
                : 'Selezionato: ${widget.selectedHostName}',
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if ((_currentText.trim().isNotEmpty) || textController.text.trim().isNotEmpty)
                  IconButton(
                    tooltip: 'Svuota',
                    icon: const Icon(Icons.clear),
                    onPressed: widget.enabled
                        ? () {
                      textController.clear();
                      setState(() => _currentText = '');
                      widget.onClearSelection();
                      focusNode.requestFocus();
                    }
                        : null,
                  ),
                IconButton(
                  tooltip: 'Ricarica lista',
                  icon: const Icon(Icons.refresh),
                  onPressed: widget.enabled ? widget.onRefresh : null,
                ),
              ],
            ),
          ),
          onChanged: (v) {
            setState(() => _currentText = v);
            if (widget.selectedHostId != null && v.trim() != (widget.selectedHostName ?? '').trim()) {
              widget.onClearSelection();
            }
          },
        );
      },
    );
  }
}

class _HostOption {
  final int id;
  final String name;
  const _HostOption({required this.id, required this.name});
}

class _VisitorOption {
  final int id;
  final String nome;
  final String cognome;

  // ✅ nuovi campi (x_visitatori)
  final String? company;
  final String? title;

  /// value reale del selection su Odoo (es: Carta_Identità)
  final String? docTipoValue;

  final String? docNumero;

  final DateTime? docExpiry; // ✅ AGGIUNTO

  const _VisitorOption({
    required this.id,
    required this.nome,
    required this.cognome,
    this.company,
    this.title,
    this.docTipoValue,
    this.docNumero,
    this.docExpiry, // ✅ AGGIUNTO
  });

  String get display {
    final base = '${cognome.trim()} ${nome.trim()}'.trim();
    final doc = [
      if (docTipoValue != null && docTipoValue!.trim().isNotEmpty) docTipoValue!.trim(),
      if (docNumero != null && docNumero!.trim().isNotEmpty) docNumero!.trim(),
    ].join(' ');
    if (doc.isEmpty) return base;
    return '$base • $doc';
  }
}
DateTime? _parseOdooDate(dynamic v) {
  final s = v?.toString().trim();
  if (s == null || s.isEmpty) return null;

  // Odoo Date normalmente: "YYYY-MM-DD"
  try {
    final parts = s.split('-');
    if (parts.length != 3) return null;
    final y = int.parse(parts[0]);
    final m = int.parse(parts[1]);
    final d = int.parse(parts[2]);
    return DateTime(y, m, d);
  } catch (_) {
    return null;
  }
}

