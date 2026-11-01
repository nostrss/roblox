#!/usr/bin/env node
// 하늘 큐브맵 생성기: 대기 색 + 3D 잡음 구름을 광선 진행으로 구워 면 6장을 PNG로 낸다. 사진을 쓰지 않으므로 라이선스 걱정이 없다.
// 쓰임: node sky_cube.mjs <day|sunset|night|debug> <outDir> [face] [size]
// 면 이름은 Roblox Sky 속성 이름(Bk Dn Ft Lf Rt Up). 면 방향은 FACES 표 (Studio에서 debug 큐브로 확인한 값).
import { deflateSync } from "node:zlib";
import { mkdirSync, writeFileSync } from "node:fs";
import { join } from "node:path";

const [preset = "sunset", outDir = ".", onlyFace, sizeArg] = process.argv.slice(2);
const SIZE = Number(sizeArg) || (preset === "debug" ? 256 : 1024);

// 벡터
const dot = (a, b) => a[0] * b[0] + a[1] * b[1] + a[2] * b[2];
const norm = (a) => {
  const l = Math.hypot(a[0], a[1], a[2]);
  return [a[0] / l, a[1] / l, a[2] / l];
};
const clamp = (x, a = 0, b = 1) => Math.min(b, Math.max(a, x));
const mix = (a, b, t) => a + (b - a) * t;
const mix3 = (a, b, t) => [mix(a[0], b[0], t), mix(a[1], b[1], t), mix(a[2], b[2], t)];
const smooth = (a, b, x) => {
  const t = clamp((x - a) / (b - a));
  return t * t * (3 - 2 * t);
};
const srgb = (hex) => {
  const c = [(hex >> 16) & 255, (hex >> 8) & 255, hex & 255];
  return c.map((v) => Math.pow(v / 255, 2.2)); // 선형 공간에서 섞는다
};

// 값 잡음 (주기 256 격자)
const PERM = new Uint8Array(512);
{
  let s = 1234567;
  const p = Array.from({ length: 256 }, (_, i) => i);
  for (let i = 255; i > 0; i--) {
    s = (s * 1103515245 + 12345) & 0x7fffffff;
    const j = s % (i + 1);
    [p[i], p[j]] = [p[j], p[i]];
  }
  for (let i = 0; i < 512; i++) PERM[i] = p[i & 255];
}
const fade = (t) => t * t * t * (t * (t * 6 - 15) + 10);
function noise(x, y, z) {
  const xi = Math.floor(x), yi = Math.floor(y), zi = Math.floor(z);
  const u = fade(x - xi), v = fade(y - yi), w = fade(z - zi);
  const X = xi & 255, Y = yi & 255, Z = zi & 255;
  const h = (a, b, c) => PERM[PERM[PERM[(X + a) & 255] + ((Y + b) & 255)] + ((Z + c) & 255)] / 255;
  return mix(
    mix(mix(h(0, 0, 0), h(1, 0, 0), u), mix(h(0, 1, 0), h(1, 1, 0), u), v),
    mix(mix(h(0, 0, 1), h(1, 0, 1), u), mix(h(0, 1, 1), h(1, 1, 1), u), v),
    w,
  );
}
function fbm(x, y, z, oct) {
  let a = 0.5, s = 0, t = 0;
  for (let i = 0; i < oct; i++) {
    s += a * noise(x, y, z);
    t += a;
    x = x * 2.03 + 17.1;
    y = y * 2.03 + 3.7;
    z = z * 2.03 + 9.2;
    a *= 0.5;
  }
  return s / t;
}

