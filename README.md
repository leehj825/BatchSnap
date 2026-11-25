# BatchSnap

Batch photo compressor & format converter (100% offline, no interstitial ads) — Flutter / Android.

## Getting started

This repository contains only `lib/` and `pubspec.yaml`; there is no `android/` platform folder. Generate it once:

```bash
flutter create --platforms=android --org com.batchsnap --project-name batchsnap .
flutter pub get
```

Then raise `minSdk` to **24 or higher** in `android/app/build.gradle(.kts)` (required by `gal`), and add the
following inside `<manifest>` in `android/app/src/main/AndroidManifest.xml`. It is only needed for saving to the
gallery on Android 9 and below; no broad storage permission is used.

```xml
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" android:maxSdkVersion="28"/>
```

```bash
flutter run
```

## Structure

| Path | Role |
| :-- | :-- |
| `lib/services/compress_service.dart` | Target-size binary search + resolution downscaling, sequential processing |
| `lib/services/app_state.dart` | Pro status, conversion history, temp cache cleanup |
| `lib/services/picker.dart` | Multi-select via the system photo picker |
| `lib/screens/` | Home / Batch setup / Progress & result / Before-after compare |

## Not implemented yet

- Real AdMob banner (placeholder in `AdBannerPlaceholder`) and `in_app_purchase` billing (Pro is currently a test toggle)
- Deleting originals after conversion (the system picker does not expose gallery asset IDs; switch to `wechat_assets_picker`)
- Localization (English only for now)

## Release (prerelease APK)

`.github/workflows/release-apk.yml` builds a release APK and publishes it as a GitHub **prerelease**.

- Push a tag: `git tag v0.1.0 && git push origin v0.1.0`
- Or run the workflow manually from the Actions tab (tag becomes `prerelease-<run number>`).

The APK is signed with the default debug key, which is fine for testing but not for Play Store upload.
