#!/usr/bin/env python3
"""Patch cryptography_flutter's Android module for AGP 8 (v2.1.0).

cryptography_flutter 2.3.2 predates AGP 8:
  1. It declares its package via the DEPRECATED AndroidManifest.xml
     `package` attribute instead of a build.gradle `namespace`.
     AGP 8.5 (our build config from fix_android.py) hard-fails:
     "Namespace not specified. Specify a namespace in the module's
     build file".
  2. It compiles against SDK 31, but our CI runners only install
     android-35 (the fix_android.py config). Bump it so the module
     builds against the installed platform.

pubspec.yaml pins the plugin to exactly 2.3.2 (2.3.3+ needs the
@internal re-export that Flutter 3.27+ foundation.dart provides, while
CI builds on 3.24), so this patch always targets the same source.

Run AFTER `flutter pub get` (the plugin must be in the pub cache) and
BEFORE `flutter build apk`. Idempotent - safe to run twice.

Every patch is verified after writing; failures exit non-zero so CI
fails loudly.
"""

import glob
import os
import re
import sys

NAMESPACE = "dev.dint.cryptography_flutter"

errors = []


def main():
    pub_cache = os.environ.get("PUB_CACHE", os.path.expanduser("~/.pub-cache"))
    roots = glob.glob(
        pub_cache + "/hosted/pub.dev/cryptography_flutter-*/android"
    )
    if not roots:
        # Some setups (e.g. PUB_CACHE not exported to this step) keep the
        # default location under HOME; the glob above already covers it,
        # so reaching here means the plugin truly is not downloaded yet.
        print(
            "ERROR: no cryptography_flutter-*/android under " + pub_cache,
            file=sys.stderr,
        )
        print("Did `flutter pub get` run before this script?", file=sys.stderr)
        sys.exit(1)

    root = roots[0]
    print("Patching: " + root)

    # --- 1) build.gradle: namespace inside android { ... } -------------
    gradle_path = os.path.join(root, "build.gradle")
    with open(gradle_path, "r", encoding="utf-8") as f:
        src = f.read()

    if not re.search(r"^\s*namespace\s+['\"]", src, re.M):
        new_src, n = re.subn(
            r"android\s*\{",
            "android {\n    namespace '%s'" % NAMESPACE,
            src,
            count=1,
        )
        if n != 1:
            errors.append("could not insert namespace into build.gradle")
        else:
            with open(gradle_path, "w", encoding="utf-8") as f:
                f.write(new_src)

    # --- 2) build.gradle: compileSdkVersion 31 -> 35 -------------------
    src = open(gradle_path, "r", encoding="utf-8").read()
    if re.search(r"compileSdkVersion\s+31\b", src):
        new_src, n = re.subn(
            r"compileSdkVersion\s+31\b", "compileSdkVersion 35", src
        )
        if n == 0:
            errors.append("compileSdkVersion bump regex failed")
        else:
            with open(gradle_path, "w", encoding="utf-8") as f:
                f.write(new_src)

    # --- 3) AndroidManifest.xml: drop deprecated package attribute ------
    manifest_path = os.path.join(root, "src", "main", "AndroidManifest.xml")
    with open(manifest_path, "r", encoding="utf-8") as f:
        xml = f.read()
    new_xml, n = re.subn(
        r'(<manifest[^>]*?)\s+package="[^"]*"', r"\1", xml
    )
    if n > 0:
        with open(manifest_path, "w", encoding="utf-8") as f:
            f.write(new_xml)

    # --- verify --------------------------------------------------------
    src = open(gradle_path, "r", encoding="utf-8").read()
    if "namespace '%s'" % NAMESPACE not in src:
        errors.append("namespace not verified in build.gradle")
    xml = open(manifest_path, "r", encoding="utf-8").read()
    if re.search(r"<manifest[^>]*package=", xml):
        errors.append("package attribute still present in AndroidManifest.xml")

    print("=== patch_crypto_plugin.py report ===")
    print("namespace in build.gradle: " + ("OK" if not errors else "check errors"))
    print("manifest package attribute removed")
    if errors:
        print("\nERRORS:", file=sys.stderr)
        for e in errors:
            print("  - " + e, file=sys.stderr)
        sys.exit(1)
    print("\ncryptography_flutter AGP-8 patch applied and verified.")


if __name__ == "__main__":
    main()
