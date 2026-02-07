import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Pages
import 'package:famity/pages/splash_screen.dart';
import 'package:famity/pages/login_page.dart';
import 'package:famity/pages/signup_page.dart';
import 'package:famity/pages/home_screen.dart';
import 'package:famity/pages/join_profile_setup_page.dart';
import 'package:famity/pages/onboarding_screen.dart';
import 'package:famity/pages/upload_image_page.dart';
import 'package:famity/pages/upload_video_page.dart';
import 'package:famity/pages/view_images_page.dart';
import 'package:famity/pages/view_videos_page.dart';
import 'package:famity/pages/view_members_page.dart';
import 'package:famity/pages/notifications_page.dart';
import 'package:famity/pages/upload_audio_page.dart';
import 'package:famity/pages/view_audios_page.dart';
import 'package:famity/constants.dart';
import 'package:famity/theme_provider.dart';

// Notifications setup
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

/// --------------------
/// MAIN
/// --------------------
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
  );

  final prefs = await SharedPreferences.getInstance();
  final isDark = prefs.getBool('isDarkMode') ?? false;

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(isDark),
      child: const MyApp(),
    ),
  );
}

/// --------------------
/// MyApp
/// --------------------
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    _setupNotifications();
  }

  Future<void> _setupNotifications() async {
    try {
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosInit = DarwinInitializationSettings();
      const initSettings =
          InitializationSettings(android: androidInit, iOS: iosInit);
      await flutterLocalNotificationsPlugin.initialize(initSettings);

      FirebaseMessaging.onMessage.listen((message) {
        if (message.notification != null) {
          const details = NotificationDetails(
            android: AndroidNotificationDetails(
              'high_importance',
              'High Importance Notifications',
              importance: Importance.high,
              priority: Priority.high,
            ),
          );
          flutterLocalNotificationsPlugin.show(
            message.notification.hashCode,
            message.notification?.title,
            message.notification?.body,
            details,
          );
        }
      });
    } catch (e) {
      debugPrint("⚠️ Notification setup error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: ThemeData.light(useMaterial3: true),
      darkTheme: ThemeData.dark(useMaterial3: true),
      themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: const SplashRouter(),

      // Routes
      routes: {
        '/login': (_) => const LoginPage(),
        '/signup': (_) => const SignupPage(),
        '/home': (_) => const HomeScreen(),
        '/upload-image': (_) => const UploadImagePage(),
        '/upload-video': (_) => const UploadVideoPage(),
        '/view-images': (_) => const ViewImagesPage(),
        '/view-videos': (_) => const ViewVideosPage(),
        '/view-members': (_) => const ViewMembersPage(),
        '/notifications': (_) => const NotificationsPage(),
        '/upload-audio': (_) => const UploadAudioPage(),
        '/view-audios': (_) => const ViewAudiosPage(),
      },

      // Handle Supabase deep links
      onGenerateRoute: (settings) {
        debugPrint("🔍 onGenerateRoute: ${settings.name}");
        if (settings.name?.contains('login-callback') == true ||
            settings.name?.contains('code=') == true) {
          return MaterialPageRoute(
            builder: (_) => FutureBuilder<Widget>(
              future: _handleDeepLink(settings.name!),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }
                return snapshot.data!;
              },
            ),
          );
        }

        if (settings.name == '/join-profile-setup') {
          final code = settings.arguments as String;
          return MaterialPageRoute(
            builder: (_) => JoinProfileSetupPage(familyCode: code),
          );
        }

        return MaterialPageRoute(
          builder: (_) => const Scaffold(
            body: Center(child: Text("404 - Page not found")),
          ),
        );
      },
    );
  }

  Future<Widget> _handleDeepLink(String url) async {
    final prefs = await SharedPreferences.getInstance();
    final client = Supabase.instance.client;
    final isJoinFlow = prefs.getBool('pending_join_verification') ?? false;
    final familyCode = prefs.getString('pending_join_family_code') ?? '';

    try {
      await client.auth.getSessionFromUrl(Uri.parse(url));
      await client.auth.refreshSession();
    } catch (e) {
      debugPrint("⚠️ Deep link restore failed: $e");
    }

    final user = client.auth.currentUser;

    if (isJoinFlow && familyCode.isNotEmpty) {
      return JoinProfileSetupPage(familyCode: familyCode);
    } else if (user != null && user.emailConfirmedAt != null) {
      return const HomeScreen();
    } else {
      return const SignupPage();
    }
  }
}

/// --------------------
/// SplashRouter (splash + routing)
/// --------------------
class SplashRouter extends StatefulWidget {
  const SplashRouter({super.key});

  @override
  State<SplashRouter> createState() => _SplashRouterState();
}

class _SplashRouterState extends State<SplashRouter> {
  bool _ready = false;
  Widget? _screen;

  @override
  void initState() {
    super.initState();
    _loadFlow();
  }

  Future<void> _loadFlow() async {
    await Future.delayed(const Duration(seconds: 2)); // always show splash 2s
    final supabase = Supabase.instance.client;
    final prefs = await SharedPreferences.getInstance();

    final seenOnboarding = prefs.getBool('onboarding_seen') ?? false;
    final isJoin = prefs.getBool('pending_join_verification') ?? false;
    final code = prefs.getString('pending_join_family_code') ?? '';

    try {
      await supabase.auth.refreshSession();
    } catch (_) {}

    final user = supabase.auth.currentUser;

    if (!seenOnboarding) {
      await prefs.setBool('onboarding_seen', true);
      _screen = const OnboardingScreen();
    } else if (isJoin && code.isNotEmpty) {
      _screen = JoinProfileSetupPage(familyCode: code);
    } else if (user != null && user.emailConfirmedAt != null) {
      _screen = const HomeScreen();
    } else {
      _screen = const LoginPage();
    }

    setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) return const SplashScreen();
    return _screen!;
  }
}
