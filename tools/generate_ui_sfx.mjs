import fs from "node:fs/promises";
import path from "node:path";

// Reproducible UI sounds (mono 16-bit 22050 Hz PCM).
// Run from the project root: node tools/generate_ui_sfx.mjs
// click_pop.wav: user pick "B soft pop" - a short bubble pop whose pitch rises.
// stamp_thud.wav: a rubber stamp slammed on paper on a wooden board (result board).
const sampleRate = 22050;
const outputDir = path.resolve("Assets/Audio/UI");

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
    bytes.writeInt16LE(Math.round(Math.max(-1, Math.min(1, samples[index])) * 32767), 44 + index * 2);
  }
  return bytes;
}

function clickPop() {
  const seconds = 0.07;
  const length = Math.round(sampleRate * seconds);
  const raw = Array.from({ length }, (_, index) => {
    const t = index / sampleRate;
    const pop = Math.sin(2 * Math.PI * (380 * t + 4200 * t * t));
    return pop * Math.exp(-t * 60) * Math.min(1, t / 0.002);
  });
  const peak = Math.max(...raw.map(Math.abs));
  return raw.map((sample, index) => sample / peak * 0.7 * Math.min(1, (length - index) / (0.004 * sampleRate)));
}

function stampThud() {
  const seconds = 0.16;
  const length = Math.round(sampleRate * seconds);
  let seed = 0x2b5d11;
  let low = 0;
  const raw = Array.from({ length }, (_, index) => {
    const t = index / sampleRate;
    seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0;
    const white = seed / 0x100000000 * 2 - 1;
    low += 0.35 * (white - low);
    const thump = Math.sin(2 * Math.PI * (150 * t - 260 * t * t)) * Math.exp(-t * 32);
    const knock = Math.sin(2 * Math.PI * 420 * t) * Math.exp(-t * 70) * 0.35;
    const slap = low * Math.exp(-t * 90) * 1.6;
    return (thump + knock + slap) * Math.min(1, t / 0.0015);
  });
  const peak = Math.max(...raw.map(Math.abs));
  return raw.map((sample, index) => sample / peak * 0.75 * Math.min(1, (length - index) / (0.01 * sampleRate)));
}

await fs.mkdir(outputDir, { recursive: true });
await fs.writeFile(path.join(outputDir, "click_pop.wav"), writeWav(clickPop()));
await fs.writeFile(path.join(outputDir, "stamp_thud.wav"), writeWav(stampThud()));
process.stdout.write("click_pop.wav\nstamp_thud.wav\n");
