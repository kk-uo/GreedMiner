import fs from "node:fs/promises";
import path from "node:path";

// Reproducible Rocky Planet enemy sounds (mono 16-bit 22050 Hz PCM), same
// recipe as generate_weapon_sfx.mjs. Run from the project root:
//   node tools/generate_enemy_sfx.mjs
// Played through Scripts/Audio/EnemySfx.gd (pooled, rate limited).
const sampleRate = 22050;
const outputDir = path.resolve("Assets/Audio/Enemies/Rocky");
const TAU = 2 * Math.PI;
let seed = 1;

function random() {
  seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0;
  return seed / 0x100000000 * 2 - 1;
}

function lowPass(samples, k) {
  let s = 0;
  return samples.map((x) => (s += k * (x - s)));
}

function highPass(samples, k) {
  const low = lowPass(samples, k);
  return samples.map((x, i) => x - low[i]);
}

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

function fade(x, t, d, fin, fout) {
  return x * Math.max(0, Math.min(t / fin, (d - t) / fout, 1));
}

function sweep(t, f0, f1, len) {
  const u = Math.min(t, len);
  return TAU * (f0 * u + (f1 - f0) * u * u / (2 * len)) + (t > len ? TAU * f1 * (t - len) : 0);
}

// Gravel: a burst of short random clicks (falling pebbles) after `start`.
function gravel(length, start, count, spread, decay, pitch) {
  const out = new Array(length).fill(0);
  for (let c = 0; c < count; c += 1) {
    const at = Math.floor((start + Math.abs(random()) * spread) * sampleRate);
    const amp = 0.35 + Math.abs(random()) * 0.65;
    const freq = pitch * (0.7 + Math.abs(random()) * 0.8);
    const len = Math.floor(sampleRate * 0.03);
    for (let i = 0; i < len && at + i < length; i += 1) {
      const t = i / sampleRate;
      out[at + i] += Math.sin(TAU * freq * t) * Math.exp(-t * 160) * amp * Math.exp(-(at / sampleRate - start) * decay);
    }
  }
  return out;
}

function synth(name, seconds, fn) {
  seed = [...name].reduce((a, c) => Math.imul(a, 31) + c.charCodeAt(0), 0x1234) >>> 0;
  const length = Math.round(sampleRate * seconds);
  const white = Array.from({ length }, random);
  const n = {
    white,
    soft: lowPass(white, 0.25),
    dark: lowPass(white, 0.05),
    deep: lowPass(white, 0.015),
    bright: highPass(white, 0.4),
    length,
  };
  return Array.from({ length }, (_, i) => fn(i / sampleRate, n, i, seconds));
}

