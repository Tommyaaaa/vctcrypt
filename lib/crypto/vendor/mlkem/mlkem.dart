/// VCTCrypt - vendored ML-KEM (FIPS 203) implementation
///
/// Upstream: pqcrypto 0.4.1 (https://pub.dev/packages/pqcrypto)
/// Copyright (c) 2025 Turkana Nation — MIT license (see LICENSE-pqcrypto).
/// Algorithm code is vendored UNMODIFIED from the published package
/// (only import paths were rewritten); only the ML-KEM subset needed
/// by VCTCrypt is included (ML-DSA / SLH-DSA files were not copied).
///
/// Why vendored: the published package requires Dart 3.10 while
/// VCTCrypt builds on Flutter 3.24 / Dart 3.5 across all five release
/// platforms. Vendoring keeps the toolchain stable and makes the whole
/// crypto stack part of this repository.
///
/// Upstream validation evidence (see upstream repo for details):
///   - 1000/1000 official KAT vectors pass for ML-KEM-768
///   - OpenSSL + liboqs A-G interop suites (bidirectional, all levels)
///   - FIPS 203 input checks (ek modulus check, dk hash check)
///   - constant-time implicit rejection via branchless select
///
/// VCTCrypt uses ML-KEM-768 exclusively (NIST level 3):
///   ek (public key)  = 1184 bytes
///   dk (private key) = 2400 bytes
///   ct (ciphertext)  = 1088 bytes
///   ss (shared secret) = 32 bytes

library;

export 'kyber/kem.dart' show KyberKem, KyberLevel, PqcKem;
export 'kyber/params.dart' show KyberParams;
