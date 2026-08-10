const test = require('node:test');
const assert = require('node:assert/strict');
const {
  generateDaySlots, dayOfWeek, isDefaultOpen, isValidSlotRange, slotsInRange, timeStrToMinutes,
} = require('../slots');

test('generateDaySlots produces exactly 16 slots covering 10:00-18:00', () => {
  const slots = generateDaySlots();
  assert.equal(slots.length, 16);
  assert.equal(slots[0].start, '10:00:00');
  assert.equal(slots[0].end, '10:30:00');
  assert.equal(slots[15].start, '17:30:00');
  assert.equal(slots[15].end, '18:00:00');
  // every slot's end must equal the next slot's start (no gaps/overlaps)
  for (let i = 0; i < slots.length - 1; i++) {
    assert.equal(slots[i].end, slots[i + 1].start);
  }
});

test('dayOfWeek matches known real calendar dates', () => {
  assert.equal(dayOfWeek('2026-08-07'), 5); // Friday
  assert.equal(dayOfWeek('2026-08-09'), 0); // Sunday
  assert.equal(dayOfWeek('2026-01-01'), 4); // Thursday
  assert.equal(dayOfWeek('2026-12-31'), 4); // Thursday
});

test('dayOfWeek does not shift near UTC midnight (the original local-Date bug this was written to avoid)', () => {
  // If this used `new Date(dateStr)` (local time) instead of Date.UTC, a
  // server running in a timezone west of UTC could compute the wrong day.
  // Testing every day of a full year is the cheapest way to catch any
  // regression back to that bug.
  const start = new Date(Date.UTC(2026, 0, 1));
  for (let i = 0; i < 365; i++) {
    const d = new Date(start.getTime() + i * 86400000);
    const dateStr = `${d.getUTCFullYear()}-${String(d.getUTCMonth() + 1).padStart(2, '0')}-${String(d.getUTCDate()).padStart(2, '0')}`;
    assert.equal(dayOfWeek(dateStr), d.getUTCDay(), `mismatch on ${dateStr}`);
  }
});

test('isDefaultOpen is false only on Sunday', () => {
  assert.equal(isDefaultOpen('2026-08-09'), false); // Sunday
  assert.equal(isDefaultOpen('2026-08-07'), true);  // Friday
  assert.equal(isDefaultOpen('2026-08-08'), true);  // Saturday
  assert.equal(isDefaultOpen('2026-08-10'), true);  // Monday
});

test('isValidSlotRange accepts the full business day', () => {
  assert.equal(isValidSlotRange('10:00', '18:00'), true);
});

test('isValidSlotRange accepts a single 30-min slot', () => {
  assert.equal(isValidSlotRange('10:00', '10:30'), true);
});

test('isValidSlotRange rejects a range starting before business hours', () => {
  assert.equal(isValidSlotRange('09:30', '10:30'), false);
});

test('isValidSlotRange rejects a range ending after business hours', () => {
  assert.equal(isValidSlotRange('17:30', '18:30'), false);
});

test('isValidSlotRange rejects zero-length and inverted ranges', () => {
  assert.equal(isValidSlotRange('10:00', '10:00'), false); // zero length
  assert.equal(isValidSlotRange('11:00', '10:00'), false); // end before start
});

test('isValidSlotRange rejects non-30-min-aligned times', () => {
  assert.equal(isValidSlotRange('10:15', '11:00'), false);
  assert.equal(isValidSlotRange('10:00', '11:15'), false);
  assert.equal(isValidSlotRange('10:05', '10:35'), false);
});

test('isValidSlotRange does not crash and safely rejects malformed/empty input (fuzz-style)', () => {
  const garbageInputs = [
    ['', ''], ['abc', 'def'], [null, null], [undefined, undefined],
    ['10:00', ''], ['', '18:00'], ['25:99', '26:00'], ['-1:00', '10:00'],
  ];
  for (const [s, e] of garbageInputs) {
    assert.doesNotThrow(() => isValidSlotRange(s, e), `threw on (${s}, ${e})`);
    assert.equal(isValidSlotRange(s, e), false, `should reject (${s}, ${e})`);
  }
});

test('slotsInRange returns every 30-min slot start covered by a range', () => {
  assert.deepEqual(slotsInRange('10:00', '11:00'), ['10:00:00', '10:30:00']);
  assert.deepEqual(slotsInRange('10:00', '10:30'), ['10:00:00']);
});

test('slotsInRange returns empty array (not a crash) for an inverted range', () => {
  assert.deepEqual(slotsInRange('11:00', '10:00'), []);
});

test('timeStrToMinutes accepts both HH:MM and HH:MM:SS', () => {
  assert.equal(timeStrToMinutes('10:30'), 630);
  assert.equal(timeStrToMinutes('10:30:00'), 630);
});
