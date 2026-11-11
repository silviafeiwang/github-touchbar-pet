'use strict';

// Boo's rules. Keep in sync with Sources/CommitPetTouchBar/ContributionCalendar.swift
// (PetStats.from) and StreakGuard.swift (first reminder hour) so the profile card
// and desktop Boo always agree.

const FIRST_REMINDER_HOUR = 10;

// dailyCounts: { 'YYYY-MM-DD': Number }, today: 'YYYY-MM-DD', hour: 0-23 (local)
function computeStats(dailyCounts, today, hour) {
  const count = (day) => dailyCounts[day] || 0;
  const total = Object.values(dailyCounts).reduce((sum, n) => sum + n, 0);
  const todayCount = count(today);

  // Streak isn't broken until today is over.
  let day = todayCount > 0 ? today : shiftDay(today, -1);
  let streak = 0;
  while (count(day) > 0) {
    streak++;
    day = shiftDay(day, -1);
  }

  let idle = 0;
  day = shiftDay(today, -1);
  while (count(day) === 0 && idle < 30) {
    idle++;
    day = shiftDay(day, -1);
  }

  let mood;
  if (todayCount > 0) mood = 'happy';
  else if (idle >= 3) mood = 'sick';
  else if (idle === 0 && hour < FIRST_REMINDER_HOUR) mood = 'content';
  else mood = 'hungry';

  return { total, todayCount, streak, mood, level: levelFromTotal(total) };
}

// 20 contributions → Lv2, 80 → Lv3, 500 → Lv6.
function levelFromTotal(total) {
  return 1 + Math.floor(Math.sqrt(Math.max(total, 0) / 20));
}

function shiftDay(day, delta) {
  const d = new Date(`${day}T12:00:00Z`);
  d.setUTCDate(d.getUTCDate() + delta);
  return d.toISOString().slice(0, 10);
}

const MOOD_LABEL = { happy: 'Happy', content: 'Okay', hungry: 'Hungry', sick: 'Sick' };
const MOOD_ICON = { happy: '✨', content: '🙂', hungry: '🍙', sick: '🤒' };

module.exports = { computeStats, levelFromTotal, shiftDay, MOOD_LABEL, MOOD_ICON };
