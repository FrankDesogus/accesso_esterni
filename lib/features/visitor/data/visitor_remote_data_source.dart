import '../../../shared/services/odoo_jsonrpc_client.dart';
import '../../../shared/utils/document_key.dart';
import '../../../core/config/app_config.dart';

class VisitorRemoteDataSource {
  VisitorRemoteDataSource(this._odoo);
  final OdooJsonRpcClient _odoo;

  // =========================
  // DEBUG
  // =========================
  static const bool _debug = true;

  // 👉 Se su Odoo i nomi tecnici sono diversi, modifica SOLO qui.
  static const String fCompany = 'x_studio_societa'; // Società
  static const String fTitle = 'x_studio_titolo'; // Titolo

  // ✅ Campo scadenza documento su x_visitatori (Date)
  static const String fDocExpiry = 'x_studio_scadenza_documento';

  // Campi base
  static const String fFirstName = 'x_studio_nome';
  static const String fLastName = 'x_studio_cognome';
  static const String fDocType = 'x_studio_tipo_di_documento';
  static const String fDocNumber = 'x_studio_numero_documento';
  static const String fDocKey = 'x_studio_chiave_documento';

  /// 🔍 Usato per l'autocomplete nella visit_checkin_page
  /// Restituisce anche società e titolo per l'autocompletamento.
  Future<List<Map<String, dynamic>>> searchVisitors({
    required String query,
    int limit = 10,
  }) async {
    final q = query.trim();
    if (q.isEmpty) return [];

    final results = await _odoo.searchRead(
      model: AppConfig.visitorModel,
      domain: [
        '|',
        [fFirstName, 'ilike', q],
        [fLastName, 'ilike', q],
      ],
      fields: [
        'id',
        fFirstName,
        fLastName,
        fCompany,
        fTitle,
        fDocKey,
        fDocExpiry, // ✅ utile in debug/autofill se vuoi
      ],
      limit: limit,
    );

    return List<Map<String, dynamic>>.from(results);
  }

