import '../../../shared/services/odoo_jsonrpc_client.dart';
import '../../../shared/utils/document_key.dart';
import '../../../core/config/app_config.dart';

class VisitorRemoteDataSource {
  VisitorRemoteDataSource(this._odoo);
  final OdooJsonRpcClient _odoo;

  Future<int> findOrCreateVisitor({
    required String nome,
    required String cognome,
    required String docTipo,
    required String docNumero,
    String? docScadenzaIsoDate, // "YYYY-MM-DD" oppure null
  }) async {
    final key = buildDocKey(tipo: docTipo, numeroRaw: docNumero);
    final normalizedNum = normalizeDocNumber(docNumero);

    // 1) lookup primario: chiave documento
    final foundByKey = await _odoo.searchRead(
      model: AppConfig.visitorModel,
      domain: [
        ['x_studio_chiave_documento', '=', key],
      ],
      fields: ['id', 'x_studio_nome', 'x_studio_cognome', 'x_studio_chiave_documento'],
      limit: 1,
    );

    if (foundByKey.isNotEmpty) {
      return foundByKey.first['id'] as int;
    }

    // 2) fallback (per rispettare la tua regola “documento nuovo => aggiorna”):
    // se non trovo la chiave, provo a riagganciare per nome+cognome e aggiorno
    final foundByName = await _odoo.searchRead(
      model: AppConfig.visitorModel,
      domain: [
        ['x_studio_nome', 'ilike', nome.trim()],
        ['x_studio_cognome', 'ilike', cognome.trim()],
      ],
      fields: ['id'],
      limit: 1,
    );

    if (foundByName.isNotEmpty) {
      final id = foundByName.first['id'] as int;

      await _odoo.write(
        model: AppConfig.visitorModel,
        ids: [id],
        values: {
          'x_studio_nome': nome.trim(),
          'x_studio_cognome': cognome.trim(),
          'x_studio_tipo_di_documento': docTipo.trim(),
          'x_studio_numero_documento': normalizedNum,
          'x_studio_scadenza_documento': docScadenzaIsoDate,
          'x_studio_chiave_documento': key,
          'x_name': '$cognome $nome (CI $normalizedNum)',
        },
      );

      return id;
    }

    // 3) create
    final newId = await _odoo.create(
      model: AppConfig.visitorModel,
      values: {
        'x_studio_nome': nome.trim(),
        'x_studio_cognome': cognome.trim(),
        'x_studio_tipo_di_documento': docTipo.trim(),
        'x_studio_numero_documento': normalizedNum,
        'x_studio_scadenza_documento': docScadenzaIsoDate,
        'x_studio_chiave_documento': key,
        'x_name': '$cognome $nome (CI $normalizedNum)',
      },
    );

    return newId;
  }
}
