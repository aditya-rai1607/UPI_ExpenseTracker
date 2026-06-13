import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/transaction_model.dart';
import '../services/app_settings_service.dart';
import '../services/sms_listener_service.dart';
import 'category_settings_screen.dart';

class MoreScreen extends StatefulWidget {
  const MoreScreen({super.key});

  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> {
  bool _smsEnabled = false;

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    _refreshSmsState();
  }

  Future<void> _refreshSmsState() async {
    final granted = await SmsListenerService.isPermissionGranted();
    if (mounted) setState(() => _smsEnabled = granted);
  }

  Future<void> _toggleSms(bool value) async {
    if (!_isAndroid) return;
    if (value) {
      final smsGranted = await SmsListenerService.requestSmsPermission();
      if (smsGranted) {
        final notificationGranted =
            await SmsListenerService.requestNotificationPermission();
        if (notificationGranted) {
          SmsListenerService.startListening();
          if (mounted) setState(() => _smsEnabled = true);
        } else if (mounted) {
          setState(() => _smsEnabled = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Notification permission is required. Grant it in Android Settings to enable auto-detect.',
              ),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'SMS permission denied. Grant it in Android Settings to enable auto-detect.',
              ),
            ),
          );
        }
      }
    } else {
      // SMS listening cannot be stopped programmatically once started;
      // inform the user to revoke via system settings.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'To stop SMS auto-detect, revoke the SMS permission in Android Settings.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _openCategorySettings(
    BuildContext context,
    String title,
    TransactionType type,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CategorySettingsScreen(title: title, type: type),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settingsBox = Hive.box(AppSettingsService.settingsBoxName);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 0,
        title: Text(
          'More',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: ValueListenableBuilder(
          valueListenable: settingsBox.listenable(
            keys: <String>[AppSettingsService.themeModeKey],
          ),
          builder: (context, _, __) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
              children: <Widget>[
                _MoreSection(
                  title: 'Category',
                  items: <_MoreItemData>[
                    _MoreItemData(
                      title: 'Expense Category Setting',
                      onTap: () => _openCategorySettings(
                        context,
                        'Expense Categories',
                        TransactionType.debit,
                      ),
                    ),
                    _MoreItemData(
                      title: 'Income Category Setting',
                      onTap: () => _openCategorySettings(
                        context,
                        'Income Categories',
                        TransactionType.credit,
                      ),
                    ),
                    _MoreItemData(
                      title: 'Investment Category Setting',
                      onTap: () => _openCategorySettings(
                        context,
                        'Investment Categories',
                        TransactionType.investment,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _MoreSection(
                  title: 'Setting',
                  items: <_MoreItemData>[
                    const _MoreItemData(title: 'Currency Setting'),
                    const _MoreItemData(title: 'Transaction Setting'),
                    _MoreItemData(
                      title: 'Dark Mode',
                      isToggle: true,
                      toggleValue:
                          AppSettingsService.getThemeMode() == ThemeMode.dark,
                      onToggleChanged: (value) {
                        AppSettingsService.setThemeMode(
                          value ? ThemeMode.dark : ThemeMode.light,
                        );
                      },
                    ),
                    if (_isAndroid)
                      _MoreItemData(
                        title: 'SMS Auto-detect',
                        subtitle:
                            'Automatically add bank transactions from SMS',
                        isToggle: true,
                        toggleValue: _smsEnabled,
                        onToggleChanged: _toggleSms,
                      ),
                    const _MoreItemData(title: 'Language Setting'),
                  ],
                ),
                const SizedBox(height: 14),
                _MoreSection(
                  title: 'Help',
                  items: <_MoreItemData>[
                    const _MoreItemData(title: 'Help'),
                    const _MoreItemData(title: 'FeedBack'),
                    const _MoreItemData(title: 'Rate Us'),
                    const _MoreItemData(title: 'Remove Ad'),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MoreSection extends StatelessWidget {
  const _MoreSection({required this.title, required this.items});

  final String title;
  final List<_MoreItemData> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _MoreScreenStateColors.surfaceColor(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _MoreScreenStateColors.softBorderColor(context),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: _MoreScreenStateColors.textColor(context),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          ...items.map((item) => _MoreItem(item: item)),
        ],
      ),
    );
  }
}

class _MoreItem extends StatelessWidget {
  const _MoreItem({required this.item});

  final _MoreItemData item;

  @override
  Widget build(BuildContext context) {
    final trailing = item.isToggle
        ? Switch.adaptive(
            value: item.toggleValue,
            onChanged: item.onToggleChanged,
          )
        : Icon(
            Icons.chevron_right_rounded,
            color: _MoreScreenStateColors.mutedTextColor(context),
          );

    return ListTile(
      onTap: item.isToggle ? null : item.onTap,
      contentPadding: EdgeInsets.zero,
      title: Text(
        item.title,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: _MoreScreenStateColors.textColor(context),
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: item.subtitle == null
          ? null
          : Text(
              item.subtitle!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: _MoreScreenStateColors.mutedTextColor(context),
              ),
            ),
      trailing: trailing,
    );
  }
}

class _MoreItemData {
  const _MoreItemData({
    required this.title,
    this.subtitle,
    this.onTap,
    this.isToggle = false,
    this.toggleValue = false,
    this.onToggleChanged,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool isToggle;
  final bool toggleValue;
  final ValueChanged<bool>? onToggleChanged;
}

class _MoreScreenStateColors {
  static Color surfaceColor(BuildContext context) =>
      Theme.of(context).cardColor;
  static Color textColor(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface;
  static Color mutedTextColor(BuildContext context) =>
      Theme.of(context).colorScheme.onSurfaceVariant;
  static Color softBorderColor(BuildContext context) =>
      Theme.of(context).dividerColor;
}
