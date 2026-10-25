# VCTCrypt

Triple AES-256-GCM file encryption with a modern Flutter (Material Design 3) UI — one codebase, five platforms: Windows, macOS, Linux, Android, iOS.

三重 AES-256-GCM 文件加密工具，采用 Flutter (Material Design 3) 界面，一套代码支持 Windows / macOS / Linux / Android / iOS。

## Features

- **Genuine Chữ Nôm UI & policies** (v2.3.1): the Han-Nom (𡸨喃) interface and the Han-Nom Privacy Policy / Terms are written in real Chữ Nôm — Vietnamese grammar and word order, generated through a free translation API instead of a word-for-word Chinese rendering
- **Checksum / hash tool** (v2.3.0): compute SHA-256 / SHA-512 / SHA-3-256 of any file — streamed, so huge files work without filling memory — and compare it against an expected value to verify integrity
- **Multilingual policies** (v2.3.0): Privacy Policy and Terms of Use are fully translated into all five UI languages
- **Five UI languages** (v2.2.5): English, 简体中文, Français, Deutsch and 𡸨喃 (Chữ Nôm / Han-Nom) — switchable in Settings; the Han-Nom UI is genuine Chữ Nôm with Vietnamese grammar and word order, not Traditional Chinese
- **Vertical language picker** (v2.2.5): the Settings language selector is a vertical list, so every language name — 𡸨喃 included — reads in full horizontally
- **Tianheng font bundled** (v2.2.1): TH-Feon (天珩全字庫, freeware) ships inside the app and renders Han-Nom and extended CJK glyphs (Unicode Ext B–F) that regular fonts lack; Chinese text is bumped two weight steps bolder for a clearer display
- **Verification-key hardening** (v2.1.0): the password verification key now uses the same 600K PBKDF2 iterations as the encryption keys, so offline password guessing is no easier than attacking the files themselves; files written by older versions remain fully compatible via automatic legacy fallback
- **Faster crypto on mobile** (v2.1.0): platform-native acceleration — Android gets native PBKDF2 and AES-GCM, iOS/macOS get native AES-GCM, desktop moves crypto off the UI thread. Same algorithms, same output
- **Triple AES-256-GCM** (`VCT-Crypt`): three independent key layers, PBKDF2-SHA256 with 600,000 iterations
- **Recipient keys / ML-KEM-768** (v1.6.0): optional post-quantum encryption (NIST FIPS 203). Generate a key pair on the Keys tab, encrypt to someone's `.vctpub` public key, open files with your `.vctkey` private key. The password becomes optional - dual-channel or key-only files
- **Decoy partition** (v1.1.0): a second password reveals an innocent decoy file instead of the real one
- **Duress password** (v1.1.0): entering it during decryption permanently shreds the encrypted file
- **Deniable by design**: every V2 file always contains all three slots — nobody can prove a decoy or duress password exists
- **Secure shred** (v1.1.0): overwrite the original with random data after verified encryption
- **Auto-lock** (v1.1.0): clear entered passwords after inactivity (1/5/10/30 min)
- **Password generator** (v1.2.0): CSPRNG-based, per-class guarantees, live strength estimation
- **File inspector** (v1.2.0): read .VCT header metadata without any password (format, sizes, algorithm) — never leaks slot usage
- **Usage statistics** (v1.2.0): local-only counters (files, bytes, decoys, duress triggers); no names, no paths, no telemetry
- **Panic lock** (v1.2.0): one tap wipes every password field in the app
- **Onboarding & help center** (v1.3.0): a 4-page first-launch guide plus an expandable FAQ covering every feature
- **Batch encryption** (v1.3.0): encrypt many files in one run with per-file results and retry-friendly failures
- **Clipboard auto-clear** (v1.3.0): KeePass-style — copied passwords are wiped from the clipboard automatically
- **Personalization** (v1.3.0): 8 accent colors, choice of start page, bilingual UI
- **iOS Files app fix + share sheet** (v1.4.0): outputs now use atomic writes (temp file + rename) so iOS's Files app reliably shows them in *On My iPhone → VCTCrypt*; a share/save button on the result cards stores files anywhere via the system sheet
- **App icon & name** (v1.4.0): Material Design shield, black on white; display name unified to VCTCrypt on all platforms
- **Other section** (v2.0.0): About (icon, name, website, author, AGPL-3.0 license), Donate (bundled Alipay QR — "free, open-source, ad-free; donate to support development"), Policies & Terms (offline privacy policy and terms of use), and a full Changelog — all bundled, zero network
- **Multilingual UI** (v2.2.5): English · 简体中文 · Français · Deutsch · 𡸨喃, light / dark / system themes
- **Desktop & mobile layouts**: NavigationRail on wide screens, NavigationBar on phones; drag-and-drop on desktop

## File format

