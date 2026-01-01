import 'package:flutter/material.dart';
import 'package:provider/provider.dart' as flutter_provider;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme_provider.dart';
import 'package:flutter/services.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final supabase = Supabase.instance.client;
  final user = Supabase.instance.client.auth.currentUser;

  String name = '';
  String dob = '';
  String email = '';
  String familyCode = '';
  String imageUrl = '';
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchProfile();
  }

  Future<void> fetchProfile() async {
    try {
      final response =
          await supabase.from("user").select().eq('user_id', user!.id).single();

      String? fetchedFamilyCode = response['family_code'] as String?;
      final familyName = response['family_name'] as String? ?? '';

      // 🛠 If family_code is null, fetch from any other family member
      if (fetchedFamilyCode == null || fetchedFamilyCode.isEmpty) {
        final fallback = await supabase
            .from('user')
            .select('family_code')
            .eq('family_name', familyName)
            .not('family_code', 'is', null)
            .limit(1)
            .maybeSingle();

        fetchedFamilyCode = fallback?['family_code'] as String?;
      }

      setState(() {
        name = response['name'] ?? '';
        dob = response['dob'] ?? '';
        familyCode = fetchedFamilyCode ?? 'Not available';
        imageUrl = response['profile_image_url'] ?? '';
        email = user?.email ?? '';
        isLoading = false;
      });
    } catch (e) {
      print("Fetch error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to load profile: $e")),
      );
    }
  }

  Future<void> showConfirmation({
    required String title,
    required String content,
    required Future<void> Function() onConfirm,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Confirm"),
          ),
        ],
      ),
    );

    if (confirmed == true) await onConfirm();
  }

  Future<void> logoutUser() async {
    await showConfirmation(
      title: "Logout",
      content: "Are you sure you want to logout?",
      onConfirm: () async {
        await supabase.auth.signOut();
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(
              context, '/login', (route) => false);
        }
      },
    );
  }

  Future<void> deleteUser() async {
    await showConfirmation(
      title: "Delete Account",
      content: "This will permanently delete your account. Continue?",
      onConfirm: () async {
        await supabase.auth.admin.deleteUser(user!.id);
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(
              context, '/login', (route) => false);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode =
        flutter_provider.Provider.of<ThemeProvider>(context).isDarkMode;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: isDarkMode
              ? null
              : const LinearGradient(
                  colors: [Color(0xFFE8D6FA), Color(0xFFD1E3FF)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
          color: isDarkMode ? Colors.black : null,
        ),
        child: SafeArea(
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: fetchProfile,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
                    children: [
                      Center(
                        child: CircleAvatar(
                          radius: 50,
                          backgroundImage: imageUrl.isNotEmpty
                              ? NetworkImage(imageUrl)
                              : null,
                          child: imageUrl.isEmpty
                              ? const Icon(Icons.person, size: 50)
                              : null,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: Column(
                          children: [
                            Text(
                              name,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: isDarkMode ? Colors.white : Colors.black,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              email,
                              style: TextStyle(
                                fontSize: 16,
                                color: isDarkMode
                                    ? Colors.grey[300]
                                    : Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildTile(
                        icon: Icons.family_restroom,
                        title: "Family Code: $familyCode",
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: familyCode));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text("Family code copied!")),
                          );
                        },
                      ),
                      _buildTile(
                        icon: Icons.lock_outline,
                        title: "Change Password (coming soon)",
                      ),
                      _buildTile(
                        icon: Icons.email_outlined,
                        title: "Change Email (coming soon)",
                      ),
                      _buildTile(
                        icon: Icons.logout,
                        iconColor: Colors.orange,
                        title: "Logout",
                        onTap: logoutUser,
                      ),
                      _buildTile(
                        icon: Icons.delete_forever,
                        iconColor: Colors.red,
                        title: "Delete Account",
                        onTap: deleteUser,
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildTile({
    required IconData icon,
    required String title,
    VoidCallback? onTap,
    Color? iconColor,
  }) {
    final isDarkMode =
        flutter_provider.Provider.of<ThemeProvider>(context).isDarkMode;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      color: isDarkMode ? Colors.grey[900] : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: iconColor ?? Colors.deepPurple),
        title: Text(
          title,
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w500,
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}
