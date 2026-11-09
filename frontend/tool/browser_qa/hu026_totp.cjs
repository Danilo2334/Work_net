'use strict';
// QA software authenticator only. Server-side verification uses django-otp.
// RFC6238/SHA1, six digits, 30s; WebCrypto is supported by Postman Desktop v12.
async function hu026Totp(secret, counter = Math.floor(Date.now() / 30000)) {
  if (!/^[A-Z2-7]{32}$/.test(secret) || !Number.isSafeInteger(counter) || counter < 0) {
    throw new Error('QA_TOTP_INPUT_INVALID');
  }
  const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
  let accumulator = 0, bits = 0;
  const keyBytes = [];
  for (const c of secret) {
    accumulator = (accumulator << 5) | alphabet.indexOf(c);
    bits += 5;
    if (bits >= 8) { bits -= 8; keyBytes.push((accumulator >>> bits) & 255); }
  }
  const message = new Uint8Array(8);
  let value = BigInt(counter);
  for (let i = 7; i >= 0; i--) { message[i] = Number(value & 255n); value >>= 8n; }
  const key = await globalThis.crypto.subtle.importKey('raw', new Uint8Array(keyBytes), {name:'HMAC',hash:'SHA-1'}, false, ['sign']);
  const signed = new Uint8Array(await globalThis.crypto.subtle.sign('HMAC', key, message));
  const offset = signed[signed.length - 1] & 15;
  const binary = ((signed[offset] & 127) << 24) | (signed[offset+1] << 16) | (signed[offset+2] << 8) | signed[offset+3];
  return String(binary % 1000000).padStart(6, '0');
}
if (typeof module !== 'undefined') module.exports = hu026Totp;
