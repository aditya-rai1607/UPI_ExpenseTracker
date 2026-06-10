# upi_expense_tracker

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Android release build

This project vendors the working Android patch for `telephony` under `third_party/telephony`.

Before building a release APK, run:

```powershell
powershell -ExecutionPolicy Bypass -File .\tooling\build_release_apk.ps1
```

This reapplies the Android patch to the hosted `telephony` package in pub cache and then runs the release build.
