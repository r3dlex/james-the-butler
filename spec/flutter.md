# Mobile Specification (Dart/Flutter)

For the full platform specification, see [platform.md](platform.md) §4.3.

## Purpose

The mobile client (`james-mobile`) is a remote viewer and controller for James the Butler on iOS and Android. It does not run agents locally — it connects to your running James instance.

## Technology

- **SDK**: Flutter 3.x / Dart 3.x
- **State Management**: Riverpod
- **HTTP**: dio
- **WebSocket**: Phoenix channels Dart client
- **WebRTC**: flutter_webrtc for computer use live stream
- **Secure Storage**: iOS Keychain / Android Keystore
- **Testing**: flutter_test, mockito

## Key Features

- **QR host binding**: One-time scan binds to a specific host. Token is signed, 5-minute expiry, single-use. Stored in device secure enclave as a named computer profile.
- **Multi-host switching**: Bind to multiple hosts. Switch from app settings. Each host shows its sessions independently.
- **Session management**: List, search, resume, create sessions across all bound hosts
- **Live stream**: WebRTC for computer use sessions. H.264 via PipeWire/Wayland capture. Adaptive resolution/frame rate.
- **Execution mode**: Tap-to-confirm for destructive tasks in Confirmed mode
- **Planner view**: Task list with risk levels and live status
- **Memory browse**: View and search memories from mobile
- **Telegram-equivalent access**: Full platform capabilities via the API

## Zero-Install

```bash
cd mobile
flutter pub get   # Install dependencies
```

## Testing

```bash
flutter test              # Unit and widget tests
flutter test --coverage   # With coverage (target: 70%)
flutter analyze           # Static analysis
dart format --set-exit-if-changed .
```

## Internal Details

See `mobile/spec/README.md` for widget tree, navigation, WebRTC integration, and host binding flow.
