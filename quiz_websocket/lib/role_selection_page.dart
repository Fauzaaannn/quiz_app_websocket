import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:quiz_websocket/quiz_page.dart';
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'login_page.dart';

class RoleSelectionPage extends StatelessWidget {
  final String token;
  const RoleSelectionPage({super.key, required this.token});

  void _submitRole(BuildContext context, String role) async {
    final response = await http.post(
      Uri.parse('http://localhost:3000/select-role'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'access_token': token, 'selected_role': role}),
    );

    if (response.statusCode == 200) {
      String msg = 'Role "$role" selected!';
      String? userName;
      try {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['message'] is String) msg = data['message'] as String;
        final user = data['user'] as Map<String, dynamic>?;
        userName =
            (user?['name'] ?? user?['preferred_username'] ?? user?['email'])
                ?.toString();
      } catch (_) {}
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

      // Navigate ke QuizPage, kirim nama & role
      if (context.mounted && role == 'mahasiswa') {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => QuizPage(),
            settings: RouteSettings(
              arguments: {'userName': userName, 'role': role},
            ),
          ),
        );
      }
    } else {
      String err = 'Failed to select role';
      try {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['message'] is String) err = data['message'] as String;
      } catch (_) {}
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
  }

  Future<void> _logout(BuildContext context) async {
    const logoutUrl = 'http://localhost:3000/logout';
    try {
      final uri = Uri.parse(logoutUrl);
      if (await canLaunchUrl(uri)) {
        // Open the IdP logout via backend, clears SSO cookie in external browser
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      // ignore, still navigate back locally
    }
    if (context.mounted) {
      // Clear app state and go back to login screen
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Pilih Role")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () => _submitRole(context, 'mahasiswa'),
              child: const Text("Saya Mahasiswa"),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _submitRole(context, 'dosen'),
              child: const Text("Saya Dosen"),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _logout(context),
              child: const Text("Logout"),
            ),
          ],
        ),
      ),
    );
  }
}
