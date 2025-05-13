import 'dart:convert';

import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart' show rootBundle;

class FirebaseCloudMessaging {
  static Future<Map<String, dynamic>> loadServiceAccountJson() async {
    final jsonString =
        await rootBundle.loadString('assets/serviceAccount.json');
    final jsonMap = json.decode(jsonString);
    return jsonMap;
  }

  static Future<String> getAccessToken() async {
    final serviceAccountJson = await loadServiceAccountJson();

    List<String> scopes = [
      "https://www.googleapis.com/auth/firebase.messaging"
    ];

    final client = http.Client();
    try {
      final credentials = await auth.obtainAccessCredentialsViaServiceAccount(
          auth.ServiceAccountCredentials.fromJson(serviceAccountJson),
          scopes,
          client);

      // Return the access token
      return credentials.accessToken.data;
    } finally {
      // Always close the HTTP client
      client.close();
    }
  }
}
