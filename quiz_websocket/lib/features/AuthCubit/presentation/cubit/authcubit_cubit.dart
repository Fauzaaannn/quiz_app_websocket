import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/repositories/auth_repository.dart';

part 'authcubit_state.dart';

class AuthcubitCubit extends Cubit<AuthcubitState> {
  final AuthRepository _repo;
  String? _token;

  AuthcubitCubit(this._repo) : super(AuthcubitInitial());

  void setToken(String token) {
    _token = token;
    emit(AuthAuthenticated(token: token));
  }

  Future<void> selectRole(String role) async {
    final t = _token;
    if (t == null) {
      emit(const AuthError('Token belum tersedia'));
      return;
    }
    emit(AuthLoading());
    try {
      final result = await _repo.selectRole(token: t, role: role);
      emit(AuthAuthenticated(
        token: t,
        userName: result.userName,
        role: role,
        message: result.message,
      ));
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> logout() async {
    try {
      await _repo.logout();
    } finally {
      _token = null;
      emit(AuthUnauthenticated());
    }
  }
}