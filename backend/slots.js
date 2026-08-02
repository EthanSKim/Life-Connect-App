// Business hours: 10:00-18:00, 30-minute slots, Monday-Saturday by default.
// Sunday defaults closed but can be opened per-slot via
// facility_availability_overrides (admin-controlled).
const SLOT_START_MIN = 10 * 60;   // 10:00 in minutes-from-midnight
const SLOT_END_MIN = 18 * 60;     // 18:00
const SLOT_LENGTH_MIN = 30;

function pad(n) {
  return String(n).padStart(2, '0');
}

function minutesToTimeStr(mins) {
  return `${pad(Math.floor(mins / 60))}:${pad(mins % 60)}:00`;
}

function timeStrToMinutes(timeStr) {
  // Accepts 'HH:MM' or 'HH:MM:SS'
  const [h, m] = timeStr.split(':').map(Number);
  return h * 60 + m;
}

// Returns the 16 base slots for a day, e.g. [{start:'10:00:00', end:'10:30:00'}, ...]
function generateDaySlots() {
  const slots = [];
  for (let m = SLOT_START_MIN; m < SLOT_END_MIN; m += SLOT_LENGTH_MIN) {
    slots.push({ start: minutesToTimeStr(m), end: minutesToTimeStr(m + SLOT_LENGTH_MIN) });
  }
  return slots;
}

// Parses a 'YYYY-MM-DD' string as a calendar date without local-timezone
// shifting, and returns the day of week (0=Sunday...6=Saturday).
function dayOfWeek(dateStr) {
  const [y, m, d] = dateStr.split('-').map(Number);
  return new Date(Date.UTC(y, m - 1, d)).getUTCDay();
}

function isDefaultOpen(dateStr) {
  return dayOfWeek(dateStr) !== 0; // closed by default only on Sunday
}

// True if a start/end range is 30-min aligned, within business hours, and end > start.
function isValidSlotRange(startTime, endTime) {
  const start = timeStrToMinutes(startTime);
  const end = timeStrToMinutes(endTime);
  if (end <= start) return false;
  if (start % SLOT_LENGTH_MIN !== 0 || end % SLOT_LENGTH_MIN !== 0) return false;
  if (start < SLOT_START_MIN || end > SLOT_END_MIN) return false;
  return true;
}

// All 30-min slot start times (as 'HH:MM:SS') covered by a [startTime, endTime) range.
function slotsInRange(startTime, endTime) {
  const starts = [];
  for (let m = timeStrToMinutes(startTime); m < timeStrToMinutes(endTime); m += SLOT_LENGTH_MIN) {
    starts.push(minutesToTimeStr(m));
  }
  return starts;
}

module.exports = {
  SLOT_START_MIN,
  SLOT_END_MIN,
  SLOT_LENGTH_MIN,
  generateDaySlots,
  dayOfWeek,
  isDefaultOpen,
  isValidSlotRange,
  slotsInRange,
  timeStrToMinutes,
};
