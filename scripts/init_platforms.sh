#!/bin/bash
set -e

echo "=== VCTCrypt Flutter Project Setup ==="
echo "Generating platform-specific directories..."
echo ""

# Generate platform scaffolding (does not overwrite existing lib/ files)
flutter create \
  --platforms=android,ios,macos,windows,linux \
  --org com.tommy \
  --project-name vctcrypt \
  .

echo ""
echo "Installing dependencies..."
flutter pub get

echo ""
echo "=== Setup Complete! ==="
echo ""
echo "Platform directories generated:"
echo "  android/  - Android APK"
echo "  ios/      - iOS IPA"
echo "  macos/    - macOS DMG"
echo "  windows/  - Windows EXE"
echo "  linux/    - Linux AppImage"
echo ""
echo "To build locally:"
echo "  flutter build apk --release"
echo "  flutter build windows --release"
echo "  flutter build macos --release"
echo "  flutter build ios --release --no-codesign"
echo "  flutter build linux --release"
echo ""
echo "Or push to GitHub and let Actions build everything."
