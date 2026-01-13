import 'dart:async';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;

class OdooException implements Exception {
  final String message;
  OdooException(this.message);
  @override
  String toString() => message;
}

class OdooJsonRpcClient {
  OdooJsonRpcClient({
    required this.baseUrl,
    required this.db,
    required this.username,
    required this.password,
    http.Client? httpClient,
  }) : _client = httpClient ?? http.Client();

  final String baseUrl;
  final String db;
  final String username;
  final String password;
  final http.Client _client;

  int? _uid;
  Map<String, dynamic>? _userContext;

  /// Cookie jar minimale (basta per Odoo web: session_id + eventuali altri)
  final Map<String, String> _cookies = {};

  bool get isAuthenticated => _uid != null;

  static int _idCounter = 0;
  static int _nextId() => ++_idCounter;

  Future<void> ensureAuthenticated() async {
    if (isAuthenticated) return;
    await authenticate();
  }

  Future<void> authenticate() async {
    final uri = Uri.parse('$baseUrl/web/session/authenticate');

    final payload = {
      "jsonrpc": "2.0",
      "method": "call",
      "params": {
        "db": db,
        "login": username,
        "password": password,
      },
      "id": _nextId(),
    };

    final res = await _client
        .post(uri, headers: _headers(), body: jsonEncode(payload))
        .timeout(const Duration(seconds: 20));

    _captureCookies(res);

    final decoded = _decodeJson(res);
    final result = decoded['result'];

    if (result == null || result['uid'] == null) {
      throw OdooException('Login Odoo fallito (credenziali/db errati?)');
    }

    _uid = result['uid'] as int;
    _userContext = (result['user_context'] as Map?)?.cast<String, dynamic>();

    // DEBUG utile quando serve:
    // print('[OdooJsonRpcClient] Auth ok uid=$_uid session_id=${_cookies['session_id']}');
  }

  Future<dynamic> callKw({
    required String model,
    required String method,
    List<dynamic> args = const [],
    Map<String, dynamic> kwargs = const {},
  }) async {
    await ensureAuthenticated();

    final uri = Uri.parse('$baseUrl/web/dataset/call_kw');

    final ctx = <String, dynamic>{
      ...?_userContext,
    };

    final finalKwargs = {
      ...kwargs,
      "context": ctx,
    };

    final payload = {
      "jsonrpc": "2.0",
      "method": "call",
      "params": {
        "model": model,
        "method": method,
        "args": args,
        "kwargs": finalKwargs,
      },
      "id": _nextId(),
    };

    debugPrint('[OdooJsonRpcClient] call_kw $model.$method args=$args kwargs=$finalKwargs');


    final res = await _client
        .post(uri, headers: _headers(), body: jsonEncode(payload))
        .timeout(const Duration(seconds: 20));

    _captureCookies(res);

    final decoded = _decodeJson(res);

    if (decoded['error'] != null) {
      final err = decoded['error'];
      final data = (err is Map) ? err['data'] : null;

      final name = (data is Map ? data['name'] : null)?.toString();
      final msg = (data is Map ? data['message'] : null)?.toString() ??
          (err is Map ? err['message'] : null)?.toString() ??
          'Errore Odoo';

      // Mostra anche il tipo errore se presente (AccessError, etc.)
      if (name != null && name.isNotEmpty) {
        throw OdooException('$name: $msg');
      }
      throw OdooException(msg);
    }

    return decoded['result'];
  }

  // --------------------------------------------------------------------------
  // Helpers alto livello
  // --------------------------------------------------------------------------

  Future<int> searchCount({
    required String model,
    required List<dynamic> domain,
  }) async {
    final result = await callKw(
      model: model,
      method: 'search_count',
      args: [domain],
      kwargs: const {},
    );
    return (result as num).toInt();
  }

  /// search_read "standard web": args=[] e domain nei kwargs
  Future<List<Map<String, dynamic>>> searchRead({
    required String model,
    required List<dynamic> domain,
    required List<String> fields,
    int limit = 10,
    int offset = 0,
    String? order,
  }) async {
    final kwargs = <String, dynamic>{
      'fields': fields,
      'offset': offset,
      if (order != null) 'order': order,
    };

    // 🔥 IMPORTANTISSIMO: in Odoo "no limit" non è limit=0
    // Non passare proprio 'limit' quando vuoi tutti i record.
    if (limit > 0) {
      kwargs['limit'] = limit;
    }

    final result = await callKw(
      model: model,
      method: 'search_read',
      args: [domain],
      kwargs: kwargs,
    );

    final list = (result as List).cast<Map>();
    return list.map((e) => e.cast<String, dynamic>()).toList();
  }


  Future<int> create({
    required String model,
    required Map<String, dynamic> values,
  }) async {
    final result = await callKw(
      model: model,
      method: 'create',
      args: [values],
    );
    return (result as num).toInt();
  }

  Future<bool> write({
    required String model,
    required List<int> ids,
    required Map<String, dynamic> values,
  }) async {
    final result = await callKw(
      model: model,
      method: 'write',
      args: [ids, values],
    );
    return result == true;
  }

  /// ✅ fields_get corretto per Odoo 18:
  /// args = [[fieldNames...]]
  /// kwargs = {attributes: [...]}
  Future<Map<String, dynamic>> fieldsGet({
    required String model,
    required List<String> fieldNames,
    List<String> attributes = const ['type', 'string', 'selection', 'required', 'readonly'],
  }) async {
    final res = await callKw(
      model: model,
      method: 'fields_get',
      args: [fieldNames],
      kwargs: {'attributes': attributes},
    );

    if (res is Map<String, dynamic>) return res;
    throw OdooException('fields_get: risposta non valida');
  }

  // --------------------------------------------------------------------------
  // HTTP helpers
  // --------------------------------------------------------------------------

  Map<String, String> _headers() {
    final cookieHeader = _cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (cookieHeader.isNotEmpty) 'Cookie': cookieHeader,
    };
  }

  /// ✅ Cookie parsing robusto:
  /// in Dart `http` spesso ti dà un singolo header "set-cookie" concatenato,
  /// e non puoi splittare a virgola (Expires contiene virgole).
  /// Noi estraiamo i cookie col pattern "<name>=<value>;" ripetuto.
  void _captureCookies(http.Response res) {
    final setCookie = res.headers['set-cookie'];
    if (setCookie == null || setCookie.isEmpty) return;

    // Trova tutte le occorrenze "name=value;" nell'header completo
    final re = RegExp(r'(?:(?:^|,)\s*)([A-Za-z0-9_]+)=([^;]+);');
    for (final m in re.allMatches(setCookie)) {
      final name = m.group(1);
      final value = m.group(2);
      if (name == null || value == null) continue;

      final k = name.trim();
      final v = value.trim();
      if (k.isNotEmpty && v.isNotEmpty) {
        _cookies[k] = v;
      }
    }

    // Fallback: session_id anche senza ';' (paranoia)
    final sid = RegExp(r'session_id=([^;,\s]+)').firstMatch(setCookie)?.group(1);
    if (sid != null && sid.trim().isNotEmpty) {
      _cookies['session_id'] = sid.trim();
    }
  }

  Map<String, dynamic> _decodeJson(http.Response res) {
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw OdooException('HTTP ${res.statusCode} verso Odoo');
    }
    final decoded = jsonDecode(res.body);
    if (decoded is! Map<String, dynamic>) {
      throw OdooException('Risposta Odoo non valida');
    }
    return decoded;
  }
}
