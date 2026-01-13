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
    String? reason,
    String? company,
    String? docType,
    String? docNumber,
    String? hostName,
  }) async {
    // 1) Costruisco il draft Visit (come prima: UI -> domain model)
    final draft = Visit(
      id: null,
      firstName: firstName,
      lastName: lastName,
      reason: reason,
      company: company,
      docType: docType,
      docNumber: docNumber,
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
      docScadenzaIsoDate: null, // se hai la scadenza in UI, passala qui "YYYY-MM-DD"
    );

    // 3) Creo la VISITA (x_visite_esterne) collegata al visitorId + snapshot documento
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
