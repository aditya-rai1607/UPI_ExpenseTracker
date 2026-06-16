import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:upi_expense_tracker/main.dart';
import 'package:upi_expense_tracker/screens/dashboard_screen.dart';
import 'package:upi_expense_tracker/services/app_settings_service.dart';
import 'package:upi_expense_tracker/services/category_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final testHivePath =
        '${Directory.systemTemp.path}${Platform.pathSeparator}upi_tracker_hive_test';
    Hive.init(testHivePath);
    await Hive.openBox('transactions');
    await Hive.openBox(AppSettingsService.settingsBoxName);
    await Hive.openBox(CategoryService.categoriesBoxName);
    await Hive.openBox(CategoryService.merchantRulesBoxName);
    await CategoryService.ensureDefaults();
  });

  tearDownAll(() async {
    await Hive.close();
  });

  testWidgets('App loads dashboard shell', (WidgetTester tester) async {
    // Pump the DashboardScreen directly to avoid permission checks in _HomeSelector.
    await tester.pumpWidget(const MaterialApp(home: DashboardScreen()));
    // Avoid pumpAndSettle which can time out due to background animations.
    // Instead pump in short increments until the expected widgets appear.
    var found = false;
    for (var i = 0; i < 50; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (find.text('Hey Aditya!').evaluate().isNotEmpty &&
          find.text('Import').evaluate().isNotEmpty) {
        found = true;
        break;
      }
    }

    expect(found, isTrue, reason: 'Dashboard did not appear in time');
  });
}
