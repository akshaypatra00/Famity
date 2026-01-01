// UploadVideoPage.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class UploadVideoPage extends StatefulWidget {
  const UploadVideoPage({super.key});

  @override
  State<UploadVideoPage> createState() => _UploadVideoPageState();
}

class _UploadVideoPageState extends State<UploadVideoPage> {
  final supabase = Supabase.instance.client;
  final _titleController = TextEditingController();
  File? _videoFile;
  bool isLoading = false;

  Future<void> _pickVideo() async {
    final picked = await ImagePicker().pickVideo(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _videoFile = File(picked.path));
    }
  }

  Future<void> _uploadVideo() async {
    if (_videoFile == null || _titleController.text.isEmpty) return;

    setState(() => isLoading = true);
    try {
      final user = supabase.auth.currentUser;
      final userId = user?.id;
      if (userId == null) throw Exception("Not logged in");

      // Get user profile details
      final profile = await supabase
          .from('user')
          .select('family_name, family_code, name, profile_image_url')
          .eq('user_id', userId)
          .maybeSingle();

      final familyName = profile?['family_name'];
      final familyCode = profile?['family_code'];
      final uploaderName = profile?['name'] ?? 'Unknown';
      final profileImageUrl = profile?['profile_image_url'];

      final fileExt = _videoFile!.path.split('.').last;
      final fileName = const Uuid().v4();
      final filePath = '$fileName.$fileExt';

      final storage = supabase.storage.from('videos');
      await storage.upload(filePath, _videoFile!);
      final publicUrl = storage.getPublicUrl(filePath);

      await supabase.from('videos').insert({
        'title': _titleController.text.trim(),
        'video_url': publicUrl,
        'user_id': userId,
        'family_name': familyName,
        'family_code': familyCode,
        'user_name': uploaderName,
        'profile_image_url': profileImageUrl,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Video uploaded!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      print("❌ Upload error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text("Upload Video")),
      body: Container(
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
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: "Video Title",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _pickVideo,
                icon: const Icon(Icons.video_library),
                label: const Text("Select Video"),
              ),
              const SizedBox(height: 16),
              _videoFile != null
                  ? Text(_videoFile!.path.split('/').last)
                  : const Text("No video selected"),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _uploadVideo,
                  child: isLoading
                      ? const CircularProgressIndicator()
                      : const Text("Upload"),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
