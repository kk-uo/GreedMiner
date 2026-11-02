import fs from "node:fs/promises";
import path from "node:path";

// Reproducible sounds for the Volcanic, Graveyard and Tree planets (enemies,
// bosses and planet events); same recipe as generate_world_sfx.mjs.
// Run from the project root: node tools/generate_planet_sfx.mjs
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


// Fire crackle (embers) helper.
const crackle = (len, start, count, spread) => clicks(len, start, count, spread, 3, 2600, 260);
// A growl-ish formant buzz (non-vocal monster rumble).
const growl = (t, f, depth = 0.4) => {
  const saw = [1, 2, 3, 4, 5, 6].reduce((a, h) => a + Math.sin(TAU * f * h * t + depth * Math.sin(TAU * 23 * t)) / h, 0);
  return saw * (0.7 + 0.3 * Math.sin(TAU * 11 * t));
};

const files = {
  // ------------------------------------------------------------ Volcanic
  "Enemies/Volcanic/imp_attack.wav": ["imp_atk", 0.35, (n, len) => {
    const c = crackle(len, 0.02, 10, 0.25);
    return (t, i, d) => fade(n.soft[i] * Math.exp(-t * 14) * 0.9 + Math.sin(sweep(t, 500, 220, 0.12)) * Math.exp(-t * 20) * 0.3 + c[i] * 0.3, t, d, 0.002, 0.05);
  }],
  "Enemies/Volcanic/imp_death.wav": ["imp_death", 0.6, (n, len) => {
    const c = crackle(len, 0.05, 22, 0.45);
    return (t, i, d) => fade(n.soft[i] * Math.sin(Math.PI * Math.min(t / 0.35, 1)) * 0.9 + Math.sin(sweep(t, 700, 200, 0.3)) * Math.exp(-t * 7) * 0.2 + c[i] * 0.35, t, d, 0.005, 0.1);
  }],
  "Enemies/Volcanic/demon_attack.wav": ["demon_atk", 0.35, (n) => (t, i, d) =>
    fade(whoosh(t, i, n, 0.14) + n.bright[i] * env(t, 0.13, 90) * 0.7 + growl(t, 70) * Math.exp(-t * 9) * 0.15, t, d, 0.002, 0.05)],
  "Enemies/Volcanic/demon_death.wav": ["demon_death", 0.8, (n, len) => {
    const c = crackle(len, 0.05, 30, 0.6);
    return (t, i, d) => fade(n.soft[i] * Math.sin(Math.PI * Math.min(t / 0.5, 1)) * 1.0 + growl(t, 60) * Math.exp(-t * 5) * 0.2 + c[i] * 0.35, t, d, 0.005, 0.15);
  }],
  "Enemies/Volcanic/big_demon_attack.wav": ["bdemon_atk", 0.8, (n) => (t, i, d) =>
    fade(Math.sin(sweep(t, 110, 45, 0.15)) * Math.exp(-t * 9) + n.dark[i] * 3 * Math.exp(-t * 14) * 0.6 + n.soft[i] * Math.sin(Math.PI * Math.min(t / 0.6, 1)) * 0.6, t, d, 0.002, 0.1)],
  "Enemies/Volcanic/big_demon_death.wav": ["bdemon_death", 1.3, (n, len) => {
    const c = crackle(len, 0.1, 50, 1.0);
    return (t, i, d) => fade(growl(t, 45, 0.6) * Math.exp(-t * 2.5) * 0.3 + n.soft[i] * Math.sin(Math.PI * Math.min(t / 0.9, 1)) * 1.0 + n.deep[i] * 8 * Math.exp(-t * 3) * 0.4 + c[i] * 0.35, t, d, 0.01, 0.25);
  }],
  "Enemies/Volcanic/hellhunter_attack.wav": ["hh_atk", 0.25, (n) => (t, i, d) =>
    fade(n.bright[i] * (Math.exp(-t * 150) + env(t, 0.06, 140)) * 0.8 + growl(t, 95) * Math.exp(-t * 14) * 0.18, t, d, 0.001, 0.04)],
  "Enemies/Volcanic/hellhunter_death.wav": ["hh_death", 0.7, (n, len) => {
    const c = crackle(len, 0.05, 24, 0.5);
    return (t, i, d) => fade(n.soft[i] * Math.sin(Math.PI * Math.min(t / 0.45, 1)) * 0.9 + Math.sin(sweep(t, 420, 160, 0.4)) * Math.exp(-t * 6) * 0.2 + c[i] * 0.35, t, d, 0.005, 0.12);
  }],
  "Enemies/Volcanic/lord_attack.wav": ["lord_atk", 0.6, (n) => (t, i, d) =>
    fade(whoosh(t, i, n, 0.2, 1.3) + Math.sin(sweep(t - 0.19, 100, 40, 0.15)) * env(t, 0.19, 10) + n.dark[i] * 3 * env(t, 0.19, 16) * 0.6, t, d, 0.002, 0.08)],
  "Enemies/Volcanic/lord_charge.wav": ["lord_charge", 2.2, (n) => (t, i, d) => {
    const r = Math.min(t / 2.0, 1);
    return fade((Math.sin(sweep(t, 80, 260, 2.2)) * 0.35 + Math.sin(sweep(t, 160, 520, 2.2)) * 0.18) * r + n.mid[i] * 1.2 * r * (0.6 + 0.4 * Math.sin(TAU * (4 + 10 * r) * t)) * 0.5, t, d, 0.05, 0.1);
  }],
  "Enemies/Volcanic/lord_qte_click.wav": ["lord_click", 0.18, (n) => (t, i, d) =>
    fade(n.bright[i] * Math.exp(-t * 90) * 0.9 + Math.sin(sweep(t, 600, 300, 0.05)) * Math.exp(-t * 35) * 0.4, t, d, 0.0005, 0.03)],
  "Enemies/Volcanic/lord_break.wav": ["lord_break", 1.2, (n, len) => {
    const shards = clicks(len, 0.02, 40, 0.6, 3.5, 2600, 120);
    return (t, i, d) => fade(n.bright[i] * Math.exp(-t * 25) * 1.1 + Math.sin(sweep(t, 300, 60, 0.5)) * Math.exp(-t * 4) * 0.5 + growl(t, 50, 0.7) * Math.exp(-t * 3) * 0.25 + shards[i] * 0.45, t, d, 0.001, 0.2);
  }],
  "Enemies/Volcanic/lord_laser.wav": ["lord_laser", 1.6, (n) => (t, i, d) => {
    const beam = Math.sin(TAU * 110 * t) * 0.35 + Math.sin(TAU * 220.5 * t) * 0.2 + Math.sin(TAU * 441 * t) * 0.1;
    return fade(n.bright[i] * Math.exp(-t * 20) * 1.0 + beam * Math.exp(-t * 1.5) * (0.7 + 0.3 * Math.sin(TAU * 30 * t)) + n.deep[i] * 9 * Math.exp(-t * 2) * 0.5, t, d, 0.001, 0.3);
  }],
  "Enemies/Volcanic/lord_summon.wav": ["lord_summon", 1.8, (n) => (t, i, d) => {
    const swirl = Math.sin(sweep(t, 140, 90, 1.8)) * 0.3 * (0.6 + 0.4 * Math.sin(TAU * 6 * t));
    return fade(swirl * Math.min(t / 0.4, 1) + n.mid[i] * 1.6 * Math.sin(Math.PI * t / d) * 0.6 + growl(t, 55) * Math.sin(Math.PI * t / d) * 0.12, t, d, 0.05, 0.3);
  }],
  "Enemies/Volcanic/lord_teleport.wav": ["lord_tp", 0.7, (n) => (t, i, d) =>
    fade(Math.sin(sweep(t, 900, 120, 0.35)) * Math.exp(-t * 5) * 0.35 + whoosh(t, i, n, 0.35) + n.soft[i] * env(t, 0.35, 12) * 0.7, t, d, 0.002, 0.1)],
  "Enemies/Volcanic/lord_death.wav": ["lord_death", 3.0, (n, len) => {
    const c = crackle(len, 0.2, 90, 2.0);
    return (t, i, d) => fade(growl(t * (1 - 0.15 * Math.min(t / 1.5, 1)), 52, 0.8) * Math.exp(-t * 1.2) * 0.32 + Math.sin(sweep(t - 0.5, 90, 30, 0.6)) * env(t, 0.5, 2.5) + n.soft[i] * Math.sin(Math.PI * Math.min(t / 2.0, 1)) * 0.8 + n.deep[i] * 10 * Math.exp(-t * 1.2) * 0.4 + c[i] * 0.35, t, d, 0.01, 0.6);
  }],
  "Volcanic/lava_vent_click.wav": ["vent_click", 0.3, (n) => (t, i, d) =>
    fade(Math.sin(sweep(t, 160, 420, 0.1)) * Math.exp(-t * 18) * 0.5 + n.dark[i] * 3 * Math.exp(-t * 20) * 0.4, t, d, 0.002, 0.05)],
  "Volcanic/lava_erupt.wav": ["erupt", 1.6, (n, len) => {
    const blobs = clicks(len, 0.3, 30, 1.0, 2, 500, 50);
    const c = crackle(len, 0.1, 50, 1.2);
    return (t, i, d) => fade(Math.sin(sweep(t, 120, 40, 0.3)) * Math.exp(-t * 4) + n.soft[i] * Math.exp(-t * 3) * 0.9 + n.deep[i] * 9 * Math.exp(-t * 2) * 0.5 + blobs[i] * 0.4 + c[i] * 0.3, t, d, 0.001, 0.3);
  }],
  "Volcanic/lava_emerge.wav": ["emerge", 1.4, (n, len) => {
    const bubbles = clicks(len, 0, 26, 0.9, 1, 260, 40);
    return (t, i, d) => fade(bubbles[i] * 0.55 + n.soft[i] * Math.sin(Math.PI * t / d) * 0.5 + n.deep[i] * 8 * Math.min(t / 0.6, 1) * 0.4, t, d, 0.05, 0.3);
  }],

  // ------------------------------------------------------------ Graveyard
  "Enemies/Graveyard/zombie_attack.wav": ["z_atk", 0.35, (n) => (t, i, d) =>
    fade(n.dark[i] * 3 * Math.exp(-t * 18) * 0.6 + growl(t, 85, 0.8) * Math.exp(-t * 8) * 0.18 + n.bright[i] * Math.exp(-t * 120) * 0.4, t, d, 0.002, 0.05)],
  "Enemies/Graveyard/zombie_death.wav": ["z_death", 0.8, (n) => (t, i, d) =>
    fade(splat(t, i, n) * 0.8 + growl(t * (1 - 0.3 * t), 75, 0.6) * Math.exp(-t * 4) * 0.18 + n.soft[i] * env(t, 0.2, 5) * 0.5, t, d, 0.002, 0.15)],
  "Enemies/Graveyard/skeleton_attack.wav": ["sk_atk", 0.3, (n, len) => {
    const rattle = clicks(len, 0, 8, 0.12, 6, 1800, 140);
    return (t, i, d) => fade(whoosh(t, i, n, 0.15, 0.8) + rattle[i] * 0.5, t, d, 0.002, 0.05);
  }],
  "Enemies/Graveyard/skeleton_death.wav": ["sk_death", 0.8, (n, len) => {
    const bones = clicks(len, 0.01, 30, 0.55, 3, 1500, 110);
    return (t, i, d) => fade(bones[i] * 0.7 + n.bright[i] * Math.exp(-t * 60) * 0.4, t, d, 0.001, 0.1);
  }],
  "Enemies/Graveyard/vampire_attack.wav": ["v_atk", 0.35, (n) => (t, i, d) =>
    fade(whoosh(t, i, n, 0.12) + n.bright[i] * Math.sin(Math.PI * Math.min(t / 0.3, 1)) * 0.35 * Math.exp(-t * 4), t, d, 0.002, 0.05)],
  "Enemies/Graveyard/vampire_death.wav": ["v_death", 1.0, (n, len) => {
    const wings = clicks(len, 0.05, 40, 0.7, 2, 600, 70);
    return (t, i, d) => fade(wings[i] * 0.6 + Math.sin(sweep(t, 1400, 500, 0.6)) * Math.exp(-t * 4) * 0.15 + n.soft[i] * Math.exp(-t * 6) * 0.4, t, d, 0.002, 0.15);
  }],
  "Enemies/Graveyard/werewolf_attack.wav": ["ww_atk", 0.4, (n) => (t, i, d) =>
    fade(whoosh(t, i, n, 0.14, 1.2) + n.bright[i] * env(t, 0.13, 70) * 0.8 + growl(t, 110, 0.5) * Math.exp(-t * 6) * 0.2, t, d, 0.002, 0.05)],
  "Enemies/Graveyard/werewolf_death.wav": ["ww_death", 0.9, (n) => (t, i, d) =>
    fade(splat(t, i, n, 0, 1.6) + Math.sin(sweep(t, 620, 240, 0.6)) * Math.exp(-t * 3) * 0.22 * (0.7 + 0.3 * Math.sin(TAU * 9 * t)), t, d, 0.002, 0.15)],
  "Enemies/Graveyard/frank_attack.wav": ["fr_atk", 0.6, (n) => (t, i, d) =>
    fade(whoosh(t, i, n, 0.18, 1.2) + Math.sin(sweep(t - 0.17, 90, 38, 0.15)) * env(t, 0.17, 9) + n.dark[i] * 3 * env(t, 0.17, 15) * 0.6, t, d, 0.002, 0.08)],
  "Enemies/Graveyard/frank_fall.wav": ["fr_fall", 1.4, (n) => (t, i, d) =>
    fade(growl(t * (1 - 0.25 * t), 60, 0.7) * Math.exp(-t * 2) * 0.25 + Math.sin(sweep(t - 0.6, 80, 30, 0.3)) * env(t, 0.6, 5) + n.dark[i] * 3 * env(t, 0.6, 7) * 0.6, t, d, 0.005, 0.25)],
  "Enemies/Graveyard/frank_graves.wav": ["fr_graves", 2.4, (n) => (t, i, d) =>
    fade(n.deep[i] * 10 * Math.sin(Math.PI * t / d) * 0.6 + [55, 58.3, 65.4].reduce((a, f) => a + Math.sin(TAU * f * t), 0) * 0.08 * Math.sin(Math.PI * t / d), t, d, 0.1, 0.4)],
  "Enemies/Graveyard/frank_zombies.wav": ["fr_zombies", 1.4, (n, len) => {
    const dirt = clicks(len, 0, 50, 0.9, 2, 700, 60);
    return (t, i, d) => fade(dirt[i] * 0.5 + n.soft[i] * Math.exp(-t * 3) * 0.6 + growl(t, 80, 0.9) * Math.sin(Math.PI * t / d) * 0.12, t, d, 0.005, 0.25);
  }],
  "Enemies/Graveyard/frank_rise.wav": ["fr_rise", 2.0, (n, len) => {
    const sparks = clicks(len, 0, 120, 1.6, 1, 3400, 200);
    return (t, i, d) => fade(sparks[i] * 0.4 + Math.sin(TAU * 60 * t) * 0.15 * (0.5 + 0.5 * Math.sin(TAU * 120 * t)) * Math.min(t / 1.2, 1) + growl(t, 50 + 30 * Math.min(t / 1.8, 1), 0.6) * env(t, 1.0, 1.5) * 0.3, t, d, 0.01, 0.3);
  }],
  "Enemies/Graveyard/frank_death.wav": ["fr_death", 2.6, (n, len) => {
    const bones = clicks(len, 0.4, 50, 1.4, 1.5, 1300, 110);
    return (t, i, d) => fade(growl(t * (1 - 0.2 * t), 48, 0.8) * Math.exp(-t * 1.5) * 0.3 + Math.sin(sweep(t - 0.4, 70, 28, 0.6)) * env(t, 0.4, 2.5) + n.deep[i] * 10 * Math.exp(-t * 1.3) * 0.5 + bones[i] * 0.4, t, d, 0.01, 0.5);
  }],
  "Graveyard/grave_rise.wav": ["grave_rise", 0.9, (n, len) => {
    const dirt = clicks(len, 0.05, 20, 0.5, 4, 600, 70);
    return (t, i, d) => fade(n.soft[i] * Math.exp(-t * 6) * 0.6 + dirt[i] * 0.45 + Math.sin(sweep(t, 140, 70, 0.2)) * Math.exp(-t * 12) * 0.4, t, d, 0.002, 0.12);
  }],

  // ------------------------------------------------------------ Tree planet
  "Enemies/Forest/treant_rise.wav": ["tr_rise", 1.3, (n, len) => {
    const roots = clicks(len, 0.45, 26, 0.6, 3, 900, 70);
    const creak = (t) => Math.sin(sweep(t, 90, 150, 0.9)) * (0.55 + 0.45 * Math.sin(TAU * 23 * t));
    return (t, i, d) => fade(creak(t) * Math.sin(Math.PI * Math.min(t / 1.1, 1)) * 0.3 + roots[i] * 0.5 + n.soft[i] * env(t, 0.45, 5) * 0.5 + n.mid[i] * 0.6 * Math.sin(Math.PI * Math.min(t / 0.5, 1)) * (t < 0.5 ? 1 : 0), t, d, 0.02, 0.2);
  }],
  "Enemies/Forest/treant_attack.wav": ["tr_atk", 0.5, (n, len) => {
    const leaves = clicks(len, 0.05, 10, 0.3, 6, 2200, 260);
    return (t, i, d) => fade(Math.sin(sweep(t, 150, 70, 0.1)) * Math.exp(-t * 14) + n.mid[i] * 1.5 * Math.exp(-t * 18) * 0.6 + leaves[i] * 0.3, t, d, 0.002, 0.06);
  }],
  "Enemies/Forest/treant_death.wav": ["tr_death", 1.2, (n, len) => {
    const splinters = clicks(len, 0.02, 40, 0.6, 3.5, 1200, 110);
    const leaves = clicks(len, 0.1, 50, 0.8, 2, 2400, 260);
    return (t, i, d) => fade(n.bright[i] * (Math.exp(-t * 25) + 0.5 * env(t, 0.1, 25)) * 0.8 + Math.sin(sweep(t, 120, 45, 0.3)) * Math.exp(-t * 5) * 0.8 + splinters[i] * 0.45 + leaves[i] * 0.2, t, d, 0.001, 0.2);
  }],
  "Enemies/Forest/fairy_attack.wav": ["f_atk", 0.35, () => (t, i, d) =>
    fade([2637, 3520, 4186].reduce((a, f, k) => a + Math.sin(TAU * f * t) * env(t, k * 0.04, 18) * 0.2, 0), t, d, 0.001, 0.05)],
  "Enemies/Forest/fairy_heal.wav": ["f_heal", 0.7, () => (t, i, d) =>
    fade([1568, 1976, 2349, 2637].reduce((a, f, k) => a + Math.sin(TAU * f * t) * env(t, k * 0.08, 6) * 0.15, 0) * (0.8 + 0.2 * Math.sin(TAU * 12 * t)), t, d, 0.002, 0.15)],
  "Enemies/Forest/fairy_death.wav": ["f_death", 0.6, (n, len) => {
    const sparkle = clicks(len, 0, 24, 0.45, 4, 5000, 90);
    return (t, i, d) => fade(sparkle[i] * 0.45 + Math.sin(sweep(t, 2400, 900, 0.3)) * Math.exp(-t * 8) * 0.2 + n.bright[i] * Math.exp(-t * 60) * 0.3, t, d, 0.001, 0.1);
  }],
  "Enemies/Forest/boss_saw_windup.wav": ["saw_wind", 1.2, (n) => (t, i, d) => {
    const rev = Math.min(t / 1.0, 1);
    const f = 60 + 140 * rev;
    return fade((Math.sin(TAU * f * t) * 0.35 + n.mid[i] * 1.2) * (0.55 + 0.45 * Math.sin(TAU * f * 0.25 * t)) * (0.4 + 0.6 * rev), t, d, 0.02, 0.05);
  }],
  "Enemies/Forest/boss_saw_fire.wav": ["saw_fire", 0.8, (n) => (t, i, d) =>
    fade([1830, 2710, 3980].reduce((a, f, k) => a + Math.sin(TAU * f * t) * [0.25, 0.18, 0.1][k], 0) * Math.exp(-t * 6) * (0.7 + 0.3 * Math.sin(TAU * 40 * t)) + whoosh(t, i, n, 0.5, 1.1), t, d, 0.002, 0.12)],
  "Enemies/Forest/boss_death.wav": ["fb_death", 2.4, (n, len) => {
    const splinters = clicks(len, 0.3, 60, 1.5, 1.8, 1200, 110);
    return (t, i, d) => {
      const engine = (Math.sin(TAU * 70 * t) * 0.3 + n.mid[i]) * (0.5 + 0.5 * Math.sin(TAU * (14 - 10 * Math.min(t / 1.2, 1)) * t)) * Math.exp(-t * 1.6);
      return fade(engine * 0.6 + Math.sin(sweep(t - 0.6, 90, 30, 0.5)) * env(t, 0.6, 3) + n.dark[i] * 3 * env(t, 0.6, 4) * 0.6 + splinters[i] * 0.45, t, d, 0.005, 0.4);
    };
  }],
  "Forest/ring_rise.wav": ["ring", 2.2, (n, len) => {
    const roots = clicks(len, 0.2, 80, 1.6, 0.6, 900, 70);
    return (t, i, d) => fade(n.deep[i] * 10 * Math.sin(Math.PI * t / d) * 0.6 + roots[i] * 0.35 + n.soft[i] * Math.sin(Math.PI * t / d) * 0.3, t, d, 0.1, 0.5);
  }],
};

for (const [file, [name, seconds, make]] of Object.entries(files)) {
  const out = path.resolve("Assets/Audio", file);
  await fs.mkdir(path.dirname(out), { recursive: true });
  const samples = file.endsWith("_loop.wav") ? loop(name, seconds, 0.5, make) : synth(name, seconds, make);
  await fs.writeFile(out, writeWav(samples));
  process.stdout.write(`${file}: ${samples.length}\n`);
}
