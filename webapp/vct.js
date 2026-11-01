// VCTCrypt web engine.
//
// Byte-compatible with the Flutter app (lib/crypto/vct_crypto.dart):
//   * V4 (layout 0x02) is written here and is the format desktop v2.5.0+
//     produces by default.
//   * V1 / V1-old and V2 containers are readable (files from older releases).
//   * V3 (recipient-key envelopes) is not supported by the web edition.
//
// AES-256-GCM everywhere, PBKDF2-HMAC-SHA256 with 600,000 iterations.

const textEncoder = new TextEncoder();
const subtle = globalThis.crypto.subtle;

export const MAX_FILE_BYTES = 64 * 1024 * 1024;
export const MAX_VCT_BYTES = 160 * 1024 * 1024;
export const MIN_PASSWORD_CHARS = 8;

const SALT = 48;
const NONCE = 12;
const TAG = 16;
const HMAC = 32;
const ITERS = 600000;
const ITERS_V_LEGACY = 10000;

const MAGIC_V1 = 'VCTCRYPT1\u0000\u0000\u0000';
const MAGIC_V1_OLD = 'VCTCRYPT1\u0000\u0000';
const MAGIC_V2 = 'VCTCRYPT2\u0000\u0000\u0000';
const MAGIC_V3 = 'VCTCRYPT3\u0000\u0000\u0000';
const MAGIC_V4 = 'VCTCRYPT4\u0000\u0000\u0000';

// V4 header offsets.
const V4_VER_OFF = 12;
const V4_FLAGS_OFF = 13;
const V4_CTLEN_OFF = 14;
const V4_REAL_SALT_OFF = 22;
const V4_REAL_HMAC_OFF = 106;
const V4_DECOY_SALT_OFF = 138;
const V4_DECOY_HMAC_OFF = 222;
const V4_DURESS_SALT_OFF = 254;
const V4_DURESS_HMAC_OFF = 302;
const V4_HEADER_LEN = 334;
const V4_LAYOUT = 2;
const V4_SLOT_REAL = 1;
const V4_SLOT_DECOY = 2;

// V2 header offsets.
const V2_CTLEN_OFF = 12;
const V2_REAL_SALT_OFF = 20;
const V2_REAL_HMAC_OFF = 104;
const V2_DECOY_SALT_OFF = 136;
const V2_DECOY_HMAC_OFF = 220;
const V2_DURESS_SALT_OFF = 252;
const V2_DURESS_HMAC_OFF = 300;
const V2_HEADER_LEN = 332;

export class VctError extends Error {
  constructor(code) {
    super(code);
    this.code = code;
  }
}

// ---- byte helpers ----

function concat(...parts) {
  let total = 0;
  for (const part of parts) total += part.length;
  const out = new Uint8Array(total);
  let offset = 0;
  for (const part of parts) {
    out.set(part, offset);
    offset += part.length;
  }
  return out;
}

function u16le(value) {
  return Uint8Array.of(value & 0xff, (value >>> 8) & 0xff);
}

function u64le(value) {
  const out = new Uint8Array(8);
  let v = BigInt(value);
  for (let i = 0; i < 8; i++) {
    out[i] = Number(v & 0xffn);
    v >>= 8n;
  }
  return out;
}

function readU64le(bytes, offset) {
  let v = 0n;
  for (let i = 7; i >= 0; i--) v = (v << 8n) | BigInt(bytes[offset + i]);
  return Number(v);
}

function randomBytes(length) {
  const out = new Uint8Array(length);
  const chunk = 65536;
  for (let i = 0; i < length; i += chunk) {
    const part = new Uint8Array(Math.min(chunk, length - i));
    globalThis.crypto.getRandomValues(part);
    out.set(part, i);
  }
  return out;
}

function randInt(maxExclusive) {
  const buf = new Uint32Array(1);
  const limit = Math.floor(0x100000000 / maxExclusive) * maxExclusive;
  let v;
  do {
    globalThis.crypto.getRandomValues(buf);
    v = buf[0];
  } while (v >= limit);
  return v % maxExclusive;
}

