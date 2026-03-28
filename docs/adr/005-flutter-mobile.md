# ADR-005: Flutter for mobile

## Status

Accepted

## Context

The mobile client must run on both iOS and Android with native performance. We need to decide between fully native development (Swift/Kotlin), a cross-platform framework, or a hybrid approach.

## Decision

Use **Flutter** with **Dart** for a single codebase targeting both iOS and Android.

Key technology choices:
- **Riverpod** for state management (compile-safe, testable)
- **GoRouter** for declarative navigation
- **dio** for HTTP networking
- **drift** for local SQLite storage (offline-first)
- **Material 3** with Cupertino adaptive widgets

## Consequences

- **Positive**: Single codebase for iOS and Android. Near-native performance via compiled Dart. Rich widget library. Strong typing with Dart. Good developer tooling (hot reload).
- **Negative**: Platform-specific features require plugins or platform channels. Flutter apps have a larger binary size than fully native apps. Dart ecosystem is smaller than Swift/Kotlin.
