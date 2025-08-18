class RoleSelectResult {
  final String message;
  final String? userName;
  RoleSelectResult({required this.message, this.userName});
}

abstract class AuthRepository {
  Future<RoleSelectResult> selectRole({required String token, required String role});
  Future<void> logout();
}