function toHex(bytes) {
  let s = '';
  for (const b of bytes) s += b.toString(16).padStart(2, '0');
  return s;
}

export function passwordCharCount(password) {
  return [...password].length;
}

function startsWithBytes(bytes, text, length = text.length) {
  const magic = textEncoder.encode(text);
  if (bytes.length < length) return false;
  for (let i = 0; i < length; i++) {
    if (bytes[i] !== magic[i]) return false;
  }
  return true;
}

function timingSafeEqual(a, b) {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a[i] ^ b[i];
  return diff === 0;
}

// ---- primitives ----

async function pbkdf2(password, salt, iterations) {
  const key = await subtle.importKey(
    'raw',
    textEncoder.encode(password),
    'PBKDF2',
    false,
    ['deriveBits'],
  );
  const bits = await subtle.deriveBits(
    { name: 'PBKDF2', hash: 'SHA-256', salt, iterations },
    key,
    256,
  );
  return new Uint8Array(bits);
}

async function hmacSha256(keyBytes, data) {
  const key = await subtle.importKey(
    'raw',
    keyBytes,
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  return new Uint8Array(await subtle.sign('HMAC', key, data));
}

async function gcmEncrypt(keyBytes, nonce, plain, aad) {
  const key = await subtle.importKey('raw', keyBytes, 'AES-GCM', false, ['encrypt']);
  const out = new Uint8Array(
    await subtle.encrypt(
      { name: 'AES-GCM', iv: nonce, additionalData: aad ?? new Uint8Array(0), tagLength: 128 },
      key,
      plain,
    ),
  );
  return { ct: out.subarray(0, out.length - TAG), tag: out.subarray(out.length - TAG) };
}

async function gcmDecrypt(keyBytes, nonce, ct, tag, aad) {
  const key = await subtle.importKey('raw', keyBytes, 'AES-GCM', false, ['decrypt']);
  const buf = concat(ct, tag);
  try {
    return new Uint8Array(
      await subtle.decrypt(
        { name: 'AES-GCM', iv: nonce, additionalData: aad ?? new Uint8Array(0), tagLength: 128 },
        key,
        buf,
      ),
    );
  } catch {
    throw new VctError('CORRUPT');
  }
}

// ---- key derivation ----

async function deriveV4(password, salt) {
  const master = await pbkdf2(`${password}::M4`, salt, ITERS);
  const sub = (label) =>
    hmacSha256(master, concat(textEncoder.encode(`VCT4::${label}`), salt));
  const [k1, k2, k3, vk] = await Promise.all([sub('1'), sub('2'), sub('3'), sub('V')]);
  return { k1, k2, k3, vk };
}

async function deriveV1(password, salt) {
  const [vk, k1, k2, k3] = await Promise.all([
    pbkdf2(`${password}::V`, salt, ITERS),
    pbkdf2(`${password}::1`, salt, ITERS),
    pbkdf2(`${password}::2`, salt, ITERS),
    pbkdf2(`${password}::3`, salt, ITERS),
  ]);
  return { k1, k2, k3, vk };
}

async function deriveBodyKeys(password, salt) {
  const [k1, k2, k3] = await Promise.all([
    pbkdf2(`${password}::1`, salt, ITERS),
    pbkdf2(`${password}::2`, salt, ITERS),
    pbkdf2(`${password}::3`, salt, ITERS),
  ]);
  return { k1, k2, k3 };
}

// ---- V4 AAD ----

function v4Aad({ magic, ver, flags, ctLen, salt, n1, n2, n3, slot, duressSalt, duressHmac }) {
  const parts = [magic, Uint8Array.of(ver, flags), u64le(ctLen), salt, n1, n2, n3];
  if (ver >= 2) parts.push(Uint8Array.of(slot), duressSalt, duressHmac);
  return concat(...parts);
}

// ---- layered body crypto ----

async function tripleEncrypt(keys, n1, n2, n3, payload, aad) {
  const l1 = await gcmEncrypt(keys.k1, n1, payload, aad);
  const l1b = concat(l1.tag, l1.ct);
  const l2 = await gcmEncrypt(keys.k2, n2, l1b, aad);
  const l2b = concat(l2.tag, l2.ct);
  const l3 = await gcmEncrypt(keys.k3, n3, l2b, aad);
  return { ct: l3.ct, tag: l3.tag };
}

async function tripleDecrypt(keys, n1, n2, n3, l3Ct, t3, aad) {
  const l2b = await gcmDecrypt(keys.k3, n3, l3Ct, t3, aad);
  if (l2b.length < TAG) throw new VctError('CORRUPT');
  const t2 = l2b.subarray(0, TAG);
  const l2Ct = l2b.subarray(TAG);

  const l1b = await gcmDecrypt(keys.k2, n2, l2Ct, t2, aad);
  if (l1b.length < TAG) throw new VctError('CORRUPT');
  const t1 = l1b.subarray(0, TAG);
  const l1Ct = l1b.subarray(TAG);

  const payload = await gcmDecrypt(keys.k1, n1, l1Ct, t1, aad);
  if (payload.length < 2) throw new VctError('PAYLOAD_CORRUPT');

  const nameLen = payload[0] | (payload[1] << 8);
    if (2 + nameLen > payload.length) throw new VctError('PAYLOAD_CORRUPT');

  let name;
  try {
    name = new TextDecoder('utf-8', { fatal: true }).decode(
      payload.subarray(2, 2 + nameLen),
    );
  } catch {
    throw new VctError('PAYLOAD_CORRUPT');
  }

  return { name: sanitizeFileName(name), data: payload.subarray(2 + nameLen) };
}

// ---- name sanitising (mirrors sanitizeFileName in vct_crypto.dart) ----

export function sanitizeFileName(raw) {
  const fallback = 'decrypted_file';
  let s = raw.replace(/[\x00-\x1f\x7f]/g, '');
  if (!s) return fallback;
  // v2.6.0 (V-16): invisible bidi overrides / zero-width characters.
  s = s.replace(/[\u200b-\u200f\u202a-\u202e\u2066-\u2069\ufeff]/g, '');
  if (!s) return fallback;
  s = s.replace(/\\/g, '/');
  const segments = s.split('/').filter((part) => part && part !== '.' && part !== '..');
  if (!segments.length) return fallback;
  let name = segments[segments.length - 1].trim().replace(/[. ]+$/, '');
  if (!name) return fallback;
  if (name.length > 512) name = name.slice(0, 512);
  return name;
}

// ---- encryption (always V4 layout 0x02) ----

function decoyFillerLength(target) {
  const jitter = Math.min(Math.max(Math.round(target * 0.2), 1), 4096);
  let length = target - jitter + randInt(2 * jitter + 1);
  if (length < 240) length = 240 + randInt(1800);
  return length;
}

export async function encryptBytes(name, data, password) {
  if (passwordCharCount(password) < MIN_PASSWORD_CHARS) {
    throw new VctError('PASSWORD_TOO_SHORT');
  }
  if (data.length > MAX_FILE_BYTES) throw new VctError('FILE_TOO_LARGE');
  if (data.length === 0) throw new VctError('EMPTY_FILE');

  let nameBytes = textEncoder.encode(name);
  if (nameBytes.length > 0xffff) nameBytes = nameBytes.subarray(0, 0xffff);
  const payload = concat(u16le(nameBytes.length), nameBytes, data);

  // Duress slot: always present. The web edition has no duress password,
  // so it is pure random filler - the file shape stays identical.
  const duressSalt = randomBytes(SALT);
  const duressHmac = randomBytes(HMAC);

  const salt = randomBytes(SALT);
  const n1 = randomBytes(NONCE);
  const n2 = randomBytes(NONCE);
  const n3 = randomBytes(NONCE);

  const ctLen = payload.length + TAG * 2;
  const magic = textEncoder.encode(MAGIC_V4);
  const aad = v4Aad({
    magic,
    ver: V4_LAYOUT,
    flags: 0,
    ctLen,
    salt,
    n1,
    n2,
    n3,
    slot: V4_SLOT_REAL,
    duressSalt,
    duressHmac,
  });

  const keys = await deriveV4(password, salt);
  const real = await tripleEncrypt(keys, n1, n2, n3, payload, aad);
  const realHmac = await hmacSha256(keys.vk, concat(salt, n1, n2, n3));

  const decoy = {
    salt: randomBytes(SALT),
    n1: randomBytes(NONCE),
    n2: randomBytes(NONCE),
    n3: randomBytes(NONCE),
    hmac: randomBytes(HMAC),
    ct: randomBytes(decoyFillerLength(ctLen)),
    tag: randomBytes(TAG),
  };

  const header = concat(
    magic,
    Uint8Array.of(V4_LAYOUT, 0),
    u64le(real.ct.length),
    salt,
    n1,
    n2,
    n3,
    realHmac,
    decoy.salt,
    decoy.n1,
    decoy.n2,
    decoy.n3,
    decoy.hmac,
    duressSalt,
    duressHmac,
  );

  const bytes = concat(header, real.ct, real.tag, decoy.ct, decoy.tag);
  // v2.6.0 (V-05): the container name never echoes the original file name.
  return { bytes, fileName: `vct-${toHex(randomBytes(16))}.VCT`, format: 'V4' };
}

// ---- decryption ----

async function verifyV4(password, salt, n1, n2, n3, storedHmac) {
  const keys = await deriveV4(password, salt);
  const computed = await hmacSha256(keys.vk, concat(salt, n1, n2, n3));
  return timingSafeEqual(computed, storedHmac) ? keys : null;
}

async function verifyDuress(password, salt, storedHmac) {
  let computed = await hmacSha256(
    await pbkdf2(`${password}::V`, salt, ITERS),
    salt,
  );
  if (timingSafeEqual(computed, storedHmac)) return true;
  computed = await hmacSha256(
    await pbkdf2(`${password}::V`, salt, ITERS_V_LEGACY),
    salt,
  );
  return timingSafeEqual(computed, storedHmac);
}

async function verifyLegacyPartition(password, salt, n1, n2, n3, storedHmac) {
  const data = concat(salt, n1, n2, n3);
  let computed = await hmacSha256(
    await pbkdf2(`${password}::V`, salt, ITERS),
    data,
  );
  if (timingSafeEqual(computed, storedHmac)) return true;
  computed = await hmacSha256(
    await pbkdf2(`${password}::V`, salt, ITERS_V_LEGACY),
    data,
  );
  return timingSafeEqual(computed, storedHmac);
}

async function decryptV4(bytes, password) {
  const ver = bytes[V4_VER_OFF];
  const flags = bytes[V4_FLAGS_OFF];
  if (ver !== 1 && ver !== 2) throw new VctError('UNSUPPORTED_FORMAT');

  const realCtLen = readU64le(bytes, V4_CTLEN_OFF);
  if (bytes.length < V4_HEADER_LEN + TAG * 2) throw new VctError('FILE_TOO_SMALL');
  if (realCtLen <= 0 || V4_HEADER_LEN + realCtLen + TAG * 2 > bytes.length) {
    throw new VctError('CORRUPT');
  }

  const realSalt = bytes.subarray(V4_REAL_SALT_OFF, V4_REAL_SALT_OFF + SALT);
  const realN1 = bytes.subarray(V4_REAL_SALT_OFF + SALT, V4_REAL_SALT_OFF + SALT + NONCE);
  const realN2 = bytes.subarray(V4_REAL_SALT_OFF + SALT + NONCE, V4_REAL_SALT_OFF + SALT + NONCE * 2);
  const realN3 = bytes.subarray(V4_REAL_SALT_OFF + SALT + NONCE * 2, V4_REAL_SALT_OFF + SALT + NONCE * 3);
  const realHmac = bytes.subarray(V4_REAL_HMAC_OFF, V4_REAL_HMAC_OFF + HMAC);

  const decoySalt = bytes.subarray(V4_DECOY_SALT_OFF, V4_DECOY_SALT_OFF + SALT);
  const decoyN1 = bytes.subarray(V4_DECOY_SALT_OFF + SALT, V4_DECOY_SALT_OFF + SALT + NONCE);
  const decoyN2 = bytes.subarray(V4_DECOY_SALT_OFF + SALT + NONCE, V4_DECOY_SALT_OFF + SALT + NONCE * 2);
  const decoyN3 = bytes.subarray(V4_DECOY_SALT_OFF + SALT + NONCE * 2, V4_DECOY_SALT_OFF + SALT + NONCE * 3);
  const decoyHmac = bytes.subarray(V4_DECOY_HMAC_OFF, V4_DECOY_HMAC_OFF + HMAC);

  const duressSalt = bytes.subarray(V4_DURESS_SALT_OFF, V4_DURESS_SALT_OFF + SALT);
  const duressHmac = bytes.subarray(V4_DURESS_HMAC_OFF, V4_DURESS_HMAC_OFF + HMAC);

  const bodyStart = V4_HEADER_LEN;
  const realCt = bytes.subarray(bodyStart, bodyStart + realCtLen);
  const realTag = bytes.subarray(bodyStart + realCtLen, bodyStart + realCtLen + TAG);
  const decoyStart = bodyStart + realCtLen + TAG;
  const decoyCt = bytes.subarray(decoyStart, bytes.length - TAG);
  const decoyTag = bytes.subarray(bytes.length - TAG);

  const magic = bytes.subarray(0, 12);
  const buildAad = (slot, salt, n1, n2, n3) =>
    v4Aad({ magic, ver, flags, ctLen: realCtLen, salt, n1, n2, n3, slot, duressSalt, duressHmac });

  // Uniform three-way verification - same work for every candidate password.
  const [realKeys, decoyKeys, duressOk] = await Promise.all([
    verifyV4(password, realSalt, realN1, realN2, realN3, realHmac),
    verifyV4(password, decoySalt, decoyN1, decoyN2, decoyN3, decoyHmac),
    verifyDuress(password, duressSalt, duressHmac),
  ]);

  if (realKeys) {
    const out = await tripleDecrypt(
      realKeys, realN1, realN2, realN3, realCt, realTag,
      buildAad(V4_SLOT_REAL, realSalt, realN1, realN2, realN3),
    );
    return { ...out, format: 'V4', isDecoy: false };
  }

  if (decoyKeys) {
    const out = await tripleDecrypt(
      decoyKeys, decoyN1, decoyN2, decoyN3, decoyCt, decoyTag,
      buildAad(V4_SLOT_DECOY, decoySalt, decoyN1, decoyN2, decoyN3),
    );
    return { ...out, format: 'V4', isDecoy: true };
  }

  // Duress password: indistinguishable from a wrong password. The web
  // edition never destroys files, so there is nothing to shred here.
  if (duressOk) throw new VctError('WRONG_PASSWORD');

  throw new VctError('WRONG_PASSWORD');
}

async function decryptV2(bytes, password) {
  if (bytes.length < V2_HEADER_LEN + TAG * 2) throw new VctError('FILE_TOO_SMALL');

  const realCtLen = readU64le(bytes, V2_CTLEN_OFF);
  if (realCtLen <= 0 || V2_HEADER_LEN + realCtLen + TAG * 2 > bytes.length) {
    throw new VctError('CORRUPT');
  }

  const grab = (offset, length) => bytes.subarray(offset, offset + length);
  const realSalt = grab(V2_REAL_SALT_OFF, SALT);
  const realN1 = grab(V2_REAL_SALT_OFF + SALT, NONCE);
  const realN2 = grab(V2_REAL_SALT_OFF + SALT + NONCE, NONCE);
  const realN3 = grab(V2_REAL_SALT_OFF + SALT + NONCE * 2, NONCE);
  const realHmac = grab(V2_REAL_HMAC_OFF, HMAC);

  const decoySalt = grab(V2_DECOY_SALT_OFF, SALT);
  const decoyN1 = grab(V2_DECOY_SALT_OFF + SALT, NONCE);
  const decoyN2 = grab(V2_DECOY_SALT_OFF + SALT + NONCE, NONCE);
  const decoyN3 = grab(V2_DECOY_SALT_OFF + SALT + NONCE * 2, NONCE);
  const decoyHmac = grab(V2_DECOY_HMAC_OFF, HMAC);

  const duressSalt = grab(V2_DURESS_SALT_OFF, SALT);
  const duressHmac = grab(V2_DURESS_HMAC_OFF, HMAC);

  const bodyStart = V2_HEADER_LEN;
  const realCt = bytes.subarray(bodyStart, bodyStart + realCtLen);
  const realTag = bytes.subarray(bodyStart + realCtLen, bodyStart + realCtLen + TAG);
  const decoyStart = bodyStart + realCtLen + TAG;
  const decoyCt = bytes.subarray(decoyStart, bytes.length - TAG);
  const decoyTag = bytes.subarray(bytes.length - TAG);

  const [realOk, decoyOk, duressOk] = await Promise.all([
    verifyLegacyPartition(password, realSalt, realN1, realN2, realN3, realHmac),
    verifyLegacyPartition(password, decoySalt, decoyN1, decoyN2, decoyN3, decoyHmac),
    verifyDuress(password, duressSalt, duressHmac),
  ]);

  if (realOk) {
    const keys = await deriveBodyKeys(password, realSalt);
    const out = await tripleDecrypt(keys, realN1, realN2, realN3, realCt, realTag, null);
    return { ...out, format: 'V2', isDecoy: false };
  }

  if (decoyOk) {
    const keys = await deriveBodyKeys(password, decoySalt);
    const out = await tripleDecrypt(keys, decoyN1, decoyN2, decoyN3, decoyCt, decoyTag, null);
    return { ...out, format: 'V2', isDecoy: true };
  }

  if (duressOk) throw new VctError('WRONG_PASSWORD');
  throw new VctError('WRONG_PASSWORD');
}

async function decryptV1(bytes, password, magicLen) {
  const minSize = magicLen + SALT + NONCE * 3 + HMAC + TAG;
  if (bytes.length < minSize) throw new VctError('FILE_TOO_SMALL');

  let pos = magicLen;
  const salt = bytes.subarray(pos, pos + SALT);
  pos += SALT;
  const n1 = bytes.subarray(pos, pos + NONCE);
  pos += NONCE;
  const n2 = bytes.subarray(pos, pos + NONCE);
  pos += NONCE;
  const n3 = bytes.subarray(pos, pos + NONCE);
  pos += NONCE;
  const storedHmac = bytes.subarray(pos, pos + HMAC);
  pos += HMAC;

  const ctLen = bytes.length - pos - TAG;
  if (ctLen <= 0) throw new VctError('CORRUPT');
  const l3Ct = bytes.subarray(pos, pos + ctLen);
  const t3 = bytes.subarray(pos + ctLen, pos + ctLen + TAG);

  if (!(await verifyLegacyPartition(password, salt, n1, n2, n3, storedHmac))) {
    throw new VctError('WRONG_PASSWORD');
  }

  const keys = await deriveBodyKeys(password, salt);
  const out = await tripleDecrypt(keys, n1, n2, n3, l3Ct, t3, null);
  return { ...out, format: magicLen === 12 ? 'V1' : 'V1-old', isDecoy: false };
}

/**
 * Decrypt a .VCT container (Uint8Array) with [password].
 * Resolves to { name, data, format, isDecoy } and throws VctError.
 */
export async function decryptBytes(bytes, password) {
  if (bytes.length < 16) throw new VctError('FILE_TOO_SMALL');

  if (startsWithBytes(bytes, MAGIC_V4)) return decryptV4(bytes, password);
  if (startsWithBytes(bytes, MAGIC_V2)) return decryptV2(bytes, password);
  if (startsWithBytes(bytes, MAGIC_V1)) return decryptV1(bytes, password, 12);
  if (startsWithBytes(bytes, MAGIC_V1_OLD, 11)) return decryptV1(bytes, password, 11);
  if (startsWithBytes(bytes, MAGIC_V3)) throw new VctError('UNSUPPORTED_V3');
  throw new VctError('NOT_VCT');
}
