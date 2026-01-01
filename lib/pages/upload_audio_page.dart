import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UploadAudioPage extends StatefulWidget {
  const UploadAudioPage({super.key});

  @override
  State<UploadAudioPage> createState() => _UploadAudioPageState();
}

class _UploadAudioPageState extends State<UploadAudioPage> {
  final supabase = Supabase.instance.client;
  final titleController = TextEditingController();

  File? _audioFile;
  String? _fileName;
  bool isLoading = false;

  Future<void> _pickAudio() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.audio);
    if (result != null && result.files.single.path != null) {
      setState(() {
        _audioFile = File(result.files.single.path!);
        _fileName = result.files.single.name;
      });
    }
  }

  Future<void> _upload() async {
    if (_audioFile == null || titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select audio and add a title.")),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception("Not logged in");

      final profile = await supabase
          .from('user')
          .select('family_code, name, profile_image_url')
          .eq('user_id', user.id)
          .single();

      final familyCode = profile['family_code'];
      final userName = profile['name'];
      final profileImage = profile['profile_image_url'];

      final ext = _audioFile!.path.split('.').last;
      final path = 'audios/${DateTime.now().millisecondsSinceEpoch}.$ext';
      final bytes = await _audioFile!.readAsBytes();

      await supabase.storage.from('audios').uploadBinary(path, bytes,
          fileOptions: const FileOptions(upsert: true));

      final publicUrl = supabase.storage.from('audios').getPublicUrl(path);
      final title = titleController.text.trim();

      await supabase.from('audios').insert({
        'title': title,
        'audio_url': publicUrl,
        'family_code': familyCode,
        'user_name': userName,
        'profile_image_url': profileImage,
        'user_id': user.id,
      });

      await supabase.from('activities').insert({
        'user_id': user.id,
        'user_name': userName,
        'activity_type': 'audio',
        'title': title,
        'family_code': familyCode,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Audio uploaded successfully!")),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: const Color(0xFFD1E3FF),
      appBar: AppBar(
        title: const Text("Upload Audio"),
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
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white30),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Enter audio title',
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: _pickAudio,
                    child: Container(
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white54),
                      ),
                      child: Center(
                        child: Text(
                          _fileName ?? 'Tap to select audio',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton(
                    onPressed: _upload,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 5,
                    ),
                    child: const Text(
                      "Upload Audio",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