// 프리셋. 해 방향은 세계 좌표: 노을은 Lighting.ClockTime 17.6의 GetSunDirection (Studio에서 읽음, 위도 37.56)
const PRESETS = {
  day: {
    sun: norm([-0.35, 0.82, 0.45]),
    zenith: srgb(0x2f6fc4), mid: srgb(0x6fa8e0), horizon: srgb(0xd6e4ee),
    glow: srgb(0xfff4e0), glowPow: 180, glowAmt: 0.35, wide: 0.1,
    antiBand: 0, sunCol: [3.2, 3.05, 2.8], ambient: srgb(0x8fb0d8), ambientAmt: 1.05,
    coverage: 0.55, sharp: 0.17, cirrus: 0.28, cirrusCol: [1.5, 1.5, 1.5], haze: srgb(0xe6edf2),
  },
  sunset: {
    sun: norm([-0.9647, 0.1014, 0.243]),
    zenith: srgb(0x1e2f62), mid: srgb(0x7a668f), horizon: srgb(0xf7a35c),
    glow: srgb(0xffb45a), glowPow: 7, glowAmt: 1.1, wide: 0.55,
    antiBand: 0.55, sunCol: [4.2, 1.9, 0.8], ambient: srgb(0x5a4a78), ambientAmt: 0.5,
    coverage: 0.56, sharp: 0.17, cirrus: 0.55, cirrusCol: [2.1, 1.0, 0.7], haze: srgb(0xf0a878),
  },
  night: {
    sun: norm([0.3, 0.75, 0.55]), // 달빛 쪽
    zenith: srgb(0x060a1c), mid: srgb(0x101838), horizon: srgb(0x2a2a48),
    glow: srgb(0x8a95c0), glowPow: 40, glowAmt: 0.04, wide: 0,
    antiBand: 0, sunCol: [0.1, 0.12, 0.18], ambient: srgb(0x161b30), ambientAmt: 0.45,
    coverage: 0.49, sharp: 0.17, cirrus: 0.08, cirrusCol: [0.12, 0.13, 0.2], haze: srgb(0x2e2c44),
    cityGlow: srgb(0xb0703c),
  },
};

// 면마다 (가로 u +1, 세로 v +1(위로), 앞 n) — Roblox Sky를 안에서 본 방향. debug 큐브로 확인
const FACES = {
  Ft: { n: [0, 0, -1], u: [1, 0, 0], v: [0, 1, 0] },
  Bk: { n: [0, 0, 1], u: [-1, 0, 0], v: [0, 1, 0] },
  Lf: { n: [1, 0, 0], u: [0, 0, 1], v: [0, 1, 0] }, // Lf가 +X를 본다 (이름과 달리 세계 동쪽)
  Rt: { n: [-1, 0, 0], u: [0, 0, -1], v: [0, 1, 0] },
  Up: { n: [0, 1, 0], u: [0, 0, -1], v: [1, 0, 0] },
  Dn: { n: [0, -1, 0], u: [0, 0, -1], v: [-1, 0, 0] }, // 땅에 가려 보이지 않는 면. 방향은 Ft·Lf·Up 규칙에서 맞춤 (Studio 미확인)
};

const CLOUD_BOTTOM = 1.0, CLOUD_TOP = 1.35;
const STEPS = 26, LIGHT_STEPS = 4;

function density(p, P) {
  const warp = noise(p[0] * 0.3 + 5, p[1], p[2] * 0.3 + 9) * 1.6;
  const f = fbm(p[0] * 1.1 + warp, p[1] * 1.6, p[2] * 1.1 - warp, 4);
  const h = clamp((p[1] - CLOUD_BOTTOM) / (CLOUD_TOP - CLOUD_BOTTOM));
  const shape = smooth(0, 0.12, h) * smooth(1, 0.35, h); // 아랫면은 평평하고 위로 뭉게뭉게 줄어든다
  const big = f * shape - (1 - P.coverage);
  if (big <= 0) return 0;
  // 가장자리를 작은 뭉게 무늬로 깎는다 (능선 잡음)
  const n = fbm(p[0] * 6.5, p[1] * 6.5, p[2] * 6.5, 4);
  const billow = 1 - Math.abs(2 * n - 1);
  return clamp((big - (1 - billow) * P.sharp) * 11);
}

