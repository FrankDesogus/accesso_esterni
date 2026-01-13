class Visit {
  // Odoo record id
  final String? id;

  // Dati visitatore
  final String firstName;
  final String lastName;
  final String? reason;

  // Campi extra (UI -> Odoo)
  final String? company;    // x_studio_societa
  final String? docType;    // x_studio_tipo_documento (selection value/key)
  final String? docNumber;  // x_studio_numero_documento

  // Host (Many2one hr.employee)
  final int? hostId;        // x_studio_persona_da_visitare (ID)
  final String? hostName;   // solo per UI, risolto poi a hostId

  // Stato flusso app
  final bool privacyAccepted;

  // Badge / check-in runtime (usati dal tuo datasource)
  final int? badgeId;        // x_studio_badge (Many2one id)
  final DateTime? checkInTime;

  const Visit({
    this.id,
    required this.firstName,
    required this.lastName,
    this.reason,

    this.company,
    this.docType,
    this.docNumber,

    this.hostId,
    this.hostName,

    this.privacyAccepted = false,

    this.badgeId,
    this.checkInTime,
  });

  Visit copyWith({
    String? id,
    String? firstName,
    String? lastName,
    String? reason,

    String? company,
    String? docType,
    String? docNumber,

    int? hostId,
    String? hostName,

    bool? privacyAccepted,

    int? badgeId,
    DateTime? checkInTime,
  }) {
    return Visit(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      reason: reason ?? this.reason,

      company: company ?? this.company,
      docType: docType ?? this.docType,
      docNumber: docNumber ?? this.docNumber,

      hostId: hostId ?? this.hostId,
      hostName: hostName ?? this.hostName,

      privacyAccepted: privacyAccepted ?? this.privacyAccepted,

      badgeId: badgeId ?? this.badgeId,
      checkInTime: checkInTime ?? this.checkInTime,
    );
  }
}
