import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:audioplayers/audioplayers.dart';

class ViewAudiosPage extends StatefulWidget {
  const ViewAudiosPage({super.key});

  @override
  State<ViewAudiosPage> createState() => _ViewAudiosPageState();
}

class _ViewAudiosPageState extends State<ViewAudiosPage> {
  final supabase = Supabase.instance.client;
  final user = Supabase.instance.client.auth.currentUser;

  List<Map<String, dynamic>> audios = [];
  bool isLoading = true;

  final AudioPlayer _audioPlayer = AudioPlayer();
  String _currentlyPlayingUrl = '';

  @override
  void initState() {
    super.initState();
    fetchAudios();

    _audioPlayer.onPlayerComplete.listen((event) {
      setState(() => _currentlyPlayingUrl = '');
    });
  }

  Future<void> fetchAudios() async {
    try {
      final profile = await supabase
          .from('user')
          .select('family_code')
          .eq('user_id', user!.id)
          .single();

      final familyCode = profile['family_code'];

      final res = await supabase
          .from('audios')
          .select('audio_url, title, user_name, profile_image_url')
          .eq('family_code', familyCode)
          .order('created_at', ascending: false);

      setState(() {
        audios = List<Map<String, dynamic>>.from(res);
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Error fetching audios: $e");
      setState(() => isLoading = false);
    }
  }

  Future<void> togglePlay(String url) async {
    if (_currentlyPlayingUrl == url) {
      await _audioPlayer.pause();
      setState(() => _currentlyPlayingUrl = '');
    } else {
      await _audioPlayer.stop();
      await _audioPlayer.play(UrlSource(url));
      setState(() => _currentlyPlayingUrl = url);
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
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
              // 🔙 Header (same as video & image pages)
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
                          "Family Audios",
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

              // 🎧 Audio list
              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : audios.isEmpty
                        ? const Center(
                            child: Text(
                              "No audios uploaded yet",
                              style: TextStyle(fontSize: 16),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: audios.length,
                            itemBuilder: (context, index) {
                              final audio = audios[index];
                              final audioUrl = audio['audio_url'];
                              final title = audio['title'] ?? 'Untitled Audio';
                              final userName = audio['user_name'] ?? 'Unknown';
                              final profileImage = audio['profile_image_url'];
                              final isPlaying =
                                  _currentlyPlayingUrl == audioUrl;

                              return GestureDetector(
                                onTap: () => togglePlay(audioUrl),
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 20),
                                  padding: const EdgeInsets.all(14),
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
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // 👤 Uploader info
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 18,
                                            backgroundImage: profileImage !=
                                                    null
                                                ? NetworkImage(profileImage)
                                                : const AssetImage(
                                                        'assets/images/profile_placeholder.png')
                                                    as ImageProvider,
                                          ),
                                          const SizedBox(width: 10),
                                          Text(
                                            userName,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 15,
                                              color: isDark
                                                  ? Colors.white
                                                  : Colors.black,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),

                                      // 🎧 Audio title + play indicator
                                      Row(
                                        children: [
                                          Icon(
                                            isPlaying
                                                ? Icons.pause_circle_filled
                                                : Icons.play_circle_fill,
                                            size: 36,
                                            color: Colors.deepPurple,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              title,
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                                color: isDark
                                                    ? Colors.white
                                                    : Colors.black,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