function skyColor(d, P) {
  const y = clamp(d[1]);
  const t = Math.pow(1 - y, 3.2);
  const t2 = Math.pow(1 - y, 9);
  let c = mix3(mix3(P.zenith, P.mid, t), P.horizon, t2);
  const cs = dot(d, P.sun);
  const up = clamp(cs * 0.5 + 0.5);
  if (P.wide > 0) {
    // 해 쪽 지평선은 뜨겁게, 반대쪽은 차게 (청자색 지구 그림자 위로 분홍 띠)
    const side = Math.pow(up, 2.2);
    const band = Math.pow(1 - y, 5);
    c = mix3(c, [c[0] * 0.55, c[1] * 0.5, c[2] * 0.72], (1 - side) * band * P.wide);
    if (P.antiBand > 0) {
      const belt = Math.exp(-Math.pow((y - 0.12) / 0.08, 2)) * Math.pow(1 - up, 1.5);
      c = mix3(c, srgb(0xd98a9c), belt * P.antiBand);
    }
  }
  const g = Math.pow(clamp(cs), P.glowPow) * P.glowAmt;
  c = [c[0] + P.glow[0] * g, c[1] + P.glow[1] * g, c[2] + P.glow[2] * g];
  if (P.wide > 0) {
    const inner = Math.pow(clamp(cs), 60) * 1.2;
    c = [c[0] + 1.3 * inner, c[1] + 0.8 * inner, c[2] + 0.35 * inner];
  }
  if (P.cityGlow) {
    const g2 = Math.pow(1 - y, 32) * 0.16;
    c = [c[0] + P.cityGlow[0] * g2, c[1] + P.cityGlow[1] * g2, c[2] + P.cityGlow[2] * g2];
  }
  return c;
}

function cirrus(d, P) {
  if (d[1] < 0.03 || P.cirrus <= 0) return 0;
  const k = 2.6 / d[1];
  const x = d[0] * k, z = d[2] * k;
  const warp = fbm(x * 0.35, 5.3, z * 0.35, 3);
  const f = fbm(x * 0.5 + warp * 2.2, 11.1, z * 1.6 + warp * 1.4, 5);
  return smooth(0.5, 0.8, f) * smooth(0.03, 0.2, d[1]) * P.cirrus;
}

function shade(d, P) {
  const sky = skyColor(d, P);
  let col = sky;
  const c2 = cirrus(d, P);
  if (c2 > 0) col = mix3(col, P.cirrusCol, c2 * 0.75);
  if (d[1] > 0.012) {
    const t0 = CLOUD_BOTTOM / d[1], t1 = CLOUD_TOP / d[1];
    const maxT = 22;
    if (t0 < maxT) {
      const dt = (Math.min(t1, maxT) - t0) / STEPS;
      const cosSun = dot(d, P.sun);
      const g = 0.72;
      const hg = ((1 - g * g) / Math.pow(1 + g * g - 2 * g * cosSun, 1.5)) * 0.25 + 0.3;
      let trans = 1;
      let acc = [0, 0, 0];
      for (let i = 0; i < STEPS && trans > 0.02; i++) {
        const t = t0 + (i + 0.5) * dt;
        const p = [d[0] * t + 40, d[1] * t, d[2] * t + 40];
        const rho = density(p, P);
        if (rho <= 0) continue;
        let od = 0;
        for (let j = 1; j <= LIGHT_STEPS; j++) {
          const s = j * 0.11;
          const q = [p[0] + P.sun[0] * s, p[1] + P.sun[1] * s, p[2] + P.sun[2] * s];
          od += density(q, P);
        }
        const light = Math.exp(-od * 1.05) * (1 - Math.exp(-od * 2.4 - rho)) * 2;
        const h = clamp((p[1] - CLOUD_BOTTOM) / (CLOUD_TOP - CLOUD_BOTTOM));
        const amb = P.ambientAmt * mix(0.55, 1.05, h);
        const r = P.ambient[0] * amb + P.sunCol[0] * light * hg;
        const gg = P.ambient[1] * amb + P.sunCol[1] * light * hg;
        const b = P.ambient[2] * amb + P.sunCol[2] * light * hg;
        const a = 1 - Math.exp(-rho * dt * 7.5);
        // 도시 불빛이 밤구름 아랫면을 비춘다
        const city = P.cityGlow ? (1 - h) * 0.05 : 0;
        const rr = r + (P.cityGlow ? P.cityGlow[0] * city : 0);
        const ggg = gg + (P.cityGlow ? P.cityGlow[1] * city : 0);
        const bb = b + (P.cityGlow ? P.cityGlow[2] * city : 0);
        acc[0] += trans * a * rr;
        acc[1] += trans * a * ggg;
        acc[2] += trans * a * bb;
        trans *= 1 - a;
      }
      // 멀수록 지평선 빛에 묻힌다
      const far = smooth(3, 16, t0);
      const hz = mix3(P.haze, sky, 0.45);
      const fog = far * 0.9;
      col = [
        mix(col[0] * trans + acc[0], hz[0], fog * (1 - trans)),
        mix(col[1] * trans + acc[1], hz[1], fog * (1 - trans)),
        mix(col[2] * trans + acc[2], hz[2], fog * (1 - trans)),
      ];
    }
  }
  // 지평선 아래는 건물·땅 뒤라 잘 안 보인다: 지평선 색이 서서히 어두워진다
  if (d[1] < 0) {
    const k = smooth(0, -0.25, d[1]);
    const h = skyColor([d[0], 0, d[2]], P);
    col = mix3(h, [h[0] * 0.25, h[1] * 0.25, h[2] * 0.25], k);
  }
  return col;
}

