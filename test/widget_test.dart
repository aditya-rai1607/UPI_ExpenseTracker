import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:upi_expense_tracker/main.dart';
import 'package:upi_expense_tracker/services/category_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final testHivePath =
        '${Directory.systemTemp.path}${Platform.pathSeparator}upi_tracker_hive_test';
    Hive.init(testHivePath);
    await Hive.openBox('transactions');
    await Hive.openBox(CategoryService.categoriesBoxName);
    await Hive.openBox(CategoryService.merchantRulesBoxName);
    await CategoryService.ensureDefaults();
  });

  tearDownAll(() async {
    await Hive.close();
  });

  testWidgets('App loads dashboard shell', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('UPI Expense Tracker'), findsOneWidget);
    expect(find.byIcon(Icons.upload_file), findsOneWidget);
  });
}
