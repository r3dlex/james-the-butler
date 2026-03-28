# Mobile Specification (Dart/Flutter)

## Purpose

The mobile client provides a native experience on iOS and Android for James the Butler.

## Technology

- **SDK**: Flutter 3.x / Dart 3.x
- **State Management**: Riverpod
- **HTTP**: dio
- **WebSocket**: Phoenix channels Dart client
- **Testing**: flutter_test, mockito

## Key Features

- Native mobile UI following Material 3 / Cupertino guidelines
- Push notifications
- Offline-first data caching with sync-on-reconnect
- Biometric authentication support

## Zero-Install

```bash
cd mobile
flutter pub get   # Install dependencies declared in pubspec.yaml
```

No global Dart packages required beyond the Flutter SDK.

## API Integration

Same backend API as the web frontend (REST + WebSocket). Shared API contract ensures parity.

## Testing

```bash
flutter test              # Unit and widget tests
flutter analyze           # Static analysis
dart format --set-exit-if-changed .  # Format check
```

## Internal Details

See `mobile/spec/README.md` for widget tree, navigation structure, and platform-specific considerations.
