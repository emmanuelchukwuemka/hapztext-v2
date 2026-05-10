import 'package:flutter/foundation.dart';

String bearerToken = '';

class ApiConstants {
  static const String baseUrl = kDebugMode ? '' : '';
}

class ApiHeaders {
  static Map<String, String> get unaunthenticatedHeader =>
      {'Content-Type': 'application/json', 'Accept': 'application/json'};

  static Map<String, String> get aunthenticatedHeader => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        "Authorization": "Bearer $bearerToken"
      };
}
