import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart';
import 'package:mime/mime.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileRepo {
  static const String _profilesTable = 'profiles';
  static const String _profilePicturesBucket = 'profile_pictures';

  Map<String, dynamic> _errorBody(String message) {
    return {
      'errors': {'detail': message}
    };
  }

  String _ensurePublicUrl(String url) {
    if (url.contains('/storage/v1/object/') && !url.contains('/storage/v1/object/public/')) {
      return url.replaceFirst('/storage/v1/object/', '/storage/v1/object/public/');
    }
    return url;
  }

  Response _jsonResponse(int statusCode, Map<String, dynamic> json) {
    return Response(jsonEncode(json), statusCode,
        headers: {'content-type': 'application/json; charset=utf-8'});
  }

  StreamedResponse _streamedJsonResponse(
      int statusCode, Map<String, dynamic> json) {
    final bytes = utf8.encode(jsonEncode(json));
    return StreamedResponse(Stream<List<int>>.value(bytes), statusCode,
        headers: {'content-type': 'application/json; charset=utf-8'});
  }

  Future<Response> fetchUserProfile() async {
    final client = Supabase.instance.client;
    final session = client.auth.currentSession;
    final user = client.auth.currentUser;
    if (user == null) {
      return _jsonResponse(401, _errorBody('Not authenticated'));
    }

    try {
      final profile = await client
          .from(_profilesTable)
          .select()
          .eq('user_id', user.id)
          .maybeSingle();
      final username = (user.userMetadata?['username'] as String?) ??
          profile?['username']?.toString();

      return _jsonResponse(200, {
        'data': {
          'id': user.id,
          'email': user.email,
          'username': username,
          'tokens': {'auth': session?.accessToken ?? ''},
          if (profile != null) 'profile': profile,
        }
      });
    } on PostgrestException catch (e) {
      return _jsonResponse(400, _errorBody(e.message));
    } catch (e) {
      return _jsonResponse(500, _errorBody(e.toString()));
    }
  }

  Future<StreamedResponse> createProfile({
    required String userId,
    String? birthDate,
    String? ethnicity,
    String? relationshipStatus,
    String? firstName,
    String? lastName,
    String? bio,
    String? occupation,
    File? profilePicture,
    File? coverPicture,
    String? location,
    String? height,
    String? weight,
  }) async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) {
      return _streamedJsonResponse(401, _errorBody('Not authenticated'));
    }
    if (user.id != userId) {
      return _streamedJsonResponse(403, _errorBody('Forbidden'));
    }

    try {
      final warnings = <String, dynamic>{};
      String? profilePictureUrl;
      if (profilePicture != null && await profilePicture.exists()) {
        try {
          final bytes = await profilePicture.readAsBytes();
          final mime = lookupMimeType(profilePicture.path) ?? 'image/jpeg';
          final ext = profilePicture.path.contains('.')
              ? profilePicture.path
                  .substring(profilePicture.path.lastIndexOf('.'))
              : '';
          final path =
              '${user.id}/profile_${DateTime.now().millisecondsSinceEpoch}$ext';
          await client.storage.from(_profilePicturesBucket).upload(
                path,
                profilePicture,
                fileOptions: FileOptions(upsert: true, contentType: mime),
              );
          profilePictureUrl =
              _ensurePublicUrl(client.storage.from(_profilePicturesBucket).getPublicUrl(path));
        } on StorageException catch (e) {
          warnings['profile_picture'] = e.message;
          profilePictureUrl = null;
        }
      }

      String? coverPictureUrl;
      if (coverPicture != null && await coverPicture.exists()) {
        try {
          final bytes = await coverPicture.readAsBytes();
          final mime = lookupMimeType(coverPicture.path) ?? 'image/jpeg';
          final ext = coverPicture.path.contains('.')
              ? coverPicture.path.substring(coverPicture.path.lastIndexOf('.'))
              : '';
          final path =
              '${user.id}/cover_${DateTime.now().millisecondsSinceEpoch}$ext';
          await client.storage.from(_profilePicturesBucket).upload(
                path,
                coverPicture,
                fileOptions: FileOptions(upsert: true, contentType: mime),
              );
          coverPictureUrl =
              _ensurePublicUrl(client.storage.from(_profilePicturesBucket).getPublicUrl(path));
        } on StorageException catch (e) {
          warnings['cover_picture'] = e.message;
          coverPictureUrl = null;
        }
      }

      final row = <String, dynamic>{
        'user_id': userId,
        if (birthDate != null) 'birth_date': birthDate.replaceAll('/', '-'),
        if (ethnicity != null) 'ethnicity': ethnicity,
        if (relationshipStatus != null)
          'relationship_status': relationshipStatus,
        if (firstName != null) 'first_name': firstName,
        if (lastName != null) 'last_name': lastName,
        if (bio != null) 'bio': bio,
        if (occupation != null) 'occupation': occupation,
        if (location != null) 'location': location,
        if (height != null) 'height': height,
        if (weight != null) 'weight': weight,
        if (profilePictureUrl != null) 'profile_picture': profilePictureUrl,
        if (coverPictureUrl != null) 'cover_picture': coverPictureUrl,
      };

      await client.from(_profilesTable).upsert(row, onConflict: 'user_id');
      final inserted = await client
          .from(_profilesTable)
          .select()
          .eq('user_id', userId)
          .limit(1)
          .maybeSingle();
      return _streamedJsonResponse(201, {
        'data': inserted ?? {},
        if (warnings.isNotEmpty) 'warnings': warnings,
      });
    } on PostgrestException catch (e) {
      return _streamedJsonResponse(400, _errorBody(e.message));
    } catch (e) {
      return _streamedJsonResponse(500, _errorBody(e.toString()));
    }
  }

  Future<StreamedResponse> updateProfile(
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
      String? location,
      String? height,
      String? weight}) async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) {
      return _streamedJsonResponse(401, _errorBody('Not authenticated'));
    }
    if (user.id != userId) {
      return _streamedJsonResponse(403, _errorBody('Forbidden'));
    }

    try {
      final warnings = <String, dynamic>{};
      final updates = <String, dynamic>{};

      if (birthDate != null)
        updates['birth_date'] = birthDate.replaceAll('/', '-');
      if (ethnicity != null) updates['ethnicity'] = ethnicity;
      if (relationshipStatus != null)
        updates['relationship_status'] = relationshipStatus;
      if (firstName != null) updates['first_name'] = firstName;
      if (lastName != null) updates['last_name'] = lastName;
      if (bio != null) updates['bio'] = bio;
      if (occupation != null) updates['occupation'] = occupation;
      if (location != null) updates['location'] = location;
      if (height != null) updates['height'] = height;
      if (weight != null) updates['weight'] = weight;

      if (profilePicture != null && await profilePicture.exists()) {
        try {
          final bytes = await profilePicture.readAsBytes();
          final mime = lookupMimeType(profilePicture.path) ?? 'image/jpeg';
          final ext = profilePicture.path.contains('.')
              ? profilePicture.path
                  .substring(profilePicture.path.lastIndexOf('.'))
              : '';
          final path =
              '${user.id}/profile_${DateTime.now().millisecondsSinceEpoch}$ext';
          await client.storage.from(_profilePicturesBucket).upload(
                path,
                profilePicture,
                fileOptions: FileOptions(upsert: true, contentType: mime),
              );
          updates['profile_picture'] =
              _ensurePublicUrl(client.storage.from(_profilePicturesBucket).getPublicUrl(path));
        } on StorageException catch (e) {
          warnings['profile_picture'] = e.message;
        }
      }

      if (coverPicture != null && await coverPicture.exists()) {
        try {
          final bytes = await coverPicture.readAsBytes();
          final mime = lookupMimeType(coverPicture.path) ?? 'image/jpeg';
          final ext = coverPicture.path.contains('.')
              ? coverPicture.path.substring(coverPicture.path.lastIndexOf('.'))
              : '';
          final path =
              '${user.id}/cover_${DateTime.now().millisecondsSinceEpoch}$ext';
          await client.storage.from(_profilePicturesBucket).upload(
                path,
                coverPicture,
                fileOptions: FileOptions(upsert: true, contentType: mime),
              );
          updates['cover_picture'] =
              _ensurePublicUrl(client.storage.from(_profilePicturesBucket).getPublicUrl(path));
        } on StorageException catch (e) {
          warnings['cover_picture'] = e.message;
        }
      }

      if (updates.isEmpty) {
        final existing = await client
            .from(_profilesTable)
            .select()
            .eq('user_id', userId)
            .maybeSingle();
        return _streamedJsonResponse(200, {'data': existing ?? {}});
      }

      final updated = await client
          .from(_profilesTable)
          .update(updates)
          .eq('user_id', userId)
          .select()
          .limit(1)
          .maybeSingle();
      return _streamedJsonResponse(200, {
        'data': updated ?? {},
        if (warnings.isNotEmpty) 'warnings': warnings,
      });
    } on PostgrestException catch (e) {
      return _streamedJsonResponse(400, _errorBody(e.message));
    } catch (e) {
      return _streamedJsonResponse(500, _errorBody(e.toString()));
    }
  }
}
