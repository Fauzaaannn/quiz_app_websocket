part of 'authcubit_cubit.dart';

abstract class AuthcubitState extends Equatable {
  const AuthcubitState();
  @override
  List<Object?> get props => [];
}

class AuthcubitInitial extends AuthcubitState {}

class AuthLoading extends AuthcubitState {}

class AuthUnauthenticated extends AuthcubitState {}

class AuthAuthenticated extends AuthcubitState {
  final String token;
  final String? userName;
  final String? role;
  final String? message;
  const AuthAuthenticated({
    required this.token,
    this.userName,
    this.role,
    this.message,
  });

  AuthAuthenticated copyWith({
    String? token,
    String? userName,
    String? role,
    String? message,
  }) =>
      AuthAuthenticated(
        token: token ?? this.token,
        userName: userName ?? this.userName,
        role: role ?? this.role,
        message: message ?? this.message,
      );

  @override
  List<Object?> get props => [token, userName, role, message];
}

class AuthError extends AuthcubitState {
  final String message;
  const AuthError(this.message);
  @override
  List<Object?> get props => [message];
}