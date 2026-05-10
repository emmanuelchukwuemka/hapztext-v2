import 'package:haptext_api/bloc/auth/cubit/auth_cubit.dart';
import 'package:haptext_api/bloc/home/cubit/home_cubit.dart';
import 'package:haptext_api/bloc/people/cubit/people_cubit.dart';
import 'package:haptext_api/bloc/profile/cubit/profile_cubit.dart';
import 'package:haptext_api/config/page_route/route.dart';
import 'package:haptext_api/exports.dart';
import 'package:haptext_api/repository/auth_repo/auth_repo.dart';
import 'package:haptext_api/repository/home_repo/home_repo.dart';
import 'package:haptext_api/repository/people_repo/people_repo.dart';
import 'package:haptext_api/repository/profile_repo/profile_repo.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'common/theme/dark_theme.dart';
import 'common/theme/light_theme.dart';
import 'package:provider/provider.dart';
import 'package:haptext_api/services/chat_ui/auth_provider.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  var supabaseUrl = const String.fromEnvironment('SUPABASE_URL');
  var supabaseAnonKey = const String.fromEnvironment('SUPABASE_ANON_KEY');
  supabaseUrl =
      supabaseUrl.isNotEmpty ? supabaseUrl : (dotenv.env['SUPABASE_URL'] ?? '');
  supabaseAnonKey = supabaseAnonKey.isNotEmpty
      ? supabaseAnonKey
      : (dotenv.env['SUPABASE_ANON_KEY'] ?? '');
  if (supabaseUrl.isEmpty) {
    supabaseUrl = dotenv.env['NEXT_PUBLIC_SUPABASE_URL'] ?? '';
  }
  if (supabaseAnonKey.isEmpty) {
    supabaseAnonKey = dotenv.env['NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY'] ?? '';
  }

  if (supabaseUrl.endsWith('/rest/v1/')) {
    supabaseUrl =
        supabaseUrl.substring(0, supabaseUrl.length - '/rest/v1/'.length);
  } else if (supabaseUrl.endsWith('/rest/v1')) {
    supabaseUrl =
        supabaseUrl.substring(0, supabaseUrl.length - '/rest/v1'.length);
  }
  if (supabaseUrl.endsWith('/')) {
    supabaseUrl = supabaseUrl.substring(0, supabaseUrl.length - 1);
  }

  if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
    throw Exception(
        'Missing SUPABASE_URL / SUPABASE_ANON_KEY. Add them to .env or pass with --dart-define.');
  }
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
        providers: [
          BlocProvider(create: (context) => AuthCubit(AuthRepo())),
          BlocProvider(create: (context) => HomeCubit(HomeRepo())),
          BlocProvider(create: (context) => ProfileCubit(ProfileRepo())),
          BlocProvider(create: (context) => PeopleCubit(PeopleRepo())),
        ],
        child: MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => AuthProvider()),
            ],
            child: ScreenUtilInit(
                designSize: MediaQuery.sizeOf(context),
                minTextAdapt: true,
                splitScreenMode: true,
                child: MaterialApp.router(
                    routerConfig: AppRoute.router,
                    debugShowCheckedModeBanner: false,
                    title: 'Hapztext',
                    theme: lightTheme(),
                    darkTheme: darkTheme(),
                    themeMode: ThemeMode.dark,
                    builder: (context, child) {
                      return MediaQuery(
                          data: MediaQuery.of(context).copyWith(
                              textScaler: const TextScaler.linear(1.0)),
                          child: child!);
                    }))));
  }
}
