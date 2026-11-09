'use strict';
const assert = require('node:assert/strict');
assert.ok(globalThis.crypto?.subtle, 'Node with WebCrypto is required');
const totp = require('./hu026_totp.cjs');
(async () => {
  // Public RFC6238 SHA1 test key and vectors, truncated to the app's six digits.
  const key = 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ';
  for (const [seconds, expected] of [[59,'287082'],[1111111109,'081804'],[1111111111,'050471'],[1234567890,'005924'],[2000000000,'279037'],[20000000000,'353130']]) {
    assert.equal(await totp(key, Math.floor(seconds/30)), expected);
  }
  await assert.rejects(totp('invalid',1));
  console.log('RFC6238 QA authenticator: 6 public vectors + invalid input OK');
})().catch(() => { console.error('QA_TOTP_TEST_FAILED'); process.exitCode=1; });
