import 'dart:io';
import 'package:path/path.dart' as p;
import 'database_helper.dart';

/// Load saved data path from config file (Windows only)
Future<void> loadDataPathConfig() async {
  try {
    final configPath = _getConfigFilePath();
    if (configPath.isEmpty) return;
    
    final configFile = File(configPath);
    if (configFile.existsSync()) {
      final savedPath = configFile.readAsStringSync().trim();
      if (savedPath.isNotEmpty) {
        DatabaseHelper.setDataPath(savedPath);
      }
    } else {
      // Default path
      const defaultPath = r'D:\My_billu\data';
      final dir = Directory(defaultPath);
      if (!dir.existsSync()) dir.createSync(recursive: true);
      DatabaseHelper.setDataPath(defaultPath);
      // Save default to config
      configFile.parent.createSync(recursive: true);
      configFile.writeAsStringSync(defaultPath);
    }
  } catch (_) {
    // Fallback to default sqflite path if config read fails
  }
}

String _getConfigFilePath() {
  if (Platform.isWindows) {
    final exeDir = p.dirname(Platform.resolvedExecutable);
    return p.join(exeDir, 'mybillu_config.txt');
  }
  return '';
}

/// Save the data path to the config file and reinitialize the DB
Future<void> saveAndApplyDataPath(String newPath) async {
  // Create directory
  final dir = Directory(newPath);
  if (!dir.existsSync()) dir.createSync(recursive: true);

  // Save config file
  final exeDir = p.dirname(Platform.resolvedExecutable);
  final configFile = File(p.join(exeDir, 'mybillu_config.txt'));
  configFile.writeAsStringSync(newPath);

  // Reinitialize database
  await DatabaseHelper.instance.reinitializeWithPath(newPath);
}

/// Get the platform path separator
String get pathSeparator => Platform.pathSeparator;

