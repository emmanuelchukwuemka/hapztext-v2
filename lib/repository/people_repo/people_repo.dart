import 'dart:convert';
import 'package:haptext_api/network/export_network.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PeopleRepo {
  static const String _profilesTable = 'profiles';
  static const String _followsTable = 'user_follows';

  Map<String, dynamic> _errorBody(String message) {
    return {
      'errors': {'detail': message}
    };
  }

  Response _jsonResponse(int statusCode, Map<String, dynamic> json) {
    return Response(jsonEncode(json), statusCode,
        headers: {'content-type': 'application/json; charset=utf-8'});
  }

  User? _currentUser() => Supabase.instance.client.auth.currentUser;

  Future<int> _countFollowers(String userId) async {
    final res = await Supabase.instance.client
        .from(_followsTable)
        .select('follower_id')
        .eq('following_id', userId);
    return res.length;
  }

  Future<int> _countFollowings(String userId) async {
    final res = await Supabase.instance.client
        .from(_followsTable)
        .select('following_id')
        .eq('follower_id', userId);
    return res.length;
  }

  Future<Response> fetchFriends({page}) async {
    final user = _currentUser();
    if (user == null) {
      return _jsonResponse(401, _errorBody('Not authenticated'));
    }

    try {
      final followingRows = await Supabase.instance.client
          .from(_followsTable)
          .select('following_id')
          .eq('follower_id', user.id);
      final followerRows = await Supabase.instance.client
          .from(_followsTable)
          .select('follower_id')
          .eq('following_id', user.id);

      final followingIds =
          followingRows.map((e) => e['following_id'].toString()).toSet();
      final followerIds =
          followerRows.map((e) => e['follower_id'].toString()).toSet();
      final friendIds = followingIds.intersection(followerIds).toList();

      if (friendIds.isEmpty) {
        return _jsonResponse(200, {
          'data': {'friends': []}
        });
      }

      final friends = await Supabase.instance.client
          .from(_profilesTable)
          .select()
          .inFilter('user_id', friendIds)
          .order('updated_at', ascending: false);

      return _jsonResponse(200, {
        'data': {'friends': friends}
      });
    } on PostgrestException catch (e) {
      return _jsonResponse(400, _errorBody(e.message));
    } catch (e) {
      return _jsonResponse(500, _errorBody(e.toString()));
    }
  }

  Future<Response> getUsers({required String userId}) async {
    final user = _currentUser();
    if (user == null) {
      return _jsonResponse(401, _errorBody('Not authenticated'));
    }
    try {
      if (userId.trim().isEmpty) {
        return _jsonResponse(400, _errorBody('Invalid user id'));
      }

      final profile = await Supabase.instance.client
          .from(_profilesTable)
          .select()
          .eq('user_id', userId)
          .limit(1)
          .maybeSingle();

      return _jsonResponse(200, {
        'data': profile ?? {'user_id': userId}
      });
    } on PostgrestException catch (e) {
      return _jsonResponse(400, _errorBody(e.message));
    } catch (e) {
      return _jsonResponse(500, _errorBody(e.toString()));
    }
  }

  Future<Response> searchFriends({query}) async {
    return searchUsers(query: query, page: 1);
  }

  Future<Response> searchUsers({query, page}) async {
    final user = _currentUser();
    if (user == null) {
      return _jsonResponse(401, _errorBody('Not authenticated'));
    }
    final q = query?.toString().trim() ?? '';
    if (q.isEmpty) {
      return _jsonResponse(200, {
        'data': {'users': []}
      });
    }

    try {
      const pageSize = 20;
      final pageInt = int.tryParse(page?.toString() ?? '1') ?? 1;
      final from = (pageInt - 1) * pageSize;
      final to = from + pageSize - 1;

      final rows = await Supabase.instance.client
          .from(_profilesTable)
          .select()
          .ilike('username', '%$q%')
          .range(from, to);

      final users = <Map<String, dynamic>>[];
      for (final row in rows) {
        final userId = row['user_id']?.toString();
        if (userId == null) continue;
        final followerCount = await _countFollowers(userId);
        final followingCount = await _countFollowings(userId);

        users.add({
          'id': userId,
          'username': row['username'],
          'email': row['email'],
          'profile_picture': row['profile_picture'],
          'follower_count': followerCount,
          'following_count': followingCount,
          'mention_count': row['mention_count'] ?? 0,
          'is_email_verified': row['is_email_verified'] ?? true,
          'created_at': row['created_at'],
          'updated_at': row['updated_at'],
        });
      }

      return _jsonResponse(200, {
        'data': {'users': users}
      });
    } on PostgrestException catch (e) {
      return _jsonResponse(400, _errorBody(e.message));
    } catch (e) {
      return _jsonResponse(500, _errorBody(e.toString()));
    }
  }

  Future<Response> fetchFollowers({page, userId}) async {
    final current = _currentUser();
    if (current == null) {
      return _jsonResponse(401, _errorBody('Not authenticated'));
    }
    try {
      const pageSize = 20;
      final pageInt = int.tryParse(page?.toString() ?? '1') ?? 1;
      final from = (pageInt - 1) * pageSize;
      final to = from + pageSize - 1;

      final rows = await Supabase.instance.client
          .from(_followsTable)
          .select('follower_id')
          .eq('following_id', userId.toString())
          .range(from, to);

      final ids = rows.map((e) => e['follower_id'].toString()).toList();
      if (ids.isEmpty) {
        return _jsonResponse(200, {
          'data': {'followers': []}
        });
      }

      final followers = await Supabase.instance.client
          .from(_profilesTable)
          .select()
          .inFilter('user_id', ids);
      return _jsonResponse(200, {
        'data': {'followers': followers}
      });
    } on PostgrestException catch (e) {
      return _jsonResponse(400, _errorBody(e.message));
    } catch (e) {
      return _jsonResponse(500, _errorBody(e.toString()));
    }
  }

  Future<Response> fetchFollowings({page, userId}) async {
    final current = _currentUser();
    if (current == null) {
      return _jsonResponse(401, _errorBody('Not authenticated'));
    }
    try {
      const pageSize = 20;
      final pageInt = int.tryParse(page?.toString() ?? '1') ?? 1;
      final from = (pageInt - 1) * pageSize;
      final to = from + pageSize - 1;

      final rows = await Supabase.instance.client
          .from(_followsTable)
          .select('following_id')
          .eq('follower_id', userId.toString())
          .range(from, to);

      final ids = rows.map((e) => e['following_id'].toString()).toList();
      if (ids.isEmpty) {
        return _jsonResponse(200, {
          'data': {'followings': []}
        });
      }

      final followings = await Supabase.instance.client
          .from(_profilesTable)
          .select()
          .inFilter('user_id', ids);
      return _jsonResponse(200, {
        'data': {'followings': followings}
      });
    } on PostgrestException catch (e) {
      return _jsonResponse(400, _errorBody(e.message));
    } catch (e) {
      return _jsonResponse(500, _errorBody(e.toString()));
    }
  }

  Future<Response> fetchProfiles({page, pageSize}) async {
    final user = _currentUser();
    if (user == null) {
      return _jsonResponse(401, _errorBody('Not authenticated'));
    }
    try {
      final pageInt = int.tryParse(page?.toString() ?? '1') ?? 1;
      final sizeInt = int.tryParse(pageSize?.toString() ?? '20') ?? 20;
      final from = (pageInt - 1) * sizeInt;
      final to = from + sizeInt - 1;

      final profiles = await Supabase.instance.client
          .from(_profilesTable)
          .select()
          .order('updated_at', ascending: false)
          .range(from, to);

      return _jsonResponse(200, {
        'data': {
          'result': profiles,
          'previous_profiles_data': null,
          'next_profiles_data': null,
        }
      });
    } on PostgrestException catch (e) {
      return _jsonResponse(400, _errorBody(e.message));
    } catch (e) {
      return _jsonResponse(500, _errorBody(e.toString()));
    }
  }

  Future<Response> followUser({userId}) async {
    final user = _currentUser();
    if (user == null) {
      return _jsonResponse(401, _errorBody('Not authenticated'));
    }
    final targetId = userId?.toString();
    if (targetId == null || targetId.isEmpty) {
      return _jsonResponse(400, _errorBody('Invalid userId'));
    }
    if (targetId == user.id) {
      return _jsonResponse(400, _errorBody('You cannot follow yourself'));
    }

    try {
      await Supabase.instance.client.from(_followsTable).upsert({
        'follower_id': user.id,
        'following_id': targetId,
      }, onConflict: 'follower_id,following_id');
      return _jsonResponse(201, {'message': 'Now following', 'data': {}});
    } on PostgrestException catch (e) {
      return _jsonResponse(400, _errorBody(e.message));
    } catch (e) {
      return _jsonResponse(500, _errorBody(e.toString()));
    }
  }

  Future<Response> unfollowUser({userId}) async {
    final user = _currentUser();
    if (user == null) {
      return _jsonResponse(401, _errorBody('Not authenticated'));
    }
    final targetId = userId?.toString();
    if (targetId == null || targetId.isEmpty) {
      return _jsonResponse(400, _errorBody('Invalid userId'));
    }

    try {
      await Supabase.instance.client
          .from(_followsTable)
          .delete()
          .eq('follower_id', user.id)
          .eq('following_id', targetId);
      return _jsonResponse(200, {'message': 'Unfollowed', 'data': {}});
    } on PostgrestException catch (e) {
      return _jsonResponse(400, _errorBody(e.message));
    } catch (e) {
      return _jsonResponse(500, _errorBody(e.toString()));
    }
  }
}
