import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class ViewImagesPage extends StatefulWidget {
  const ViewImagesPage({super.key});

  @override
  State<ViewImagesPage> createState() => _ViewImagesPageState();
}

class _ViewImagesPageState extends State<ViewImagesPage> {
  final supabase = Supabase.instance.client;
  final user = Supabase.instance.client.auth.currentUser;
  List<dynamic> images = [];
  Set<String> likedImageIds = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchImagesAndLikes();
  }

  Future<void> fetchImagesAndLikes() async {
    try {
      final profile = await supabase
          .from('user')
          .select('family_code')
          .eq('user_id', user!.id)
          .single();

      final familyCode = profile['family_code'];

      final imagesRes = await supabase
          .from('images')
          .select()
          .eq('family_code', familyCode)
          .order('created_at', ascending: false);

      final likedRes = await supabase
          .from('image_likes')
          .select('image_id')
          .eq('user_id', user!.id);

      setState(() {
        images = imagesRes;
        likedImageIds =
            likedRes.map<String>((row) => row['image_id'] as String).toSet();
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Error fetching images: $e");
    }
  }

  Future<void> toggleLike(String imageId) async {
    final alreadyLiked = likedImageIds.contains(imageId);
    try {
      if (alreadyLiked) {
        await supabase
            .from('image_likes')
            .delete()
            .eq('user_id', user!.id)
            .eq('image_id', imageId);
        await supabase
            .rpc('decrement_like', params: {'image_id_input': imageId});
        likedImageIds.remove(imageId);
      } else {
        await supabase.from('image_likes').insert({
          'user_id': user!.id,
          'image_id': imageId,
        });
        await supabase
            .rpc('increment_like', params: {'image_id_input': imageId});
        likedImageIds.add(imageId);
      }
      await fetchImagesAndLikes();
    } catch (e) {
      debugPrint("Error toggling like: $e");
    }
  }

  Future<void> deleteImage(String imageId) async {
    try {
      await supabase.from('images').delete().eq('id', imageId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Photo deleted successfully!'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      await fetchImagesAndLikes();
    } catch (e) {
      debugPrint("Error deleting image: $e");
    }
  }

  void showDeleteConfirmation(String imageId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black26,
      isScrollControlled: false,
      builder: (context) {
        return ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(25),
            topRight: Radius.circular(25),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.85),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(25),
                  topRight: Radius.circular(25),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 12,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Are you sure you want to delete this photo?",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF3C2A4D),
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(
                        child: TextButton(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            backgroundColor: Colors.grey.withOpacity(0.2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            "Cancel",
                            style: TextStyle(
                              color: Color(0xFF3C2A4D),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextButton(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            backgroundColor: Color(0xFF6A4C93),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () async {
                            Navigator.pop(context);
                            await deleteImage(imageId);
                          },
                          child: const Text(
                            "Delete",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void openImageViewer(String imageUrl) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: InteractiveViewer(
            child: Image.network(
              imageUrl,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.broken_image, size: 100),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final itemWidth = (screenWidth - 48) / 2;
    final cardHeight = 270.0;
    final aspectRatio = itemWidth / cardHeight;

    return Scaffold(
      backgroundColor: const Color(0xFFE8D6FA),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(top: 20, left: 20, child: _glassyBackButton()),
            Column(
              children: [
                const SizedBox(height: 20),
                const Text(
                  "Family Images",
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF3C2A4D),
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  height: 1,
                  width: 160,
                  color: const Color(0xFF3C2A4D).withOpacity(0.2),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF6A4C93),
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 18,
                            crossAxisSpacing: 14,
                            childAspectRatio: aspectRatio,
                          ),
                          itemCount: images.length,
                          itemBuilder: (context, index) {
                            final img = images[index];
                            final imageUrl = img['image_url'] ?? '';
                            final profilePic = img['profile_image_url'] ?? '';
                            final uploaderName = img['user_name'] ?? 'Unknown';
                            final title = img['title'] ?? '';
                            final imageId = img['id'] ?? '';
                            final uploaderId = img['user_id'] ?? '';
                            final liked = likedImageIds.contains(imageId);
                            final likeCount = img['likes'] ?? 0;
                            final date = DateFormat('dd-MM-yyyy').format(
                              DateTime.tryParse(img['created_at'] ?? '') ??
                                  DateTime.now(),
                            );
                            final isUploader = uploaderId == user?.id;

                            return _buildGlassyImageCard(
                              imageUrl,
                              profilePic,
                              uploaderName,
                              title,
                              date,
                              isUploader,
                              liked,
                              likeCount,
                              () => toggleLike(imageId),
                              () => showDeleteConfirmation(imageId),
                              () => openImageViewer(imageUrl),
                            );
                          },
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _glassyBackButton() => ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(20),
              border:
                  Border.all(color: Colors.white.withOpacity(0.5), width: 1.5),
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Color(0xFF6A4C93)),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
      );

  Widget _buildGlassyImageCard(
    String imageUrl,
    String profilePic,
    String uploaderName,
    String title,
    String date,
    bool isUploader,
    bool liked,
    int likeCount,
    Function onLike,
    Function onDelete,
    Function onView,
  ) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(25),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.55),
                Colors.white.withOpacity(0.25)
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(25),
            border:
                Border.all(color: Colors.white.withOpacity(0.4), width: 1.5),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundImage: profilePic.isNotEmpty
                          ? NetworkImage(profilePic)
                          : const AssetImage("assets/images/default_avatar.png")
                              as ImageProvider,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        uploaderName,
                        style: const TextStyle(
                          color: Color(0xFF3C2A4D),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => onView(),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Image.network(
                      imageUrl,
                      height: 140,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.broken_image, size: 60),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF3C2A4D),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            date,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: Icon(
                            liked ? Icons.favorite : Icons.favorite_border,
                            color: const Color(0xFF6A4C93),
                            size: 18,
                          ),
                          onPressed: () => onLike(),
                        ),
                        Text(
                          "$likeCount",
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(width: 4),
                        if (isUploader)
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: const Icon(
                              Icons.delete,
                              color: Colors.black54,
                              size: 18,
                            ),
                            onPressed: () => onDelete(),
                          ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
