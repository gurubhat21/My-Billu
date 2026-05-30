import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Save file on native platforms
/// Windows/macOS/Linux: Opens save dialog to choose location
/// Android/iOS: Opens share sheet
Future<void> saveFile(Uint8List bytes, String fileName, String mimeType) async {
  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    // Desktop: Use file picker save dialog
    final result = await FilePicker.platform.saveFile(
      dialogTitle: 'Save $fileName',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: [fileName.split('.').last],
    );
    if (result != null) {
      final file = File(result);
      await file.writeAsBytes(bytes);
      // Open the file after saving
      await Process.run('explorer.exe', ['/select,', result]);
    }
  } else {
    // Mobile: Share the file
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: mimeType)],
      subject: fileName,
    );
  }
}
