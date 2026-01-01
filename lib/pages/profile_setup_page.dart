import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'home_screen.dart';
import 'package:famity/utills/animated_route.dart';

class ProfileSetupPage extends StatefulWidget {
  const ProfileSetupPage({super.key});

  @override
  State<ProfileSetupPage> createState() => _ProfileSetupPageState();
}

class _ProfileSetupPageState extends State<ProfileSetupPage> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController familyNameController = TextEditingController();
  final TextEditingController dobController = TextEditingController();

  File? profileImage;
  File? familyImage;
  bool isLoading = false;

  Future<void> pickImage(bool isProfile) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        if (isProfile) {
          profileImage = File(pickedFile.path);
        } else {
          familyImage = File(pickedFile.path);
        }
      });
    }
  }

  String generateFamilyCode() {
    final random = DateTime.now().millisecondsSinceEpoch.remainder(10000000000);
    return random.toString().padLeft(10, '0');
  }

  Future<String?> uploadImage(File image, String path) async {
    final userId = Supabase.instance.client.auth.currentUser!.id;
    final fileExt = image.path.split('.').last;
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
    final filePath = '$path/$userId/$fileName';

    final bytes = await image.readAsBytes();
    final response = await Supabase.instance.client.storage
        .from('user-files')
        .uploadBinary(filePath, bytes,
            fileOptions: const FileOptions(upsert: true));

    if (response.isEmpty) return null;

    final publicUrl = Supabase.instance.client.storage
        .from('user-files')
        .getPublicUrl(filePath);
    return publicUrl;
  }

  Future<void> handleContinue() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    setState(() => isLoading = true);

    try {
      final name = nameController.text.trim();
      final familyName = familyNameController.text.trim();
      final rawDob = dobController.text.trim();

      final dobParts = rawDob.split('/');
      final formattedDob =
          '${dobParts[2]}-${dobParts[1].padLeft(2, '0')}-${dobParts[0].padLeft(2, '0')}';

      final profileUrl = profileImage != null
          ? await uploadImage(profileImage!, 'profile')
          : null;
      final familyUrl = familyImage != null
          ? await uploadImage(familyImage!, 'family')
          : null;

      final familyCode = generateFamilyCode();

      await Supabase.instance.client.from('user').upsert({
        'user_id': user.id,
        'name': name,
        'family_name': familyName,
        'family_code': familyCode,
        'dob': formattedDob,
        'profile_image_url': profileUrl,
        'family_image_url': familyUrl,
        'email': user.email, // ensures email is stored if not already
      });

      if (mounted) {
        Navigator.pushReplacement(
          context,
          SlidePageRoute(page: const HomeScreen()),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F2FC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Profile Setup',
          style: TextStyle(
              fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: () => pickImage(true),
              child: CircleAvatar(
                radius: 50,
                backgroundColor: Colors.grey[300],
                backgroundImage:
                    profileImage != null ? FileImage(profileImage!) : null,
                child: profileImage == null
                    ? const Icon(Icons.person, size: 50, color: Colors.grey)
                    : null,
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => pickImage(false),
              child: Container(
                width: double.infinity,
                height: 150,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(16),
                  image: familyImage != null
                      ? DecorationImage(
                          image: FileImage(familyImage!), fit: BoxFit.cover)
                      : null,
                ),
                child: familyImage == null
                    ? const Center(
                        child: Icon(Icons.family_restroom,
                            size: 40, color: Colors.grey),
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 20),
            buildTextField(nameController, "Your Name", Icons.person),
            const SizedBox(height: 16),
            buildTextField(
                familyNameController, "Family Name", Icons.family_restroom),
            const SizedBox(height: 16),
            TextField(
              controller: dobController,
              readOnly: true,
              decoration: InputDecoration(
                hintText: 'Date of Birth',
                prefixIcon: const Icon(Icons.cake),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide.none,
                ),
              ),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: DateTime(2000),
                  firstDate: DateTime(1900),
                  lastDate: DateTime.now(),
                );
                if (date != null) {
                  dobController.text = '${date.day}/${date.month}/${date.year}';
                }
              },
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isLoading ? null : handleContinue,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                ),
                child: isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Continue",
                        style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildTextField(
      TextEditingController controller, String hint, IconData icon) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
