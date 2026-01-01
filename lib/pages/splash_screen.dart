import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:famity/utills/animated_route.dart';
import 'home_screen.dart';
import 'login_page.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleStartup();
    });
  }

  Future<void> _handleStartup() async {
    final supabase = Supabase.instance.client;

    try {
      // Keep splash visible briefly
      await Future.delayed(const Duration(seconds: 2));

      final prefs = await SharedPreferences.getInstance();
      final seenOnboarding = prefs.getBool("onboarding_seen") ?? false;

      await supabase.auth.refreshSession();
      final session = supabase.auth.currentSession;
      final user = supabase.auth.currentUser;

      // 🟣 First launch → Onboarding
      if (!seenOnboarding) {
        await prefs.setBool("onboarding_seen", true);
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          SlidePageRoute(page: const OnboardingScreen()),
        );
        return;
      }

      // 🟢 Verified session → Home
      if (session != null && user != null && user.emailConfirmedAt != null) {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          SlidePageRoute(page: const HomeScreen()),
        );
        return;
      }

      // 🔵 Otherwise → Login
      await supabase.auth.signOut();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        SlidePageRoute(page: const LoginPage()),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        SlidePageRoute(page: const LoginPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFEBD6FB), // solid color background
      body: Center(
        child: Image(
          image: AssetImage('assets/images/logo.png'),
          height: 200,
          width: 200,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
