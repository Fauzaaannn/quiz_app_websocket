import 'package:quiz_websocket/features/AuthCubit/data/datasources/auth_datasources.dart';

import '../../domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _remote;
  AuthRepositoryImpl(this._remote);

  @override
  Future<RoleSelectResult> selectRole({
    required String token,
    required String role,
  }) async {
    final data = await _remote.selectRole(token: token, role: role);
    final msg = (data['message'] as String?) ?? 'Role selected';
    final user = data['user'] as Map<String, dynamic>?;
    final userName =
        (user?['name'] ?? user?['preferred_username'] ?? user?['email'])
            ?.toString();
    return RoleSelectResult(message: msg, userName: userName);
  }

  @override
  Future<void> logout() => _remote.logout();
}
