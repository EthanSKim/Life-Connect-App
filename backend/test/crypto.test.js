process.env.ENCRYPTION_KEY = require('crypto').randomBytes(32).toString('hex');
const test = require('node:test');
const assert = require('node:assert/strict');
const { encryptPin, decryptPin, isEncrypted, generateAttendanceToken } = require('../crypto');

test('encrypt -> decrypt round-trip returns the original PIN', () => {
  const encrypted = encryptPin('123456');
  assert.equal(decryptPin(encrypted), '123456');
});

test('encryptPin coerces non-string input (e.g. a number) before encrypting', () => {
  const encrypted = encryptPin(123456);
  assert.equal(decryptPin(encrypted), '123456');
});

test('encryptPin produces a different ciphertext every time (random IV), even for the same PIN', () => {
  const a = encryptPin('123456');
  const b = encryptPin('123456');
  assert.notEqual(a, b);
  assert.equal(decryptPin(a), '123456');
  assert.equal(decryptPin(b), '123456');
});

test('isEncrypted recognizes the iv:authTag:ciphertext shape', () => {
  assert.equal(isEncrypted(encryptPin('123456')), true);
});

test('isEncrypted rejects legacy plaintext PINs', () => {
  assert.equal(isEncrypted('123456'), false);
});

test('decryptPin returns legacy plaintext as-is (un-migrated seed data)', () => {
  assert.equal(decryptPin('123456'), '123456');
});

test('decryptPin handles empty/null/undefined without crashing', () => {
  assert.equal(decryptPin(''), '');
  assert.equal(decryptPin(null), '');
  assert.equal(decryptPin(undefined), '');
});

test('decryptPin does not throw on a value that matches the encrypted format but is not valid ciphertext (corrupted/tampered data)', () => {
  assert.doesNotThrow(() => decryptPin('aa:bb:cc'));
});

test('decryptPin does not throw on a well-formed but wrong-length hex triplet', () => {
  assert.doesNotThrow(() => decryptPin('deadbeef:cafebabe:0123456789abcdef'));
});

test('generateAttendanceToken produces a 48-char hex string', () => {
  const token = generateAttendanceToken();
  assert.equal(token.length, 48);
  assert.match(token, /^[0-9a-f]{48}$/);
});

test('generateAttendanceToken does not produce collisions across many calls', () => {
  const tokens = new Set();
  for (let i = 0; i < 1000; i++) tokens.add(generateAttendanceToken());
  assert.equal(tokens.size, 1000);
});
