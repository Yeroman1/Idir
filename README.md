# Idir App — Phase 1 Setup Complete 🎉

## What was built (Phase 1)

### Project structure
```
idir_app/
├── lib/
│   ├── main.dart                          # App entry + Firebase init + Riverpod
│   ├── core/
│   │   ├── constants/app_constants.dart   # All magic strings
│   │   ├── firebase/
│   │   │   ├── firebase_options.dart      # ⚠️ Replace with flutterfire configure output
│   │   │   └── firestore_provider.dart    # Offline persistence enabled
│   │   ├── models/app_user.dart           # AppUser + UserRole + permission helpers
│   │   ├── providers/locale_provider.dart # Language switching
│   │   ├── router/
│   │   │   ├── app_router.dart            # GoRouter + auth redirect guard
│   │   │   └── shell_route.dart           # Bottom nav shell
│   │   └── theme/app_theme.dart           # Material 3 + Ethiopian palette + dark mode
│   ├── l10n/
│   │   ├── app_en.arb                     # English
│   │   ├── app_am.arb                     # Amharic
│   │   └── app_om.arb                     # Afan Oromo
│   └── features/
│       ├── auth/presentation/screens/login_screen.dart
│       ├── home/presentation/screens/home_screen.dart
│       ├── members/presentation/screens/members_screen.dart
│       ├── contributions/presentation/screens/contributions_screen.dart
│       ├── claims/presentation/screens/claims_screen.dart
│       └── more/presentation/screens/more_screen.dart
├── android/
│   ├── build.gradle                       # Firebase google-services plugin
│   ├── app/
│   │   ├── build.gradle                   # minSdk 21, Firebase BOM
│   │   ├── google-services.json           # ⚠️ Replace with your Firebase config
│   │   └── src/main/AndroidManifest.xml   # Internet + biometric permissions
├── assets/fonts/                          # ⚠️ Add NotoSansEthiopic .ttf files
├── pubspec.yaml
├── l10n.yaml
└── analysis_options.yaml
```

## Next steps before running

### 1. Firebase setup (required)
```bash
# Install FlutterFire CLI
dart pub global activate flutterfire_cli

# Configure (creates firebase_options.dart automatically)
flutterfire configure --project=YOUR_PROJECT_ID
```

### 2. Add Noto Sans Ethiopic fonts
Download from https://fonts.google.com/noto/specimen/Noto+Sans+Ethiopic
Place in `assets/fonts/`:
- `NotoSansEthiopic-Regular.ttf`
- `NotoSansEthiopic-Bold.ttf`

### 3. Install dependencies
```bash
cd idir_app
flutter pub get
flutter gen-l10n   # generates lib/generated/l10n/
```

### 4. Run
```bash
flutter run
```

## Design decisions
- **Teal-green (#1A6B5A)** primary — conveys trust, community, nature (Ethiopian highlands)
- **Warm amber (#D4821A)** secondary — warmth, Ethiopian culture
- **NotoSansEthiopic** font — supports Amharic fidel and Latin characters
- **Offline-first** — Firestore persistence enabled, sync indicator planned Phase 10
- **Append-only records** — enforced at Firestore Rules level (Phase 11)
- **Permission matrix** encoded in `UserRole` extension methods, enforced in UI + Rules
