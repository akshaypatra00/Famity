// All your imports
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'search_page.dart';
import 'settings_page.dart';
import 'profile_page.dart';
import 'notifications_page.dart';
import 'family_chat.dart'; // 👈 Full screen chat page
import 'package:famity/widgets/upload_modal.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final user = Supabase.instance.client.auth.currentUser;
  Map<String, dynamic>? userData;
  List<dynamic> familyMembers = [];
  bool isLoading = true;
  int imageCount = 0;
  int audioCount = 0;
  int videoCount = 0;
  int memberCount = 0;
  int unreadNotifications = 0;
  String voiceMemoryOfDay = '';
  int currentIndex = 0;

  final List<Widget> _pages = [];
  String? familyCode; // store familyCode for chat

  @override
  void initState() {
    super.initState();
    fetchUserData();
    fetchUnreadNotifications();
  }

  Future<void> fetchUserData() async {
    try {
      final userId = user?.id;
      if (userId == null) return;

      final userResponse = await Supabase.instance.client
          .from('user')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (userResponse == null) return;

      final familyName = userResponse['family_name'];
      final fCode = userResponse['family_code'];

      final membersResponse = await Supabase.instance.client
          .from('user')
          .select('profile_image_url')
          .eq('family_name', familyName);

      final imageResponse = await Supabase.instance.client
          .from('images')
          .select()
          .eq('family_code', fCode);

      final audioResponse = await Supabase.instance.client
          .from('audios')
          .select()
          .eq('family_code', fCode);

      final videoResponse = await Supabase.instance.client
          .from('videos')
          .select()
          .eq('family_code', fCode);

      final memoryResponse = await Supabase.instance.client
          .from('voice_memories')
          .select()
          .eq('family_name', familyName)
          .order('created_at', ascending: false)
          .limit(1);

      if (!mounted) return;

      setState(() {
        userData = userResponse;
        familyMembers = membersResponse;
        familyCode = fCode;
        isLoading = false;
        imageCount = imageResponse.length;
        audioCount = audioResponse.length;
        videoCount = videoResponse.length;
        memberCount = membersResponse.length;
        voiceMemoryOfDay = memoryResponse.isNotEmpty
            ? memoryResponse.first['title'] ?? ''
            : 'No memory today';
      });
    } catch (e) {
      if (mounted) {
        print("❌ Error fetching data: $e");
      }
    }
  }

  Future<void> fetchUnreadNotifications() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    final res = await Supabase.instance.client
        .from('activities')
        .select('id')
        .eq('user_id', userId)
        .eq('is_read', false);

    if (!mounted) return;

    setState(() {
      unreadNotifications = res.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    _pages.clear();
    _pages.addAll([
      buildMainHomeContent(isDark),
      const SearchPage(),
      const SizedBox(),
      const SettingsPage(),
      const ProfilePage(),
    ]);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          IndexedStack(
            index: currentIndex,
            children: _pages,
          ),

          // 👇 Sticky Family Chat card (only for Home tab)
          if (currentIndex == 0 && familyCode != null)
            Positioned(
              bottom: 100, // above nav bar
              left: 54,
              right: 54,
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          FamilyChatPage(familyCode: familyCode!),
                    ),
                  );
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 16, horizontal: 20),
                      decoration: BoxDecoration(
                        color: (isDark ? Colors.white : Colors.black)
                            .withOpacity(0.2), // glassy adaptive
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.chat_bubble,
                            color: isDark ? Colors.white : Colors.black87,
                            size: 26,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            "Family Chat",
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // 👇 Bottom Navigation Bar
          Positioned(
            bottom: 16,
            left: 24,
            right: 24,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15.0, sigmaY: 15.0),
                child: Container(
                  height: 70,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _navItem(Icons.home, "Home", 0),
                      _navItem(Icons.search, "Search", 1),
                      _navItem(Icons.add, "Add", 2),
                      _navItem(Icons.settings, "Settings", 3),
                      _navItem(Icons.person, "Profile", 4),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _navItem(IconData icon, String label, int index) {
    return GestureDetector(
      onTap: () {
        if (label == "Add") {
          showUploadModal(context, fetchUserData);
          return;
        }
        setState(() => currentIndex = index);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(color: Colors.white, fontSize: 10)),
        ],
      ),
    );
  }

  Widget buildMainHomeContent(bool isDark) {
    final now = DateTime.now();
    final dateStr = DateFormat('dd MMM, yyyy').format(now);
    final dayStr = DateFormat('EEEE').format(now);

    final familyImageUrl = userData?['family_image_url'];
    final safeFamilyImage =
        (familyImageUrl != null && familyImageUrl.toString().isNotEmpty)
            ? familyImageUrl.toString()
            : null;

    return Container(
      decoration: BoxDecoration(
        gradient: isDark
            ? const LinearGradient(
                colors: [Color(0xFF1F1F1F), Color(0xFF121212)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              )
            : const LinearGradient(
                colors: [Color(0xFFE8D6FA), Color(0xFFD1E3FF)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
      ),
      child: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // greeting row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Hey, ${userData?['name'] ?? 'User'}!",
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                "from ${userData?['family_name'] ?? 'Family'}",
                                style: TextStyle(
                                  fontSize: 18,
                                  color: isDark
                                      ? Colors.deepPurple.shade200
                                      : const Color.fromARGB(255, 122, 51, 222),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Stack(
                          children: [
                            IconButton(
                              icon: Icon(Icons.notifications_none_rounded,
                                  color: isDark ? Colors.white : Colors.black),
                              onPressed: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const NotificationsPage(),
                                  ),
                                );
                                fetchUnreadNotifications();
                              },
                            ),
                            if (unreadNotifications > 0)
                              Positioned(
                                right: 4,
                                top: 6,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  constraints: const BoxConstraints(
                                      minWidth: 16, minHeight: 16),
                                  child: Text(
                                    '$unreadNotifications',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: (isDark ? Colors.white : Colors.black)
                                .withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: safeFamilyImage != null
                                    ? Image.network(
                                        safeFamilyImage,
                                        width: 130,
                                        height: 80,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) {
                                          return _fallbackFamilyImage();
                                        },
                                      )
                                    : _fallbackFamilyImage(),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "${userData?['family_name'] ?? 'Family'}",
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text("$dateStr, $dayStr",
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: isDark
                                                ? Colors.white70
                                                : Colors.black54)),
                                    const SizedBox(height: 6),
                                    Row(
                                      children:
                                          familyMembers.take(6).map((member) {
                                        final imgUrl =
                                            member['profile_image_url'] ?? '';
                                        final valid =
                                            imgUrl.toString().isNotEmpty;
                                        return Padding(
                                          padding:
                                              const EdgeInsets.only(right: 4),
                                          child: CircleAvatar(
                                            radius: 12,
                                            backgroundColor: Colors.grey[300],
                                            backgroundImage: valid
                                                ? NetworkImage(imgUrl)
                                                : null,
                                            child: !valid
                                                ? const Icon(Icons.person,
                                                    size: 14,
                                                    color: Colors.grey)
                                                : null,
                                          ),
                                        );
                                      }).toList(),
                                    )
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: (isDark ? Colors.white : Colors.black)
                            .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        "💡 Voice Memory of the Day: '$voiceMemoryOfDay'",
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // main grid
                    Expanded(
                      child: GridView.count(
                        crossAxisCount: 2,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        children: [
                          _gridTile("Pictures", Icons.image,
                              "$imageCount photos", isDark, () {
                            Navigator.pushNamed(context, '/view-images');
                          }),
                          _gridTile("Audio", Icons.graphic_eq,
                              "$audioCount audio", isDark, () {
                            Navigator.pushNamed(context, '/view-audios');
                          }),
                          _gridTile("Video", Icons.play_circle_fill,
                              "$videoCount videos", isDark, () {
                            Navigator.pushNamed(context, '/view-videos');
                          }),
                          _gridTile("Members", Icons.groups,
                              "$memberCount members", isDark, () {
                            Navigator.pushNamed(context, '/view-members');
                          }),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _fallbackFamilyImage() {
    return Container(
      width: 130,
      height: 80,
      color: Colors.grey[300],
      child: const Icon(Icons.family_restroom, size: 40),
    );
  }

  Widget _gridTile(String title, IconData icon, String subtitle, bool isDark,
      VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: (isDark ? Colors.white : Colors.black).withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: isDark ? Colors.white : Colors.black87, size: 36),
            const SizedBox(height: 16),
            Text(title,
                style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            Text(subtitle,
                style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black54,
                    fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
