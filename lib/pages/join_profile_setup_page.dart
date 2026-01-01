import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'home_screen.dart';
import 'login_page.dart';

class JoinProfileSetupPage extends StatefulWidget {
  final String familyCode;

  const JoinProfileSetupPage({super.key, required this.familyCode});

  @override
  State<JoinProfileSetupPage> createState() => _JoinProfileSetupPageState();
}

class _JoinProfileSetupPageState extends State<JoinProfileSetupPage> {
  final supabase = Supabase.instance.client;
  final nameController = TextEditingController();
  final dobController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  File? profileImage;
  bool isLoading = false;
  bool emailVerificationSent = false;
  bool isEmailVerified = false;
  bool obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _restoreSavedFields();
    _checkExistingAuth();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPendingVerification();
    });
  }

  Future<void> _restoreSavedFields() async {
    final prefs = await SharedPreferences.getInstance();
    nameController.text = prefs.getString('join_name') ?? '';
    dobController.text = prefs.getString('join_dob') ?? '';
    emailController.text = prefs.getString('join_email') ?? '';
    passwordController.text = prefs.getString('join_password') ?? '';
    final imagePath = prefs.getString('join_profile_image');
    if (imagePath != null && File(imagePath).existsSync()) {
      setState(() => profileImage = File(imagePath));
    }
  }

  Future<void> _saveJoinFields() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('join_name', nameController.text.trim());
    await prefs.setString('join_dob', dobController.text.trim());
    await prefs.setString('join_email', emailController.text.trim());
    await prefs.setString('join_password', passwordController.text.trim());
    if (profileImage != null) {
      await prefs.setString('join_profile_image', profileImage!.path);
    }
  }

  Future<void> _checkPendingVerification() async {
    final prefs = await SharedPreferences.getInstance();
    final pending = prefs.getBool('pending_join_verification') ?? false;

    if (pending) {
      await Future.delayed(const Duration(milliseconds: 1000));
      final user = supabase.auth.currentUser;

      if (user != null && user.emailConfirmedAt == null) {
        setState(() {
          emailVerificationSent = true;
        });
      } else if (user != null && user.emailConfirmedAt != null) {
        await prefs.setBool('pending_join_verification', false);
        setState(() {
          isEmailVerified = true;
          emailVerificationSent = false;
          emailController.text = user.email ?? '';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ Email verified successfully!")),
        );
      }
    }
  }

  Future<void> _checkExistingAuth() async {
    final user = supabase.auth.currentUser;
    if (user != null && user.emailConfirmedAt != null) {
      setState(() {
        isEmailVerified = true;
        emailController.text = user.email ?? '';
      });
    }
  }

  Future<void> pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => profileImage = File(picked.path));
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('join_profile_image', picked.path);
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      dobController.text = DateFormat('yyyy-MM-dd').format(picked);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('join_dob', dobController.text);
    }
  }

  /// ✅ Final fixed version of sendVerificationEmail()
  Future<void> sendVerificationEmail() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter email and password")),
      );
      return;
    }

    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Password must be at least 6 characters"),
      ));
      return;
    }

    setState(() => isLoading = true);

    try {
      await _saveJoinFields();

      // ✅ STEP 1: Check if email already exists in Supabase `user` table
      final existing = await supabase
          .from('user')
          .select('email')
          .eq('email', email)
          .maybeSingle();

      if (existing != null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              "⚠️ This email is already registered. Please sign in instead."),
        ));
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const LoginPage()),
          );
        }
        return;
      }

      // ✅ STEP 2: Proceed with Supabase signup
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('pending_join_verification', true);
      await prefs.setString('pending_join_family_code', widget.familyCode);

      final response = await supabase.auth.signUp(
        email: email,
        password: password,
        data: {'family_code': widget.familyCode},
      );

      if (response.user == null) {
        throw Exception("Signup failed");
      }

      setState(() => emailVerificationSent = true);

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("✅ Verification email sent! Check your inbox."),
      ));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("❌ Error: $e")));
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> checkEmailVerification() async {
    setState(() => isLoading = true);
    try {
      await supabase.auth.refreshSession();
      final user = supabase.auth.currentUser;
      if (user != null && user.emailConfirmedAt != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('pending_join_verification', false);
        setState(() {
          isEmailVerified = true;
          emailVerificationSent = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ Email verified successfully!")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text("⚠️ Email not verified yet. Please check your email."),
          ),
        );
      }
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<String?> _getFamilyNameFromCode(String code) async {
    try {
      final response = await supabase
          .from('user')
          .select('family_name')
          .eq('family_code', code)
          .limit(1)
          .maybeSingle();
      return response?['family_name'] as String?;
    } catch (_) {
      return null;
    }
  }

  Future<void> joinFamily() async {
    if (nameController.text.trim().isEmpty ||
        dobController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all fields")),
      );
      return;
    }

    setState(() => isLoading = true);
    try {
      await supabase.auth.refreshSession();
      final user = supabase.auth.currentUser;
      if (user == null || user.emailConfirmedAt == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("⚠️ Please verify your email first")),
        );
        setState(() => isLoading = false);
        return;
      }

      final familyName = await _getFamilyNameFromCode(widget.familyCode);
      if (familyName == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("❌ Family not found. Please check the code.")),
        );
        setState(() => isLoading = false);
        return;
      }

      String profileImageUrl = '';
      if (profileImage != null) {
        final ext = profileImage!.path.split('.').last;
        final path = 'avatars/${user.id}.$ext';
        await supabase.storage.from('avatars').upload(path, profileImage!);
        profileImageUrl = supabase.storage.from('avatars').getPublicUrl(path);
      }

      await supabase.from('user').upsert({
        'user_id': user.id,
        'name': nameController.text.trim(),
        'dob': dobController.text.trim(),
        'email': user.email,
        'family_name': familyName,
        'family_code': widget.familyCode,
        'profile_image_url': profileImageUrl,
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("❌ Error: $e")));
    } finally {
      setState(() => isLoading = false);
    }
  }

  // --- UI ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFE8D6FA), Color(0xFFD1E3FF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Positioned(top: 20, left: 20, child: _glassyBackButton()),
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 100, 24, 40),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 450),
                    child: IntrinsicHeight(child: _buildProfileForm()),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _glassyBackButton() => ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(20),
              border:
                  Border.all(color: Colors.white.withOpacity(0.5), width: 1.5),
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Color(0xFF6A4C93)),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
      );

  Widget _buildProfileForm() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(25),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.25),
            borderRadius: BorderRadius.circular(25),
            border:
                Border.all(color: Colors.white.withOpacity(0.4), width: 1.5),
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
              const Text("JOIN FAMILY PROFILE",
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF6A4C93))),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: pickImage,
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.white.withOpacity(0.3),
                  backgroundImage:
                      profileImage != null ? FileImage(profileImage!) : null,
                  child: profileImage == null
                      ? const Icon(Icons.camera_alt,
                          color: Color(0xFF6A4C93), size: 40)
                      : null,
                ),
              ),
              const SizedBox(height: 20),
              _input("Full Name", nameController),
              const SizedBox(height: 16),
              _dateInput(),
              const SizedBox(height: 16),
              if (!isEmailVerified) ...[
                _input("Email", emailController,
                    keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 16),
                _passwordInput(),
                const SizedBox(height: 20),
                if (emailVerificationSent) ...[
                  const Text("📧 Check your email for verification link",
                      style: TextStyle(
                          color: Colors.green, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  _button("Check Verification", checkEmailVerification,
                      color: const Color(0xFF8A6FBF)),
                  const SizedBox(height: 10),
                  TextButton(
                      onPressed: sendVerificationEmail,
                      child: const Text("Resend Verification Email")),
                ] else
                  _button("Send Verification Email", sendVerificationEmail),
              ] else ...[
                const Text("✅ Email Verified Successfully",
                    style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
                const SizedBox(height: 20),
              ],
              _button("Join Family", joinFamily,
                  color: const Color(0xFF6A4C93),
                  enabled: isEmailVerified && !isLoading),
            ],
          ),
        ),
      ),
    );
  }

  Widget _input(String label, TextEditingController controller,
      {TextInputType keyboardType = TextInputType.text}) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: Color(0xFF333333)),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF6A4C93)),
        filled: true,
        fillColor: Colors.white.withOpacity(0.7),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      ),
    );
  }

  Widget _passwordInput() {
    return TextField(
      controller: passwordController,
      obscureText: obscurePassword,
      style: const TextStyle(color: Color(0xFF333333)),
      decoration: InputDecoration(
        labelText: 'Password (min. 6 characters)',
        labelStyle: const TextStyle(color: Color(0xFF6A4C93)),
        filled: true,
        fillColor: Colors.white.withOpacity(0.7),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        suffixIcon: IconButton(
          icon: Icon(obscurePassword ? Icons.visibility_off : Icons.visibility,
              color: const Color(0xFF6A4C93)),
          onPressed: () => setState(() => obscurePassword = !obscurePassword),
        ),
      ),
    );
  }

  Widget _dateInput() {
    return TextField(
      controller: dobController,
      readOnly: true,
      onTap: _selectDate,
      style: const TextStyle(color: Color(0xFF333333)),
      decoration: InputDecoration(
        labelText: 'Date of Birth',
        labelStyle: const TextStyle(color: Color(0xFF6A4C93)),
        filled: true,
        fillColor: Colors.white.withOpacity(0.7),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        suffixIcon: const Icon(Icons.calendar_today, color: Color(0xFF6A4C93)),
      ),
    );
  }

  Widget _button(String text, Function() onPressed,
      {Color color = const Color(0xFF6A4C93), bool enabled = true}) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: enabled && !isLoading ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: enabled ? color : Colors.grey,
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(color: Colors.white))
            : Text(text),
      ),
    );
  }
}
