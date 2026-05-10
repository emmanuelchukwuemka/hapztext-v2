// ignore_for_file: use_build_context_synchronously

import 'package:haptext_api/bloc/auth/cubit/auth_cubit.dart';
import 'package:haptext_api/exports.dart';
import 'package:haptext_api/models/user_infor_model.dart';
import 'package:haptext_api/utils/session_manager.dart';
import 'package:provider/provider.dart';
import 'package:haptext_api/services/chat_ui/auth_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(seconds: 3));
      final client = Supabase.instance.client;
      final session = client.auth.currentSession;
      final supabaseUser = client.auth.currentUser;

      final expiresAt = session?.expiresAt;
      final isExpired = expiresAt != null
          ? DateTime.now().isAfter(
              DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000),
            )
          : false;

      if (session == null || supabaseUser == null || isExpired) {
        await SessionManager.deleteUser();
        await SessionManager().deleteToken();
        await context.read<AuthProvider>().logout();
        context.go(RouteName.login.path);
        return;
      }

      final effectiveUser = UserInfoModel(
        id: supabaseUser.id,
        email: supabaseUser.email,
        username: (supabaseUser.userMetadata?['username'] as String?),
        tokens: Tokens(auth: session.accessToken),
      );

      await SessionManager.storeUser(effectiveUser);
      await SessionManager().storeToken(session.accessToken);
      context.read<AuthCubit>().fetchLocalUser();
      context
          .read<AuthProvider>()
          .setTokenFromSession(session.accessToken, supabaseUser.id);
      context.go(RouteName.bottomNav.path);
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Scaffold(
      body: Center(
        child: Image.asset("assets/images/hapz_logo.png",
            height: size.height * 0.1, width: size.height * 0.1),
      ),
    );
  }
}
