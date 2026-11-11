#!/usr/bin/env node
'use strict';

// Renders Boo's profile card with the same rules as the desktop app.
// Usage: node generate.js --user NAME --name Boo --species ghost --out commit-pet.svg
//        [--tz America/Vancouver] [--demo]   (TZ decides what "today" is)

const fs = require('fs');
const path = require('path');
const { buildCard } = require('./card');
const { computeStats } = require('./stats');

function parseArgs(argv) {
  const args = {};
  for (let i = 2; i < argv.length; i++) {
    if (!argv[i].startsWith('--')) continue;
    const next = argv[i + 1];
    if (next == null || next.startsWith('--')) args[argv[i].slice(2)] = true;
    else { args[argv[i].slice(2)] = next; i++; }
  }
  return args;
}

function localNow(timeZone) {
  const parts = Object.fromEntries(
    new Intl.DateTimeFormat('en-CA', {
      timeZone, year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', hourCycle: 'h23',
    }).formatToParts(new Date()).map((p) => [p.type, p.value]),
  );
  return { today: `${parts.year}-${parts.month}-${parts.day}`, hour: Number(parts.hour) };
}

// The profile graph's day buckets; same data the desktop app reads.
async function fetchDailyCounts(username, token) {
  if (!token) throw new Error('GITHUB_TOKEN is required.');
  const query = `query($login:String!){ user(login:$login){ contributionsCollection{
    contributionCalendar{ weeks{ contributionDays{ date contributionCount } } } } } }`;
  const res = await fetch('https://api.github.com/graphql', {
    method: 'POST',
    headers: { Authorization: `bearer ${token}`, 'Content-Type': 'application/json', 'User-Agent': 'github-touchbar-pet' },
    body: JSON.stringify({ query, variables: { login: username } }),
  });
  if (!res.ok) throw new Error(`GitHub API ${res.status}: ${(await res.text()).slice(0, 200)}`);
  const json = await res.json();
  if (json.errors) throw new Error(json.errors.map((e) => e.message).join('; '));
  const weeks = json.data?.user?.contributionsCollection?.contributionCalendar?.weeks;
  if (!weeks) throw new Error(`No contribution data for "${username}".`);
  const counts = {};
  for (const week of weeks) for (const d of week.contributionDays) counts[d.date] = d.contributionCount;
  return counts;
}

async function main() {
  const args = parseArgs(process.argv);
  const username = args.user || 'octocat';
  const { today, hour } = localNow(args.tz || process.env.TZ || 'UTC');

  const dailyCounts = args.demo
    ? { [today]: 3 }
    : await fetchDailyCounts(username, process.env.GITHUB_TOKEN);
  const stats = computeStats(dailyCounts, today, hour);
  const svg = buildCard({ username, species: args.species || 'ghost', name: args.name, stats });

  const out = args.out || 'commit-pet.svg';
  fs.mkdirSync(path.dirname(path.resolve(out)), { recursive: true });
  fs.writeFileSync(out, svg, 'utf8');
  console.log(`wrote ${out}: Lv${stats.level} ${stats.mood} streak=${stats.streak} today=${stats.todayCount} total=${stats.total}`);
}

main().catch((e) => { console.error(e.message || e); process.exit(1); });
