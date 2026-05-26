import 'dart:convert';
import 'dart:io';
import 'package:haptext_api/network/export_network.dart';
import 'package:mime/mime.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HomeRepo {
  static const String _postsTable = 'posts';
  static const String _mediaFilesTable = 'media_files';
  static const String _reactionsTable = 'post_reactions';
  static const String _notificationsTable = 'notifications';
  static const String _postMediaBucket = 'post_media';

  Map<String, dynamic> _errorBody(String message) {
    return {
      'errors': {'detail': message}
    };
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

  User? _currentUser() => Supabase.instance.client.auth.currentUser;

  Future<String?> _currentUsername(String userId) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null && user.id == userId) {
      final metadataUsername = user.userMetadata?['username']?.toString();
      if (metadataUsername != null && metadataUsername.isNotEmpty) {
        return metadataUsername;
      }
    }
    try {
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('username')
          .eq('user_id', userId)
          .maybeSingle();
      final dbUsername = profile?['username']?.toString();
      if (dbUsername != null && dbUsername.isNotEmpty) {
        return dbUsername;
      }
    } catch (e) {
      // Fail-safe: fall back to auth user metadata if DB query fails
    }
    return user?.userMetadata?['username']?.toString();
  }

  String _ensurePublicUrl(String url) {
    if (url.contains('/storage/v1/object/') && !url.contains('/storage/v1/object/public/')) {
      return url.replaceFirst('/storage/v1/object/', '/storage/v1/object/public/');
    }
    return url;
  }

  Future<Response> fetchPost(
      {required int page, String? feedType, String? query}) async {
    final client = Supabase.instance.client;
    final user = _currentUser();
    if (user == null) {
      return _jsonResponse(401, _errorBody('Not authenticated'));
    }

    try {
      final currentUserId = user.id;
      dynamic builder = client
          .from(_postsTable)
          .select('*, $_mediaFilesTable(*), replies:posts!previous_post_id(count)')
          .eq('is_reply', false);

      if (query != null && query.trim().isNotEmpty) {
        builder = builder.ilike('text_content', '%${query.trim()}%');
      }

      if (feedType == 'popular') {
        builder = builder.order('like_count', ascending: false);
      } else if (feedType == 'trending') {
        builder = builder.order('share_count', ascending: false);
      } else {
        builder = builder.order('created_at', ascending: false);
      }

      const pageSize = 20;
      final from = (page - 1) * pageSize;
      final to = from + pageSize - 1;
      final rows = await builder.range(from, to);

      // Fetch current user's reactions for these posts
      final postIds = (rows as List).map((r) => r['id'].toString()).toList();
      Map<String, String> userReactions = {};
      if (postIds.isNotEmpty) {
        final reactions = await client
            .from(_reactionsTable)
            .select('post_id, reaction')
            .eq('user_id', currentUserId)
            .inFilter('post_id', postIds);
        for (final r in reactions) {
          userReactions[r['post_id'].toString()] = r['reaction'].toString();
        }
      }

      // Inject current_user_reaction and reply_count into each post
      final enriched = rows.map((r) {
        final map = Map<String, dynamic>.from(r as Map);
        map['current_user_reaction'] = userReactions[map['id'].toString()];
        
        int replyCount = 0;
        final repliesList = map['replies'];
        if (repliesList is List && repliesList.isNotEmpty) {
          final first = repliesList.first;
          if (first is Map) {
            replyCount = int.tryParse(first['count']?.toString() ?? '0') ?? 0;
          }
        }
        map['reply_count'] = replyCount;
        return map;
      }).toList();

      return _jsonResponse(200, {
        'data': {
          'result': enriched,
          'previous_posts_data': null,
          'next_posts_data': null,
        }
      });
    } on PostgrestException catch (e) {
      return _jsonResponse(400, _errorBody(e.message));
    } catch (e) {
      return _jsonResponse(500, _errorBody(e.toString()));
    }
  }

  Future<Response> fetchUserPost({required int page, userId}) async {
    final client = Supabase.instance.client;
    final user = _currentUser();
    if (user == null) {
      return _jsonResponse(401, _errorBody('Not authenticated'));
    }

    final effectiveUserId = userId?.toString() ?? user.id;
    try {
      const pageSize = 20;
      final from = (page - 1) * pageSize;
      final to = from + pageSize - 1;

      final rows = await client
          .from(_postsTable)
          .select('*, $_mediaFilesTable(*), replies:posts!previous_post_id(count)')
          .eq('sender_id', effectiveUserId)
          .eq('is_reply', false)
          .order('created_at', ascending: false)
          .range(from, to);

      final enriched = (rows as List).map((r) {
        final map = Map<String, dynamic>.from(r as Map);
        int replyCount = 0;
        final repliesList = map['replies'];
        if (repliesList is List && repliesList.isNotEmpty) {
          final first = repliesList.first;
          if (first is Map) {
            replyCount = int.tryParse(first['count']?.toString() ?? '0') ?? 0;
          }
        }
        map['reply_count'] = replyCount;
        return map;
      }).toList();

      return _jsonResponse(200, {
        'data': {
          'result': enriched,
          'previous_posts_data': null,
          'next_posts_data': null,
        }
      });
    } on PostgrestException catch (e) {
      return _jsonResponse(400, _errorBody(e.message));
    } catch (e) {
      return _jsonResponse(500, _errorBody(e.toString()));
    }
  }

  Future<Response> commentOnPost(
      {required String postId, String? comment, File? audioFile}) async {
    final client = Supabase.instance.client;
    final user = _currentUser();
    if (user == null) {
      return _jsonResponse(401, _errorBody('Not authenticated'));
    }

    try {
      final username = await _currentUsername(user.id);

      String? audioUrl;
      if (audioFile != null && await audioFile.exists()) {
        final mime = lookupMimeType(audioFile.path) ?? 'audio/m4a';
        final ext = audioFile.path.contains('.')
            ? audioFile.path.substring(audioFile.path.lastIndexOf('.'))
            : '';
        final path =
            '${user.id}/comments/${DateTime.now().millisecondsSinceEpoch}$ext';

        await client.storage.from(_postMediaBucket).upload(
              path,
              audioFile,
              fileOptions: FileOptions(upsert: true, contentType: mime),
            );
        audioUrl = _ensurePublicUrl(client.storage.from(_postMediaBucket).getPublicUrl(path));
      }

      final inserted = await client
          .from(_postsTable)
          .insert({
            'sender_id': user.id,
            'sender_username': username,
            'post_format': audioUrl != null ? 'audio' : 'text',
            'text_content': comment ?? '',
            'audio_content': audioUrl,
            'is_reply': true,
            'previous_post_id': postId,
            'is_published': true,
          })
          .select()
          .single();

      return _jsonResponse(201, {'data': inserted});
    } on PostgrestException catch (e) {
      return _jsonResponse(400, _errorBody(e.message));
    } catch (e) {
      return _jsonResponse(500, _errorBody(e.toString()));
    }
  }

  Future<Response> fetchPostComment({required String postId}) async {
    final client = Supabase.instance.client;
    final user = _currentUser();
    if (user == null) {
      return _jsonResponse(401, _errorBody('Not authenticated'));
    }

    try {
      final rows = await client
          .from(_postsTable)
          .select('*, $_mediaFilesTable(*)')
          .eq('is_reply', true)
          .eq('previous_post_id', postId)
          .order('created_at', ascending: false);

      final commentIds = (rows as List).map((r) => r['id'].toString()).toList();
      Map<String, String> userReactions = {};
      if (commentIds.isNotEmpty) {
        final reactions = await client
            .from(_reactionsTable)
            .select('post_id, reaction')
            .eq('user_id', user.id)
            .inFilter('post_id', commentIds);
        for (final r in reactions) {
          userReactions[r['post_id'].toString()] = r['reaction'].toString();
        }
      }

      final enriched = rows.map((r) {
        final map = Map<String, dynamic>.from(r as Map);
        map['current_user_reaction'] = userReactions[map['id'].toString()];
        map['reaction_count'] = map['like_count'];
        return map;
      }).toList();

      return _jsonResponse(200, {
        'data': {
          'result': enriched,
          'previous_replies_data': null,
          'next_replies_data': null,
        }
      });
    } on PostgrestException catch (e) {
      return _jsonResponse(400, _errorBody(e.message));
    } catch (e) {
      return _jsonResponse(500, _errorBody(e.toString()));
    }
  }

  Future<Response> sharePost({required String id}) async {
    final client = Supabase.instance.client;
    final user = _currentUser();
    if (user == null) {
      return _jsonResponse(401, _errorBody('Not authenticated'));
    }

    try {
      final post = await client
          .from(_postsTable)
          .select('share_count')
          .eq('id', id)
          .maybeSingle();
      final current = (post?['share_count'] as int?) ?? 0;
      await client
          .from(_postsTable)
          .update({'share_count': current + 1}).eq('id', id);
      return _jsonResponse(201, {'message': 'Post shared', 'data': {}});
    } on PostgrestException catch (e) {
      return _jsonResponse(400, _errorBody(e.message));
    } catch (e) {
      return _jsonResponse(500, _errorBody(e.toString()));
    }
  }

  Future<Response> reactPost(
      {required String id, required String reaction}) async {
    final client = Supabase.instance.client;
    final user = _currentUser();
    if (user == null) {
      return _jsonResponse(401, _errorBody('Not authenticated'));
    }

    try {
      final existing = await client
          .from(_reactionsTable)
          .select('reaction')
          .eq('post_id', id)
          .eq('user_id', user.id)
          .maybeSingle();

      if (existing != null && existing['reaction'] == reaction) {
        await client
            .from(_reactionsTable)
            .delete()
            .eq('post_id', id)
            .eq('user_id', user.id);
      } else {
        await client.from(_reactionsTable).upsert({
          'post_id': id,
          'user_id': user.id,
          'reaction': reaction,
        });
      }

      final reactions =
          await client.from(_reactionsTable).select('id').eq('post_id', id);
      final likeCount = reactions.length;

      await client
          .from(_postsTable)
          .update({'like_count': likeCount}).eq('id', id);
      return _jsonResponse(201, {
        'message': existing != null && existing['reaction'] == reaction
            ? 'Reaction removed'
            : 'Reaction saved',
        'data': {}
      });
    } on PostgrestException catch (e) {
      return _jsonResponse(400, _errorBody(e.message));
    } catch (e) {
      return _jsonResponse(500, _errorBody(e.toString()));
    }
  }

  Future<Response> fetchNotification({required int page}) async {
    final client = Supabase.instance.client;
    final user = _currentUser();
    if (user == null) {
      return _jsonResponse(401, _errorBody('Not authenticated'));
    }

    try {
      const pageSize = 20;
      final from = (page - 1) * pageSize;
      final to = from + pageSize - 1;
      final rows = await client
          .from(_notificationsTable)
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .range(from, to);
      return _jsonResponse(200, {
        'data': {
          'result': rows,
          'previous_notifications_data': null,
          'next_notifications_data': null,
        }
      });
    } on PostgrestException catch (e) {
      return _jsonResponse(400, _errorBody(e.message));
    } catch (e) {
      return _jsonResponse(500, _errorBody(e.toString()));
    }
  }

  Future<Response> createTextPost(
      {required String textContent,
      String? scheduledAt,
      String? taggedUser}) async {
    final client = Supabase.instance.client;
    final user = _currentUser();
    if (user == null) {
      return _jsonResponse(401, _errorBody('Not authenticated'));
    }
    try {
      final username = await _currentUsername(user.id);
      final inserted = await client
          .from(_postsTable)
          .insert({
            'sender_id': user.id,
            'sender_username': username,
            'post_format': 'text',
            'text_content': textContent,
            'is_reply': false,
            'scheduled_at': scheduledAt,
            'is_published': true,
          })
          .select('*, $_mediaFilesTable(*)')
          .single();
      return _jsonResponse(201, {'data': inserted});
    } on PostgrestException catch (e) {
      return _jsonResponse(400, _errorBody(e.message));
    } catch (e) {
      return _jsonResponse(500, _errorBody(e.toString()));
    }
  }

  Future<StreamedResponse> createAudioPost(
      {required File audioFile,
      String? scheduledAt,
      String? taggedUser}) async {
    final client = Supabase.instance.client;
    final user = _currentUser();
    if (user == null) {
      return _streamedJsonResponse(401, _errorBody('Not authenticated'));
    }

    try {
      final mime = lookupMimeType(audioFile.path) ?? 'audio/m4a';
      final ext = audioFile.path.contains('.')
          ? audioFile.path.substring(audioFile.path.lastIndexOf('.'))
          : '';
      final storagePath =
          '${user.id}/audio/${DateTime.now().millisecondsSinceEpoch}$ext';

      await client.storage.from(_postMediaBucket).upload(
            storagePath,
            audioFile,
            fileOptions: FileOptions(upsert: true, contentType: mime),
          );
      final audioUrl =
          _ensurePublicUrl(client.storage.from(_postMediaBucket).getPublicUrl(storagePath));

      final username = await _currentUsername(user.id);
      final post = await client
          .from(_postsTable)
          .insert({
            'sender_id': user.id,
            'sender_username': username,
            'post_format': 'audio',
            'text_content': '',
            'audio_content': audioUrl,
            'is_reply': false,
            'scheduled_at': scheduledAt,
            'is_published': true,
          })
          .select()
          .single();

      await client.from(_mediaFilesTable).insert({
        'post_id': post['id'],
        'media_type': 'audio',
        'audio_file': audioUrl,
      });

      final fullPost = await client
          .from(_postsTable)
          .select('*, $_mediaFilesTable(*)')
          .eq('id', post['id'])
          .single();

      return _streamedJsonResponse(201, {'data': fullPost});
    } on PostgrestException catch (e) {
      return _streamedJsonResponse(400, _errorBody(e.message));
    } catch (e) {
      return _streamedJsonResponse(500, _errorBody(e.toString()));
    }
  }

  Future<StreamedResponse> createImagePost({
    required List<File> images,
    String? caption,
    String? scheduledAt,
    String? taggedUser,
  }) async {
    final client = Supabase.instance.client;
    final user = _currentUser();
    if (user == null) {
      return _streamedJsonResponse(401, _errorBody('Not authenticated'));
    }

    try {
      final username = await _currentUsername(user.id);
      final post = await client
          .from(_postsTable)
          .insert({
            'sender_id': user.id,
            'sender_username': username,
            'post_format': 'image',
            'text_content': caption ?? '',
            'is_reply': false,
            'scheduled_at': scheduledAt,
            'is_published': true,
          })
          .select()
          .single();

      for (final image in images) {
        if (!await image.exists()) continue;
        final mime = lookupMimeType(image.path) ?? 'image/jpeg';
        final ext = image.path.contains('.')
            ? image.path.substring(image.path.lastIndexOf('.'))
            : '';
        final storagePath =
            '${user.id}/images/${DateTime.now().millisecondsSinceEpoch}_${image.hashCode}$ext';

        await client.storage.from(_postMediaBucket).upload(
              storagePath,
              image,
              fileOptions: FileOptions(upsert: true, contentType: mime),
            );
        final url =
            _ensurePublicUrl(client.storage.from(_postMediaBucket).getPublicUrl(storagePath));

        await client.from(_mediaFilesTable).insert({
          'post_id': post['id'],
          'media_type': 'image',
          'image_file': url,
        });
      }

      final fullPost = await client
          .from(_postsTable)
          .select('*, $_mediaFilesTable(*)')
          .eq('id', post['id'])
          .single();
      return _streamedJsonResponse(201, {'data': fullPost});
    } on PostgrestException catch (e) {
      return _streamedJsonResponse(400, _errorBody(e.message));
    } catch (e) {
      return _streamedJsonResponse(500, _errorBody(e.toString()));
    }
  }
  // Future<StreamedResponse> createImagePost(
  //     {required List <File> image,
  //     String? caption,
  //     String? scheduledAt,
  //     String? taggedUser}) async {

  //   var request = MultipartRequest('POST', Uri.parse(ApiConstants.postBaseUrl));
  //   request.files.add(await MultipartFile.fromPath('image_files', image.path,
  //       filename: image.path.split('/').last));
  //   request.fields.addAll({
  //     "post_format": "image",
  //     "text_content": caption ?? '',
  //     "is_reply": "false",
  //     if (scheduledAt != null) "scheduled_at": scheduledAt,
  //     if (taggedUser != null) "tagged_user_ids": taggedUser
  //   });
  //   request.headers.addAll(ApiHeaders.aunthenticatedHeader);
  //   return await request.send();
  // }

  Future<StreamedResponse> createVideoPost(
      {required File videoFile,
      String? caption,
      String? scheduledAt,
      String? taggedUser}) async {
    final client = Supabase.instance.client;
    final user = _currentUser();
    if (user == null) {
      return _streamedJsonResponse(401, _errorBody('Not authenticated'));
    }

    try {
      final mime = lookupMimeType(videoFile.path) ?? 'video/mp4';
      final ext = videoFile.path.contains('.')
          ? videoFile.path.substring(videoFile.path.lastIndexOf('.'))
          : '';
      final storagePath =
          '${user.id}/videos/${DateTime.now().millisecondsSinceEpoch}$ext';

      await client.storage.from(_postMediaBucket).upload(
            storagePath,
            videoFile,
            fileOptions: FileOptions(upsert: true, contentType: mime),
          );
      final videoUrl =
          _ensurePublicUrl(client.storage.from(_postMediaBucket).getPublicUrl(storagePath));

      final username = await _currentUsername(user.id);
      final post = await client
          .from(_postsTable)
          .insert({
            'sender_id': user.id,
            'sender_username': username,
            'post_format': 'video',
            'text_content': caption ?? '',
            'video_content': videoUrl,
            'is_reply': false,
            'scheduled_at': scheduledAt,
            'is_published': true,
          })
          .select()
          .single();

      await client.from(_mediaFilesTable).insert({
        'post_id': post['id'],
        'media_type': 'video',
        'video_file': videoUrl,
      });

      final fullPost = await client
          .from(_postsTable)
          .select('*, $_mediaFilesTable(*)')
          .eq('id', post['id'])
          .single();

      return _streamedJsonResponse(201, {'data': fullPost});
    } on PostgrestException catch (e) {
      return _streamedJsonResponse(400, _errorBody(e.message));
    } catch (e) {
      return _streamedJsonResponse(500, _errorBody(e.toString()));
    }
  }

  Future<Response> deletePost({required String postId}) async {
    final client = Supabase.instance.client;
    final user = _currentUser();
    if (user == null) {
      return _jsonResponse(401, _errorBody('Not authenticated'));
    }

    try {
      await client
          .from(_postsTable)
          .delete()
          .eq('id', postId)
          .eq('sender_id', user.id);
      return _jsonResponse(200, {'message': 'Post deleted successfully', 'data': {}});
    } on PostgrestException catch (e) {
      return _jsonResponse(400, _errorBody(e.message));
    } catch (e) {
      return _jsonResponse(500, _errorBody(e.toString()));
    }
  }
}
