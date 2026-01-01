import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class DownloadHelper {
  static Future<void> downloadFile(String url, String fileName) async {
    if (url.isEmpty) throw Exception("Invalid URL");

    // Ask storage permission (especially on Android)
    if (Platform.isAndroid) {
      var status = await Permission.storage.request();
      if (!status.isGranted) {
        throw Exception("Storage permission denied");
      }
    }

    final directory = await getExternalStorageDirectory();
    if (directory == null) throw Exception("Unable to access storage");

    final filePath = '${directory.path}/$fileName.jpg';

    final dio = Dio();
    await dio.download(url, filePath);
  }
}
