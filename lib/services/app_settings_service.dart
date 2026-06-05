import 'package:hive_flutter/hive_flutter.dart';

class AppSettingsService {
  static const String settingsBoxName = 'app_settings';
  static const String googleSheetsEndpointKey = 'google_sheets_endpoint';
  static const String lastBackupAtKey = 'last_backup_at';

  static Box<dynamic> get _box => Hive.box(settingsBoxName);

  static String? getGoogleSheetsEndpoint() {
    final value = _box.get(googleSheetsEndpointKey)?.toString().trim();
    if (value == null || value.isEmpty) {
      return null;
    }
    return value;
  }

  static Future<void> setGoogleSheetsEndpoint(String endpoint) async {
    await _box.put(googleSheetsEndpointKey, endpoint.trim());
  }

  static DateTime? getLastBackupAt() {
    final raw = _box.get(lastBackupAtKey)?.toString();
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return DateTime.tryParse(raw);
  }

  static Future<void> setLastBackupAt(DateTime dateTime) async {
    await _box.put(lastBackupAtKey, dateTime.toIso8601String());
  }
}
