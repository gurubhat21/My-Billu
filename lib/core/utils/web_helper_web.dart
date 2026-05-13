// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:convert';

void downloadJson(String jsonString, String filename) {
  final bytes = utf8.encode(jsonString);
  final blob = html.Blob([bytes], 'application/json');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
}

Future<String?> triggerFileUpload() async {
  final input = html.FileUploadInputElement()..accept = '.json';
  input.click();
  await input.onChange.first;
  if (input.files == null || input.files!.isEmpty) return null;
  final reader = html.FileReader();
  reader.readAsText(input.files!.first);
  await reader.onLoadEnd.first;
  return reader.result as String?;
}

/// Upload image (png/jpeg) and return as base64 data URL
Future<String?> triggerImageUpload() async {
  final input = html.FileUploadInputElement()..accept = 'image/png,image/jpeg';
  input.click();
  await input.onChange.first;
  if (input.files == null || input.files!.isEmpty) return null;
  final reader = html.FileReader();
  reader.readAsDataUrl(input.files!.first);
  await reader.onLoadEnd.first;
  return reader.result as String?;
}


