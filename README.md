# bucket_app

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## CI

This repository includes a GitHub Actions workflow that runs `flutter analyze`, `flutter test` (if a `test/` directory exists), and builds an Android APK on pushes and pull requests to `main`/`master`.

### Local commands

- Install dependencies: `flutter pub get`
- Run analyzer: `flutter analyze`
- Run tests: `flutter test`
- Build release APK: `flutter build apk --release`
