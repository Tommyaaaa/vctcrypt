# VCTCrypt

Triple AES-256-GCM file encryption with a modern Flutter (Material Design 3) UI — one codebase, five platforms: Windows, macOS, Linux, Android, iOS.

三重 AES-256-GCM 文件加密工具，采用 Flutter (Material Design 3) 界面，一套代码支持 Windows / macOS / Linux / Android / iOS。

## Features

- **Triple AES-256-GCM** (`VCT-Crypt`): three independent key layers, PBKDF2-SHA256 with 600,000 iterations
- **Decoy partition** (v1.1.0): a second password reveals an innocent decoy file instead of the real one
- **Duress password** (v1.1.0): entering it during decryption permanently shreds the encrypted file
- **Deniable by design**: every V2 file always contains all three slots — nobody can prove a decoy or duress password exists
- **Secure shred** (v1.1.0): overwrite the original with random data after verified encryption
- **Auto-lock** (v1.1.0): clear entered passwords after inactivity (1/5/10/30 min)
- **Password generator** (v1.2.0): CSPRNG-based, per-class guarantees, live entropy estimation
- **File inspector** (v1.2.0): read .VCT header metadata without any password (format, sizes, algorithm) — never leaks slot usage
- **Usage statistics** (v1.2.0): local-only counters (files, bytes, decoys, duress triggers); no names, no paths, no telemetry
- **Panic lock** (v1.2.0): one tap wipes every password field in the app
- **Onboarding & help center** (v1.3.0): a 4-page first-launch guide plus an expandable FAQ covering every feature
- **Batch encryption** (v1.3.0): encrypt many files in one run with per-file results and retry-friendly failures
- **Clipboard auto-clear** (v1.3.0): KeePass-style — copied passwords are wiped from the clipboard automatically
- **Personalization** (v1.3.0): 8 accent colors, choice of start page, bilingual UI
- **Bilingual UI**: English / 简体中文, light / dark / system themes
- **Desktop & mobile layouts**: NavigationRail on wide screens, NavigationBar on phones; drag-and-drop on desktop

## File format

| Version | Magic | Notes |
|---------|-------|-------|
| V1 | `VCTCRYPT1\0\0\0` | Classic triple-GCM format, byte-compatible with the CLI releases |
| V2 | `VCTCRYPT2\0\0\0` | Adds always-present decoy + duress slots (332-byte header) |

The V1 and V2 formats are fully interoperable: VCTCrypt decrypts both; files encrypted without advanced options keep using V1 for maximum compatibility.

## Building

Automated builds for all five platforms run on GitHub Actions (`.github/workflows/build.yml`): Windows EXE, macOS DMG, iOS IPA (unsigned), Android APK, Linux AppImage.

Local development:

```bash
flutter pub get
flutter run          # or: flutter run -d windows / macos / linux / chrome
```

## Version history

- **1.3.0** — Onboarding guide & help center · batch encryption · clipboard auto-clear · accent colors · start page preference
- **1.2.0** — Password generator with entropy meter · passwordless .VCT file inspector · local usage statistics · panic lock
- **1.1.0** — Decoy partition · duress password · secure shred · auto-lock · V2 file format
- **1.0.x** — Flutter rewrite (Win32 GUI → Material 3), five-platform CI, V1/CLI format compatibility

## Author

Tommy
