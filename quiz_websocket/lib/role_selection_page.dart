import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:quiz_websocket/quiz_page.dart';
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'login_page.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'features/AuthCubit/presentation/cubit/authcubit_cubit.dart';

class RoleSelectionPage extends StatelessWidget {
  final String token;
  const RoleSelectionPage({super.key, required this.token});

  Future<void> _selectRole(BuildContext context, String role) async {
    // Delegasikan ke Cubit
    final cubit = context.read<AuthcubitCubit>();
    await cubit.selectRole(role);

    final state = cubit.state;
    if (state is AuthAuthenticated) {
      final msg = state.message ?? 'Role selected';
      final userName = state.userName;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

      // Navigate ke QuizPage, kirim nama & role
      if (context.mounted && role == 'mahasiswa') {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const QuizPage(),
            settings: RouteSettings(
              arguments: {'userName': userName, 'role': role},
            ),
          ),
        );
      }
    } else if (state is AuthError) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(state.message)));
    }
  }

  Future<void> _logout(BuildContext context) async {
    await context.read<AuthcubitCubit>().logout();
    if (context.mounted) {
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
              onPressed: () => _selectRole(context, 'mahasiswa'),
              child: const Text("Saya Mahasiswa"),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _selectRole(context, 'dosen'),
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
