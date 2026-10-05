---
name: ai-remote-release
description: Prepare and verify an AI Remote Android release, including versioning, permissions, signing readiness, APK or AAB builds, changelog, and artifact checks. Use for release candidates and Play Store delivery; do not invoke for ordinary feature development.
---

# AI Remote Release

Prepare a reproducible Android release without silently publishing it.

## Release checks

- Confirm the intended release scope and inspect the current `version` in `pubspec.yaml`.
- Increase both the semantic version and build number as required; never reuse an uploaded Android `versionCode`.
- Review Android permissions against implemented features, especially microphone, Bluetooth, notifications, foreground services, and network access. Remove unjustified permissions rather than adding broad ones preemptively.
- Confirm production builds do not embed long-lived API keys, test endpoints, or development secrets.
- Run formatting, analysis, and the full test suite before building.
- Build the requested artifact with Flutter, normally `C:\src\flutter\bin\flutter.bat build appbundle --release` for Play Store delivery or `C:\src\flutter\bin\flutter.bat build apk --release` for direct testing.
- Verify the artifact path, size, timestamp, package identity, version metadata, and signing state when tooling permits.
- Write release notes that distinguish implemented behavior from planned realtime, wearable, backend, or live-AI functionality.

Do not upload, publish, promote a testing track, or change store listings unless the user explicitly asks for that external action. Report whether validation covered only source/build output or also installation and real-device behavior.
