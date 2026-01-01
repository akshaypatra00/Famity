import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart'; // For ImageFilter
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:famity/utills/animated_route.dart'; // Assuming you have this

class JoinFamilyPage extends StatefulWidget {
  const JoinFamilyPage({super.key});

  @override
  State<JoinFamilyPage> createState() => _JoinFamilyPageState();
}

class _JoinFamilyPageState extends State<JoinFamilyPage> {
  final supabase = Supabase.instance.client;
  final codeController = TextEditingController();
  bool isLoading = false;

  Future<void> validateFamilyCode() async {
    setState(() => isLoading = true);
    final code = codeController.text.trim();

    try {
      final response = await supabase
          .from('user') // 🔁 now check in 'families' table
          .select('family_name')
          .eq('family_code', code)
          .limit(1)
          .maybeSingle();

      if (response != null) {
        // Temporarily pass email instead of family_name
        Navigator.pushNamed(
          context,
          '/join-profile-setup',
          arguments: code, // <-- pass family_code instead
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid Family Code')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => isLoading = false);
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
              Color(0xFFE8D6FA), // Your homepage color
              Color(0xFFD1E3FF), // Your homepage color
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
                          Navigator.pop(context);
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
                      // Glassmorphism container for the join family form
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
                                  "JOIN FAMILY",
                                  style: TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF6A4C93),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                const Text(
                                  "Enter the invitation code provided by your family",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Color(0xFF6A4C93),
                                  ),
                                ),
                                const SizedBox(height: 25),
                                TextField(
                                  controller: codeController,
                                  style:
                                      const TextStyle(color: Color(0xFF333333)),
                                  decoration: InputDecoration(
                                    hintText: "Family Invitation Code",
                                    hintStyle:
                                        TextStyle(color: Colors.grey[600]),
                                    prefixIcon: const Icon(Icons.group,
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
                                const SizedBox(height: 25),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed:
                                        isLoading ? null : validateFamilyCode,
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
                                            "Join Family",
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
