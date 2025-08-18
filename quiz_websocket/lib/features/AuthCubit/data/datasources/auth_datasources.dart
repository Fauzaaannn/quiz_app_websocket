import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class AuthRemoteDataSource {
  final String baseUrl;
  final http.Client _client;
  AuthRemoteDataSource({
    http.Client? client,
    this.baseUrl = 'http://localhost:3000',
  }) : _client = client ?? http.Client();

  Future<Map<String, dynamic>> selectRole({
    required String token,
    required String role,
  }) async {
    final uri = Uri.parse('$baseUrl/select-role');
    final res = await _client.post(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'access_token': token, 'selected_role': role}),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    try {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      throw Exception(body['message'] ?? 'Failed to select role');
    } catch (_) {
      throw Exception('Failed to select role (${res.statusCode})');
    }
  }

  Future<void> logout() async {
    final uri = Uri.parse('$baseUrl/logout');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
