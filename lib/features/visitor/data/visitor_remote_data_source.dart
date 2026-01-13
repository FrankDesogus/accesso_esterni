import '../../../shared/services/odoo_jsonrpc_client.dart';
import '../../../shared/utils/document_key.dart';
import '../../../core/config/app_config.dart';

class VisitorRemoteDataSource {
  VisitorRemoteDataSource(this._odoo);
  final OdooJsonRpcClient _odoo;

  // 👉 Se su Odoo i nomi tecnici sono diversi, modifica SOLO qui.
  static const String fCompany = 'x_studio_societa'; // Società
  static const String fTitle = 'x_studio_titolo'; // Titolo

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
        ['x_studio_nome', 'ilike', q],
        ['x_studio_cognome', 'ilike', q],
      ],
      fields: [
        'id',
        'x_studio_nome',
        'x_studio_cognome',
        fCompany,
        fTitle,
        'x_studio_chiave_documento',
      ],
      limit: limit,
    );

    return List<Map<String, dynamic>>.from(results);
  }

  /// ✅ Trova o crea un visitatore (ORA salva anche società e titolo)
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

    // helper: inserisce solo valori non null e non vuoti
    Map<String, dynamic> _nonEmptyFields(Map<String, dynamic> values) {
      values.removeWhere((k, v) {
        if (v == null) return true;
        if (v is String && v.trim().isEmpty) return true;
        return false;
      });
      return values;
    }

    // 1) lookup primario: chiave documento
    final foundByKey = await _odoo.searchRead(
      model: AppConfig.visitorModel,
      domain: [
        ['x_studio_chiave_documento', '=', key],
      ],
      fields: [
        'id',
        'x_studio_nome',
        'x_studio_cognome',
        'x_studio_chiave_documento',
        fCompany,
        fTitle,
      ],
      limit: 1,
    );

    if (foundByKey.isNotEmpty) {
      final id = foundByKey.first['id'] as int;

      // ✅ Aggiorno società/titolo se me li hai passati (utile se mancavano)
      final values = _nonEmptyFields({
        fCompany: societaTrim,
        fTitle: titoloTrim,
      });

      if (values.isNotEmpty) {
        await _odoo.write(
          model: AppConfig.visitorModel,
          ids: [id],
          values: values,
        );
      }

      return id;
    }

    // 2) fallback: riaggancia per nome+cognome e aggiorna documento + campi nuovi
    final foundByName = await _odoo.searchRead(
      model: AppConfig.visitorModel,
      domain: [
        ['x_studio_nome', 'ilike', nomeTrim],
        ['x_studio_cognome', 'ilike', cognomeTrim],
      ],
      fields: ['id'],
      limit: 1,
    );

    if (foundByName.isNotEmpty) {
      final id = foundByName.first['id'] as int;

      await _odoo.write(
        model: AppConfig.visitorModel,
        ids: [id],
        values: _nonEmptyFields({
          'x_studio_nome': nomeTrim,
          'x_studio_cognome': cognomeTrim,
          'x_studio_tipo_di_documento': docTipo.trim(),
          'x_studio_numero_documento': normalizedNum,
          'x_studio_scadenza_documento': docScadenzaIsoDate,
          'x_studio_chiave_documento': key,

          // 🔹 NUOVI CAMPI
          fCompany: societaTrim,
          fTitle: titoloTrim,

          'x_name': '$cognomeTrim $nomeTrim (CI $normalizedNum)',
        }),
      );

      return id;
    }

    // 3) create
    final newId = await _odoo.create(
      model: AppConfig.visitorModel,
      values: _nonEmptyFields({
        'x_studio_nome': nomeTrim,
        'x_studio_cognome': cognomeTrim,
        'x_studio_tipo_di_documento': docTipo.trim(),
        'x_studio_numero_documento': normalizedNum,
        'x_studio_scadenza_documento': docScadenzaIsoDate,
        'x_studio_chiave_documento': key,

        // 🔹 NUOVI CAMPI
        fCompany: societaTrim,
        fTitle: titoloTrim,

        'x_name': '$cognomeTrim $nomeTrim (CI $normalizedNum)',
      }),
    );

    return newId;
  }

  /// ♻️ Utility: aggiorna solo società/titolo su un visitatore già noto
  /// (comodo se vuoi chiamarlo direttamente al check-in)
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

    await _odoo.write(
      model: AppConfig.visitorModel,
      ids: [visitorId],
      values: values,
    );
  }
}
