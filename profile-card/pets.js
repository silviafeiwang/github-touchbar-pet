// Adapted from yukurash/commit-pet (MIT). See THIRD_PARTY_NOTICES.md.
'use strict';

const { hslToHex } = require('./colors');

// Each builder returns the INNER svg (shadow + bobbing group) inside a 192x192 box.
// Animations use SMIL so they play inside a GitHub README <img>.

const SPECIES = ['slime', 'cat', 'ghost'];

function bob(inner, mood) {
  const amp = mood === 'happy' ? 13 : mood === 'content' ? 7 : mood === 'hungry' ? 3 : 2;
  const dur = mood === 'happy' ? '1.15s' : mood === 'content' ? '2.1s' : mood === 'hungry' ? '3s' : '3.6s';
  const sw = 72 - amp * 2;
  const sx = 60 + (72 - sw) / 2;
  return (
    `<rect x="60" y="158" width="72" height="9" fill="#000" opacity="0.12">` +
    `<animate attributeName="width" values="72;${sw};72" dur="${dur}" repeatCount="indefinite"/>` +
    `<animate attributeName="x" values="60;${sx};60" dur="${dur}" repeatCount="indefinite"/></rect>` +
    `<g><animateTransform attributeName="transform" type="translate" values="0 0;0 -${amp};0 0" ` +
    `dur="${dur}" repeatCount="indefinite" calcMode="spline" ` +
    `keySplines="0.4 0 0.6 1;0.4 0 0.6 1" keyTimes="0;0.5;1"/>` +
    inner +
    '</g>'
  );
}

// --- eyes --------------------------------------------------------------------
function blinkEye(x, y, w, h, eye, hi) {
  return (
    `<rect x="${x}" y="${y}" width="${w}" height="${h}" fill="${eye}">` +
    `<animate attributeName="height" values="${h};${h};${h};6;${h};${h}" ` +
    `keyTimes="0;0.85;0.9;0.93;0.96;1" dur="4s" repeatCount="indefinite"/></rect>` +
    (hi ? `<rect x="${x + w - 10}" y="${y + 2}" width="8" height="8" fill="#ffffff"/>` : '')
  );
}

// happy: wide-open shiny eyes with a big highlight
function happyEye(x, y, w, h, eye) {
  return (
    `<rect x="${x}" y="${y}" width="${w}" height="${h}" fill="${eye}"/>` +
    `<rect x="${x + 2}" y="${y + 2}" width="9" height="9" fill="#ffffff"/>` +
    `<rect x="${x + w - 7}" y="${y + h - 7}" width="5" height="5" fill="#ffffff" opacity="0.7"/>`
  );
}

// hungry: half-closed droopy eyes
function tiredEye(x, y, w, h, eye) {
  const lidY = y + Math.round(h * 0.5);
  const eh = Math.max(6, Math.round(h * 0.4));
  return (
    `<rect x="${x}" y="${lidY}" width="${w}" height="${eh}" fill="${eye}"/>` +
    `<rect x="${x}" y="${lidY - 4}" width="${w}" height="3" fill="${eye}" opacity="0.45"/>`
  );
}

// sick: crossed-out X eyes
function crossEye(cx, cy, size, color) {
  const len = size, w = Math.max(4, Math.round(size * 0.32));
  return (
    `<g transform="translate(${cx},${cy})">` +
    `<rect x="${-len / 2}" y="${-w / 2}" width="${len}" height="${w}" fill="${color}" transform="rotate(45)"/>` +
    `<rect x="${-len / 2}" y="${-w / 2}" width="${len}" height="${w}" fill="${color}" transform="rotate(-45)"/></g>`
  );
}

function sadBrow(cx, cy, w, eye, sign) {
  return `<g transform="translate(${cx},${cy}) rotate(${sign * 24})"><rect x="${-w / 2}" y="-3" width="${w}" height="5" fill="${eye}"/></g>`;
}

