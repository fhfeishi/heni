# Paused Platform Development Log

Last updated: 2026-05-13

## Status

Android, iOS, macOS, and Ubuntu/Linux development is paused. The shared Flutter
code should continue to stay portable, but no platform-specific work should be
prioritized until Windows is stable.

## Shared Work Completed

- Flutter application scaffold exists for:
  - Android
  - iOS
  - macOS
  - Linux
- Shared Dart layers are platform-neutral:
  - App startup and routing.
  - Theme palettes.
  - Media domain models.
  - Scenery domain model.
  - Playback abstraction.
  - FFmpeg command builder.
  - ffprobe parser.
  - FFmpeg progress parser.
  - Media editor use case.
- Unit tests run on the host VM and cover the shared media tooling.

## Android

Current progress:

- `android/` scaffold has been generated.
- No Android build has been run.
- No storage permission, media picker, or FFmpeg packaging strategy has been
  designed yet.

Known blocker:

- `flutter doctor` reports Android SDK is not configured.

Resume checklist:

1. Install Android Studio and Android SDK.
2. Configure `flutter config --android-sdk` if the SDK is in a custom path.
3. Run `flutter doctor -v`.
4. Decide media file access strategy for modern Android storage rules.
5. Decide whether Android uses system FFmpeg alternatives, bundled FFmpeg, or
   a mobile-specific package.
6. Run `flutter build apk` and device smoke tests.

## iOS

Current progress:

- `ios/` scaffold has been generated.
- No iOS build has been run.
- No iOS entitlements, sandbox, or file picker behavior has been validated.

Known blocker:

- iOS builds require macOS and Xcode.

Resume checklist:

1. Open the project on macOS.
2. Run `flutter doctor -v`.
3. Configure signing and bundle identifier.
4. Validate local file access and document picker behavior.
5. Decide FFmpeg packaging and licensing approach for iOS.
6. Run simulator and physical-device smoke tests.

## macOS

Current progress:

- `macos/` scaffold has been generated.
- No macOS build has been run.
- No sandbox entitlement review has been done.

Known blocker:

- macOS builds require macOS and Xcode.

Resume checklist:

1. Build with `flutter build macos`.
2. Check file picker entitlements.
3. Test media playback and scenery file access.
4. Decide signed/notarized distribution strategy.

## Ubuntu / Linux

Current progress:

- `linux/` scaffold has been generated.
- No Linux build has been run.
- No package dependencies have been validated.

Known blocker:

- Build needs a Linux environment with GTK, CMake, Ninja, and media runtime
  dependencies.

Resume checklist:

1. Build on Ubuntu with `flutter build linux`.
2. Confirm native dependencies for `media_kit`.
3. Verify file picker behavior and FFmpeg/ffprobe discovery.
4. Decide packaging format: tarball, deb, AppImage, or Flatpak.
