import 'package:flutter/foundation.dart';

String bearerToken = '';

class ApiConstants {
  static const String baseUrl = kDebugMode
      ? 'http://72.62.4.119:8005/api/v1'
      : "http://72.62.4.119:8005/api/v1";

  static const String authBaseUrl = "$baseUrl/authentication";
  static const String login = "$authBaseUrl/login/";
  static const String register = "$authBaseUrl/register/";
  static const String requestPasswordReset = "$authBaseUrl/password-reset/request/";
  static const String verifyPasswordReset = "$authBaseUrl/password-reset/";
  static const String verifyEmailUrl = "$authBaseUrl/verify-email/";
  static const String verifyEmailRequestUrl =
      "$authBaseUrl/verify-email/request/";
  static const String userProfileBaseUrl = "$baseUrl/users";
  static String followUserUrl({userId}) =>
      "$userProfileBaseUrl/follow-request/$userId/";
  static String get createProfileUrl => "$userProfileBaseUrl/profile/create/";
  static String get updateProfileUrl => "$userProfileBaseUrl/profile/update/";
  static String aceeptOrDeclineFollowUrl({requestId}) =>
      "$userProfileBaseUrl/follow-request/handle/$requestId/";
  // TODO: Backend returned 404 for this URL pattern. Verify correct endpoint with backend team.
  static String pendingFollowRequestUrl({page}) =>
      "$userProfileBaseUrl/follow-requests/pending/$page/20/";
  static String getFriendsUrl({page}) =>
      '$baseUrl/users/friends/$page/10/';

  static String getProfilesListUrl({page, pageSize = 10}) =>
      '$baseUrl/users/profiles/$page/$pageSize/';

  static String getUserByIdUrl({userId}) =>
      "$userProfileBaseUrl/profile/$userId/";
  static String searchFriendsUrl({query}) =>
      "$userProfileBaseUrl/search?query=$query&limit=20&offset=1";
  static String usersSearchUrl({query, page}) =>
      "$userProfileBaseUrl/search?query=$query&limit=20&offset=$page";
  static String getFollowersUrl({userId, page}) =>
      "$userProfileBaseUrl/followers/$userId/$page/20/";
  static String getFollowingsUrl({userId, page}) =>
      "$userProfileBaseUrl/followings/$userId/$page/20/";
  static const String postBaseUrl = "$baseUrl/posts/";
  static String postCommentUrl({page, postId}) =>
      "$baseUrl/posts/$postId/replies/$page/30";
  static String fetchNotificationUrl({page}) =>
      "$baseUrl/notifications/$page/20/";
  static String sharePostUrl({postId}) => "$postBaseUrl$postId/share/";
  static String reactPostUrl({postId}) => "$postBaseUrl$postId/react/";
  static String fetchPostUrl({required page, required pageSize, String? feedType, String? query}) =>
      "${postBaseUrl}list/$page/$pageSize/${feedType != null ? '?feed_type=$feedType' : ''}${query != null ? '${feedType != null ? '&' : '?'}query=$query' : ''}";
  static String fetchUserPostUrl(
          {required page, required userId, required pageSize}) =>
      "${postBaseUrl}user/$userId/$page/$pageSize/";
}

class ApiHeaders {
  static Map<String, String> get unaunthenticatedHeader =>
      {'Content-Type': 'application/json', 'Accept': 'application/json'};

  static Map<String, String> get aunthenticatedHeader => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        "Authorization": "Bearer $bearerToken"
      };
}
