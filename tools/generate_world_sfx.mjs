import fs from "node:fs/promises";
import path from "node:path";

// Reproducible sounds for Verdant / Frozen enemies, weather and mining
// (mono 16-bit 22050 Hz PCM; same recipe as generate_enemy_sfx.mjs).
// Run from the project root: node tools/generate_world_sfx.mjs
// *_loop.wav files are seamless (tail cross-faded into the head) and are
// imported with loop_mode = forward.
const sampleRate = 22050;
const TAU = 2 * Math.PI;
let seed = 1;

function random() {
  seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0;
  return seed / 0x100000000 * 2 - 1;
}
const lowPass = (xs, k) => { let s = 0; return xs.map((x) => (s += k * (x - s))); };
const highPass = (xs, k) => { const l = lowPass(xs, k); return xs.map((x, i) => x - l[i]); };
const bandPass = (xs, lo, hi) => highPass(lowPass(xs, hi), lo);

function writeWav(samples) {
  const bytes = Buffer.alloc(44 + samples.length * 2);
  bytes.write("RIFF", 0);
  bytes.writeUInt32LE(bytes.length - 8, 4);
  bytes.write("WAVEfmt ", 8);
  bytes.writeUInt32LE(16, 16);
  bytes.writeUInt16LE(1, 20);
  bytes.writeUInt16LE(1, 22);
  bytes.writeUInt32LE(sampleRate, 24);
  bytes.writeUInt32LE(sampleRate * 2, 28);
  bytes.writeUInt16LE(2, 32);
  bytes.writeUInt16LE(16, 34);
  bytes.write("data", 36);
  bytes.writeUInt32LE(samples.length * 2, 40);
  for (let i = 0; i < samples.length; i += 1) {
    const limited = Math.tanh(samples[i] * 1.2) * 0.82;
    bytes.writeInt16LE(Math.round(limited * 32767), 44 + i * 2);
  }
  return bytes;
}

const fade = (x, t, d, fin, fout) => x * Math.max(0, Math.min(t / fin, (d - t) / fout, 1));
function sweep(t, f0, f1, len) {
  const u = Math.min(t, len);
  return TAU * (f0 * u + (f1 - f0) * u * u / (2 * len)) + (t > len ? TAU * f1 * (t - len) : 0);
}
const env = (t, at, k) => (t >= at ? Math.exp(-(t - at) * k) : 0);

// Sparse random clicks (pebbles, ice bits, splinters, coins...).
function clicks(length, start, count, spread, decay, pitch, ring = 160) {
  const out = new Array(length).fill(0);
  for (let c = 0; c < count; c += 1) {
    const at = Math.floor((start + Math.abs(random()) * spread) * sampleRate);
    const amp = 0.35 + Math.abs(random()) * 0.65;
    const freq = pitch * (0.7 + Math.abs(random()) * 0.8);
    const len = Math.floor(sampleRate * 0.05);
    for (let i = 0; i < len && at + i < length; i += 1) {
      const t = i / sampleRate;
      out[at + i] += Math.sin(TAU * freq * t) * Math.exp(-t * ring) * amp * Math.exp(-(at / sampleRate - start) * decay);
    }
  }
  return out;
}

function noises(length) {
  const white = Array.from({ length }, random);
  return {
    white,
    soft: lowPass(white, 0.25),
    dark: lowPass(white, 0.05),
    deep: lowPass(white, 0.015),
    bright: highPass(white, 0.4),
    mid: bandPass(white, 0.08, 0.35),
    length,
  };
}

function synth(name, seconds, make) {
  seed = [...name].reduce((a, c) => Math.imul(a, 31) + c.charCodeAt(0), 0x2468) >>> 0;
  const length = Math.round(sampleRate * seconds);
  const n = noises(length);
  const fn = make(n, length);
  return Array.from({ length }, (_, i) => fn(i / sampleRate, i, seconds));
}