// --- mouths ------------------------------------------------------------------
function happyMouth(mx, my, mw, eye) {
  return (
    `<rect x="${mx + 2}" y="${my}" width="${mw - 4}" height="15" rx="7" fill="${eye}"/>` +
    `<rect x="${mx + 7}" y="${my + 8}" width="${mw - 14}" height="6" rx="3" fill="#ff7aa2"/>`
  );
}

function contentMouth(cx, my, eye) {
  return (
    `<rect x="${cx - 1}" y="${my + 3}" width="14" height="5" fill="${eye}"/>` +
    `<rect x="${cx - 5}" y="${my - 1}" width="5" height="5" fill="${eye}"/>` +
    `<rect x="${cx + 12}" y="${my - 1}" width="5" height="5" fill="${eye}"/>`
  );
}

function hungryMouth(cx, my, eye) {
  return (
    `<rect x="${cx + 1}" y="${my + 2}" width="11" height="9" rx="4" fill="${eye}"/>` +
    `<rect x="${cx + 4}" y="${my + 11}" width="5" height="10" rx="2" fill="#7fc4ff" opacity="0.85">` +
    `<animate attributeName="height" values="10;15;10" dur="1.6s" repeatCount="indefinite"/></rect>`
  );
}

function sickMouth(mx, my, mw, eye) {
  const half = Math.floor(mw / 2);
  return (
    `<rect x="${mx}" y="${my + 4}" width="${half}" height="7" fill="${eye}"/>` +
    `<rect x="${mx + half}" y="${my - 2}" width="${half}" height="7" fill="${eye}"/>`
  );
}

// --- effects -----------------------------------------------------------------
function sparkle(x, y, sz, delay) {
  return (
    `<g transform="translate(${x},${y})">` +
    `<rect x="${-sz / 2}" y="-2" width="${sz}" height="4" fill="#fff7ad"/>` +
    `<rect x="-2" y="${-sz / 2}" width="4" height="${sz}" fill="#fff7ad"/>` +
    `<animate attributeName="opacity" values="0.15;1;0.15" dur="1.5s" begin="${delay || 0}s" repeatCount="indefinite"/></g>`
  );
}

function heart(x, y) {
  return (
    `<g fill="#ff7aa2">` +
    `<animateTransform attributeName="transform" type="translate" values="0 0;0 -12;0 0" dur="2.2s" repeatCount="indefinite"/>` +
    `<animate attributeName="opacity" values="1;0.25;1" dur="2.2s" repeatCount="indefinite"/>` +
    `<rect x="${x}" y="${y}" width="6" height="6"/><rect x="${x + 8}" y="${y}" width="6" height="6"/>` +
    `<rect x="${x}" y="${y + 6}" width="14" height="6"/><rect x="${x + 3}" y="${y + 12}" width="8" height="5"/></g>`
  );
}

function sweat(x, y) {
  return (
    `<rect x="${x}" y="${y}" width="10" height="14" rx="5" fill="#7fc4ff" opacity="0.9">` +
    `<animate attributeName="opacity" values="0.9;0.35;0.9" dur="1.4s" repeatCount="indefinite"/></rect>`
  );
}

function steam(x, y) {
  return (
    `<g opacity="0.6" fill="#9fb3c8">` +
    `<rect x="${x}" y="${y}" width="5" height="10"/><rect x="${x + 11}" y="${y - 4}" width="5" height="12"/>` +
    `<animate attributeName="opacity" values="0.6;0.15;0.6" dur="1.7s" repeatCount="indefinite"/></g>`
  );
}

// floating thought bubble with a food emoji -- the clear "hungry" sign
function foodBubble(x, y) {
  return (
    `<g>` +
    `<animateTransform attributeName="transform" type="translate" values="0 0;0 -4;0 0" dur="2.4s" repeatCount="indefinite"/>` +
    `<rect x="${x}" y="${y}" width="54" height="50" rx="13" fill="#fffdf6" stroke="#d8d2c2" stroke-width="2"/>` +
    `<text x="${x + 27}" y="${y + 37}" font-size="32" text-anchor="middle">\uD83C\uDF59</text>` +
    `<rect x="${x - 2}" y="${y + 52}" width="10" height="10" rx="5" fill="#fffdf6" stroke="#d8d2c2" stroke-width="1"/>` +
    `<rect x="${x - 10}" y="${y + 60}" width="6" height="6" rx="3" fill="#fffdf6"/>` +
    `</g>`
  );
}

