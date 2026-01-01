import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_page.dart';
import 'profile_setup_page.dart';
import 'package:famity/utills/animated_route.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool isLoading = false;
  bool obscure = true;
  bool _dialogShown = false;

  @override
  void initState() {
    super.initState();
    debugPrint("🔵 SignupPage initState called");

    // Give Supabase time to process the deep link
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 800), () {
        debugPrint("🔵 Post frame callback - checking pending verification");
        _checkPendingVerification();
      });
    });
  }

  // Check if there's a pending email verification
  Future<void> _checkPendingVerification() async {
    if (_dialogShown) {
      debugPrint("⚠️ Dialog already shown, skipping");
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final isPendingVerification =
        prefs.getBool('pending_verification') ?? false;

    debugPrint("🔍 Pending verification status: $isPendingVerification");

    if (isPendingVerification) {
      // Wait a bit more for Supabase to fully process the auth state
      await Future.delayed(const Duration(milliseconds: 500));

      final user = Supabase.instance.client.auth.currentUser;

      debugPrint("🔍 Current user: ${user?.id}");
      debugPrint("🔍 Email confirmed: ${user?.emailConfirmedAt}");

      if (user != null && user.emailConfirmedAt == null) {
        // Still pending verification, show dialog
        debugPrint("✅ Showing verification dialog");
        _dialogShown = true;
        if (mounted) {
          _showVerificationDialog();
        }
      } else if (user != null && user.emailConfirmedAt != null) {
        // Already verified, clear the flag and proceed
        debugPrint("✅ User already verified, proceeding to profile setup");
        await prefs.setBool('pending_verification', false);
        _proceedToProfileSetup();
      } else {
        // No user yet, but pending verification - show dialog anyway
        debugPrint(
            "⚠️ No user session yet, but showing dialog for pending verification");
        _dialogShown = true;
        if (mounted) {
          _showVerificationDialog();
        }
      }
    } else {
      debugPrint("ℹ️ No pending verification");
    }
  }

  Future<void> _signUp() async {
    setState(() => isLoading = true);
    try {
      final email = emailController.text.trim();
      final password = passwordController.text;

      debugPrint("📧 Attempting signup with email: $email");

      final response = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
      );

      if (response.user != null) {
        debugPrint("✅ Signup successful, user ID: ${response.user!.id}");

        // Save that we're waiting for verification
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('pending_verification', true);
        debugPrint("💾 Saved pending_verification = true");

        _dialogShown = true;
        _showVerificationDialog();
      }
    } on AuthException catch (e) {
      debugPrint("❌ Signup error: ${e.message}");
      if (e.message.contains("User already registered")) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Email already exists. Try logging in.")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Signup Error: ${e.message}")),
        );
      }
    } finally {
      setState(() => isLoading = false);
    }
  }

  // Show dialog for email verification
  void _showVerificationDialog() {
    if (!mounted) {
      debugPrint("⚠️ Widget not mounted, cannot show dialog");
      return;
    }

    debugPrint("🎯 Showing verification dialog now");

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          title: const Text('Verify Your Email'),
          content: const Text(
              'A verification email has been sent. Please click the link in your email to verify.'),
          actions: [
            TextButton(
              onPressed: () {
                debugPrint("🔘 User clicked 'I Have Verified'");
                _checkVerificationStatus();
              },
              child: const Text('I Have Verified'),
            ),
          ],
        ),
      ),
    );
  }

  // Check if user verified email
  Future<void> _checkVerificationStatus() async {
    try {
      debugPrint("🔄 Checking verification status");

      // Give extra time for auth state to sync
      await Future.delayed(const Duration(milliseconds: 500));

      await Supabase.instance.client.auth.refreshSession();
      final user = Supabase.instance.client.auth.currentUser;

      debugPrint("🔍 After refresh - User: ${user?.id}");
      debugPrint("🔍 Email confirmed at: ${user?.emailConfirmedAt}");

      if (user != null && user.emailConfirmedAt != null) {
        debugPrint("✅ Email verified successfully!");

        // Clear the pending verification flag
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('pending_verification', false);
        debugPrint("💾 Cleared pending_verification flag");

        if (mounted) {
          Navigator.of(context).pop(); // Close verification dialog
          _proceedToProfileSetup();
        }
      } else {
        debugPrint("⚠️ Email not verified yet");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Email is not verified yet. Please check your email and click the verification link first.'),
              duration: Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("❌ Error checking verification status: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  // Proceed to profile setup after verification
  Future<void> _proceedToProfileSetup() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      debugPrint("⚠️ No user found for profile setup");
      return;
    }

    debugPrint("🚀 Proceeding to profile setup");

    // Get OneSignal Player ID (FCM token)
    final onesignalId = OneSignal.User.pushSubscription.id;
    debugPrint("🔔 OneSignal ID: $onesignalId");

    if (onesignalId != null) {
      await Supabase.instance.client.from('user').upsert({
        'user_id': user.id,
        'email': user.email,
        'onesignal_id': onesignalId,
      });
      debugPrint("💾 User data saved to database");
    }

    if (mounted) {
      Navigator.pushReplacement(
        context,
        SlidePageRoute(page: const ProfileSetupPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFE8D6FA),
              Color(0xFFD1E3FF),
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Glassy Back Button
              Positioned(
                top: 20,
                left: 20,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.5),
                          width: 1.5,
                        ),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back,
                            color: Color(0xFF6A4C93)),
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            SlidePageRoute(page: const LoginPage()),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),

              // Centered content
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Glassmorphism container for the signup form
                      ClipRRect(
                        borderRadius: BorderRadius.circular(25),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(28),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.25),
                              borderRadius: BorderRadius.circular(25),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.4),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                const Text(
                                  "SIGN UP",
                                  style: TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF6A4C93),
                                  ),
                                ),
                                const SizedBox(height: 25),
                                TextField(
                                  controller: emailController,
                                  style:
                                      const TextStyle(color: Color(0xFF333333)),
                                  decoration: InputDecoration(
                                    hintText: "Email",
                                    hintStyle:
                                        TextStyle(color: Colors.grey[600]),
                                    prefixIcon: const Icon(Icons.email,
                                        color: Color(0xFF6A4C93)),
                                    filled: true,
                                    fillColor: Colors.white.withOpacity(0.7),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(20),
                                      borderSide: BorderSide.none,
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                        vertical: 16, horizontal: 20),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                TextField(
                                  controller: passwordController,
                                  obscureText: obscure,
                                  style:
                                      const TextStyle(color: Color(0xFF333333)),
                                  decoration: InputDecoration(
                                    hintText: "Password",
                                    hintStyle:
                                        TextStyle(color: Colors.grey[600]),
                                    prefixIcon: const Icon(Icons.lock,
                                        color: Color(0xFF6A4C93)),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        obscure
                                            ? Icons.visibility_off
                                            : Icons.visibility,
                                        color: const Color(0xFF6A4C93),
                                      ),
                                      onPressed: () =>
                                          setState(() => obscure = !obscure),
                                    ),
                                    filled: true,
                                    fillColor: Colors.white.withOpacity(0.7),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(20),
                                      borderSide: BorderSide.none,
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                        vertical: 16, horizontal: 20),
                                  ),
                                ),
                                const SizedBox(height: 25),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: isLoading ? null : _signUp,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF6A4C93),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 16),
                                      elevation: 5,
                                      shadowColor:
                                          Colors.purple.withOpacity(0.4),
                                    ),
                                    child: isLoading
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Text(
                                            "Sign Up",
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