// Seamless loop: render seconds + xfade, then blend the tail into the head.
function loop(name, seconds, xfade, make) {
  const raw = synth(name, seconds + xfade, make);
  const length = Math.round(sampleRate * seconds);
  const fadeLen = Math.round(sampleRate * xfade);
  const out = raw.slice(0, length);
  for (let i = 0; i < fadeLen; i += 1) {
    const k = i / fadeLen;
    out[i] = raw[i] * k + raw[length + i] * (1 - k);
  }
  return out;
}

// Short whoosh (swing / throw), from f0 to f1 in `len` seconds.
const whoosh = (t, i, n, len, gain = 1) => {
  const shape = Math.sin(Math.PI * Math.min(t / len, 1));
  return n.mid[i] * 2.4 * shape * shape * gain;
};

// Wet splat (goblin / yeti gore).
const splat = (t, i, n, at = 0, size = 1) => {
  if (t < at) return 0;
  const u = t - at;
  return (n.dark[i] * 4 * Math.exp(-u * 18 / size) + Math.sin(sweep(u, 220 / size, 70 / size, 0.08)) * Math.exp(-u * 30 / size) * 0.7);
};

const files = {
  // ------------------------------------------------------------ Verdant
  "Enemies/Verdant/goblin_attack.wav": ["g_atk", 0.22, (n) => (t, i, d) =>
    fade(whoosh(t, i, n, 0.12) + Math.sin(TAU * 1900 * t) * env(t, 0.11, 70) * 0.35 + n.bright[i] * env(t, 0.11, 200) * 0.6, t, d, 0.002, 0.03)],
  "Enemies/Verdant/goblin_death.wav": ["g_death", 0.4, (n) => (t, i, d) =>
    fade(splat(t, i, n) + Math.sin(sweep(t, 900, 320, 0.18)) * Math.exp(-t * 9) * 0.28 * (t < 0.2 ? 1 : 0), t, d, 0.001, 0.06)],
  "Enemies/Verdant/elite_goblin_attack.wav": ["eg_atk", 0.35, (n) => (t, i, d) =>
    fade(whoosh(t, i, n, 0.18, 1.2) + Math.sin(sweep(t - 0.17, 160, 70, 0.08)) * env(t, 0.17, 25) + n.dark[i] * 3 * env(t, 0.17, 30) * 0.5, t, d, 0.002, 0.04)],
  "Enemies/Verdant/elite_goblin_death.wav": ["eg_death", 0.75, (n) => {
    const clang = (t) => [1180, 1730, 2650].reduce((a, f, k) => a + Math.sin(TAU * f * t) * [0.4, 0.28, 0.16][k], 0);
    return (t, i, d) => fade(splat(t, i, n, 0, 1.4) + (t > 0.22 ? clang(t - 0.22) * env(t, 0.22, 6) * 0.5 : 0), t, d, 0.001, 0.12);
  }],
  "Enemies/Verdant/goblin_hunter_attack.wav": ["gh_atk", 0.3, (n) => (t, i, d) =>
    fade(Math.sin(sweep(t, 420, 180, 0.06)) * Math.exp(-t * 40) * 0.5 + whoosh(t, i, n, 0.25, 0.9), t, d, 0.001, 0.04)],
  "Enemies/Verdant/goblin_engineer_attack.wav": ["ge_atk", 0.4, (n) => (t, i, d) =>
    fade(n.bright[i] * (0.5 + 0.3 * Math.sin(TAU * 50 * t)) * Math.exp(-t * 4) * 0.5 + whoosh(t - 0.12 > 0 ? t - 0.12 : 0, i, n, 0.22, t > 0.12 ? 0.9 : 0), t, d, 0.003, 0.05)],
  "Enemies/Verdant/dynamite_explode.wav": ["dyn", 0.75, (n, len) => {
    const sparks = clicks(len, 0.04, 18, 0.4, 5, 3000);
    return (t, i, d) => fade(Math.sin(sweep(t, 150, 45, 0.25)) * Math.exp(-t * 7) + n.soft[i] * Math.exp(-t * 20) * 1.1 + n.dark[i] * 3 * Math.exp(-t * 6) * 0.5 + sparks[i] * 0.3, t, d, 0.001, 0.08);
  }],
  "Enemies/Verdant/chariot_throw.wav": ["ch_throw", 0.9, (n) => {
    const creak = (t) => Math.sin(sweep(t, 180, 260, 0.35)) * (0.6 + 0.4 * Math.sin(TAU * 31 * t));
    return (t, i, d) => fade(creak(t) * (t < 0.35 ? 0.35 : 0) + Math.sin(sweep(t - 0.35, 120, 55, 0.1)) * env(t, 0.35, 18) + n.dark[i] * 3 * env(t, 0.35, 25) * 0.6 + whoosh(Math.max(t - 0.38, 0), i, n, 0.45, t > 0.38 ? 1.1 : 0), t, d, 0.005, 0.08);
  }],
  "Enemies/Verdant/chariot_berserk.wav": ["ch_berserk", 1.6, (n) => (t, i, d) => {
    const swell = Math.min(t / 0.25, 1) * (t > 1.1 ? Math.exp(-(t - 1.1) * 5) : 1);
    const horn = [1, 2, 3, 4, 5].reduce((a, h) => a + Math.sin(TAU * 98 * h * t + 0.4 * Math.sin(TAU * 5.5 * t)) / (h * 1.3), 0);
    return fade(horn * swell * 0.55 + n.deep[i] * 8 * Math.min(t / 0.4, 1) * 0.35, t, d, 0.02, 0.2);
  }],
  "Enemies/Verdant/chariot_ram.wav": ["ch_ram", 0.5, (n, len) => {
    const splinters = clicks(len, 0.02, 14, 0.2, 9, 1400, 120);
    return (t, i, d) => fade(Math.sin(sweep(t, 110, 50, 0.12)) * Math.exp(-t * 12) + n.dark[i] * 3.4 * Math.exp(-t * 18) * 0.6 + splinters[i] * 0.45, t, d, 0.001, 0.06);
  }],
  "Enemies/Verdant/chariot_death.wav": ["ch_death", 1.8, (n, len) => {
    const splinters = clicks(len, 0.05, 70, 1.1, 2.4, 1300, 110);
    const wheels = clicks(len, 0.5, 9, 1.0, 1.5, 420, 60);
    return (t, i, d) => fade(Math.sin(sweep(t, 90, 35, 0.4)) * Math.exp(-t * 3.5) + n.dark[i] * 3 * Math.exp(-t * 5) * 0.6 + n.deep[i] * 8 * Math.exp(-t * 2) * 0.4 + splinters[i] * 0.5 + wheels[i] * 0.5, t, d, 0.001, 0.3);
  }],

  // ------------------------------------------------------------ Frozen
  "Enemies/Frozen/snow_attack.wav": ["s_atk", 0.25, (n) => (t, i, d) =>
    fade(n.soft[i] * Math.exp(-t * 22) * 1.1 + Math.sin(sweep(t, 160, 80, 0.06)) * Math.exp(-t * 35) * 0.6, t, d, 0.001, 0.04)],
  "Enemies/Frozen/snow_death.wav": ["s_death", 0.55, (n, len) => {
    const ice = clicks(len, 0.03, 12, 0.3, 6, 4200, 220);
    return (t, i, d) => fade(splat(t, i, n) + n.soft[i] * Math.exp(-t * 10) * 0.5 + ice[i] * 0.35, t, d, 0.001, 0.08);
  }],
  "Enemies/Frozen/big_snow_attack.wav": ["bs_atk", 0.5, (n, len) => {
    const ice = clicks(len, 0.17, 10, 0.18, 8, 3800, 200);
    return (t, i, d) => fade(whoosh(t, i, n, 0.17) + Math.sin(sweep(t - 0.16, 120, 50, 0.1)) * env(t, 0.16, 16) + n.bright[i] * env(t, 0.16, 70) * 0.7 + ice[i] * 0.4, t, d, 0.002, 0.06);
  }],
  "Enemies/Frozen/big_snow_death.wav": ["bs_death", 0.9, (n, len) => {
    const ice = clicks(len, 0.3, 14, 0.4, 5, 3200, 160);
    return (t, i, d) => fade(splat(t, i, n, 0, 1.5) + Math.sin(sweep(t - 0.3, 260, 180, 0.2)) * env(t, 0.3, 9) * 0.35 + ice[i] * 0.4, t, d, 0.001, 0.12);
  }],
  "Enemies/Frozen/wizard_attack.wav": ["w_atk", 0.5, (n) => (t, i, d) => {
    const shimmer = [1, 1.5, 2.02].reduce((a, k) => a + Math.sin(sweep(t, 900 * k, 1600 * k, 0.4)), 0) * 0.13;
    return fade(shimmer * Math.sin(Math.PI * Math.min(t / 0.45, 1)) + whoosh(Math.max(t - 0.25, 0), i, n, 0.22, t > 0.25 ? 0.7 : 0), t, d, 0.01, 0.05);
  }],
  "Enemies/Frozen/wizard_death.wav": ["w_death", 0.8, (n, len) => {
    const sparkle = clicks(len, 0.1, 20, 0.6, 3, 5200, 90);
    return (t, i, d) => fade(splat(t, i, n) + Math.sin(sweep(t, 1400, 600, 0.6)) * Math.exp(-t * 3.5) * 0.15 + sparkle[i] * 0.3, t, d, 0.001, 0.12);
  }],
  "Enemies/Frozen/sled_attack.wav": ["sl_atk", 0.45, (n, len) => {
    const wood = clicks(len, 0.01, 6, 0.08, 10, 900, 100);
    return (t, i, d) => fade(Math.sin(sweep(t, 140, 60, 0.1)) * Math.exp(-t * 14) + n.soft[i] * Math.exp(-t * 9) * 0.6 + wood[i] * 0.4, t, d, 0.001, 0.06);
  }],
  "Enemies/Frozen/sled_death.wav": ["sl_death", 1.0, (n, len) => {
    const splinters = clicks(len, 0.03, 40, 0.6, 3.5, 1250, 110);
    return (t, i, d) => fade(Math.sin(sweep(t, 120, 45, 0.25)) * Math.exp(-t * 6) + n.soft[i] * Math.exp(-t * 6) * 0.7 + splinters[i] * 0.5, t, d, 0.001, 0.15);
  }],
  "Enemies/Frozen/mega_attack.wav": ["m_atk", 0.7, (n) => (t, i, d) =>
    fade(whoosh(t, i, n, 0.5, 1.4) + n.dark[i] * 3 * Math.sin(Math.PI * Math.min(t / 0.5, 1)) * 0.4, t, d, 0.01, 0.08)],
  "Enemies/Frozen/mega_freeze_throw.wav": ["m_freeze", 1.2, (n) => (t, i, d) => {
    const crystal = [1, 1.26, 1.5, 2.0].reduce((a, k) => a + Math.sin(TAU * 1320 * k * t), 0) * 0.08 * (0.6 + 0.4 * Math.sin(TAU * 9 * t));
    return fade(crystal * Math.min(t / 0.3, 1) + whoosh(Math.max(t - 0.35, 0), i, n, 0.6, t > 0.35 ? 1.3 : 0), t, d, 0.02, 0.15);
  }],
  "Enemies/Frozen/mega_death.wav": ["m_death", 2.2, (n, len) => {
    const ice = clicks(len, 0.4, 50, 1.4, 1.6, 2800, 140);
    return (t, i, d) => fade(Math.sin(sweep(t, 80, 30, 0.6)) * Math.exp(-t * 2.2) + n.soft[i] * Math.exp(-t * 1.4) * 0.6 * Math.min(t / 0.2, 1) + n.deep[i] * 9 * Math.exp(-t * 1.5) * 0.4 + ice[i] * 0.35, t, d, 0.001, 0.4);
  }],

  // ------------------------------------------------------------ Weather
  "Weather/blizzard_loop.wav": ["blizzard", 4.0, (n) => (t, i) => {
    const gust = 0.55 + 0.25 * Math.sin(TAU * 0.25 * t) + 0.2 * Math.sin(TAU * 0.75 * t + 1.3);
    const howl = Math.sin(TAU * (420 + 60 * Math.sin(TAU * 0.25 * t)) * t) * 0.05 * gust;
    return n.mid[i] * 1.6 * gust + n.dark[i] * 1.4 * gust + howl;
  }],
  "Weather/rain_loop.wav": ["rain", 4.0, (n, len) => {
    const drops = clicks(len, 0, 1400, 4.2, 0, 2600, 380);
    return (t, i) => n.bright[i] * 0.45 + n.soft[i] * 0.25 + drops[i] * 0.22;
  }],
  "Weather/blood_moon_loop.wav": ["moon_loop", 4.0, (n) => (t, i) => {
    const pulse = 0.7 + 0.3 * Math.sin(TAU * 0.5 * t);
    return (Math.sin(TAU * 55 * t) * 0.3 + Math.sin(TAU * 82.5 * t) * 0.15 + Math.sin(TAU * 110.5 * t) * 0.06) * pulse + n.deep[i] * 2.5;
  }],
  "Weather/blood_moon_start.wav": ["moon_start", 3.0, (n) => (t, i, d) => {
    const rise = Math.min(t / 1.6, 1);
    const chord = [55, 58.3, 82.4, 110, 116.5].reduce((a, f, k) => a + Math.sin(TAU * f * t * (1 + 0.04 * rise)) * [0.35, 0.18, 0.2, 0.14, 0.08][k], 0);
    const shriek = Math.sin(sweep(t, 600, 980, 2.5)) * 0.05 * rise;
    return fade((chord + shriek) * rise + n.deep[i] * 4 * rise * 0.5, t, d, 0.05, 0.9);
  }],
  "Weather/thunder.wav": ["thunder", 2.6, (n) => (t, i, d) => {
    const crack = n.bright[i] * (Math.exp(-t * 30) + 0.7 * env(t, 0.06, 25) + 0.4 * env(t, 0.13, 20));
    const roll = n.deep[i] * 10 * Math.min(t / 0.15, 1) * Math.exp(-t * 1.3) * (0.75 + 0.25 * Math.sin(TAU * 3 * t));
    return fade(crack * 1.1 + roll * 0.7 + n.dark[i] * 3 * Math.exp(-t * 4) * 0.4, t, d, 0.001, 0.6);
  }],
  "Weather/storm_warning.wav": ["storm_warn", 2.6, (n) => (t, i, d) =>
    fade(n.deep[i] * 9 * Math.sin(Math.PI * Math.min(t / 2.4, 1)) * (0.7 + 0.3 * Math.sin(TAU * 2.2 * t)) * 0.6, t, d, 0.2, 0.5)],
  "Weather/freeze_start.wav": ["freeze_on", 1.0, (n, len) => {
    const crystals = clicks(len, 0, 60, 0.75, 1, 3600, 120);
    return (t, i, d) => fade(crystals[i] * 0.5 + n.bright[i] * 0.25 * Math.min(t / 0.6, 1) * Math.exp(-Math.max(t - 0.6, 0) * 8) + Math.sin(sweep(t, 1800, 2600, 0.8)) * 0.05, t, d, 0.01, 0.15);
  }],
  "Weather/freeze_break.wav": ["freeze_off", 0.8, (n, len) => {
    const shards = clicks(len, 0.01, 40, 0.5, 4, 3800, 110);
    return (t, i, d) => fade(n.bright[i] * Math.exp(-t * 25) * 1.1 + shards[i] * 0.55 + Math.sin(sweep(t, 300, 120, 0.1)) * Math.exp(-t * 30) * 0.4, t, d, 0.001, 0.12);
  }],
  "Weather/freeze_click.wav": ["freeze_click", 0.12, (n) => (t, i, d) =>
    fade(n.bright[i] * Math.exp(-t * 60) * 0.8 + Math.sin(TAU * 3100 * t) * Math.exp(-t * 50) * 0.3, t, d, 0.0005, 0.02)],
  "Weather/boss_entrance.wav": ["entrance", 3.2, (n) => (t, i, d) =>
    fade(n.deep[i] * 11 * Math.min(t / 0.5, 1) * (0.8 + 0.2 * Math.sin(TAU * 7 * t)) * 0.7 + n.soft[i] * 0.35 * Math.min(t / 1.0, 1), t, d, 0.05, 0.8)],

  // ------------------------------------------------------------ Mining
  "Mining/pick_stone.wav": ["pick", 0.25, (n) => (t, i, d) =>
    fade([2400, 3550, 5100].reduce((a, f, k) => a + Math.sin(TAU * f * t) * [0.3, 0.2, 0.1][k], 0) * Math.exp(-t * 28) + n.bright[i] * Math.exp(-t * 180) * 0.8 + Math.sin(TAU * 260 * t) * Math.exp(-t * 60) * 0.3, t, d, 0.0005, 0.04)],
  "Mining/axe_wood.wav": ["axe", 0.25, (n) => (t, i, d) =>
    fade(Math.sin(sweep(t, 420, 220, 0.05)) * Math.exp(-t * 40) * 0.8 + n.mid[i] * 2 * Math.exp(-t * 45) + n.bright[i] * Math.exp(-t * 200) * 0.5, t, d, 0.0005, 0.04)],
  "Mining/shovel_dirt.wav": ["shovel", 0.3, (n) => (t, i, d) =>
    fade(n.soft[i] * Math.exp(-t * 14) * 1.2 + Math.sin(TAU * 1500 * t) * Math.exp(-t * 80) * 0.15 + n.dark[i] * 2 * Math.exp(-t * 20) * 0.4, t, d, 0.001, 0.05)],
  "Mining/crystal_break.wav": ["crystal", 0.9, (n, len) => {
    const tinkle = clicks(len, 0.03, 26, 0.5, 4, 3600, 70);
    return (t, i, d) => fade(n.bright[i] * Math.exp(-t * 40) * 0.9 + [1760, 2640, 3520, 4400].reduce((a, f, k) => a + Math.sin(TAU * f * t) * [0.2, 0.14, 0.1, 0.06][k], 0) * Math.exp(-t * 6) + tinkle[i] * 0.4, t, d, 0.0005, 0.15);
  }],
  "Mining/tree_fall.wav": ["tree", 1.6, (n, len) => {
    const leaves = clicks(len, 0.2, 60, 1.0, 2, 2200, 260);
    return (t, i, d) => fade(n.bright[i] * (Math.exp(-t * 18) + 0.5 * env(t, 0.12, 22) + 0.4 * env(t, 0.25, 18)) * 0.8 + n.soft[i] * Math.sin(Math.PI * Math.min(t / 0.9, 1)) * 0.35 + Math.sin(sweep(t - 0.85, 100, 45, 0.2)) * env(t, 0.85, 7) + n.dark[i] * 3 * env(t, 0.85, 8) * 0.5 + leaves[i] * 0.2, t, d, 0.001, 0.3);
  }],
  "Mining/grave_open.wav": ["grave", 1.0, (n) => (t, i, d) => {
    const creak = Math.sin(sweep(Math.max(t - 0.2, 0), 120, 190, 0.6)) * (0.6 + 0.4 * Math.sin(TAU * 27 * t)) * (t > 0.2 && t < 0.8 ? 0.3 : 0);
    return fade(n.soft[i] * Math.exp(-t * 8) * 0.8 + creak + Math.sin(sweep(t - 0.8, 140, 60, 0.1)) * env(t, 0.8, 20) * 0.6, t, d, 0.002, 0.08);
  }],
  "Mining/ore_collect.wav": ["ore", 0.35, () => (t, i, d) =>
    fade((Math.sin(TAU * 1568 * t) * env(t, 0, 14) + Math.sin(TAU * 2093 * t) * env(t, 0.07, 12)) * 0.35 + Math.sin(TAU * 4186 * t) * env(t, 0.07, 30) * 0.1, t, d, 0.001, 0.05)],
  "Mining/drill_tick.wav": ["drill", 0.35, (n) => (t, i, d) =>
    fade((Math.sin(TAU * 130 * t) * 0.4 + n.mid[i] * 1.6) * (0.6 + 0.4 * Math.sin(TAU * 34 * t)) * Math.sin(Math.PI * t / d), t, d, 0.01, 0.05)],
  "Mining/qte_marker.wav": ["marker", 0.35, () => (t, i, d) =>
    fade((Math.sin(TAU * 1175 * t) * env(t, 0, 10) + Math.sin(TAU * 1760 * t) * env(t, 0.09, 10)) * 0.35, t, d, 0.002, 0.08)],
  "Mining/qte_burst_hit.wav": ["burst", 0.22, (n) => (t, i, d) =>
    fade(Math.sin(sweep(t, 300, 120, 0.05)) * Math.exp(-t * 40) * 0.7 + n.bright[i] * Math.exp(-t * 120) * 0.7 + Math.sin(TAU * 2350 * t) * Math.exp(-t * 25) * 0.25, t, d, 0.0005, 0.04)],
  "Mining/qte_check_start.wav": ["check", 0.5, () => (t, i, d) =>
    fade([0, 0.12, 0.24].reduce((a, at) => a + Math.sin(TAU * 2000 * t) * env(t, at, 60), 0) * 0.3, t, d, 0.001, 0.05)],
  "Mining/qte_good.wav": ["good", 0.4, (n) => (t, i, d) =>
    fade(Math.sin(TAU * 2400 * t) * Math.exp(-t * 18) * 0.3 + Math.sin(TAU * 3600 * t) * Math.exp(-t * 22) * 0.15 + n.bright[i] * Math.exp(-t * 150) * 0.5, t, d, 0.0005, 0.06)],
  "Mining/qte_perfect.wav": ["perfect", 0.7, () => (t, i, d) =>
    fade([1568, 1976, 2349, 3136].reduce((a, f, k) => a + Math.sin(TAU * f * t) * env(t, k * 0.06, 7) * 0.2, 0), t, d, 0.001, 0.1)],
  "Mining/qte_miss.wav": ["miss", 0.4, (n) => (t, i, d) =>
    fade(Math.sin(sweep(t, 300, 150, 0.3)) * Math.exp(-t * 6) * 0.3 + n.soft[i] * Math.exp(-t * 20) * 0.4, t, d, 0.002, 0.06)],
  "Mining/chest_land.wav": ["chest_land", 0.4, (n, len) => {
    const rattle = clicks(len, 0.03, 8, 0.15, 10, 2200, 120);
    return (t, i, d) => fade(Math.sin(sweep(t, 150, 70, 0.08)) * Math.exp(-t * 22) + n.dark[i] * 3 * Math.exp(-t * 25) * 0.5 + rattle[i] * 0.3, t, d, 0.001, 0.05);
  }],
  "Mining/chest_open.wav": ["chest_open", 1.0, (n, len) => {
    const coins = clicks(len, 0.25, 30, 0.55, 3, 3000, 50);
    return (t, i, d) => fade(Math.sin(sweep(t, 150, 230, 0.25)) * (0.6 + 0.4 * Math.sin(TAU * 29 * t)) * (t < 0.25 ? 0.3 : 0) + Math.sin(sweep(t - 0.24, 180, 90, 0.06)) * env(t, 0.24, 30) * 0.5 + coins[i] * 0.4 + [2093, 2637, 3136].reduce((a, f, k) => a + Math.sin(TAU * f * t) * env(t, 0.3 + k * 0.07, 9) * 0.12, 0), t, d, 0.003, 0.12);
  }],
};

for (const [file, [name, seconds, make]] of Object.entries(files)) {
  const out = path.resolve("Assets/Audio", file);
  await fs.mkdir(path.dirname(out), { recursive: true });
  const samples = file.endsWith("_loop.wav") ? loop(name, seconds, 0.5, make) : synth(name, seconds, make);
  await fs.writeFile(out, writeWav(samples));
  process.stdout.write(`${file}: ${samples.length}\n`);
}
