const crypto = require('crypto');

const ALGORITHM = 'aes-256-gcm';
const KEY = Buffer.from(process.env.ENCRYPTION_KEY || '', 'hex');

if (KEY.length !== 32) {
  console.warn(
    '[crypto] ENCRYPTION_KEY is missing or not a 32-byte hex string (64 hex chars). ' +
    'PIN encryption will fail until this is set correctly in the environment.'
  );
}

// Encrypted values are stored as "iv:authTag:ciphertext", all hex.
// Anything NOT in that shape (e.g. a legacy plaintext "123456" seed value)
// is treated as legacy plaintext by decryptPin - this lets old/seed data
// keep working without a separate migration step, and gets opportunistically
// re-encrypted the next time it's touched (see index.js login handler).
const ENCRYPTED_FORMAT = /^[0-9a-f]+:[0-9a-f]+:[0-9a-f]+$/i;

function isEncrypted(value) {
  return typeof value === 'string' && ENCRYPTED_FORMAT.test(value);
}

function encryptPin(plainPin) {
  const iv = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv(ALGORITHM, KEY, iv);
  const ciphertext = Buffer.concat([cipher.update(String(plainPin), 'utf8'), cipher.final()]);
  const authTag = cipher.getAuthTag();
  return `${iv.toString('hex')}:${authTag.toString('hex')}:${ciphertext.toString('hex')}`;
}

function decryptPin(storedValue) {
  if (!storedValue) return '';
  if (!isEncrypted(storedValue)) {
    // Legacy plaintext (e.g. un-migrated seed data) - return as-is.
    return storedValue;
  }
  const [ivHex, authTagHex, ciphertextHex] = storedValue.split(':');
  const decipher = crypto.createDecipheriv(ALGORITHM, KEY, Buffer.from(ivHex, 'hex'));
  decipher.setAuthTag(Buffer.from(authTagHex, 'hex'));
  const plaintext = Buffer.concat([
    decipher.update(Buffer.from(ciphertextHex, 'hex')),
    decipher.final(),
  ]);
  return plaintext.toString('utf8');
}

module.exports = { encryptPin, decryptPin, isEncrypted };
