/// Stub for non-web platforms - uses file_picker, path_provider, share_plus
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

void downloadJson(String jsonString, String filename) async {
  try {
    // Save to temp file first
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsString(jsonString);

    // Try desktop save dialog first
    try {
      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Backup',
        fileName: filename,
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (result != null) {
        final saveFile = File(result);
        await saveFile.writeAsString(jsonString);
        return;
      }
    } catch (_) {
      // saveFile not supported on this platform (Android)
    }

    // Fallback: Share the file (works on Android)
    final xFile = XFile(
      file.path,
      name: filename,
      mimeType: 'application/json',
    );
    await Share.shareXFiles(
      [xFile],
      subject: 'My Billu Backup',
      text: 'My Billu data backup file',
    );
  } catch (_) {}
}

Future<String?> triggerFileUpload() async {
  try {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.first;
    if (file.bytes != null) {
      return utf8.decode(file.bytes!);
    }
    if (file.path != null) {
      return await File(file.path!).readAsString();
    }
    return null;
  } catch (_) {
    return null;
  }
}

Future<String?> triggerImageUpload() async {
  try {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.first;
    List<int>? bytes = file.bytes;
    // On Android, bytes may be null — read from path
    if (bytes == null && file.path != null) {
      bytes = await File(file.path!).readAsBytes();
    }
    if (bytes != null) {
      final base64Str = base64Encode(bytes);
      final ext = file.extension ?? 'png';
      return 'data:image/$ext;base64,$base64Str';
    }
    return null;
  } catch (_) {
    return null;
  }
}


