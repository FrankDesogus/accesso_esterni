String normalizeDocNumber(String raw) {
  final upper = raw.toUpperCase().trim();
  return upper.replaceAll(RegExp(r'[^A-Z0-9]'), '');
}

String buildDocKey({required String tipo, required String numeroRaw}) {
  final t = tipo.trim().toUpperCase();
  final n = normalizeDocNumber(numeroRaw);
  return '$t|$n';
}
