import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final supabase = Supabase.instance.client;
  List<dynamic> activities = [];
  List<dynamic> upcomingBirthdays = [];
  bool isLoading = true;

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    loadData();
  }

  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
    );
    await flutterLocalNotificationsPlugin.initialize(initSettings);
  }

  Future<void> loadData() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final profile = await supabase
        .from('user')
        .select('family_name')
        .eq('user_id', user.id)
        .maybeSingle();

    final familyName = profile?['family_name'];

    final activityResponse = await supabase
        .from('activities')
        .select()
        .eq('family_name', familyName)
        .eq('user_id', user.id)
        .order('created_at', ascending: false);

    // ✅ Mark all unread notifications as read
    final unreadIds = activityResponse
        .where((item) => item['is_read'] == false)
        .map((item) => item['id'])
        .toList();

    if (unreadIds.isNotEmpty) {
      await supabase
          .from('activities')
          .update({'is_read': true}).inFilter('id', unreadIds);
    }

    final members = await supabase
        .from('user')
        .select('name, dob')
        .eq('family_name', familyName);

    final today = DateTime.now();
    final upcoming = today.add(const Duration(days: 7));

    final birthdays = members.where((member) {
      final dob = DateTime.tryParse(member['dob'] ?? '');
      if (dob == null) return false;

      final thisYearBday = DateTime(today.year, dob.month, dob.day);
      return thisYearBday.isAfter(today) && thisYearBday.isBefore(upcoming);
    }).toList();

    setState(() {
      activities = activityResponse;
      upcomingBirthdays = birthdays;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Notifications"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      backgroundColor: isDark ? Colors.black : const Color(0xFFD1E3FF),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: ListView(
                children: [
                  if (upcomingBirthdays.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "🎉 Upcoming Birthdays",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ...upcomingBirthdays.map((user) {
                          final name = user['name'];
                          final dob = DateTime.parse(user['dob']);
                          final dobStr = DateFormat('dd MMM').format(dob);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text("🎂 $name — $dobStr"),
                          );
                        }),
                        const Divider(height: 32),
                      ],
                    ),
                  const Text(
                    "📢 Activity Log",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  ...activities.map((item) {
                    final type = item['activity_type'];
                    final title = item['title'] ?? '';
                    final userName = item['user_name'] ?? 'Unknown';
                    final created = DateTime.parse(item['created_at']);
                    final timeStr =
                        DateFormat.yMMMd().add_jm().format(created.toLocal());

                    IconData icon = Icons.info;
                    if (type == 'image') icon = Icons.image;
                    if (type == 'audio') icon = Icons.audiotrack;
                    if (type == 'video') icon = Icons.videocam;

                    return Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      color: isDark
                          ? Colors.grey[900]
                          : Colors.white.withOpacity(0.9),
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: Icon(icon,
                            color: isDark ? Colors.white : Colors.black87),
                        title: Text(
                          "$userName uploaded a $type",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        subtitle: Text(
                          "$title\n$timeStr",
                          style: TextStyle(
                              color: isDark ? Colors.white70 : Colors.black54),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
    );
  }
}
