// ✅ UploadImagePage with push notifications via FCM
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;

class UploadImagePage extends StatefulWidget {
  const UploadImagePage({super.key});

  @override
  State<UploadImagePage> createState() => _UploadImagePageState();
}

class _UploadImagePageState extends State<UploadImagePage> {
  final supabase = Supabase.instance.client;
  final titleController = TextEditingController();

  File? _imageFile;
  String? _fileName;
  bool isLoading = false;

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null && result.files.single.path != null) {
      setState(() {
        _imageFile = File(result.files.single.path!);
        _fileName = result.files.single.name;
      });
    }
  }

  /// 🔔 Send push notification to all family members
  Future<void> _sendPushToFamily(String familyCode, String uploaderName) async {
    try {
      final members = await supabase
          .from('user')
          .select('fcm_token')
          .eq('family_code', familyCode);

      for (final member in members) {
        final token = member['fcm_token'];
        if (token == null || token.toString().isEmpty) continue;

        final response = await http.post(
          Uri.parse("https://fcm.googleapis.com/fcm/send"),
          headers: {
            "Content-Type": "application/json",
            "Authorization":
                "key=YOUR_FCM_SERVER_KEY", // 🔑 Replace with your real server key
          },
          body: jsonEncode({
            "to": token,
            "notification": {
              "title": "📷 New Photo Uploaded",
              "body": "$uploaderName added a new image!",
            },
            "data": {
              "type": "upload",
              "family_code": familyCode,
            }
          }),
        );

        if (response.statusCode == 200) {
          print("✅ Push sent to $token");
        } else {
          print("❌ Push failed: ${response.body}");
        }
      }
    } catch (e) {
      print("❌ Push send error: $e");
    }
  }

  Future<void> _upload() async {
    if (_imageFile == null || titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select image and add title.")),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception("Not logged in");

      final profile = await supabase
          .from('user')
          .select('family_name, name, profile_image_url, family_code')
          .eq('user_id', user.id)
          .single();

      final familyName = profile['family_name'];
      final familyCode = profile['family_code'];
      final userName = profile['name'];
      final profileImage = profile['profile_image_url'];

      final ext = _imageFile!.path.split('.').last;
      final path = 'images/${DateTime.now().millisecondsSinceEpoch}.$ext';
      final bytes = await _imageFile!.readAsBytes();

      await supabase.storage.from('images').uploadBinary(path, bytes,
          fileOptions: const FileOptions(upsert: true));

      final publicUrl = supabase.storage.from('images').getPublicUrl(path);

      await supabase.from('images').insert({
        'title': titleController.text.trim(),
        'image_url': publicUrl,
        'family_name': familyName,
        'family_code': familyCode,
        'user_id': user.id,
        'user_name': userName,
        'profile_image_url': profileImage,
        'likes': 0,
      });

      /// 🔔 Send push notification after successful upload
      await _sendPushToFamily(familyCode, userName);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Image uploaded successfully!")),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Upload failed: $e")),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFD1E3FF),
      appBar: AppBar(
        title: const Text("Upload Image"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'Title'),
                  ),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      height: 150,
                      decoration: BoxDecoration(
                        color: Colors.black12,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          _fileName ?? 'Tap to select image',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _upload,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30)),
                    ),
                    child: const Center(child: Text("Upload")),
                  ),
                ],
              ),
      ),
    );
  }
}
