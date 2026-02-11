import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FamilyChatPage extends StatefulWidget {
  final String familyCode;

  const FamilyChatPage({super.key, required this.familyCode});

  @override
  State<FamilyChatPage> createState() => _FamilyChatPageState();
}

class _FamilyChatPageState extends State<FamilyChatPage> {
  final supabase = Supabase.instance.client;
  final TextEditingController _controller = TextEditingController();

  String? myName;
  String? myProfileImage;
  bool profileLoaded = false;

  /// 🔥 Local optimistic messages
  final List<Map<String, dynamic>> _localMessages = [];

  @override
  void initState() {
    super.initState();
    _loadMyProfile();
  }

  Future<void> _loadMyProfile() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final profile = await supabase
        .from('user')
        .select('name, profile_image_url')
        .eq('user_id', user.id)
        .single();

    setState(() {
      myName = profile['name'];
      myProfileImage = profile['profile_image_url'];
      profileLoaded = true;
    });
  }

  /// 🚀 Send message (OPTIMISTIC)
  Future<void> _sendMessage() async {
    if (!profileLoaded) return;

    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _controller.clear();

    final optimisticMessage = {
      'id': UniqueKey().toString(),
      'user_id': supabase.auth.currentUser!.id,
      'family_code': widget.familyCode.toString(),
      'user_name': myName,
      'profile_image_url': myProfileImage,
      'message': text,
      'created_at': DateTime.now().toIso8601String(),
      'optimistic': true,
    };

    setState(() {
      _localMessages.add(optimisticMessage);
    });

    await supabase.from('family_chats').insert({
      'user_id': supabase.auth.currentUser!.id,
      'family_code': widget.familyCode.toString(),
      'user_name': myName,
      'profile_image_url': myProfileImage,
      'message': text,
    });
  }

  @override
  Widget build(BuildContext context) {
    final myId = supabase.auth.currentUser!.id;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark
              ? const LinearGradient(
                  colors: [Color(0xFF0F0F0F), Color(0xFF1E1E1E)],
                )
              : const LinearGradient(
                  colors: [Color(0xFFE8D6FA), Color(0xFFD1E3FF)],
                ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Expanded(
                      child: Center(
                        child: Text(
                          "Family Chat",
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 40),
                  ],
                ),
              ),

              // Messages
              Expanded(
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: supabase
                      .from('family_chats')
                      .stream(primaryKey: ['id'])
                      .eq('family_code', widget.familyCode.toString())
                      .order('created_at'),
                  builder: (context, snapshot) {
                    final dbMessages = snapshot.data ?? [];

                    /// 🔥 Merge optimistic + db messages
                    final messages = [
                      ...dbMessages,
                      ..._localMessages.where((m) => m['optimistic'] == true),
                    ];

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final msg = messages[index];
                        final isMe = msg['user_id'] == myId;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            mainAxisAlignment: isMe
                                ? MainAxisAlignment.end
                                : MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!isMe)
                                CircleAvatar(
                                  radius: 16,
                                  backgroundImage: msg['profile_image_url'] !=
                                          null
                                      ? NetworkImage(msg['profile_image_url'])
                                      : const AssetImage(
                                              'assets/images/profile_placeholder.png')
                                          as ImageProvider,
                                ),
                              const SizedBox(width: 8),
                              Container(
                                constraints:
                                    const BoxConstraints(maxWidth: 260),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isMe
                                      ? Colors.black
                                      : Colors.white.withOpacity(0.75),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (!isMe)
                                      Text(
                                        msg['user_name'] ?? 'Unknown',
                                        style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600),
                                      ),
                                    Text(
                                      msg['message'] ?? '',
                                      style: TextStyle(
                                        color:
                                            isMe ? Colors.white : Colors.black,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),

              // Input
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        decoration: const InputDecoration(
                          hintText: "Type a message...",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(30)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: _sendMessage,
                    )
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
