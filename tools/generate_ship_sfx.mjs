import fs from "node:fs/promises";
import path from "node:path";

// Original, deterministic placeholder audio. Run from the Godot project root.
// Files are plain mono PCM WAV so the game needs no synthesis at runtime.
const rate = 22050;
const output = path.resolve("Assets/Audio/Ship");
const tau = Math.PI * 2;
let seed = 0x519af38d;

function noise() {
  seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0;
  return seed / 0x80000000 - 1;
}

function sweep(start, end, time, duration) {
  return Math.sin(tau * (start * time + (end - start) * time * time / (2 * duration)));
}

function envelope(time, duration, attack, release) {
  return Math.min(1, time / attack, (duration - time) / release);
}

function synth(duration, sampleAt) {
  const count = Math.round(duration * rate);
  const wav = Buffer.alloc(44 + count * 2);
  wav.write("RIFF", 0);
  wav.writeUInt32LE(wav.length - 8, 4);
  wav.write("WAVEfmt ", 8);
  wav.writeUInt32LE(16, 16);
  wav.writeUInt16LE(1, 20); // PCM
  wav.writeUInt16LE(1, 22); // mono
  wav.writeUInt32LE(rate, 24);
  wav.writeUInt32LE(rate * 2, 28);
  wav.writeUInt16LE(2, 32);
  wav.writeUInt16LE(16, 34);
  wav.write("data", 36);
  wav.writeUInt32LE(count * 2, 40);
  let filteredNoise = 0;
  for (let index = 0; index < count; index += 1) {
    const time = index / rate;
    filteredNoise += 0.22 * (noise() - filteredNoise);
    const sample = Math.tanh(sampleAt(time, filteredNoise, duration)) * 0.83;
    wav.writeInt16LE(Math.round(Math.max(-1, Math.min(1, sample)) * 32767), 44 + index * 2);
  }
  return wav;
}

const sounds = {
  "takeoff.wav": synth(1.45, (t, n, length) => {
    const progress = t / length;
    const rev = sweep(75, 245, t, length);
    const turbine = sweep(225, 735, t, length);
    const ignition = n * Math.exp(-t * 16) * 0.9;
    const engine = (rev * 0.50 + turbine * 0.13 + n * 0.35)
      * (0.45 + 0.55 * Math.min(t / 0.48, 1));
    const rushingAir = n * progress * 0.40;
    return (ignition + engine + rushingAir) * envelope(t, length, 0.012, 0.11);
  }),
  "landing.wav": synth(1.30, (t, n, length) => {
    const progress = t / length;
    const descendingMotor = sweep(215, 78, t, length) * 0.43;
    const highWhine = sweep(520, 190, t, length) * 0.11;
    const air = n * (0.22 + progress * 0.31);
    return (descendingMotor + highWhine + air)
      * envelope(t, length, 0.025, 0.04);
  }),
  "touchdown.wav": synth(0.67, (t, n, length) => {
    const impact = sweep(105, 45, t, length) * Math.exp(-t * 7) * 0.80;
    const crunch = n * Math.exp(-t * 18) * 0.98;
    const chassis = sweep(365, 155, t, length) * Math.exp(-t * 10) * 0.20;
    const vent = n * Math.exp(-t * 4.3) * 0.16;
    return (impact + crunch + chassis + vent)
      * envelope(t, length, 0.002, 0.07);
  }),
};

await fs.mkdir(output, { recursive: true });
for (const [name, data] of Object.entries(sounds)) {
  await fs.writeFile(path.join(output, name), data);
  process.stdout.write(`${name}: ${(data.length - 44) / 2 / rate}s\n`);
}
