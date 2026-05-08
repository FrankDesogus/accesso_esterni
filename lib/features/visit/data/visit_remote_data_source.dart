// lib/features/visit/data/visit_remote_data_source.dart

import 'models/visit.dart';
import '../../../core/config/app_config.dart';
import '../../../shared/services/odoo_jsonrpc_client.dart';

class VisitRemoteDataSource {
  VisitRemoteDataSource(this._odoo);
  final OdooJsonRpcClient _odoo;

  // =========================
  // DEBUG
  // =========================
  static const bool _debug = true;

  // ===========================================================================
  // ✅ NOMI TECNICI REALI (ODOO STUDIO) — MODIFICA SOLO QUI SE CAMBIANO
  // ===========================================================================

  /// MODEL: x_visite_esterne
  static const String fVisitName = 'x_name';

  /// Link al VISITATORE (Many2one -> x_visitatori)
  static const String fVisitVisitorId = 'x_studio_visitatore';

  /// Campi visita
  static const String fVisitCompany = 'x_studio_societa';
  static const String fVisitReason = 'x_studio_motivo_accesso';
  static const String fVisitHost = 'x_studio_persona_da_visitare';

  /// Stato e tempi
  static const String fVisitState = 'x_studio_stato_visita'; // draft/checked_in/checked_out
  static const String fVisitCheckIn = 'x_studio_ingresso'; // datetime
  static const String fVisitCheckOut = 'x_studio_uscita'; // datetime

  /// Privacy + firma
  static const String fVisitPrivacyAccepted = 'x_studio_consenso_privacy'; // boolean
  static const String fVisitSignature = 'x_studio_firma'; // image/base64

  /// Snapshot documento (sulla VISITA)
  static const String fSnapDocType = 'x_studio_tipo_di_documento_visita'; // selection
  static const String fSnapDocNumber = 'x_studio_numero_documento_visita'; // char
  static const String fSnapDocExpiry = 'x_studio_scadenza_documento_visita'; // date

  /// Badge (Many2one -> x_badge)
  static const String fVisitBadge = 'x_studio_badge';

  /// MODEL: x_badge
  static const String fBadgeCode = 'x_studio_codice_badge';
  static const String fBadgeActive = 'x_studio_attivo';
  static const String fBadgeCurrentVisit = 'x_studio_visita_corrente';

  // ===========================================================================
  // CREATE VISIT (visitorId + snapshot doc)
  // ===========================================================================

  Future<Visit> createVisit({
    required Visit visit,
    required int visitorId,
  }) async {
    // Normalizza stringhe per selection Odoo (apostrofo tipografico)
    String normalizeOdooSelection(String s) => s.trim().replaceAll('’', "'");

    final now = DateTime.now();

    // ✅ Risolvi hostId se la UI ha fornito hostName (Many2one -> hr.employee)
    int? resolvedHostId = visit.hostId;

    final hostName = visit.hostName?.trim();
    if (resolvedHostId == null && hostName != null && hostName.isNotEmpty) {
      resolvedHostId = await _findEmployeeIdByName(hostName);
      if (resolvedHostId == null) {
        throw OdooException('Persona da visitare non trovata: "$hostName"');
      }
    }

    final recordName =
        '${(visit.firstName ?? '').trim()} ${(visit.lastName ?? '').trim()} - '
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    // Snapshot doc
    final docTypeSnap = visit.docType?.trim();
    final docNumberSnap = visit.docNumber?.trim();

    // ✅ DEBUG FIX: leggi la scadenza direttamente dal model Visit (non via toJson)
    final String? docExpiryIsoDate = _toIsoDateOrNull(visit.docExpiry);

    final values = <String, dynamic>{
      // Record name obbligatorio
      fVisitName: recordName,

      // link visitatore
      fVisitVisitorId: visitorId,

      // Campi visita
      if (visit.company != null && visit.company!.trim().isNotEmpty)
        fVisitCompany: visit.company!.trim(),

      if (visit.reason != null && visit.reason!.trim().isNotEmpty)
        fVisitReason: visit.reason!.trim(),

      if (resolvedHostId != null) fVisitHost: resolvedHostId,

      // Stato iniziale
      fVisitState: 'draft',

      // Privacy iniziale
      fVisitPrivacyAccepted: visit.privacyAccepted == true,

      // Snapshot documento (storico)
      if (docTypeSnap != null && docTypeSnap.isNotEmpty)
        fSnapDocType: normalizeOdooSelection(docTypeSnap),

      if (docNumberSnap != null && docNumberSnap.isNotEmpty)
        fSnapDocNumber: docNumberSnap,

      // ✅ scadenza documento snapshot
      if (docExpiryIsoDate != null) fSnapDocExpiry: docExpiryIsoDate,
    };

    if (_debug) {
      // ignore: avoid_print
      print('[CREATE VISIT] docExpiryRaw=${visit.docExpiry} docExpiryIso=$docExpiryIsoDate');
      // ignore: avoid_print
      print('[CREATE VISIT] payload values=$values');
    }

    final id = await _odoo.create(model: AppConfig.visitModel, values: values);

    // ✅ DEBUG: readback immediato (capisci se Odoo ha salvato davvero)
    if (_debug) {
      final rb = await _odoo.searchRead(
        model: AppConfig.visitModel,
        domain: [
          ['id', '=', id],
        ],
        fields: [fSnapDocExpiry, fSnapDocType, fSnapDocNumber],
        limit: 1,
      );
      // ignore: avoid_print
      print('[CREATE VISIT] created id=$id readback=${rb.isNotEmpty ? rb.first : rb}');
    }

    return visit.copyWith(
      id: id.toString(),
      hostId: resolvedHostId,
    );
  }

