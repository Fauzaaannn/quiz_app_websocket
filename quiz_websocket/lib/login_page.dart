import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:quiz_websocket/role_selection_page.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'features/AuthCubit/presentation/cubit/authcubit_cubit.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  StreamSubscription? _sub;
  String? _accessToken;
  final _appLinks = AppLinks();
  bool _handledNavigation = false;

  @override
  void initState() {
    super.initState();
    _listenForDeepLinks();
  }

  void _handleUri(Uri? uri) {
    if (uri != null && uri.scheme == 'com.yourapp') {
      // Cek skema URI
      final token =
          uri.queryParameters['access_token']; // Ambil token dari parameter query
      setState(() {
        _accessToken = token;
      });
      if (!_handledNavigation && token != null && mounted) {
        _handledNavigation = true;

        // Simpan token ke Cubit
        context.read<AuthcubitCubit>().setToken(token);

        // Stop listening to avoid duplicate navigations
        _sub?.cancel();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => RoleSelectionPage(token: token),
          ),
        );
      }
    }
  }

  void _listenForDeepLinks() {
    _sub = _appLinks.uriLinkStream.listen(_handleUri);
  }

  void _launchSSOLogin() async {
    // Meluncurkan proses login SSO
    const loginUrl = 'http://localhost:3000/login'; // Ganti jika backend online
    if (await canLaunchUrl(Uri.parse(loginUrl))) {
      // Cek ketersediaan URL
      await launchUrl(
        // Buka URL di browser eksternal
        Uri.parse(loginUrl), // URL login SSO
        mode: LaunchMode.externalApplication, // Buka di aplikasi eksternal
      );
    } else {
      throw 'Could not launch SSO login';
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Login SSO")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: _launchSSOLogin,
              child: const Text("Login with SSO"),
            ),
            if (_accessToken != null) ...[
              const SizedBox(height: 12),
              const Text(
                'Token captured',
                style: TextStyle(color: Colors.green),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
