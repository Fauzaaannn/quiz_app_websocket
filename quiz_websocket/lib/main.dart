import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quiz_websocket/features/AuthCubit/data/datasources/auth_datasources.dart';
import 'features/AuthCubit/data/repositories/auth_repository_impl.dart';
import 'features/AuthCubit/presentation/cubit/authcubit_cubit.dart';
import 'login_page.dart';

void main() {
  final repo = AuthRepositoryImpl(AuthRemoteDataSource());
  runApp(
    BlocProvider(create: (_) => AuthcubitCubit(repo), child: const MyApp()),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quiz WS',
      theme: ThemeData(useMaterial3: true),
      home: const LoginPage(),
    );
  }
}
