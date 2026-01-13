/// Modello che rappresenta l'accettazione della privacy e la firma.
///
/// La firma potrà essere un'immagine (es. PNG) o un PDF.
/// In questa fase tieniamo solo un placeholder.
class PrivacyConsent {
  final String visitId; // id della visita a cui è collegato il consenso
  final DateTime acceptedAt;
  final String? signatureFilePath; // percorso locale del file di firma
  final String? remoteFileUrl; // URL del file sul backend (se disponibile)

  const PrivacyConsent({
    required this.visitId,
    required this.acceptedAt,
    this.signatureFilePath,
    this.remoteFileUrl,
  });

/// TODO: metodi toJson/fromJson per inviare/ricevere dati dal backend.
}
