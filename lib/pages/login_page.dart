import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart'; // For ImageFilter
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'signup_page.dart';
import 'join_family_page.dart';
import 'home_screen.dart';
import 'profile_setup_page.dart';
import 'package:famity/utills/animated_route.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool isLoading = false;

  // ✅ Core function to check profile and navigate
  Future<void> _handlePostLogin(User user) async {
    final supabase = Supabase.instance.client;

    try {
      // Query the correct table and column
      final profile = await supabase
          .from('user') // Table name in Supabase
          .select()
          .eq('user_id', user.id) // Column storing auth ID
          .maybeSingle();

      // Upsert OneSignal ID
      final onesignalId = OneSignal.User.pushSubscription.id;
      if (onesignalId != null) {
        await supabase.from('user').upsert({
          'user_id': user.id,
          'email': user.email,
          'onesignal_id': onesignalId,
        });
      }

      // Navigate based on profile existence
      if (profile != null) {
        Navigator.pushReplacement(
          context,
          SlidePageRoute(page: const HomeScreen()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          SlidePageRoute(page: const ProfileSetupPage()),
        );
      }
    } catch (e) {
      print("Error checking user profile: $e");
      // fallback
      Navigator.pushReplacement(
        context,
        SlidePageRoute(page: const ProfileSetupPage()),
      );
    }
  }

  // ✅ Email/password login
  Future<void> _loginUser() async {
    final email = emailController.text.trim();
    final password = passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showError("Please enter both email and password.");
      return;
    }

    setState(() => isLoading = true);

    try {
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final user = response.user;

      if (user != null) {
        if (user.emailConfirmedAt != null) {
          await _handlePostLogin(user); // ✅ Correct navigation
        } else {
          _showError("Please verify your email before logging in.");
        }
      } else {
        _showError("Invalid login. Please try again.");
      }
    } catch (e) {
      _showError("Login failed: ${e.toString()}");
    } finally {
      setState(() => isLoading = false);
    }
  }

  // ✅ Google login
  Future<void> _signInWithGoogle() async {
    try {
      final supabase = Supabase.instance.client;

      await supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: "famity://login-callback",
      );

      // Listen for auth state changes
      supabase.auth.onAuthStateChange.listen((data) async {
        final user = data.session?.user;
        if (user != null) {
          await _handlePostLogin(user); // ✅ Correct navigation
        }
      });
    } catch (e) {
      _showError("Google Sign-In failed: ${e.toString()}");
    }
  }

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Error"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          )
        ],
      ),
    );
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
              Color(0xFFE8D6FA), // Your homepage color
              Color(0xFFD1E3FF), // Your homepage color
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Glassmorphism container for the login form
                  ClipRRect(
                    borderRadius: BorderRadius.circular(25),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                      child: Container(
                        width: double.infinity, // Full width
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
                              "LOGIN",
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF6A4C93),
                              ),
                            ),
                            const SizedBox(height: 25),
                            TextField(
                              controller: emailController,
                              style: const TextStyle(color: Color(0xFF333333)),
                              decoration: InputDecoration(
                                hintText: "Email",
                                hintStyle: TextStyle(color: Colors.grey[600]),
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
                              obscureText: _obscurePassword,
                              style: const TextStyle(color: Color(0xFF333333)),
                              decoration: InputDecoration(
                                hintText: "Password",
                                hintStyle: TextStyle(color: Colors.grey[600]),
                                prefixIcon: const Icon(Icons.lock,
                                    color: Color(0xFF6A4C93)),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility
                                        : Icons.visibility_off,
                                    color: const Color(0xFF6A4C93),
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
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
                            const SizedBox(height: 15),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () {
                                  // TODO: Add Forgot Password logic
                                },
                                child: const Text(
                                  "Forgot Password?",
                                  style: TextStyle(
                                    color: Color(0xFF6A4C93),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 15),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: isLoading ? null : _loginUser,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF6A4C93),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  elevation: 5,
                                  shadowColor: Colors.purple.withOpacity(0.4),
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
                                        "Login",
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 25),
                            const Text(
                              "Or login with",
                              style: TextStyle(
                                color: Color(0xFF6A4C93),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 15),
                            IconButton(
                              onPressed: _signInWithGoogle,
                              icon: Image.asset(
                                'assets/images/google.png',
                                width: 36,
                                height: 36,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 25),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "Don't have an Account? ",
                        style: TextStyle(
                          color: Color(0xFF6A4C93),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            SlidePageRoute(page: const SignupPage()),
                          );
                        },
                        child: const Text(
                          "Register",
                          style: TextStyle(
                            color: Color(0xFF6A4C93),
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        SlidePageRoute(page: const JoinFamilyPage()),
                      );
                    },
                    child: const Text(
                      "Join Family",
                      style: TextStyle(
                        color: Color(0xFF6A4C93),
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