// --- face assembly -----------------------------------------------------------
// p: { ex1, ex2, ey, ew, eh, hi, mx, my, mw, fx, fy }
function face(mood, p, eye) {
  let s = '';
  const cmx = p.mx + Math.floor(p.mw / 2 - 6);
  const e1c = p.ex1 + p.ew / 2;
  const e2c = p.ex2 + p.ew / 2;
  const ecy = p.ey + p.eh / 2;

  if (mood === 'happy') {
    s += happyEye(p.ex1, p.ey, p.ew, p.eh, eye) + happyEye(p.ex2, p.ey, p.ew, p.eh, eye);
    s += happyMouth(p.mx, p.my, p.mw, eye);
    s += sparkle(p.fx, p.fy, 12, 0) + sparkle(192 - p.fx - 4, p.fy + 18, 9, 0.5) + sparkle(p.fx - 2, p.fy + 30, 7, 0.9);
    s += heart(p.fx - 4, p.fy - 14);
  } else if (mood === 'content') {
    s += blinkEye(p.ex1, p.ey, p.ew, p.eh, eye, p.hi) + blinkEye(p.ex2, p.ey, p.ew, p.eh, eye, p.hi);
    s += contentMouth(cmx, p.my, eye);
  } else if (mood === 'hungry') {
    s += tiredEye(p.ex1, p.ey, p.ew, p.eh, eye) + tiredEye(p.ex2, p.ey, p.ew, p.eh, eye);
    s += sadBrow(e1c, p.ey - 9, p.ew * 0.85, eye, -1) + sadBrow(e2c, p.ey - 9, p.ew * 0.85, eye, 1);
    s += hungryMouth(cmx, p.my, eye);
    s += sweat(p.ex2 + p.ew + 8, p.ey - 4);
    s += foodBubble(124, 6);
  } else {
    s += crossEye(e1c, ecy, p.ew * 0.95, eye) + crossEye(e2c, ecy, p.ew * 0.95, eye);
    s += sickMouth(p.mx, p.my, p.mw, eye);
    s += sweat(p.ex2 + p.ew + 6, p.ey - 4);
    s += steam(92, 16);
  }
  return s;
}

// --- color tones -------------------------------------------------------------
// happy = bright, content = normal, hungry = a little dull, sick = pale
function toneSat(mood, base) {
  if (mood === 'sick') return base * 0.45;
  if (mood === 'hungry') return base * 0.72;
  if (mood === 'happy') return base * 1.05;
  return base;
}

function slime(hue, mood) {
  const light = hslToHex(hue, toneSat(mood, 62), mood === 'sick' ? 64 : 68);
  const dark = hslToHex(hue, toneSat(mood, 52), mood === 'sick' ? 50 : 52);
  const cheek = mood === 'sick' ? '#a9c7a0' : '#ff9bb3';
  const body =
    `<g fill="${light}">` +
    '<rect x="84" y="36" width="24" height="12"/><rect x="72" y="48" width="48" height="12"/>' +
    '<rect x="60" y="60" width="72" height="12"/><rect x="48" y="72" width="96" height="12"/>' +
    '<rect x="48" y="84" width="96" height="12"/><rect x="48" y="96" width="96" height="12"/></g>' +
    `<g fill="${dark}">` +
    '<rect x="48" y="108" width="96" height="12"/><rect x="48" y="120" width="96" height="12"/>' +
    '<rect x="60" y="132" width="72" height="12"/></g>' +
    '<rect x="60" y="48" width="12" height="24" fill="#ffffff" opacity="0.4"/>' +
    `<rect x="48" y="84" width="12" height="12" fill="${cheek}"/>` +
    `<rect x="132" y="84" width="12" height="12" fill="${cheek}"/>`;
  const f = face(mood, { ex1: 60, ex2: 108, ey: 72, ew: 24, eh: 24, hi: true, mx: 84, my: 96, mw: 24, fx: 150, fy: 52 }, '#1d3329');
  return bob(body + f, mood);
}

