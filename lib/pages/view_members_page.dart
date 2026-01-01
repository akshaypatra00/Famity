import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:share_plus/share_plus.dart';

class ViewMembersPage extends StatefulWidget {
  const ViewMembersPage({super.key});

  @override
  State<ViewMembersPage> createState() => _ViewMembersPageState();
}

class _ViewMembersPageState extends State<ViewMembersPage> {
  final supabase = Supabase.instance.client;
  List<dynamic> members = [];
  bool isLoading = true;
  String? familyCode;

  @override
  void initState() {
    super.initState();
    fetchMembers();
  }

  Future<void> fetchMembers() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      final profile = await supabase
          .from('user')
          .select('family_code')
          .eq('user_id', user.id)
          .maybeSingle();

      familyCode = profile?['family_code'];

      final response = await supabase
          .from('user')
          .select()
          .eq('family_code', familyCode ?? '')
          .order('name');

      setState(() {
        members = response;
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Fetch error: $e");
      setState(() => isLoading = false);
    }
  }

  void shareFamilyCode() {
    if (familyCode != null) {
      Share.share(
        "Join my Memory Chain family with this invite code: $familyCode",
        subject: "Family Invite Code",
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark
              ? const LinearGradient(
                  colors: [Color(0xFF0F0F0F), Color(0xFF1E1E1E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : const LinearGradient(
                  colors: [Color(0xFFE8D6FA), Color(0xFFD1E3FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // 🔙 Header (same as other pages)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withOpacity(0.1)
                              : Colors.white.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 18,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                    const Expanded(
                      child: Center(
                        child: Text(
                          "Family Members",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 40),
                  ],
                ),
              ),
              const Divider(thickness: 0.6, indent: 30, endIndent: 30),

              // 👨‍👩‍👧 Members List
              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : members.isEmpty
                        ? const Center(
                            child: Text(
                              "No family members found",
                              style: TextStyle(fontSize: 16),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: members.length,
                            itemBuilder: (context, index) {
                              final member = members[index];
                              final image = member['profile_image_url'] ?? '';

                              return Container(
                                margin: const EdgeInsets.only(bottom: 18),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  gradient: LinearGradient(
                                    colors: isDark
                                        ? [
                                            Colors.white.withOpacity(0.06),
                                            Colors.white.withOpacity(0.02)
                                          ]
                                        : [
                                            Colors.white.withOpacity(0.6),
                                            Colors.white.withOpacity(0.3)
                                          ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 26,
                                      backgroundImage: image.isNotEmpty
                                          ? NetworkImage(image)
                                          : const AssetImage(
                                                  'assets/images/profile_placeholder.png')
                                              as ImageProvider,
                                    ),
                                    const SizedBox(width: 14),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          member['name'] ?? 'No Name',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 16,
                                            color: isDark
                                                ? Colors.white
                                                : Colors.black,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          member['email'] ?? '',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: isDark
                                                ? Colors.white70
                                                : Colors.black54,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),

      // ➕ Invite Member (BLACK button)
      floatingActionButton: FloatingActionButton.extended(
        onPressed: shareFamilyCode,
        backgroundColor: Colors.black,
        icon: const Icon(Icons.share, color: Colors.white),
        label: const Text(
          "Invite Member",
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}
