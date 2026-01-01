import 'package:flutter/material.dart';

void showAddModal(BuildContext context, void Function() onUploadComplete) {
  showModalBottomSheet(
    context: context,
    backgroundColor: const Color.fromARGB(0, 138, 246, 250),
    isScrollControlled: true,
    builder: (_) {
      return DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: const Color(0xFFD1E3FF).withOpacity(0.9),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(30)),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            padding: const EdgeInsets.all(20),
            child: ListView(
              controller: scrollController,
              children: [
                const Text(
                  "➕ Add New Item",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: const Icon(Icons.image),
                  title: const Text("Upload Image"),
                  onTap: () {
                    Navigator.pop(context);
                    _handleUpload(context, UploadType.image, onUploadComplete);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.audiotrack),
                  title: const Text("Upload Audio"),
                  onTap: () {
                    Navigator.pop(context);
                    _handleUpload(context, UploadType.audio, onUploadComplete);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.video_call),
                  title: const Text("Upload Video"),
                  onTap: () {
                    Navigator.pop(context);
                    _handleUpload(context, UploadType.video, onUploadComplete);
                  },
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

enum UploadType { image, audio, video }

void _handleUpload(
  BuildContext context,
  UploadType type,
  void Function() onUploadComplete,
) {
  String route;
  switch (type) {
    case UploadType.image:
      route = '/upload-image';
      break;
    case UploadType.audio:
      route = '/upload-audio';
      break;
    case UploadType.video:
      route = '/upload-video';
      break;
  }

  Navigator.pushNamed(context, route).then((shouldRefresh) {
    if (shouldRefresh == true) {
      onUploadComplete();
    }
  });
}
