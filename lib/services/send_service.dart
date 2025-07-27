import 'dart:convert';
import 'dart:io';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;

class SendService {
  static Future<void> sendNotification({
    required String fcmToken,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    final serviceAccount = ServiceAccountCredentials.fromJson(
      File('/server/firebase-adminsdk.json').readAsStringSync(),
    );

    final scopes = ['https://www.googleapis.com/auth/firebase.messaging'];
    final authClient = await clientViaServiceAccount(serviceAccount, scopes);
    final accessToken = authClient.credentials.accessToken.data;

    final url = Uri.parse(
      'https://fcm.googleapis.com/v1/projects/mealmommyapplication/messages:send',
    );

    final message = {
      "message": {
        "token": fcmToken,
        "notification": {
          "title": title,
          "body": body,
        },
        if (data != null) "data": data,
      }
    };

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(message),
    );

    print('Status: ${response.statusCode}');
    print('Response: ${response.body}');
  }
}
