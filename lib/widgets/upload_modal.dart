import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Local notifications instance (reuse from main.dart)
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void showUploadModal(BuildContext context, VoidCallback onSuccessRefresh) {
  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (_) => _UploadDialog(onSuccessRefresh: onSuccessRefresh),
  );
}

class _UploadDialog extends StatefulWidget {
  final VoidCallback onSuccessRefresh;
  const _UploadDialog({required this.onSuccessRefresh});

  @override
  State<_UploadDialog> createState() => _UploadDialogState();
}

class _UploadDialogState extends State<_UploadDialog> {
  File? selectedFile;
  String? fileType;
  String? fileName;
  bool isUploading = false;
  double uploadProgress = 0.0;
  bool uploadSuccess = false;
  bool isCancelled = false;

  final titleController = TextEditingController();

  Future<void> pickFile(String type) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: type == 'image'
          ? FileType.image
          : type == 'video'
              ? FileType.video
              : FileType.audio,
    );
    if (result != null) {
      setState(() {
        selectedFile = File(result.files.single.path!);
        fileType = type;
        fileName = result.files.single.name;
      });
    }
  }

  Future<void> uploadFile() async {
    if (selectedFile == null ||
        fileType == null ||
        titleController.text.isEmpty) {
      return;
    }

    setState(() {
      isUploading = true;
      uploadProgress = 0.0;
      uploadSuccess = false;
      isCancelled = false;
    });

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception("User not logged in");

      // Get user info
      final userData = await supabase
          .from('user')
          .select('family_name, family_code, name, profile_image_url')
          .eq('user_id', user.id)
          .maybeSingle();

      final familyCode = userData?['family_code'];
      final familyName = userData?['family_name'];
      final uploaderName = userData?['name'];
      final uploaderImage = userData?['profile_image_url'];

      // Upload file to Supabase Storage
      final ext = selectedFile!.path.split('.').last;
      final uuid = const Uuid().v4();
      final path = '$uuid.$ext';
      final storage = supabase.storage.from('${fileType}s');

      setState(() => uploadProgress = 0.3);
      await Future.delayed(const Duration(milliseconds: 300));
      setState(() => uploadProgress = 0.6);
      await Future.delayed(const Duration(milliseconds: 300));

      await storage.upload(
        path,
        selectedFile!,
        fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
      );

      setState(() => uploadProgress = 1.0);
      if (isCancelled) return;

      final publicUrl = storage.getPublicUrl(path);

      // Insert uploaded file info
      await supabase.from('${fileType}s').insert({
        'title': titleController.text.trim(),
        '${fileType}_url': publicUrl,
        'user_id': user.id,
        'user_name': uploaderName,
        'profile_image_url': uploaderImage,
        'family_name': familyName,
        'family_code': familyCode,
      });

      // ----------------------------
      // 1️⃣ Insert activity for all family members
      // ----------------------------
      final members = await supabase
          .from('user')
          .select('user_id')
          .eq('family_name', familyName);

      final activityInserts = members.map((member) {
        return {
          'title': titleController.text.trim(),
          'user_id': member['user_id'],
          'user_name': uploaderName,
          'profile_image_url': uploaderImage,
          'family_name': familyName,
          'activity_type': fileType,
          'is_read': member['user_id'] == user.id, // uploader sees it as read
        };
      }).toList();

      await supabase.from('activities').insert(activityInserts);

      setState(() => uploadSuccess = true);

      // Callback + close dialog
      Future.delayed(const Duration(seconds: 1), () {
        widget.onSuccessRefresh();
        Navigator.pop(context);
      });
    } catch (e) {
      print("Upload error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Upload failed: $e")),
      );
    } finally {
      if (mounted && !isCancelled) setState(() => isUploading = false);
    }
  }

  Widget _buildIconButton(String label, IconData icon, String type) {
    return ElevatedButton.icon(
      onPressed: () => pickFile(type),
      icon: Icon(icon, color: const Color(0xFFD1E3FF)),
      label: Text(label, style: const TextStyle(color: Colors.white)),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF150729),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              width: 330,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.25),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white.withOpacity(0.3)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Upload Memory",
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 18),
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(
                      hintText: 'Title',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    children: [
                      _buildIconButton("Image", Icons.image, 'image'),
                      _buildIconButton("Video", Icons.videocam, 'video'),
                      _buildIconButton("Audio", Icons.music_note, 'audio'),
                    ],
                  ),
                  if (fileName != null) ...[
                    const SizedBox(height: 10),
                    Text(fileName!,
                        style: const TextStyle(
                            fontSize: 11, color: Colors.white70),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                          onPressed: () {
                            isCancelled = true;
                            Navigator.pop(context);
                          },
                          child: const Text("Cancel",
                              style: TextStyle(color: Color(0xFFD1E3FF)))),
                      ElevatedButton(
                        onPressed: isUploading ? null : uploadFile,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD1E3FF)),
                        child: const Text("Upload"),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