const sounds = {
  // Little Rock head-butt: a dry stone knock.
  "little_rock_attack.wav": ["lr_attack", 0.14, (t, n, i, d) => {
    const knock = Math.sin(sweep(t, 520, 260, 0.05)) * Math.exp(-t * 55);
    const body = Math.sin(TAU * 180 * t) * Math.exp(-t * 40) * 0.5;
    const click = n.bright[i] * Math.exp(-t * 300) * 0.8;
    return fade(knock * 0.8 + body + click, t, d, 0.0008, 0.02);
  }],
  // Little Rock shatters: a crack and a patter of pebbles.
  "little_rock_death.wav": ["lr_death", 0.42, (() => {
    let pebbles = null;
    return (t, n, i, d) => {
      if (pebbles === null) pebbles = gravel(n.length, 0.03, 14, 0.22, 7, 2400);
      const crack = n.bright[i] * Math.exp(-t * 90) * 1.1;
      const thud = Math.sin(sweep(t, 300, 120, 0.08)) * Math.exp(-t * 30) * 0.6;
      return fade(crack + thud + pebbles[i] * 0.55, t, d, 0.0008, 0.05);
    };
  })()],
  // Red Rock fuse: a sizzling hiss that rises as it heats up (~fuse_time).
  "red_rock_fuse.wav": ["rr_fuse", 0.38, (t, n, i, d) => {
    const rise = t / d;
    const hiss = n.bright[i] * (0.35 + 0.55 * rise) * (0.75 + 0.25 * Math.sin(TAU * 40 * t));
    const tone = Math.sin(sweep(t, 600, 1500, d)) * 0.12 * rise;
    return fade(hiss + tone, t, d, 0.01, 0.01);
  }],
  // Red Rock blows up: magma pop, boom and crackling embers.
  "red_rock_explode.wav": ["rr_explode", 0.7, (() => {
    let embers = null;
    return (t, n, i, d) => {
      if (embers === null) embers = gravel(n.length, 0.05, 22, 0.45, 5, 3200);
      const boom = Math.sin(sweep(t, 160, 45, 0.25)) * Math.exp(-t * 7);
      const blast = n.soft[i] * Math.exp(-t * 18) * 1.1;
      const roar = n.dark[i] * 3 * Math.exp(-t * 6);
      return fade(boom * 0.9 + blast + roar * 0.5 + embers[i] * 0.35, t, d, 0.001, 0.08);
    };
  })()],
  // Rock Golem two-fist slam: a heavy thud with a gravel spray.
  "rock_golem_attack.wav": ["rg_attack", 0.45, (() => {
    let spray = null;
    return (t, n, i, d) => {
      if (spray === null) spray = gravel(n.length, 0.02, 10, 0.18, 9, 1800);
      const thud = Math.sin(sweep(t, 140, 55, 0.12)) * Math.exp(-t * 12);
      const impact = n.dark[i] * 3.5 * Math.exp(-t * 22);
      const crack = n.bright[i] * Math.exp(-t * 120) * 0.6;
      return fade(thud + impact * 0.6 + crack + spray[i] * 0.4, t, d, 0.001, 0.06);
    };
  })()],
  // Rock Golem breaks apart: a big crack, then rubble tumbling.
  "rock_golem_death.wav": ["rg_death", 0.95, (() => {
    let rubble = null;
    return (t, n, i, d) => {
      if (rubble === null) rubble = gravel(n.length, 0.06, 38, 0.7, 3.2, 1400);
      const crack = n.bright[i] * Math.exp(-t * 45) * 1.2;
      const split = Math.sin(sweep(t, 220, 70, 0.2)) * Math.exp(-t * 9) * 0.8;
      const rumble = n.deep[i] * 9 * Math.exp(-t * 3.5);
      return fade(crack + split + rumble * 0.5 + rubble[i] * 0.6, t, d, 0.001, 0.12);
    };
  })()],
  // Rock Titan slam: a deep ground-shaking boom with a long rumble.
  "rock_titan_attack.wav": ["rt_attack", 1.1, (() => {
    let debris = null;
    return (t, n, i, d) => {
      if (debris === null) debris = gravel(n.length, 0.05, 20, 0.5, 4, 1200);
      const boom = Math.sin(sweep(t, 90, 32, 0.4)) * Math.exp(-t * 4.5);
      const sub = Math.sin(TAU * 38 * t) * Math.exp(-t * 3) * 0.5;
      const impact = n.dark[i] * 3.2 * Math.exp(-t * 14);
      const rumble = n.deep[i] * 10 * Math.exp(-t * 2.6);
      return fade(boom + sub + impact * 0.6 + rumble * 0.55 + debris[i] * 0.35, t, d, 0.001, 0.15);
    };
  })()],
  // Rock Titan collapses: cracking, a huge crumble and a rolling landslide.
  "rock_titan_death.wav": ["rt_death", 2.4, (() => {
    let slide = null;
    return (t, n, i, d) => {
      if (slide === null) slide = gravel(n.length, 0.25, 90, 1.7, 1.4, 1100);
      const cracks = n.bright[i] * (Math.exp(-t * 20) + 0.6 * Math.exp(-Math.abs(t - 0.18) * 40) + 0.4 * Math.exp(-Math.abs(t - 0.33) * 40));
      const fall = Math.sin(sweep(t, 70, 28, 0.9)) * Math.exp(-t * 1.6) * 0.9;
      const rumble = n.deep[i] * 11 * Math.exp(-t * 1.1) * (0.8 + 0.2 * Math.sin(TAU * 5 * t));
      return fade(cracks * 0.9 + fall + rumble * 0.6 + slide[i] * 0.5, t, d, 0.001, 0.4);
    };
  })()],
};

await fs.mkdir(outputDir, { recursive: true });
for (const [file, [name, seconds, fn]] of Object.entries(sounds)) {
  const samples = synth(name, seconds, fn);
  await fs.writeFile(path.join(outputDir, file), writeWav(samples));
  process.stdout.write(`${file}: ${samples.length} samples\n`);
}
