part of 'profile_cubit.dart';

@immutable
sealed class ProfileState {}

final class ProfileInitial extends ProfileState {}

final class ProfileLoading extends ProfileState {}

final class ProfileLoaded extends ProfileState {}

final class ProfileUpdated extends ProfileState {
  final SearchedUserProfile? profile;
  final Map<String, dynamic>? warnings;

  ProfileUpdated({this.profile, this.warnings});
}

final class ProfileError extends ProfileState {}
