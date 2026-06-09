import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/material.dart';

class AppSettingsService {
  static const String settingsBoxName = 'app_settings';
  static const String googleSheetsEndpointKey = 'google_sheets_endpoint';
  static const String lastBackupAtKey = 'last_backup_at';
  static const String themeModeKey = 'theme_mode';
  static const String systemThemeMode = 'system';
  static const String lightThemeMode = 'light';
  static const String darkThemeMode = 'dark';

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

  static ThemeMode getThemeMode() {
    return switch (_box.get(themeModeKey)?.toString()) {
      lightThemeMode => ThemeMode.light,
      darkThemeMode => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  static String getThemeModeName() {
    return switch (getThemeMode()) {
      ThemeMode.light => lightThemeMode,
      ThemeMode.dark => darkThemeMode,
      ThemeMode.system => systemThemeMode,
    };
  }

  static Future<void> setThemeMode(ThemeMode mode) async {
    final value = switch (mode) {
      ThemeMode.light => lightThemeMode,
      ThemeMode.dark => darkThemeMode,
      ThemeMode.system => systemThemeMode,
    };
    await _box.put(themeModeKey, value);
  }
}
