/// Modello per rappresentare un badge fisico con QR code.
class Badge {
  final int id; // id lato backend
  final String code; // codice univoco (es. "badge_1")
  final bool isAssigned;

  const Badge({
    required this.id,
    required this.code,
    this.isAssigned = false,
  });

/// TODO: fromJson / toJson per integrazione con API Odoo.
}
