# iFriends 🔥

Vibrant social media UI built with Flutter (orange / pink / coral gradient theme).

## Run locally
```bash
flutter pub get
flutter create --platforms=android .   # generate android/ folder on first checkout
flutter run
```

## Build APK via GitHub Actions
Push the repo to GitHub. The workflow `.github/workflows/flutter-build.yml` runs automatically and produces `app-release.apk` as a downloadable artifact (`ifriends-release-apk`).

## Structure
- `lib/main.dart` — entry point + bottom nav shell
- `lib/theme/` — gradient + color tokens
- `lib/screens/` — Feed, Profile, Create Post
- `lib/widgets/` — reusable cards & components
- `lib/models/mock_data.dart` — rich mock dataset
