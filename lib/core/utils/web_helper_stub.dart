/// Stub for non-web platforms - uses file_picker and path_provider
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

void downloadJson(String jsonString, String filename) async {
  try {
    // Let user pick save location
    final result = await FilePicker.platform.saveFile(
      dialogTitle: 'Save Backup',
      fileName: filename,
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result != null) {
      final file = File(result);
      await file.writeAsString(jsonString);
    } else {
      // Fallback: save to documents directory
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$filename');
      await file.writeAsString(jsonString);
    }
  } catch (e) {
    // Fallback: save to documents directory
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$filename');
      await file.writeAsString(jsonString);
    } catch (_) {}
  }
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
    if (file.bytes != null) {
      final base64Str = base64Encode(file.bytes!);
      final ext = file.extension ?? 'png';
      return 'data:image/$ext;base64,$base64Str';
    }
    return null;
  } catch (_) {
    return null;
  }
}
