import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:http/http.dart';
import 'package:haptext_api/exports.dart';
import 'package:haptext_api/models/user_infor_model.dart';
import 'package:haptext_api/network/api_constants.dart';
import 'package:haptext_api/repository/auth_repo/auth_repo.dart';
import 'package:haptext_api/repository/profile_repo/profile_repo.dart';
import 'package:haptext_api/utils/session_manager.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  AuthRepo authRepo;
  AuthCubit(this.authRepo) : super(AuthInitial());
  final usernameController = TextEditingController();
  final emailController = TextEditingController();
  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final passwordController = TextEditingController();
  final passwordConfirmController = TextEditingController();
  final otpController = TextEditingController();

  final locationController = TextEditingController();
  final occupationController = TextEditingController();
  final birthDateController = TextEditingController();
  String? selectedGender;
  String? selectedRelationshipStatus;
  File? profileImage;

  String _extractErrorMessage(dynamic body, {String fallback = 'Request failed'}) {
    try {
      if (body is Map) {
        final errors = body['errors'];
        if (errors is Map && errors['detail'] != null) {
          final detail = errors['detail'].toString().trim();
          if (detail.isNotEmpty) return detail;
        }
        if (body['message'] != null) {
          final message = body['message'].toString().trim();
          if (message.isNotEmpty) return message;
        }
      }
    } catch (_) {}
    return fallback;
  }

  registerUser() async {
    emit(AuthLoadingState());
    try {
      final streamedResponse = await authRepo.registerUser(
          username: usernameController.text,
          email: emailController.text,
          firstName: firstNameController.text.isNotEmpty
              ? firstNameController.text
              : null,
          lastName: lastNameController.text.isNotEmpty
              ? lastNameController.text
              : null,
          gender: selectedGender,
          birthDate: birthDateController.text.isNotEmpty
              ? birthDateController.text
              : null,
          location: locationController.text.isNotEmpty
              ? locationController.text
              : null,
          relationshipStatus: selectedRelationshipStatus,
          occupation: occupationController.text.isNotEmpty
              ? occupationController.text
              : null,
          profilePicture: profileImage,
          password: passwordController.text,
          passwordConfirm: passwordConfirmController.text);

      final response = await Response.fromStream(streamedResponse);
      final body = jsonDecode(response.body);
      if (response.statusCode == 201 || response.statusCode == 200) {
        log("message${body['data']}");
        useInfo = UserInfoModel.fromJson(body["data"]);
        bearerToken = useInfo.tokens?.auth ?? '';
        SessionManager.storeUser(useInfo);
        SessionManager().storeToken(bearerToken);
        emit(AuthLoginState());
      } else {
        ToastMessage.showErrorToast(
            message: _extractErrorMessage(body, fallback: 'Registration failed'));
        emit(AuthErrorState());
      }
    } catch (e) {
      ToastMessage.showErrorToast(message: "Registration failed: $e");
      emit(AuthErrorState());
      log("register $e");
    }
  }

  verifyEmail() async {
    emit(AuthLoadingState());
    try {
      final response = await authRepo.verifyUserEmail(
          otp: otpController.text, email: emailController.text);

      final body = jsonDecode(response.body);
      if (response.statusCode == 200) {
        emit(AuthEmailVerifiedState());
      } else {
        ToastMessage.showErrorToast(
            message: _extractErrorMessage(body, fallback: 'Verification failed'));
        emit(AuthErrorState());
      }
    } catch (e) {
      ToastMessage.showErrorToast(message: "Verification failed: $e");
      emit(AuthErrorState());
      log("verify otp $e");
    }
  }

  verifyEmailRequest() async {
    emit(AuthLoadingState());
    try {
      final response =
          await authRepo.requestEmailVerify(email: emailController.text);

      final body = jsonDecode(response.body);
      if (response.statusCode == 200) {
        emit(AuthVerifyOtpSentState());
      } else {
        ToastMessage.showErrorToast(
            message: _extractErrorMessage(body, fallback: 'Unable to send OTP'));
        emit(AuthErrorState());
      }
    } catch (e) {
      ToastMessage.showErrorToast(message: "Unable to send OTP: $e");
      emit(AuthErrorState());
      log("request verify otp $e");
    }
  }

  UserInfoModel useInfo = UserInfoModel();
  loginUser() async {
    emit(AuthLoadingState());
    try {
      final response = await authRepo.userLogin(
          password: passwordController.text, email: emailController.text);
      final body = jsonDecode(response.body);
      if (response.statusCode == 200) {
        log("message${body['data']}");
        useInfo = UserInfoModel.fromJson(body["data"]);
        bearerToken = useInfo.tokens?.auth ?? '';
        SessionManager.storeUser(useInfo);
        SessionManager().storeToken(bearerToken);
        emit(AuthLoginState());
      } else {
        final errorDetail = _extractErrorMessage(body, fallback: 'Login failed');
        if (errorDetail.contains("is not verified")) {
          verifyEmailRequest();
        } else {
          ToastMessage.showErrorToast(message: errorDetail);
          emit(AuthErrorState());
        }
      }
    } catch (e) {
      ToastMessage.showErrorToast(message: "Login failed: $e");
      emit(AuthErrorState());
      log("Login $e");
    }
  }

  requestPasswordReset() async {
    emit(AuthLoadingState());
    try {
      final response =
          await authRepo.requestPasswordReset(email: emailController.text);

      final body = jsonDecode(response.body);
      if (response.statusCode == 200) {
        ToastMessage.showSuccessToast(message: body["message"]);
        emit(AuthResetPasswordOtpState());
      } else {
        ToastMessage.showErrorToast(
            message:
                _extractErrorMessage(body, fallback: 'Password reset failed'));
        emit(AuthErrorState());
      }
    } catch (e) {
      ToastMessage.showErrorToast(message: "Password reset failed: $e");
      emit(AuthErrorState());
      log("verify otp $e");
    }
  }

  final confirmPasword = TextEditingController();
  resetPassword() async {
    emit(AuthLoadingState());
    try {
      final response = await authRepo.resetPassword(
          newPassword: passwordController.text,
          confirmNewPassword: confirmPasword.text,
          otp: otpController.text,
          email: emailController.text);

      final body = jsonDecode(response.body);
      if (response.statusCode == 200) {
        emit(AuthResetPasswordSucess());
      } else {
        ToastMessage.showErrorToast(
            message:
                _extractErrorMessage(body, fallback: 'Password reset failed'));
        emit(AuthErrorState());
      }
    } catch (e) {
      ToastMessage.showErrorToast(message: "Password reset failed: $e");
      emit(AuthErrorState());
      log("confirm reset Password $e");
    }
  }

  fetchUserProfile() async {
    emit(AuthLoadingState());
    try {
      final response = await ProfileRepo().fetchUserProfile();
      final body = jsonDecode(response.body);
      if (response.statusCode == 200) {
        useInfo = UserInfoModel.fromJson(body["data"]);

        emit(AuthLoadedState());
      } else {
        final body = jsonDecode(response.body);
        ToastMessage.showErrorToast(
            message:
                _extractErrorMessage(body, fallback: 'Unable to load profile'));
        emit(AuthErrorState());
      }
    } catch (e) {
      ToastMessage.showErrorToast(message: "Unable to load profile: $e");
      emit(AuthErrorState());
      log("user Profile $e");
    }
  }

  fetchLocalUser() async {
    emit(AuthLoadingState());
    try {
      final storedUser = await SessionManager.getUser();
      if (storedUser != null) {
        useInfo = storedUser;
        emit(AuthLoadedState());
      } else {
        ToastMessage.showErrorToast(message: 'Not logged in');
        emit(AuthErrorState());
      }
    } catch (e) {
      ToastMessage.showErrorToast(message: "Unable to restore session: $e");
      emit(AuthErrorState());
      log("local user $e");
    }
  }

  logout() async {
    try {
      await Supabase.instance.client.auth.signOut();
      await SessionManager.deleteUser();
      await SessionManager().deleteToken();
      bearerToken = '';
      useInfo = UserInfoModel();
      emit(AuthInitial());
    } catch (e) {
      log("logout error $e");
    }
  }
}