function cat(hue, mood) {
  const fur = hslToHex(hue, toneSat(mood, 60), mood === 'sick' ? 58 : 62);
  const stripe = hslToHex(hue, toneSat(mood, 55), mood === 'sick' ? 44 : 46);
  const cheek = mood === 'sick' ? '#bcae9b' : '#ff9bb3';
  const body =
    `<g fill="${fur}">` +
    '<rect x="48" y="36" width="24" height="12"/><rect x="120" y="36" width="24" height="12"/>' +
    '<rect x="36" y="48" width="120" height="12"/><rect x="36" y="60" width="120" height="12"/>' +
    '<rect x="36" y="72" width="120" height="12"/><rect x="36" y="84" width="120" height="12"/>' +
    '<rect x="48" y="96" width="96" height="12"/><rect x="48" y="108" width="96" height="12"/>' +
    '<rect x="48" y="120" width="96" height="12"/><rect x="60" y="132" width="72" height="12"/>' +
    '<rect x="144" y="84" width="12" height="12"/><rect x="144" y="96" width="12" height="48"/></g>' +
    '<rect x="60" y="36" width="12" height="12" fill="#ff9bb3"/>' +
    '<rect x="120" y="36" width="12" height="12" fill="#ff9bb3"/>' +
    `<g fill="${stripe}"><rect x="72" y="48" width="12" height="12"/>` +
    '<rect x="96" y="48" width="12" height="12"/><rect x="120" y="48" width="12" height="12"/>' +
    '<rect x="144" y="108" width="12" height="12"/><rect x="144" y="132" width="12" height="12"/></g>' +
    `<rect x="36" y="72" width="12" height="12" fill="${cheek}"/>` +
    `<rect x="144" y="72" width="12" height="12" fill="${cheek}"/>` +
    '<rect x="84" y="84" width="24" height="12" fill="#ff7aa2"/>';
  const f = face(mood, { ex1: 72, ex2: 108, ey: 60, ew: 12, eh: 24, hi: false, mx: 84, my: 96, mw: 24, fx: 150, fy: 40 }, '#1d3329');
  return bob(body + f, mood);
}

function ghost(hue, mood) {
  const light = hslToHex(hue, toneSat(mood, 40), mood === 'sick' ? 88 : 93);
  const shade = hslToHex(hue, toneSat(mood, 35), mood === 'sick' ? 78 : 80);
  const blush = mood === 'sick' ? '#bcd0c4' : '#ffb3c7';
  const body =
    `<g fill="${light}">` +
    '<rect x="72" y="36" width="48" height="12"/><rect x="60" y="48" width="72" height="12"/>' +
    '<rect x="60" y="60" width="72" height="12"/><rect x="60" y="72" width="72" height="12"/>' +
    '<rect x="60" y="84" width="72" height="12"/><rect x="60" y="96" width="72" height="12"/>' +
    '<rect x="60" y="108" width="72" height="12"/>' +
    '<rect x="60" y="120" width="12" height="12"/><rect x="84" y="120" width="12" height="12"/>' +
    '<rect x="108" y="120" width="12" height="12"/></g>' +
    `<rect x="120" y="60" width="12" height="60" fill="${shade}"/>` +
    `<rect x="60" y="84" width="12" height="12" fill="${blush}"/>` +
    `<rect x="120" y="84" width="12" height="12" fill="${blush}"/>`;
  const f = face(mood, { ex1: 72, ex2: 108, ey: 60, ew: 12, eh: 24, hi: false, mx: 84, my: 84, mw: 24, fx: 150, fy: 42 }, '#2a2f45');
  return bob(body + f, mood);
}

const BUILDERS = { slime, cat, ghost };

function renderPet(species, hue, mood) {
  const fn = BUILDERS[species] || slime;
  return fn(hue, mood);
}

module.exports = { renderPet, SPECIES };
