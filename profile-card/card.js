'use strict';

// Card layout adapted from yukurash/commit-pet (MIT). See THIRD_PARTY_NOTICES.md.

const { renderPet } = require('./pets');
const { hueFromSeed } = require('./colors');
const { MOOD_LABEL, MOOD_ICON } = require('./stats');

const REPO_URL = 'https://github.com/silviafeiwang/github-touchbar-pet';
const FONT = `font-family="'Segoe UI',Verdana,sans-serif"`;

function esc(s) {
  return String(s).replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
}

function buildCard({ username, species = 'ghost', name, stats }) {
  const hue = hueFromSeed(username || species);
  const petName = name || username;
  const moodLabel = MOOD_LABEL[stats.mood];
  const feed = { happy: 5, content: 4, hungry: 2, sick: 1 }[stats.mood];
  let bar = '';
  for (let i = 0; i < 5; i++) {
    bar += `<rect x="${248 + i * 26}" y="150" width="20" height="14" rx="2" fill="${i < feed ? '#ffd166' : '#3a3f55'}"/>`;
  }
  const days = stats.streak === 1 ? 'day' : 'days';

  return (
    `<svg xmlns="http://www.w3.org/2000/svg" width="480" height="200" viewBox="0 0 480 200" ` +
    `role="img" aria-label="${esc(petName)} - Lv${stats.level} ${moodLabel}">` +
    '<defs><linearGradient id="bg" x1="0" y1="0" x2="0" y2="1">' +
    '<stop offset="0" stop-color="#1b2030"/><stop offset="1" stop-color="#11151f"/></linearGradient></defs>' +
    '<rect x="0" y="0" width="480" height="200" rx="16" fill="url(#bg)"/>' +
    '<rect x="1" y="1" width="478" height="198" rx="15" fill="none" stroke="#2c3346" stroke-width="2"/>' +
    '<rect x="16" y="16" width="200" height="168" rx="12" fill="#0d1018"/>' +
    `<g transform="translate(12,8)" shape-rendering="crispEdges">${renderPet(species, hue, stats.mood)}</g>` +
    `<text x="240" y="46" ${FONT} font-size="22" font-weight="700" fill="#f4f6ff">${esc(petName)}</text>` +
    `<text x="240" y="74" ${FONT} font-size="15" fill="#9aa7c7">Lv ${stats.level} ・ ${MOOD_ICON[stats.mood]} ${moodLabel}</text>` +
    `<text x="240" y="104" ${FONT} font-size="15" fill="#cdd6ef">🔥 ${stats.streak} ${days}　🌱 ${stats.todayCount} today</text>` +
    `<text x="240" y="130" ${FONT} font-size="13" fill="#7e8aa8">${stats.total} contributions this year</text>` +
    bar +
    `<a href="${REPO_URL}"><text x="464" y="190" text-anchor="end" ${FONT} font-size="11" fill="#6b76a0">★ GitHub Touch Bar Pet</text></a>` +
    '</svg>'
  );
}

module.exports = { buildCard };