| Version | Magic | Notes |
|---------|-------|-------|
| V1 | `VCTCRYPT1\0\0\0` | Classic triple-GCM format, byte-compatible with the CLI releases |
| V2 | `VCTCRYPT2\0\0\0` | Adds always-present decoy + duress slots (332-byte header) |
| V3 | `VCTCRYPT3\0\0\0` | Hybrid envelope: random CEK wrapped by password and/or ML-KEM-768 recipient key (1394-byte header) |

The V1 and V2 formats are fully interoperable: VCTCrypt decrypts both; files encrypted without advanced options keep using V1 for maximum compatibility. V3 is produced only when you encrypt to a recipient key; it is opened with the recipient private key (and optionally the password).

## Testing

The ML-KEM-768 implementation is cross-validated against Go's standard library (`crypto/mlkem`, FIPS 203): the same seed derives the same keys, Dart↔Go encapsulation/decapsulation agree, and tampered ciphertexts are implicitly rejected. Deterministic KAT vectors are checked in via `test/mlkem768_kat.json` (generated by `tool/mlkem_interop.dart`).

```bash
flutter test          # KAT + key containers + V1/V3 roundtrips + H1/H2 security tests
```

## Known limitations

- **V3 header flags** are stored in plaintext, and the Settings screen shows whether duress/decoy features are in use. This only matters if an adversary has physical access to your unlocked device; the ciphertext itself is unaffected.
- **Decoy of a very small file**: H2 makes the filler partition match the *real* partition, but if a decoy *is* configured and is much smaller than the real file, the length difference can still hint at it. Encrypt a decoy of similar size if that matters to you.

## Building

Automated builds for all five platforms run on GitHub Actions (`.github/workflows/build.yml`): Windows EXE, macOS DMG, iOS IPA (unsigned), Android APK, Linux AppImage.

Local development:

```bash
flutter pub get
flutter run          # or: flutter run -d windows / macos / linux / chrome
```

## Version history

- **2.4.0** — Security: **H1** decrypted file names are sanitized to a safe basename with a directory guard, closing the Zip Slip / CWE-73 arbitrary-write path · Security: **H2** the filler partition is now sized like the real one (±20%), so file size no longer reveals whether a decoy or duress password is set · desktop no longer silently overwrites existing files · fully backward compatible (files without a decoy are now ~2× larger)
- **2.3.1** — Han-Nom (𡸨喃) UI and Policies & Terms rewritten as genuine Chữ Nôm via a free translation API: Vietnamese grammar and word order instead of a word-for-word Chinese rendering · fully backward compatible
- **2.3.0** — New checksum tool (SHA-256 / SHA-512 / SHA-3-256, streamed, compare against expected value) · Policies & Terms fully translated into all five UI languages · fully backward compatible
- **2.2.5** — Han-Nom UI rewritten as genuine 𡸨喃 (Chữ Nôm): Vietnamese grammar and word order, not Traditional Chinese · Settings language picker is a vertical list with full horizontal names · fully backward compatible
- **2.2.1** — Five UI languages (English / 简体中文 / Français / Deutsch / 漢喃文) · bundled Tianheng font TH-Feon renders Han-Nom and extended CJK glyphs (Ext B–F) · Chinese text two weight steps bolder · fully backward compatible
- **2.1.0** — Verification-key hardening (600K PBKDF2, legacy files auto-supported) · platform-native crypto acceleration on mobile · bolder typography · license corrected to AGPL-3.0
- **2.0.0** — New "Other" section (About / Donate / Policies & Terms / Changelog) · LICENSE file added · feature-set milestone
- **1.6.0** — Optional post-quantum encryption: ML-KEM-768 (FIPS 203) recipient keys. New Keys tab (generate/import/share/delete `.vctpub` / `.vctkey`), encrypt to a public key with optional password (dual-channel or key-only V3 files), decrypt with your private key. Cross-validated against Go's `crypto/mlkem` with checked-in KAT vectors
- **1.5.0** — Secure Notes · password strength meter · desktop shortcuts · full-width share button
- **1.4.0** — iOS Files app visibility fix (atomic writes) · share/save sheet on mobile · new app icon (black shield on white) · display name VCTCrypt
- **1.3.0** — Onboarding guide & help center · batch encryption · clipboard auto-clear · accent colors · start page preference
- **1.2.0** — Password generator with strength meter · passwordless .VCT file inspector · local usage statistics · panic lock
- **1.1.0** — Decoy partition · duress password · secure shred · auto-lock · V2 file format
- **1.0.x** — Flutter rewrite (Win32 GUI → Material 3), five-platform CI, V1/CLI format compatibility

## License

This project is licensed under the **GNU Affero General Public License v3.0 (AGPL-3.0)** — see [LICENSE](LICENSE). You are free to use, study, modify and redistribute it; modified versions must be released under the same license, and if you offer it as a network service you must make the source code available to those users.

## Author

Tommy
