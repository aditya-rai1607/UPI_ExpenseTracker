import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../services/app_settings_service.dart';

class StyleSettingsScreen extends StatelessWidget {
  const StyleSettingsScreen({super.key});

  String _systemSubtitle(BuildContext context) {
    return MediaQuery.platformBrightnessOf(context) == Brightness.dark
        ? 'Currently following system dark mode'
        : 'Currently following system light mode';
  }

  Future<void> _setThemeMode(ThemeMode mode) async {
    await AppSettingsService.setThemeMode(mode);
  }

  @override
  Widget build(BuildContext context) {
    final settingsBox = Hive.box(AppSettingsService.settingsBoxName);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 0,
        title: Text(
          'Style',
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: ValueListenableBuilder<Box<dynamic>>(
          valueListenable: settingsBox.listenable(),
          builder: (context, _, __) {
            final selectedMode = AppSettingsService.getThemeMode();

            return ListView(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: theme.dividerColor),
                  ),
                  child: Column(
                    children: <Widget>[
                      RadioListTile<ThemeMode>(
                        value: ThemeMode.system,
                        groupValue: selectedMode,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('System Mode'),
                        subtitle: Text(_systemSubtitle(context)),
                        onChanged: (value) {
                          if (value != null) {
                            _setThemeMode(value);
                          }
                        },
                      ),
                      const Divider(),
                      RadioListTile<ThemeMode>(
                        value: ThemeMode.dark,
                        groupValue: selectedMode,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Dark Mode'),
                        subtitle: const Text('Use the dark theme in the app'),
                        onChanged: (value) {
                          if (value != null) {
                            _setThemeMode(value);
                          }
                        },
                      ),
                      const Divider(),
                      RadioListTile<ThemeMode>(
                        value: ThemeMode.light,
                        groupValue: selectedMode,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Light Mode'),
                        subtitle: const Text('Use the light theme in the app'),
                        onChanged: (value) {
                          if (value != null) {
                            _setThemeMode(value);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