// 필름 톤매핑 → sRGB
const tone = (x) => Math.pow(clamp((x * (2.51 * x + 0.03)) / (x * (2.43 * x + 0.59) + 0.14)), 1 / 2.2);

function crcTable() {
  const t = new Uint32Array(256);
  for (let n = 0; n < 256; n++) {
    let c = n;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    t[n] = c >>> 0;
  }
  return t;
}
const CRC = crcTable();
function crc(buf) {
  let c = 0xffffffff;
  for (const b of buf) c = CRC[(c ^ b) & 255] ^ (c >>> 8);
  return (c ^ 0xffffffff) >>> 0;
}
function chunk(type, data) {
  const len = Buffer.alloc(4);
  len.writeUInt32BE(data.length);
  const td = Buffer.concat([Buffer.from(type), data]);
  const c = Buffer.alloc(4);
  c.writeUInt32BE(crc(td));
  return Buffer.concat([len, td, c]);
}
function png(w, h, rgb) {
  const raw = Buffer.alloc((w * 3 + 1) * h);
  for (let y = 0; y < h; y++) {
    raw[y * (w * 3 + 1)] = 0;
    rgb.copy(raw, y * (w * 3 + 1) + 1, y * w * 3, (y + 1) * w * 3);
  }
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(w, 0);
  ihdr.writeUInt32BE(h, 4);
  ihdr[8] = 8;
  ihdr[9] = 2;
  return Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    chunk("IHDR", ihdr),
    chunk("IDAT", deflateSync(raw, { level: 9 })),
    chunk("IEND", Buffer.alloc(0)),
  ]);
}

function render(name) {
  const f = FACES[name];
  const rgb = Buffer.alloc(SIZE * SIZE * 3);
  const P = PRESETS[preset];
  for (let y = 0; y < SIZE; y++) {
    const v = 1 - ((y + 0.5) / SIZE) * 2;
    for (let x = 0; x < SIZE; x++) {
      const u = ((x + 0.5) / SIZE) * 2 - 1;
      const i = (y * SIZE + x) * 3;
      if (preset === "debug") {
        // 면마다 다른 색, 위쪽 띠 흰색, 오른쪽 띠 검정 → 화면에서 방향·뒤집힘을 읽는다
        const base = { Ft: [220, 40, 40], Bk: [40, 200, 40], Lf: [40, 80, 230], Rt: [230, 220, 40], Up: [220, 60, 220], Dn: [40, 220, 220] }[name];
        const c = v > 0.8 ? [255, 255, 255] : u > 0.8 ? [0, 0, 0] : base;
        rgb[i] = c[0], rgb[i + 1] = c[1], rgb[i + 2] = c[2];
        continue;
      }
      const d = norm([
        f.n[0] + f.u[0] * u + f.v[0] * v,
        f.n[1] + f.u[1] * u + f.v[1] * v,
        f.n[2] + f.u[2] * u + f.v[2] * v,
      ]);
      const c = shade(d, P);
      const dith = (Math.random() - 0.5) * 1.0; // 띠 무늬 방지
      rgb[i] = clamp(tone(c[0]) * 255 + dith, 0, 255);
      rgb[i + 1] = clamp(tone(c[1]) * 255 + dith, 0, 255);
      rgb[i + 2] = clamp(tone(c[2]) * 255 + dith, 0, 255);
    }
  }
  writeFileSync(join(outDir, `${preset}_${name}.png`), png(SIZE, SIZE, rgb));
}

mkdirSync(outDir, { recursive: true });
for (const name of onlyFace && onlyFace !== "all" ? [onlyFace] : Object.keys(FACES)) render(name);
