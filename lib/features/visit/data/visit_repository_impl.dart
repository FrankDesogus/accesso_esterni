import '../domain/visit_repository.dart';
import 'models/visit.dart';
import 'visit_remote_data_source.dart';
import '../../visitor/data/visitor_remote_data_source.dart';

class VisitRepositoryImpl implements VisitRepository {
  VisitRepositoryImpl(this._remote, this._visitorRemote);

  final VisitRemoteDataSource _remote;
  final VisitorRemoteDataSource _visitorRemote;

  @override
  Future<Visit> createVisit({
    required String firstName,
    required String lastName,

    // ✅ Titolo: opzionale (NON blocchiamo qui)
    String? title,

    String? reason,
    String? company,
    String? docType,
    String? docNumber,

    // ✅ NUOVO: scadenza documento raccolta in UI
    DateTime? docExpiry,

    String? hostName,
  }) async {
    // Converte DateTime -> "YYYY-MM-DD" per campi Odoo Date
    String? toIsoDateOrNull(DateTime? d) {
      if (d == null) return null;
      final y = d.year.toString().padLeft(4, '0');
      final m = d.month.toString().padLeft(2, '0');
      final day = d.day.toString().padLeft(2, '0');
      return '$y-$m-$day';
    }

    final docExpiryIso = toIsoDateOrNull(docExpiry);

    // 1) Costruisco il draft Visit (UI -> domain model)
    //    ✅ IMPORTANT: passiamo anche la scadenza se il model Visit la supporta.
    //    - Se il tuo Visit ha già un campo (es. docExpiry/documentExpiry) usalo qui.
    //    - Se NON esiste ancora, questo compilerà solo dopo che lo aggiungi nel model Visit.
    final draft = Visit(
      id: null,
      firstName: firstName,
      lastName: lastName,

      // title è opzionale: se il model Visit lo prevede, puoi salvarlo lì,
      // altrimenti lo gestiamo solo per Visitatori tramite _visitorRemote.
      // title: title,

      reason: reason,
      company: company,
      docType: docType,
      docNumber: docNumber,

      // ✅ NUOVO (da aggiungere anche nel model Visit, vedi nota sopra)
      docExpiry: docExpiry,

      hostId: null,
      hostName: hostName,
      privacyAccepted: false,
      badgeId: null,
      checkInTime: null,
    );

    // 2) Trovo o creo il VISITATORE (x_visitatori) usando i dati documento
    //    Regola: cerco sempre per x_chiave_documento (gestita nel datasource visitor)
    final visitorId = await _visitorRemote.findOrCreateVisitor(
      nome: firstName,
      cognome: lastName,
      docTipo: docType ?? '',
      docNumero: docNumber ?? '',

      // ✅ Obiettivo #2: salva scadenza su Visitatori (x_scadenza_documento)
      docScadenzaIsoDate: docExpiryIso,

      // (mantengo invariati)
      societa: company,
      titolo: title,
    );

    // 3) Creo la VISITA (x_visite_esterne) collegata al visitorId + snapshot documento
    //    La scadenza verrà snapshot-tata dal VisitRemoteDataSource (fSnapDocExpiry)
    //    leggendo dal draft (docExpiry) oppure da toJson() a seconda del tuo model.
    final created = await _remote.createVisit(
      visit: draft,
      visitorId: visitorId,
    );

    return created;
  }

  @override
  Future<Visit> acceptPrivacyWithSignature({
    required Visit visit,
    required String signaturePngBase64,
  }) =>
      _remote.acceptPrivacyWithSignature(
        visit: visit,
        signaturePngBase64: signaturePngBase64,
      );

  @override
  Future<Visit> acceptPrivacy(Visit visit) => _remote.acceptPrivacy(visit);

  @override
  Future<Visit> assignBadgeAndCheckIn({
    required Visit visit,
    required String badgeCode,
  }) =>
      _remote.assignBadgeAndCheckIn(visit: visit, badgeCode: badgeCode);

  @override
  Future<void> checkOutByBadgeCode({required String badgeCode}) =>
      _remote.checkOutByBadgeCode(badgeCode: badgeCode);
}
