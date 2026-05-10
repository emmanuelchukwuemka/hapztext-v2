import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRepo {
  static const String _profilesTable = 'profiles';
  static const String _profilePicturesBucket = 'profile_pictures';
  static const Duration _timeout = Duration(seconds: 15);

  Map<String, dynamic> _errorBody(String message) {
    return {
      'errors': {'detail': message}
    };
  }

  StreamedResponse _streamedJsonResponse(
      int statusCode, Map<String, dynamic> json) {
    final bytes = utf8.encode(jsonEncode(json));
    return StreamedResponse(Stream<List<int>>.value(bytes), statusCode,
        headers: {'content-type': 'application/json; charset=utf-8'});
  }

  Response _jsonResponse(int statusCode, Map<String, dynamic> json) {
    return Response(jsonEncode(json), statusCode,
        headers: {'content-type': 'application/json; charset=utf-8'});
  }

  Future<Map<String, dynamic>?> _fetchProfile(String userId) async {
    final data = await Supabase.instance.client
        .from(_profilesTable)
        .select()
        .eq('user_id', userId)
        .limit(1)
        .maybeSingle();
    if (data == null) return null;
    return Map<String, dynamic>.from(data as Map);
  }

  Future<StreamedResponse> registerUser(
      {required String username,
      required String email,
      required String password,
      String? firstName,
      String? lastName,
      String? gender,
      String? birthDate,
      String? location,
      String? relationshipStatus,
      String? occupation,
      File? profilePicture,
      required String passwordConfirm}) async {
    if (password != passwordConfirm) {
      return _streamedJsonResponse(400, _errorBody('Passwords do not match'));
    }

    final client = Supabase.instance.client;

    try {
      final signUpRes = await client.auth.signUp(
        email: email,
        password: password,
        data: {
          'username': username,
          if (firstName != null) 'first_name': firstName,
          if (lastName != null) 'last_name': lastName,
        },
      ).timeout(_timeout);

      if (signUpRes.user == null && client.auth.currentUser == null) {
        return _streamedJsonResponse(
            400, _errorBody('Sign up failed. Check email and password.'));
      }

      if (client.auth.currentSession == null) {
        await client.auth
            .signInWithPassword(email: email, password: password)
            .timeout(_timeout);
      }

      final session = client.auth.currentSession;
      final user = client.auth.currentUser;
      if (user == null) {
        return _streamedJsonResponse(400, _errorBody('Sign up failed.'));
      }

      String? profilePictureUrl;
      if (profilePicture != null && await profilePicture.exists()) {
        try {
          final fileBytes = await profilePicture.readAsBytes();
          final extension = profilePicture.path.contains('.')
              ? profilePicture.path
                  .substring(profilePicture.path.lastIndexOf('.'))
              : '';
          final path =
              '${user.id}/profile_${DateTime.now().millisecondsSinceEpoch}$extension';

          await client.storage
              .from(_profilePicturesBucket)
              .upload(
                path,
                profilePicture,
                fileOptions: const FileOptions(upsert: true),
              )
              .timeout(_timeout);

          profilePictureUrl =
              client.storage.from(_profilePicturesBucket).getPublicUrl(path);
        } on StorageException {
          profilePictureUrl = null;
        }
      }

      final profileRow = <String, dynamic>{
        'user_id': user.id,
        'username': username,
        if (firstName != null) 'first_name': firstName,
        if (lastName != null) 'last_name': lastName,
        if (gender != null) 'gender': gender,
        if (birthDate != null) 'birth_date': birthDate.replaceAll('/', '-'),
        if (location != null) 'location': location,
        if (relationshipStatus != null)
          'relationship_status': relationshipStatus,
        if (occupation != null) 'occupation': occupation,
        if (profilePictureUrl != null) 'profile_picture': profilePictureUrl,
      };

      await client.from(_profilesTable).upsert(profileRow).timeout(_timeout);

      final profile = await _fetchProfile(user.id);
      final responseBody = {
        'data': {
          'id': user.id,
          'email': user.email,
          'username': username,
          'tokens': {'auth': session?.accessToken ?? ''},
          if (profile != null) 'profile': profile,
        }
      };

      return _streamedJsonResponse(200, responseBody);
    } on AuthException catch (e) {
      return _streamedJsonResponse(400, _errorBody(e.message));
    } on TimeoutException {
      return _streamedJsonResponse(
          504, _errorBody('Request timed out. Check your connection.'));
    } catch (e) {
      return _streamedJsonResponse(500, _errorBody(e.toString()));
    }
  }

  Future<Response> verifyUserEmail(
      {required String email, required String otp}) async {
    final client = Supabase.instance.client;
    try {
      await client.auth.verifyOTP(
        email: email,
        token: otp,
        type: OtpType.signup,
      ).timeout(_timeout);
      return _jsonResponse(200, {'message': 'Email verified', 'data': {}});
    } on AuthException catch (e) {
      return _jsonResponse(400, _errorBody(e.message));
    } on TimeoutException {
      return _jsonResponse(
          504, _errorBody('Request timed out. Check your connection.'));
    } catch (e) {
      return _jsonResponse(500, _errorBody(e.toString()));
    }
  }

  Future<Response> userLogin(
      {required String email, required String password}) async {
    final client = Supabase.instance.client;
    try {
      final res = await client.auth
          .signInWithPassword(email: email, password: password)
          .timeout(_timeout);
      final session = res.session ?? client.auth.currentSession;
      final user = res.user ?? client.auth.currentUser;
      if (user == null) {
        return _jsonResponse(401, _errorBody('Invalid login credentials'));
      }

      final username = (user.userMetadata?['username'] as String?) ??
          (await _fetchProfile(user.id))?['username']?.toString();
      final profile = await _fetchProfile(user.id);

      return _jsonResponse(200, {
        'data': {
          'id': user.id,
          'email': user.email,
          'username': username,
          'tokens': {'auth': session?.accessToken ?? ''},
          if (profile != null) 'profile': profile,
        }
      });
    } on AuthException catch (e) {
      return _jsonResponse(401, _errorBody(e.message));
    } on TimeoutException {
      return _jsonResponse(
          504, _errorBody('Request timed out. Check your connection.'));
    } catch (e) {
      return _jsonResponse(500, _errorBody(e.toString()));
    }
  }

  Future<Response> requestPasswordReset({required String email}) async {
    final client = Supabase.instance.client;
    try {
      await client.auth.resetPasswordForEmail(email).timeout(_timeout);
      return _jsonResponse(
          200, {'message': 'Password reset email sent', 'data': {}});
    } on AuthException catch (e) {
      return _jsonResponse(400, _errorBody(e.message));
    } on TimeoutException {
      return _jsonResponse(
          504, _errorBody('Request timed out. Check your connection.'));
    } catch (e) {
      return _jsonResponse(500, _errorBody(e.toString()));
    }
  }

  Future<Response> requestEmailVerify({required String email}) async {
    final client = Supabase.instance.client;
    try {
      await client.auth
          .resend(type: OtpType.signup, email: email)
          .timeout(_timeout);
      return _jsonResponse(
          200, {'message': 'Verification email resent', 'data': {}});
    } on AuthException catch (e) {
      return _jsonResponse(400, _errorBody(e.message));
    } on TimeoutException {
      return _jsonResponse(
          504, _errorBody('Request timed out. Check your connection.'));
    } catch (e) {
      return _jsonResponse(500, _errorBody(e.toString()));
    }
  }

  Future<Response> resetPassword(
      {required String email,
      required String newPassword,
      required String otp,
      required String confirmNewPassword}) async {
    if (newPassword != confirmNewPassword) {
      return _jsonResponse(400, _errorBody('Passwords do not match'));
    }

    final client = Supabase.instance.client;
    try {
      await client.auth.verifyOTP(
        email: email,
        token: otp,
        type: OtpType.recovery,
      ).timeout(_timeout);
      await client.auth
          .updateUser(UserAttributes(password: newPassword))
          .timeout(_timeout);
      return _jsonResponse(200, {'message': 'Password updated', 'data': {}});
    } on AuthException catch (e) {
      return _jsonResponse(400, _errorBody(e.message));
    } on TimeoutException {
      return _jsonResponse(
          504, _errorBody('Request timed out. Check your connection.'));
    } catch (e) {
      return _jsonResponse(500, _errorBody(e.toString()));
    }
  }
}
