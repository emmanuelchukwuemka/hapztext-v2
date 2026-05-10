part of 'auth_cubit.dart';

@immutable
sealed class AuthState {}

final class AuthInitial extends AuthState {}

final class AuthLoadingState extends AuthState {}

final class AuthLoadedState extends AuthState {}

final class AuthVerifyOtpSentState extends AuthState {}

final class AuthLoginState extends AuthState {}

final class AuthRegisterState extends AuthState {}

final class AuthResetPasswordSucess extends AuthState {}

final class AuthResetPasswordOtpState extends AuthState {}

final class AuthEmailVerifiedState extends AuthState {}

final class AuthErrorState extends AuthState {}
