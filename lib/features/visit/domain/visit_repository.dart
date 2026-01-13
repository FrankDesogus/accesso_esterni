import '../data/models/visit.dart';

abstract class VisitRepository {
  Future<Visit> createVisit({
    required String firstName,
    required String lastName,
    String? title,
    String? reason,
    String? company,
    String? docType,
    String? docNumber,
    String? hostName,
  });

  Future<Visit> acceptPrivacy(Visit visit);

  Future<Visit> assignBadgeAndCheckIn({
    required Visit visit,
    required String badgeCode,
  });

  /// Salva firma (PNG base64) e imposta consenso privacy=true sulla visita.
  /// Metodo aggiuntivo: non modifica i flussi esistenti che usano [acceptPrivacy].
  Future<Visit> acceptPrivacyWithSignature({
    required Visit visit,
    required String signaturePngBase64,
  });

  Future<void> checkOutByBadgeCode({required String badgeCode});
}
