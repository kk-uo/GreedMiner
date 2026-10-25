import fs from "node:fs/promises";
import path from "node:path";

// Reproducible, original sounds for the 13 fusion weapons (same recipe as
// generate_weapon_sfx.mjs: mono 16-bit 22050 Hz PCM, no runtime synthesis).
// Run from the project root: node tools/generate_fusion_sfx.mjs
// Loops (*_loop.wav) use frequencies that fit their length exactly so the
// replay seam is clean; WeaponSound restarts them while the beam is active.
const sampleRate = 22050;
const outputDir = path.resolve("Assets/Audio/Weapons/Fusion");
const TAU = 2 * Math.PI;
let seed = 1;

function random() {
  seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0;
  return seed / 0x100000000 * 2 - 1;
}

function lowPass(samples, coefficient) {
  let state = 0;
  return samples.map((sample) => {
    state += coefficient * (sample - state);
    return state;
  });
}

function highPass(samples, coefficient) {
  const low = lowPass(samples, coefficient);
  return samples.map((sample, index) => sample - low[index]);
}

function fade(sample, position, duration, fadeIn, fadeOut) {
  const start = Math.min(position / fadeIn, 1);
  const end = Math.min((duration - position) / fadeOut, 1);
  return sample * Math.max(0, Math.min(start, end));
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
  for (let index = 0; index < samples.length; index += 1) {
    const limited = Math.tanh(samples[index] * 1.2) * 0.82;
    bytes.writeInt16LE(Math.round(limited * 32767), 44 + index * 2);
  }
  return bytes;
}

// callback(t, n) where n = { soft, dark, bright } noise samples.
function synthesize(name, seconds, callback) {
  seed = 0x5f3a1c00 ^ [...name].reduce((a, c) => Math.imul(a, 31) + c.charCodeAt(0), 7);
  const length = Math.round(sampleRate * seconds);
  const white = Array.from({ length }, random);
  const soft = lowPass(white, 0.27);
  const dark = lowPass(white, 0.06);
  const bright = highPass(white, 0.35);
  return Array.from({ length }, (_, index) => callback(index / sampleRate, { soft: soft[index], dark: dark[index], bright: bright[index] }, seconds));
}

// Phase of a linear sweep from f0 to f1 Hz over `len` seconds (holds f1 after).
function sweep(t, f0, f1, len) {
  const u = Math.min(t, len);
  return TAU * (f0 * u + (f1 - f0) * u * u / (2 * len)) + (t > len ? TAU * f1 * (t - len) : 0);
}

// A deep cannon thump with a cracking muzzle blast.
function cannon(t, n, base, decay) {
  const thump = Math.sin(sweep(t, base * 2.0, base * 0.7, 0.18));
  const crack = n.soft * Math.exp(-t * 28);
  const rumble = n.dark * 2.4 * Math.exp(-t * decay * 0.6);
  return (thump * 0.75 + crack * 0.95) * Math.exp(-t * decay) + rumble * 0.5;
}

