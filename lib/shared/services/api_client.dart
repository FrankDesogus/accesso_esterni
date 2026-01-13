import 'dart:convert';
import 'package:http/http.dart' as http;

/// Semplice client per le chiamate REST verso il backend Odoo.
/// In questa fase è solo uno scheletro con metodi di base.
class ApiClient {
  ApiClient({required this.baseUrl, http.Client? httpClient})
      : _client = httpClient ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  /// Esegue una richiesta GET generica.
  /// [path] è il path relativo (es. '/api/visitor/checkin').
  Future<http.Response> get(String path, {Map<String, String>? headers}) async {
    final uri = Uri.parse('$baseUrl$path');
    // TODO: gestire query parameters se necessario
    final response = await _client.get(uri, headers: headers);
    // TODO: gestire errori, status code, logging
    return response;
  }

  /// Esegue una richiesta POST generica con body JSON.
  Future<http.Response> post(
      String path, {
        Map<String, String>? headers,
        Object? body,
      }) async {
    final uri = Uri.parse('$baseUrl$path');
    final defaultHeaders = <String, String>{
      'Content-Type': 'application/json',
      // TODO: aggiungere header di autenticazione se necessario (token, ecc.)
    };

    final mergedHeaders = {
      ...defaultHeaders,
      if (headers != null) ...headers,
    };

    final response = await _client.post(
      uri,
      headers: mergedHeaders,
      body: body != null ? jsonEncode(body) : null,
    );

    // TODO: gestione errori, parsing, ecc.
    return response;
  }

/// TODO: eventuale metodo per upload file (firma come immagine/PDF).
///
/// In futuro potrai aggiungere un metodo:
/// - Future<http.Response> uploadFile(...);
}
