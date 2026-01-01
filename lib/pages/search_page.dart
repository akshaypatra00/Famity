import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import '../theme_provider.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final SupabaseClient supabase = Supabase.instance.client;

  List<dynamic> searchResults = [];
  TextEditingController searchController = TextEditingController();

  String? familyName;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    getFamilyName();
  }

  Future<void> getFamilyName() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      print("User not logged in");
      return;
    }

    final response = await supabase
        .from('user')
        .select('family_name')
        .eq('user_id', user.id)
        .maybeSingle();

    if (response != null && response['family_name'] != null) {
      setState(() {
        familyName = response['family_name'];
      });
    }
  }

  Future<void> performSearch(String query) async {
    if (familyName == null || query.isEmpty) return;

    setState(() => isLoading = true);

    final voiceMemories = await supabase
        .from('voice_memories')
        .select()
        .ilike('title', '%$query%')
        .eq('family_name', familyName!);

    final images = await supabase
        .from('images')
        .select()
        .ilike('title', '%$query%')
        .eq('family_name', familyName!);

    final videos = await supabase
        .from('videos')
        .select()
        .ilike('title', '%$query%')
        .eq('family_name', familyName!);

    final audios = await supabase
        .from('audios')
        .select()
        .ilike('title', '%$query%')
        .eq('family_name', familyName!);

    setState(() {
      searchResults = [
        ...voiceMemories,
        ...images,
        ...videos,
        ...audios,
      ];
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [Colors.black, Colors.grey.shade900]
              : [const Color(0xFFE8D6FA), const Color(0xFFD1E3FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: searchController,
                  onChanged: (value) => performSearch(value),
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                  decoration: InputDecoration(
                    hintText: "Search memories...",
                    hintStyle:
                        TextStyle(color: isDark ? Colors.grey : Colors.black54),
                    filled: true,
                    fillColor: isDark ? Colors.grey[850] : Colors.white,
                    prefixIcon: Icon(Icons.search,
                        color: isDark ? Colors.white : Colors.black),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                isLoading
                    ? const CircularProgressIndicator()
                    : Expanded(
                        child: ListView.builder(
                          itemCount: searchResults.length,
                          itemBuilder: (context, index) {
                            final item = searchResults[index];
                            return Card(
                              color: isDark
                                  ? Colors.white.withOpacity(0.1)
                                  : Colors.white.withOpacity(0.8),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15)),
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              child: ListTile(
                                title: Text(item['title'] ?? '',
                                    style: TextStyle(
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black)),
                                subtitle: Text(
                                  item['description'] ?? '',
                                  style: TextStyle(
                                      color: isDark
                                          ? Colors.grey
                                          : Colors.grey[800]),
                                ),
                              ),
                            );
                          },
                        ),
                      )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
