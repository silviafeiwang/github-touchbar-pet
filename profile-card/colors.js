// Adapted from yukurash/commit-pet (MIT). See THIRD_PARTY_NOTICES.md.
'use strict';

// Deterministic helpers: username -> stable color, no external deps.

function hashString(str) {
  let h = 2166136261 >>> 0; // FNV-1a
  const s = String(str);
  for (let i = 0; i < s.length; i++) {
    h ^= s.charCodeAt(i);
    h = Math.imul(h, 16777619) >>> 0;
  }
  return h >>> 0;
}

function hueFromSeed(seed) {
  return hashString(seed) % 360;
}

// HSL -> #rrggbb (we output hex for maximum SVG renderer compatibility).
function hslToHex(h, s, l) {
  s /= 100;
  l /= 100;
  const k = (n) => (n + h / 30) % 12;
  const a = s * Math.min(l, 1 - l);
  const f = (n) => l - a * Math.max(-1, Math.min(k(n) - 3, Math.min(9 - k(n), 1)));
  const toHex = (x) => Math.round(255 * x).toString(16).padStart(2, '0');
  return '#' + toHex(f(0)) + toHex(f(8)) + toHex(f(4));
}

module.exports = { hashString, hueFromSeed, hslToHex };