  // ===========================================================================
  // PRIVACY
  // ===========================================================================

  Future<Visit> acceptPrivacy(Visit visit) async {
    final id = int.tryParse(visit.id ?? '');
    if (id == null) throw OdooException('ID visita non valido');

    await _odoo.write(
      model: AppConfig.visitModel,
      ids: [id],
      values: {fVisitPrivacyAccepted: true},
    );

    return visit.copyWith(privacyAccepted: true);
  }

  Future<Visit> acceptPrivacyWithSignature({
    required Visit visit,
    required String signaturePngBase64,
  }) async {
    final id = int.tryParse(visit.id ?? '');
    if (id == null) throw OdooException('ID visita non valido');

    final ok = await _odoo.write(
      model: AppConfig.visitModel,
      ids: [id],
      values: {
        fVisitSignature: signaturePngBase64,
        fVisitPrivacyAccepted: true,
      },
    );
    if (!ok) {
      throw OdooException('Impossibile salvare la firma');
    }

    return visit.copyWith(privacyAccepted: true);
  }

  // ===========================================================================
  // BADGE + CHECK-IN
  // ===========================================================================

  Future<Visit> assignBadgeAndCheckIn({
    required Visit visit,
    required String badgeCode,
  }) async {
    final visitId = int.tryParse(visit.id ?? '');
    if (visitId == null) throw OdooException('ID visita non valido');

    final badges = await _odoo.searchRead(
      model: AppConfig.badgeModel,
      domain: [
        [fBadgeCode, '=', badgeCode],
      ],
      fields: [
        'id',
        fBadgeActive,
        fBadgeCurrentVisit,
        fBadgeCode,
      ],
      limit: 1,
    );

    if (badges.isEmpty) {
      throw OdooException('Badge non riconosciuto');
    }

    final b = badges.first;
    final badgeId = b['id'] as int;
    final attivo = b[fBadgeActive] == true;

    final visitaCorrente = b[fBadgeCurrentVisit];
    final isFree = visitaCorrente == false || visitaCorrente == null;

    if (!attivo) {
      throw OdooException('Badge non attivo');
    }
    if (!isFree) {
      throw OdooException('Badge già assegnato');
    }

    final okBadge = await _odoo.write(
      model: AppConfig.badgeModel,
      ids: [badgeId],
      values: {fBadgeCurrentVisit: visitId},
    );
    if (!okBadge) {
      throw OdooException('Impossibile assegnare la visita al badge');
    }

    final now = DateTime.now();
    final nowStr = _formatOdooDateTime(now);

    final okVisit = await _odoo.write(
      model: AppConfig.visitModel,
      ids: [visitId],
      values: {
        fVisitBadge: badgeId,
        fVisitCheckIn: nowStr,
        fVisitState: 'checked_in',
        fVisitPrivacyAccepted: true,
      },
    );
    if (!okVisit) {
      throw OdooException('Impossibile aggiornare la visita con il badge');
    }

    return visit.copyWith(
      badgeId: badgeId,
      checkInTime: now,
      privacyAccepted: true,
    );
  }

