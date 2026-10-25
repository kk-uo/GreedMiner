import fs from "node:fs/promises";
import path from "node:path";

// Reproducible, original placeholder sounds. The game loads the resulting
// mono PCM WAV files directly; no audio plugin or runtime synthesis is needed.
const sampleRate = 22050;
const outputDir = path.resolve("Assets/Audio/Weapons");
let seed = 0x7a31b6d5;

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

function makeNoise(length, coefficient) {
  return lowPass(Array.from({ length }, random), coefficient);
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
  bytes.writeUInt16LE(1, 20); // PCM
  bytes.writeUInt16LE(1, 22); // mono
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

function synthesize(seconds, callback) {
  const length = Math.round(sampleRate * seconds);
  const noise = makeNoise(length, 0.27);
  return Array.from({ length }, (_, index) => callback(index / sampleRate, noise[index], index, length));
}

const sounds = {
  "machine_gun_shot.wav": synthesize(0.105, (t, noise) => {
    const body = Math.sin(2 * Math.PI * (170 * t - 680 * t * t));
    const click = noise * Math.exp(-t * 75);
    return fade((body * 0.42 + click * 1.0) * Math.exp(-t * 28), t, 0.105, 0.001, 0.018);
  }),
  "dwarf_cannon_shot.wav": synthesize(0.56, (t, noise) => {
    const thump = Math.sin(2 * Math.PI * (93 * t - 39 * t * t));
    const rumble = Math.sin(2 * Math.PI * 47 * t) * Math.exp(-t * 5);
    const crack = noise * Math.exp(-t * 24);
    return fade((thump * 0.68 + rumble * 0.24 + crack * 0.92) * Math.exp(-t * 4.5), t, 0.56, 0.002, 0.035);
  }),
  "laser_loop.wav": synthesize(0.32, (t, noise) => {
    const hum = Math.sin(2 * Math.PI * 175 * t) * 0.38;
    const edge = Math.sin(2 * Math.PI * 525 * t) * 0.1;
    const flutter = 0.78 + 0.22 * Math.sin(2 * Math.PI * 12.5 * t);
    return fade((hum + edge + noise * 0.14) * flutter, t, 0.32, 0.009, 0.009);
  }),
  "chainsaw_loop.wav": synthesize(0.32, (t, noise) => {
    const motor = Math.sin(2 * Math.PI * 125 * t) * 0.32;
    const teeth = Math.sin(2 * Math.PI * 375 * t) * 0.16;
    const chatter = 0.66 + 0.34 * Math.sin(2 * Math.PI * 25 * t);
    return fade((motor + teeth + noise * 0.43) * chatter, t, 0.32, 0.009, 0.009);
  }),
  "flamethrower_loop.wav": synthesize(0.36, (t, noise) => {
    const hiss = noise * (0.7 + 0.18 * Math.sin(2 * Math.PI * 11 * t));
    const burner = Math.sin(2 * Math.PI * 110 * t) * 0.17;
    return fade(hiss * 0.56 + burner, t, 0.36, 0.01, 0.01);
  }),
};

await fs.mkdir(outputDir, { recursive: true });
for (const [name, samples] of Object.entries(sounds)) {
  await fs.writeFile(path.join(outputDir, name), writeWav(samples));
  process.stdout.write(`${name}: ${samples.length} samples\n`);
}
