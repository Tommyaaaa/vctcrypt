#!/usr/bin/env python3
"""iOS Info.plist fixer for VCTCrypt CI.

Registers the .vct / .VCT extension as a proper document type in
Info.plist:

  - UTImportedTypeDeclarations: declares the custom UTI
    com.tommy.vctcrypt.vct so iOS/Launch Services can recognise VCT
    files (needed because Apple has no built-in UTI for .vct). The
    system file picker greys out files whose extension maps to no
    known UTI when a type filter is active.
  - CFBundleDocumentTypes: lets iOS offer "Open in VCTCrypt" for
    .vct files and shows them in the Files app.
  - UIFileSharingEnabled + LSSupportsOpeningDocumentsInPlace:
    expose the app's Documents folder to the Files app so users can
    drop a .vct next to the app and pick it from there.

Runs AFTER `flutter create` (which regenerates ios/), so patches are
applied to the freshly generated Info.plist every build. Idempotent:
running it twice produces the same plist.
"""

import plistlib
import sys

PLIST = "ios/Runner/Info.plist"
UTI = "com.tommy.vctcrypt.vct"

try:
    with open(PLIST, "rb") as f:
        plist = plistlib.load(f)
except FileNotFoundError:
    print(f"ERROR: {PLIST} not found - run flutter create first", file=sys.stderr)
    sys.exit(1)

# --- UTImportedTypeDeclarations ---
plist["UTImportedTypeDeclarations"] = [
    {
        "UTTypeIdentifier": UTI,
        "UTTypeDescription": "VCTCrypt Encrypted File",
        "UTTypeConformsTo": ["public.data", "public.content"],
        "UTTypeTagSpecification": {
            "public.filename-extension": ["vct", "VCT"],
            "public.mime-type": "application/octet-stream",
        },
    }
]

# --- CFBundleDocumentTypes ---
plist["CFBundleDocumentTypes"] = [
    {
        "CFBundleTypeName": "VCTCrypt Encrypted File",
        "CFBundleTypeRole": "Editor",
        "LSHandlerRank": "Owner",
        "LSItemContentTypes": [UTI],
    }
]

# --- Files app integration ---
plist["UIFileSharingEnabled"] = True
plist["LSSupportsOpeningDocumentsInPlace"] = True

with open(PLIST, "wb") as f:
    plistlib.dump(plist, f, sort_keys=True)

print("=== fix_ios.py report ===")
print(f"Registered UTI {UTI} for extensions .vct/.VCT")
print("CFBundleDocumentTypes, UIFileSharingEnabled, "
      "LSSupportsOpeningDocumentsInPlace set")
print(f"Patched: {PLIST}")
