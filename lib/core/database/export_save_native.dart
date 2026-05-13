import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Save file on native (Android/Windows) — opens share dialog or saves to downloads
Future<void> saveFile(Uint8List bytes, String fileName, String mimeType) async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/$fileName');
  await file.writeAsBytes(bytes);

  // Share the file so user can save/send it
  await Share.shareXFiles(
    [XFile(file.path, mimeType: mimeType)],
    subject: fileName,
  );
}