  // ===========================================================================
  // CHECK-OUT
  // ===========================================================================

  Future<void> checkOutByBadgeCode({required String badgeCode}) async {
    final badges = await _odoo.searchRead(
      model: AppConfig.badgeModel,
      domain: [
        [fBadgeCode, '=', badgeCode],
      ],
      fields: [
        'id',
        fBadgeActive,
        fBadgeCurrentVisit,
        fBadgeCode,
      ],
      limit: 1,
    );

    if (badges.isEmpty) {
      throw OdooException('Badge non riconosciuto');
    }

    final b = badges.first;
    final badgeId = b['id'] as int;
    final attivo = b[fBadgeActive] == true;

    if (!attivo) {
      throw OdooException('Badge non attivo');
    }

    final visitaCorrente = b[fBadgeCurrentVisit];
    if (visitaCorrente == false || visitaCorrente == null) {
      throw OdooException('Nessuna visita attiva per questo badge');
    }

    int visitId;
    if (visitaCorrente is List && visitaCorrente.isNotEmpty) {
      visitId = visitaCorrente.first as int;
    } else if (visitaCorrente is int) {
      visitId = visitaCorrente;
    } else {
      throw OdooException('Formato visita corrente non valido');
    }

    final nowStr = _formatOdooDateTime(DateTime.now());

    final okVisit = await _odoo.write(
      model: AppConfig.visitModel,
      ids: [visitId],
      values: {
        fVisitCheckOut: nowStr,
        fVisitState: 'checked_out',
      },
    );
    if (!okVisit) {
      throw OdooException('Impossibile aggiornare la visita in uscita');
    }

    final okBadge = await _odoo.write(
      model: AppConfig.badgeModel,
      ids: [badgeId],
      values: {fBadgeCurrentVisit: false},
    );
    if (!okBadge) {
      throw OdooException('Impossibile liberare il badge');
    }
  }

  // Tenuto per compatibilità con repository esistente
  Future<Visit> updateVisit(Visit visit) async => visit;

  // ===========================================================================
  // HELPERS
  // ===========================================================================

  Future<int?> _findEmployeeIdByName(String name) async {
    final res = await _odoo.searchRead(
      model: 'hr.employee',
      domain: [
        ['name', 'ilike', name],
      ],
      fields: ['id', 'name'],
      limit: 1,
    );

    if (res.isEmpty) return null;
    return res.first['id'] as int;
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  /// Odoo datetime: "YYYY-MM-DD HH:MM:SS"
  static String _formatOdooDateTime(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = _two(dt.month);
    final d = _two(dt.day);
    final hh = _two(dt.hour);
    final mm = _two(dt.minute);
    final ss = _two(dt.second);
    return '$y-$m-$d $hh:$mm:$ss';
  }

  // Lasciati per compatibilità (non usati per docExpiry nel debug fix)
  static dynamic _tryGetProp(Object obj, String fieldName) {
    try {
      // ignore: avoid_dynamic_calls
      return (obj as dynamic).toJson()[fieldName];
    } catch (_) {
      return null;
    }
  }

  static dynamic _tryGetJson(Object obj, String fieldName) {
    try {
      // ignore: avoid_dynamic_calls
      return (obj as dynamic).toJson()[fieldName];
    } catch (_) {
      return null;
    }
  }

  /// Converte in "YYYY-MM-DD" se possibile:
  /// - DateTime -> YYYY-MM-DD
  /// - String già ISO date -> accetta primi 10 char se formato valido
  static String? _toIsoDateOrNull(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) {
      final y = v.year.toString().padLeft(4, '0');
      final m = _two(v.month);
      final d = _two(v.day);
      return '$y-$m-$d';
    }
    if (v is String) {
      final s = v.trim();
      if (s.length >= 10) {
        final p = s.substring(0, 10);
        final ok = RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(p);
        return ok ? p : null;
      }
    }
    return null;
  }
}
