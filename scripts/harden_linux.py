#!/usr/bin/env python3
"""v2.5.0: harden the Flutter-generated Linux runner before building.

The linux/ directory is generated on the fly by `flutter create` (see
L7), so these two fixes are applied to the generated tree:

  L2 - link the executable with Full RELRO + immediate binding
       (-Wl,-z,relro,-z,now).
  L5 - when there is no DISPLAY / WAYLAND_DISPLAY, print a readable
       message instead of letting GTK emit "cannot open display".

Idempotent: running it twice is a no-op.
"""

import os
import sys

MARKER = "VCTCrypt v2.5.0 hardening"

LINKER_BLOCK = f"""
# {MARKER} (L2): Full RELRO + immediate binding.
set(CMAKE_EXE_LINKER_FLAGS "${{CMAKE_EXE_LINKER_FLAGS}} -Wl,-z,relro,-z,now")
set(CMAKE_SHARED_LINKER_FLAGS "${{CMAKE_SHARED_LINKER_FLAGS}} -Wl,-z,relro,-z,now")
"""

NO_DISPLAY_CHECK = f"""  // {MARKER} (L5): fail with a readable message, not a bare GTK warning.
  if (std::getenv("DISPLAY") == nullptr &&
      std::getenv("WAYLAND_DISPLAY") == nullptr) {{
    std::cerr
        << "VCTCrypt needs a graphical environment.\\n"
        << "Run it from a desktop session, or connect with SSH -X / VNC.\\n"
        << "VCTCrypt 需要图形界面：请在桌面环境中运行，或使用 SSH -X / VNC。"
        << std::endl;
    return 1;
  }}
"""


def patch_cmake(path: str) -> bool:
    with open(path, "r", encoding="utf-8") as f:
        text = f.read()
    if MARKER in text:
        return False
    with open(path, "a", encoding="utf-8") as f:
        f.write(LINKER_BLOCK)
    return True


def patch_main(path: str) -> bool:
    with open(path, "r", encoding="utf-8") as f:
        text = f.read()
    if MARKER in text:
        return False

    header = (
        "#include <cstdlib>\n"
        "#include <iostream>\n\n"
    )
    text = text.replace('#include "my_application.h"',
                        '#include "my_application.h"\n\n' + header.rstrip("\n"), 1)

    needle = "int main(int argc, char** argv) {\n"
    if needle not in text:
        raise SystemExit(f"FATAL: cannot find main() in {path}")

    text = text.replace(needle, needle + NO_DISPLAY_CHECK, 1)
    with open(path, "w", encoding="utf-8") as f:
        f.write(text)
    return True


def main() -> int:
    cmake = os.path.join("linux", "CMakeLists.txt")
    runner = os.path.join("linux", "runner", "main.cc")
    for p in (cmake, runner):
        if not os.path.exists(p):
            print(f"FATAL: {p} missing - run flutter create --platforms=linux first")
            return 1

    cmake_changed = patch_cmake(cmake)
    main_changed = patch_main(runner)
    print(f"CMake RELRO: {'patched' if cmake_changed else 'already applied'}")
    print(f"main.cc display check: {'patched' if main_changed else 'already applied'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
