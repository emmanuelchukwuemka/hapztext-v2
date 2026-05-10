import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:haptext_api/exports.dart';
import 'package:haptext_api/repository/profile_repo/profile_repo.dart';

part 'profile_state.dart';

class ProfileCubit extends Cubit<ProfileState> {
  ProfileRepo profileRepo;
  ProfileCubit(this.profileRepo) : super(ProfileInitial());

  createProfile(
      {required String userId,
      String? birthDate,
      String? ethnicity,
      String? relationshipStatus,
      String? firstName,
      String? lastName,
      String? bio,
      String? occupation,
      File? profilePicture,
      File? coverPicture,
      bool updateProfile = false,
      String? location,
      String? height,
      String? weight}) async {
    emit(ProfileLoading());
    try {
      final response = updateProfile
          ? await profileRepo.updateProfile(
              userId: userId,
              birthDate: birthDate,
              ethnicity: ethnicity,
              relationshipStatus: relationshipStatus,
              firstName: firstName,
              lastName: lastName,
              profilePicture: profilePicture,
              coverPicture: coverPicture,
              bio: bio,
              occupation: occupation,
              location: location,
              height: height,
              weight: weight)
          : await profileRepo.createProfile(
              userId: userId,
              birthDate: birthDate,
              ethnicity: ethnicity,
              relationshipStatus: relationshipStatus,
              firstName: firstName,
              lastName: lastName,
              profilePicture: profilePicture,
              coverPicture: coverPicture,
              bio: bio,
              occupation: occupation,
              location: location,
              height: height,
              weight: weight);
      final body = jsonDecode(await response.stream.bytesToString());

      if (response.statusCode == 201 ||
          response.statusCode == 200 ||
          response.statusCode == 202) {
        SearchedUserProfile? profile;
        final data = body is Map ? body['data'] : null;
        if (data is Map<String, dynamic>) {
          profile = SearchedUserProfile.fromJson(data);
        }
        final warnings = body is Map<String, dynamic> ? body['warnings'] : null;
        emit(ProfileUpdated(
          profile: profile,
          warnings: warnings is Map<String, dynamic> ? warnings : null,
        ));
      } else {
        String errorMessage = "Failed to update profile";
        try {
          if (body["errors"] != null) {
            if (body["errors"] is Map) {
              final errors = body["errors"] as Map;
              // Check for 'detail' or other specific field errors
              if (errors.containsKey("detail")) {
                errorMessage = errors["detail"].toString();
              } else {
                // Combine multiple field errors if present
                errorMessage = errors.entries
                    .map((e) => "${e.key}: ${e.value}")
                    .join(", ");
              }
            } else {
              errorMessage = body["errors"].toString();
            }
          }
        } catch (e) {
          log("Error parsing error message: $e");
        }
        ToastMessage.showErrorToast(message: errorMessage);
        emit(ProfileError());
      }
    } catch (e) {
      ToastMessage.showErrorToast(message: "Failed to update profile: $e");
      emit(ProfileError());
      log("create Profile $e");
    }
  }
}