  /// ✅ Trova o crea un visitatore (salva anche società, titolo e scadenza documento)
  Future<int> findOrCreateVisitor({
    required String nome,
    required String cognome,
    required String docTipo,
    required String docNumero,
    String? docScadenzaIsoDate, // "YYYY-MM-DD" oppure null

    // 🔹 NUOVI CAMPI
    String? societa,
    String? titolo,
  }) async {
    final key = buildDocKey(tipo: docTipo, numeroRaw: docNumero);
    final normalizedNum = normalizeDocNumber(docNumero);

    final nomeTrim = nome.trim();
    final cognomeTrim = cognome.trim();
    final societaTrim = societa?.trim();
    final titoloTrim = titolo?.trim();

    if (_debug) {
      // ignore: avoid_print
      print('[VISITOR] findOrCreate key="$key" docExpiry="$docScadenzaIsoDate" '
          'nome="$nomeTrim" cognome="$cognomeTrim" docTipo="$docTipo" docNumeroNorm="$normalizedNum" '
          'fieldExpiry=$fDocExpiry');
    }

    // helper: inserisce solo valori non null e non vuoti
    Map<String, dynamic> _nonEmptyFields(Map<String, dynamic> values) {
      values.removeWhere((k, v) {
        if (v == null) return true;
        if (v is String && v.trim().isEmpty) return true;
        return false;
      });
      return values;
    }

    Future<void> _debugReadback(int id, String tag) async {
      if (!_debug) return;
      final rb = await _odoo.searchRead(
        model: AppConfig.visitorModel,
        domain: [
          ['id', '=', id],
        ],
        fields: [
          'id',
          fFirstName,
          fLastName,
          fDocType,
          fDocNumber,
          fDocKey,
          fDocExpiry,
          fCompany,
          fTitle,
        ],
        limit: 1,
      );
      // ignore: avoid_print
      print('[VISITOR][$tag] readback id=$id -> ${rb.isNotEmpty ? rb.first : rb}');
    }

    // 1) lookup primario: chiave documento
    final foundByKey = await _odoo.searchRead(
      model: AppConfig.visitorModel,
      domain: [
        [fDocKey, '=', key],
      ],
      fields: [
        'id',
        fFirstName,
        fLastName,
        fDocKey,
        fCompany,
        fTitle,
        fDocExpiry,
        fDocType,
        fDocNumber,
      ],
      limit: 1,
    );

    if (foundByKey.isNotEmpty) {
      final id = foundByKey.first['id'] as int;

      final values = _nonEmptyFields({
        // Dati documento
        fDocType: docTipo.trim(),
        fDocNumber: normalizedNum,
        fDocExpiry: docScadenzaIsoDate,
        fDocKey: key,

        // Nuovi campi
        fCompany: societaTrim,
        fTitle: titoloTrim,

        // Record name utile
        'x_name': '$cognomeTrim $nomeTrim (CI $normalizedNum)',
      });

      if (_debug) {
        // ignore: avoid_print
        print('[VISITOR][foundByKey] id=$id updateValues=$values');
      }

      if (values.isNotEmpty) {
        await _odoo.write(
          model: AppConfig.visitorModel,
          ids: [id],
          values: values,
        );
        await _debugReadback(id, 'foundByKey');
      }

      return id;
    }

    // 2) fallback: riaggancia per nome+cognome e aggiorna documento + campi nuovi
    final foundByName = await _odoo.searchRead(
      model: AppConfig.visitorModel,
      domain: [
        [fFirstName, 'ilike', nomeTrim],
        [fLastName, 'ilike', cognomeTrim],
      ],
      fields: ['id'],
      limit: 1,
    );

    if (foundByName.isNotEmpty) {
      final id = foundByName.first['id'] as int;

      final values = _nonEmptyFields({
        fFirstName: nomeTrim,
        fLastName: cognomeTrim,
        fDocType: docTipo.trim(),
        fDocNumber: normalizedNum,
        fDocExpiry: docScadenzaIsoDate,
        fDocKey: key,

        fCompany: societaTrim,
        fTitle: titoloTrim,

        'x_name': '$cognomeTrim $nomeTrim (CI $normalizedNum)',
      });

      if (_debug) {
        // ignore: avoid_print
        print('[VISITOR][foundByName] id=$id updateValues=$values');
      }

      await _odoo.write(
        model: AppConfig.visitorModel,
        ids: [id],
        values: values,
      );

      await _debugReadback(id, 'foundByName');

      return id;
    }

    // 3) create
    final createValues = _nonEmptyFields({
      fFirstName: nomeTrim,
      fLastName: cognomeTrim,
      fDocType: docTipo.trim(),
      fDocNumber: normalizedNum,
      fDocExpiry: docScadenzaIsoDate,
      fDocKey: key,

      fCompany: societaTrim,
      fTitle: titoloTrim,

      'x_name': '$cognomeTrim $nomeTrim (CI $normalizedNum)',
    });

    if (_debug) {
      // ignore: avoid_print
      print('[VISITOR][create] values=$createValues');
    }

    final newId = await _odoo.create(
      model: AppConfig.visitorModel,
      values: createValues,
    );

    await _debugReadback(newId, 'create');

    return newId;
  }

  /// ♻️ Utility: aggiorna solo società/titolo su un visitatore già noto
  Future<void> updateVisitorCompanyAndTitle({
    required int visitorId,
    String? societa,
    String? titolo,
  }) async {
    final societaTrim = societa?.trim();
    final titoloTrim = titolo?.trim();

    final values = <String, dynamic>{
      fCompany: societaTrim,
      fTitle: titoloTrim,
    }..removeWhere((k, v) => v == null || (v is String && v.trim().isEmpty));

    if (values.isEmpty) return;

    if (_debug) {
      // ignore: avoid_print
      print('[VISITOR][updateCompanyTitle] id=$visitorId values=$values');
    }

    await _odoo.write(
      model: AppConfig.visitorModel,
      ids: [visitorId],
      values: values,
    );

    if (_debug) {
      final rb = await _odoo.searchRead(
        model: AppConfig.visitorModel,
        domain: [
          ['id', '=', visitorId],
        ],
        fields: [fCompany, fTitle, fDocExpiry],
        limit: 1,
      );
      // ignore: avoid_print
      print('[VISITOR][updateCompanyTitle] readback id=$visitorId -> ${rb.isNotEmpty ? rb.first : rb}');
    }
  }
}
