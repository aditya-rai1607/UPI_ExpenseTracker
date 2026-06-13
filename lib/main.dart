import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

import 'screens/dashboard_screen.dart';
import 'screens/permissions_onboarding_screen.dart';
import 'services/app_settings_service.dart';
import 'services/category_service.dart';
import 'services/notification_service.dart';
import 'services/sms_listener_service.dart';
import 'services/native_sms_bridge.dart';
import 'services/sms_transaction_parser.dart';
import 'models/transaction_model.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('transactions');
  await Hive.openBox(AppSettingsService.settingsBoxName);
  await Hive.openBox(CategoryService.categoriesBoxName);
  await Hive.openBox(CategoryService.merchantRulesBoxName);
  await CategoryService.ensureDefaults();

  // Initialise notification service (registers tap-to-navigate handler).
  await NotificationService.init(appNavigatorKey);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF6C63FF),
      brightness: brightness,
    );
    final baseTextTheme = GoogleFonts.interTextTheme(
      isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: isDark
          ? const Color(0xFF0F1117)
          : const Color(0xFFF8F9FD),
      cardColor: isDark ? const Color(0xFF171B24) : Colors.white,
      dividerColor: isDark ? const Color(0xFF2A3140) : const Color(0xFFE5E7EB),
      appBarTheme: AppBarTheme(
        backgroundColor: isDark
            ? const Color(0xFF0F1117)
            : const Color(0xFFF8F9FD),
        foregroundColor: isDark
            ? const Color(0xFFF5F7FB)
            : const Color(0xFF111827),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? const Color(0xFF171B24) : Colors.white,
      ),
      bottomAppBarTheme: BottomAppBarThemeData(
        color: isDark ? const Color(0xFF171B24) : Colors.white,
      ),
      textTheme: baseTextTheme.copyWith(
        headlineMedium: GoogleFonts.inter(
          fontSize: 34,
          fontWeight: FontWeight.w700,
          color: isDark ? const Color(0xFFF5F7FB) : const Color(0xFF111827),
        ),
        headlineSmall: GoogleFonts.inter(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: isDark ? const Color(0xFFF5F7FB) : const Color(0xFF111827),
        ),
        titleLarge: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: isDark ? const Color(0xFFF5F7FB) : const Color(0xFF111827),
        ),
        titleMedium: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: isDark ? const Color(0xFFF5F7FB) : const Color(0xFF111827),
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: isDark ? const Color(0xFFE5E7EB) : const Color(0xFF111827),
        ),
        bodySmall: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settingsBox = Hive.box(AppSettingsService.settingsBoxName);

    return ValueListenableBuilder<Box<dynamic>>(
      valueListenable: settingsBox.listenable(),
      builder: (context, _, __) {
        return MaterialApp(
          navigatorKey: appNavigatorKey,
          title: 'UPI Expense Tracker',
          theme: _buildTheme(Brightness.light),
          darkTheme: _buildTheme(Brightness.dark),
          themeMode: AppSettingsService.getThemeMode(),
          home: const _HomeSelector(),
          routes: {
            '/dashboard': (context) => const DashboardScreen(),
            '/permissions': (context) => const PermissionsOnboardingScreen(),
          },
        );
      },
    );
  }
}

/// Widget that decides whether to show permissions onboarding or dashboard
/// based on SMS permission status.
class _HomeSelector extends StatefulWidget {
  const _HomeSelector();

  @override
  State<_HomeSelector> createState() => _HomeSelectorState();
}

class _HomeSelectorState extends State<_HomeSelector>
    with WidgetsBindingObserver {
  late Future<bool> _permissionCheckFuture;

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _permissionCheckFuture = _checkAndResumeSmsListener();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _drainNativeQueue();
    }
  }

  Future<bool> _checkAndResumeSmsListener() async {
    if (!_isAndroid) {
      return true; // Non-Android platforms skip permission check
    }

    // Require both SMS and notification permissions at startup.
    final smsPermissionStatus = await Permission.sms.status;
    final notificationPermissionStatus = await Permission.notification.status;

    if (smsPermissionStatus.isGranted &&
        notificationPermissionStatus.isGranted) {
      // Required permissions granted; resume listener.
      SmsListenerService.startListening();
      // Drain any transactions processed natively while app was closed.
      _drainNativeQueue();
      return true;
    }

    // Any required permission missing; show onboarding.
    return false;
  }

  Future<void> _drainNativeQueue() async {
    try {
      final pending = await NativeSmsBridge.getPendingTransactions();
      if (pending.isEmpty) return;

      final box = Hive.box('transactions');

      for (final map in pending) {
        try {
          final txn = TransactionModel.fromMap(map);
          if (SmsTransactionParser.isDuplicate(txn, box)) continue;

          final key = await box.add(txn.toMap());
          await NotificationService.showCategorizationPrompt(txn, key);
        } catch (_) {
          // Ignore malformed entries
        }
      }
    } catch (_) {
      // best-effort
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _permissionCheckFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // If SMS permission is granted, show dashboard; otherwise show onboarding
        if (snapshot.data == true) {
          return const DashboardScreen();
        } else {
          return const PermissionsOnboardingScreen();
        }
      },
    );
  }
}
