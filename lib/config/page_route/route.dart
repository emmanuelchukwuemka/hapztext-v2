import 'package:haptext_api/exports.dart' hide ChatsHome, ChatScreen, ChatItem;
import 'package:haptext_api/main.dart';
import 'package:haptext_api/views/chat_ui/chats_home.dart';
import 'package:haptext_api/views/chat_ui/chat_screen.dart' hide ChatItem;
import 'package:haptext_api/models/chat_ui/chat_item.dart';
import 'package:haptext_api/models/searched_user_model.dart';
import 'package:haptext_api/views/Bottom_Nav/People/friend_profile_page.dart';
import 'package:haptext_api/views/Bottom_Nav/Post/comment_page.dart';
import 'package:haptext_api/views/Bottom_Nav/Post/upload_photo_post.dart';
import 'package:haptext_api/views/Bottom_Nav/Post/post_video_upload.dart';
import 'package:haptext_api/views/Bottom_Nav/Post/post_audio_upload_page.dart';
import 'package:haptext_api/views/Bottom_Nav/Post/text_write_up.dart';
import 'package:haptext_api/views/Bottom_Nav/Profile/edit_profile.dart';
import 'package:haptext_api/views/navigation.dart';
import 'package:haptext_api/views/screen/authentication/forget_password.dart';
import 'package:haptext_api/views/screen/authentication/reset_password.dart';
import 'package:haptext_api/views/screen/authentication/reset_password_otp.dart';
import 'package:haptext_api/views/screen/authentication/reset_password_success.dart';
import 'package:haptext_api/views/screen/chats/voice_call.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppRoute {
  static bool _isAuthenticated() {
    final client = Supabase.instance.client;
    final session = client.auth.currentSession;
    final user = client.auth.currentUser;
    if (session == null || user == null) return false;

    final expiresAt = session.expiresAt;
    if (expiresAt != null) {
      final expiry = DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000);
      if (DateTime.now().isAfter(expiry)) return false;
    }
    return true;
  }

  static final router = GoRouter(
    navigatorKey: navigatorKey,
    initialLocation: '/',
    redirect: (context, state) {
      final loggedIn = _isAuthenticated();
      final location = state.uri.path;

      final isPublicRoute = location == RouteName.splah.path ||
          location == RouteName.login.path ||
          location == RouteName.signUp.path ||
          location == RouteName.otpScreen.path ||
          location == RouteName.forgetPassword.path ||
          location == RouteName.resetPasswordPage.path ||
          location == RouteName.resetPasswordOtpPage.path ||
          location == RouteName.resetPaswordSuccess.path;

      if (!loggedIn && !isPublicRoute) {
        return RouteName.login.path;
      }

      final isAuthScreen = location == RouteName.login.path ||
          location == RouteName.signUp.path ||
          location == RouteName.splah.path;
      if (loggedIn && isAuthScreen) {
        return RouteName.bottomNav.path;
      }

      return null;
    },
    routes: [
      GoRoute(
          path: RouteName.splah.path,
          builder: (context, state) {
            return const SplashPage();
          }),
      GoRoute(
          path: RouteName.login.path,
          builder: (context, state) {
            return const SignIn();
          }),
      GoRoute(
          path: RouteName.signUp.path,
          builder: (context, state) {
            return const Register();
          }),
      GoRoute(
          path: RouteName.otpScreen.path,
          builder: (context, state) {
            return const OTPVerification();
          }),
      GoRoute(
          path: RouteName.bottomNav.path,
          builder: (context, state) {
            return const Navigation();
          }),
      GoRoute(
          path: RouteName.forgetPassword.path,
          builder: (context, state) {
            return const ForgetPasswordPage();
          }),
      GoRoute(
          path: RouteName.commentpage.path,
          builder: (context, state) {
            final ResultPostModel post = state.extra as ResultPostModel;
            return CommentScreen(post: post);
          }),
      GoRoute(
          path: RouteName.resetPasswordPage.path,
          builder: (context, state) {
            return const ResetPasswordPage();
          }),
      GoRoute(
          path: RouteName.resetPasswordOtpPage.path,
          builder: (context, state) {
            return const ResetPasswordOtpPage();
          }),
      GoRoute(
          path: RouteName.resetPaswordSuccess.path,
          builder: (context, state) {
            return const ResetPasswordSuccessPage();
          }),
      GoRoute(
          path: RouteName.createTextPostPage.path,
          builder: (context, state) {
            return const WriteText();
          }),
      GoRoute(
          path: RouteName.audioUploadPage.path,
          builder: (context, state) {
            return const PostAudioUploadPage();
          }),
      GoRoute(
          path: RouteName.voiceCallPage.path,
          builder: (context, state) {
            return const VoiceCallPage();
          }),
      GoRoute(
          path: RouteName.videoCallPage.path,
          builder: (context, state) {
            return const GroupCallPage();
          }),
      GoRoute(
          path: RouteName.createPhotoPost.path,
          builder: (context, state) {
            return const CreatePhotoPost();
          }),
      GoRoute(
          path: RouteName.confirmVideoUpload.path,
          builder: (context, state) {
            return const PostVideoUpload();
          }),
      GoRoute(
          path: RouteName.editProfile.path,
          builder: (context, state) {
            return const EditProfile();
          }),
      GoRoute(
          path: RouteName.chatPage.path,
          builder: (context, state) {
            return const ChatsHome();
          }),
      GoRoute(
          path: '/chat-screen',
          builder: (context, state) {
            final ChatItem chat = state.extra as ChatItem;
            return ChatScreen(chat: chat);
          }),
      GoRoute(
          path: RouteName.notificationPage.path,
          builder: (context, state) {
            return const Notifications();
          }),
      GoRoute(
          path: RouteName.friendsProfilePage.path,
          builder: (context, state) {
            final SearchedUserModel user = state.extra as SearchedUserModel;
            return FriendProfilePage(user: user);
          }),
      GoRoute(
          path: RouteName.innerPost.path,
          builder: (context, state) {
            final ResultPostModel post = state.extra as ResultPostModel;
            return CommentScreen(post: post);
          }),
    ],
  );
}