const sounds = {
  // Five pellets leave almost together: a wide, crunchy shotgun bark.
  "scatter_machine_gun_shot.wav": ["scatter", 0.17, (t, n, d) => {
    let clicks = 0;
    for (const at of [0, 0.006, 0.011, 0.017, 0.024]) {
      if (t >= at) clicks += n.bright * Math.exp(-(t - at) * 160);
    }
    const body = Math.sin(sweep(t, 220, 90, 0.08)) * Math.exp(-t * 30);
    const blast = n.soft * Math.exp(-t * 34);
    return fade(clicks * 0.55 + body * 0.55 + blast * 0.75, t, d, 0.001, 0.02);
  }],
  // A single heavy barrel: a pneumatic "thoomp" that shoves.
  "knockback_machine_gun_shot.wav": ["knockback_mg", 0.16, (t, n, d) => {
    const whomp = Math.sin(sweep(t, 320, 70, 0.1)) * Math.exp(-t * 22);
    const puff = n.dark * 3.0 * Math.exp(-t * 26);
    const click = n.bright * Math.exp(-t * 220) * 0.6;
    return fade(whomp * 0.85 + puff * 0.5 + click, t, d, 0.001, 0.02);
  }],
  // A snappy energy "pew" bolt.
  "laser_machine_gun_shot.wav": ["laser_mg", 0.1, (t, n, d) => {
    const zap = Math.sin(sweep(t, 1500, 420, 0.09));
    const sub = Math.sin(sweep(t, 750, 210, 0.09)) * 0.35;
    return fade((zap * 0.55 + sub + n.bright * 0.12) * Math.exp(-t * 26), t, d, 0.001, 0.015);
  }],
  // Launching a spinning saw: metallic "shing" over a short whoosh.
  "sawblade_machine_gun_shot.wav": ["sawblade", 0.2, (t, n, d) => {
    let ring = 0;
    for (const [f, a] of [[1830, 0.32], [2710, 0.24], [3980, 0.16], [5210, 0.08]]) ring += Math.sin(TAU * f * t) * a;
    ring *= Math.exp(-t * 16) * (0.75 + 0.25 * Math.sin(TAU * 38 * t));
    const whoosh = n.soft * Math.sin(Math.PI * Math.min(t / 0.12, 1)) * 0.55;
    const kick = Math.sin(sweep(t, 260, 110, 0.04)) * Math.exp(-t * 60) * 0.5;
    return fade(ring + whoosh + kick, t, d, 0.001, 0.03);
  }],
  // A spat fireball: "fwoomp" with a sizzling tail.
  "flame_machine_gun_shot.wav": ["flame_mg", 0.2, (t, n, d) => {
    const roar = n.dark * 3.2 * Math.exp(-t * 14);
    const crackle = n.bright * Math.exp(-t * 18) * (0.5 + 0.5 * Math.sin(TAU * 60 * t));
    const pop = Math.sin(sweep(t, 180, 80, 0.06)) * Math.exp(-t * 35);
    return fade(roar * 0.7 + crackle * 0.3 + pop * 0.6, t, d, 0.002, 0.04);
  }],
  // Laser-edged chainsaw: motor chatter plus a high cutting whine (loop).
  "laser_chainsaw_loop.wav": ["laser_chainsaw", 0.32, (t, n, d) => {
    const motor = Math.sin(TAU * 125 * t) * 0.3 + Math.sin(TAU * 250 * t) * 0.12;
    const chatter = 0.62 + 0.38 * Math.sin(TAU * 25 * t);
    const whine = Math.sin(TAU * 1250 * t) * 0.16 * (0.8 + 0.2 * Math.sin(TAU * 50 * t));
    return fade((motor + n.soft * 0.35) * chatter + whine, t, d, 0.009, 0.009);
  }],
  // Huge sustained beam: a deep throbbing drone with crackle (loop).
  "heavy_laser_loop.wav": ["heavy_laser", 0.4, (t, n, d) => {
    const drone = Math.sin(TAU * 65 * t) * 0.42 + Math.sin(TAU * 130 * t) * 0.24 + Math.sin(TAU * 260 * t) * 0.1;
    const throb = 0.72 + 0.28 * Math.sin(TAU * 7.5 * t);
    const fizz = n.bright * 0.16 * (0.5 + 0.5 * Math.sin(TAU * 35 * t));
    return fade(drone * throb + n.dark * 1.2 + fizz, t, d, 0.01, 0.01);
  }],
  // Rapid-fire light cannon: a short punchy boom.
  "automatic_cannon_shot.wav": ["auto_cannon", 0.26, (t, n, d) => fade(cannon(t, n, 120, 13) * 0.9, t, d, 0.001, 0.03)],
  // The siege gun: an enormous boom with a long rolling rumble.
  "siege_cannon_shot.wav": ["siege", 1.3, (t, n, d) => {
    const boom = cannon(t, n, 70, 3.2);
    const roll = n.dark * 2.6 * Math.exp(-t * 2.4) * (0.7 + 0.3 * Math.sin(TAU * 6 * t));
    const sub = Math.sin(TAU * 38 * t) * Math.exp(-t * 2.8) * 0.4;
    return fade(boom + roll * 0.6 + sub, t, d, 0.001, 0.12);
  }],
  // Cannon boom plus a falling "vwoom" of the shove.
  "knockback_cannon_shot.wav": ["knockback_cannon", 0.75, (t, n, d) => {
    const boom = cannon(t, n, 95, 5.5);
    const vwoom = Math.sin(sweep(t, 260, 45, 0.45)) * Math.exp(-t * 4.5) * 0.45;
    return fade(boom + vwoom, t, d, 0.001, 0.08);
  }],
  // Cannon boom that ignites into a roaring fire tail.
  "flame_cannon_shot.wav": ["flame_cannon", 0.85, (t, n, d) => {
    const boom = cannon(t, n, 90, 6.5);
    const swell = Math.min(t / 0.08, 1) * Math.exp(-t * 3.6);
    const roar = n.dark * 3.0 * swell * (0.75 + 0.25 * Math.sin(TAU * 13 * t));
    const crackle = n.bright * 0.25 * swell * (Math.sin(TAU * 47 * t) > 0.6 ? 1 : 0.2);
    return fade(boom * 0.85 + roar * 0.55 + crackle, t, d, 0.001, 0.1);
  }],
  // A pushing shock-wave: rising charge, then a wide wobbling "vwoooom".
  "knockback_laser_shot.wav": ["knockback_laser", 0.8, (t, n, d) => {
    const charge = t < 0.08 ? Math.sin(sweep(t, 300, 900, 0.08)) * (t / 0.08) * 0.3 : 0;
    const w = Math.max(t - 0.06, 0);
    const wave = (Math.sin(sweep(w, 340, 70, 0.6)) * 0.55 + Math.sin(sweep(w, 680, 140, 0.6)) * 0.2)
      * Math.exp(-w * 4.2) * (0.7 + 0.3 * Math.sin(TAU * 18 * w)) * (t >= 0.06 ? 1 : 0);
    const air = n.dark * 2.2 * Math.exp(-w * 6) * (t >= 0.06 ? 1 : 0);
    return fade(charge + wave + air * 0.5, t, d, 0.003, 0.08);
  }],
  // Searing beam: a hot buzzing hum with fire crackle (loop; pitch rises in-game as it doubles).
  "flame_laser_loop.wav": ["flame_laser", 0.36, (t, n, d) => {
    const hum = Math.sin(TAU * 200 * t) * 0.32 + Math.sin(TAU * 400 * t) * 0.12 + Math.sin(TAU * 600 * t) * 0.06;
    const buzz = 0.8 + 0.2 * Math.sin(TAU * 25 * t);
    const fire = n.soft * 0.5 * (0.6 + 0.4 * Math.sin(TAU * 11.111 * t));
    const crackle = n.bright * 0.22 * (Math.sin(TAU * 41.667 * t) > 0.7 ? 1 : 0.15);
    return fade(hum * buzz + fire + crackle, t, d, 0.009, 0.009);
  }],
};

await fs.mkdir(outputDir, { recursive: true });
for (const [file, [name, seconds, callback]] of Object.entries(sounds)) {
  const samples = synthesize(name, seconds, callback);
  await fs.writeFile(path.join(outputDir, file), writeWav(samples));
  process.stdout.write(`${file}: ${samples.length} samples\n`);
}
