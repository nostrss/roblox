#!/usr/bin/env node
// 주변 건물 입면·밤 창 불빛·박석 텍스처 생성기. 사진을 쓰지 않는다. 쓰임: node facade_png.mjs <outDir>
// 입면 타일 하나 = 8층 × 8칸 (층고 3.5 m, 칸 3 m. server Silhouette의 FACADE와 같아야 한다).
// 낮 타일은 유리 칸을 반투명으로 둔다 → 밑의 파트 반사(Reflectance)가 비쳐 하늘이 유리에 든다.
// 밤 타일은 켜진 창만 불투명하고 나머지는 투명하다 → SurfaceGui(LightInfluence 0)로 얹어 스스로 빛난다.
import { deflateSync } from "node:zlib";
import { mkdirSync, writeFileSync } from "node:fs";
import { join } from "node:path";

const outDir = process.argv[2] ?? ".";
mkdirSync(outDir, { recursive: true });

const clamp = (x, a = 0, b = 1) => Math.min(b, Math.max(a, x));
const mix = (a, b, t) => a + (b - a) * t;

let seed = 20261102;
const rnd = () => {
  seed = (seed * 1664525 + 1013904223) >>> 0;
  return seed / 4294967296;
};

// 값 잡음: 격자 256칸을 주기로 이어져 타일 경계가 맞는다
function makeNoise(period) {
  const g = Float32Array.from({ length: period * period }, () => rnd());
  return (x, y) => {
    const xi = Math.floor(x), yi = Math.floor(y);
    const u = x - xi, v = y - yi;
    const su = u * u * (3 - 2 * u), sv = v * v * (3 - 2 * v);
    const at = (a, b) => g[((yi + b) % period + period) % period * period + ((xi + a) % period + period) % period];
    return mix(mix(at(0, 0), at(1, 0), su), mix(at(0, 1), at(1, 1), su), sv);
  };
}
const n1 = makeNoise(16), n2 = makeNoise(64), n3 = makeNoise(256);
const fine = (u, v) => n3(u * 256, v * 256) * 0.5 + n2(u * 64, v * 64) * 0.3 + n1(u * 16, v * 16) * 0.2;

class Img {
  constructor(w, h) {
    this.w = w;
    this.h = h;
    this.d = new Float32Array(w * h * 4);
  }
  // 사각형 칠하기 (0~1 좌표, 타일을 넘어가면 돌아온다). fn(u, v) 또는 [r, g, b, a]
  rect(x0, y0, x1, y1, c) {
    const { w, h, d } = this;
    for (let y = Math.round(y0 * h); y < Math.round(y1 * h); y++) {
      for (let x = Math.round(x0 * w); x < Math.round(x1 * w); x++) {
        const px = ((x % w) + w) % w, py = ((y % h) + h) % h;
        const col = typeof c === "function" ? c(px / w, py / h) : c;
        const i = (py * w + px) * 4;
        const a = col[3] ?? 1;
        if (col.over) {
          // 위에 덧칠 (a만큼)
          d[i] = mix(d[i], col[0], a);
          d[i + 1] = mix(d[i + 1], col[1], a);
          d[i + 2] = mix(d[i + 2], col[2], a);
        } else {
          d[i] = col[0];
          d[i + 1] = col[1];
          d[i + 2] = col[2];
          d[i + 3] = a;
        }
      }
    }
  }
  save(name) {
    const { w, h, d } = this;
    const raw = Buffer.alloc((w * 4 + 1) * h);
    for (let y = 0; y < h; y++) {
      const row = y * (w * 4 + 1);
      for (let x = 0; x < w; x++) {
        const i = (y * w + x) * 4, o = row + 1 + x * 4;
        raw[o] = clamp(d[i]) * 255;
        raw[o + 1] = clamp(d[i + 1]) * 255;
        raw[o + 2] = clamp(d[i + 2]) * 255;
        raw[o + 3] = clamp(d[i + 3]) * 255;
      }
    }
    writeFileSync(join(outDir, name + ".png"), png(w, h, raw));
  }
}

const CRC = new Uint32Array(256).map((_, n) => {
  let c = n;
  for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
  return c >>> 0;
});
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
function png(w, h, raw) {
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(w, 0);
  ihdr.writeUInt32BE(h, 4);
  ihdr[8] = 8;
  ihdr[9] = 6;
  return Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    chunk("IHDR", ihdr),
    chunk("IDAT", deflateSync(raw, { level: 9 })),
    chunk("IEND", Buffer.alloc(0)),
  ]);
}

const hex = (h) => [((h >> 16) & 255) / 255, ((h >> 8) & 255) / 255, (h & 255) / 255];

// 벽 재질: 잡음 얼룩 + 층마다 때 자국
function wall(base, amp = 0.09, streak = 0.05) {
  return (u, v) => {
    const k = 1 + (fine(u, v) - 0.5) * amp * 2 - n1(u * 16, 0) * streak;
    return [base[0] * k, base[1] * k, base[2] * k, 1];
  };
}

const SIZE = 1024;
const WARM = [hex(0xffd9a0), hex(0xffc98a), hex(0xffe6c0), hex(0xfff0d8)];
const COOL = [hex(0xdff0ff), hex(0xeef6ff), hex(0xcfe6f6)];

// 켜진 창 고르기 (건물마다 타일을 공유하므로 패턴은 몇 층씩 뭉치게: 사무실은 한 층이 함께 켜진다)
function litColor(floorOn) {
  if (rnd() > floorOn) return null;
  const c = rnd() < 0.35 ? COOL[Math.floor(rnd() * COOL.length)] : WARM[Math.floor(rnd() * WARM.length)];
  const dim = 0.32 + rnd() * 0.4; // 밤 창은 하얗게 날리지 않게 어둡게
  return [c[0] * dim, c[1] * dim, c[2] * dim, 0.9];
}

// 밤 바탕: 어두운 남색으로 면 전체를 덮는다. 창 불빛 판은 대기·조명을 받지 않아, 비워 두면 창만 하늘에 떠 보인다
function nightBase(img, wallColor) {
  const k = (wallColor[0] + wallColor[1] + wallColor[2]) / 3;
  img.rect(0, 0, 1, 1, (u, v) => {
    const g = 0.9 + fine(u, v) * 0.2;
    return [(0.035 + k * 0.05) * g, (0.042 + k * 0.05) * g, (0.075 + k * 0.05) * g, 1];
  });
  for (let f = 0; f < 8; f++) img.rect(0, f / 8, 1, f / 8 + 0.002, [0.07, 0.08, 0.12, 1]); // 층 선
}

// 격자 입면 공통: 벽 → 칸마다 창. window(cx0, cy0, cx1, cy1)은 칸 안 창 사각형 비율
function gridFacade(name, opts) {
  const day = new Img(SIZE, SIZE), night = new Img(SIZE, SIZE);
  day.rect(0, 0, 1, 1, wall(opts.wall, opts.amp, opts.streak));
  nightBase(night, opts.wall);
  const F = 8, B = 8;
  for (let f = 0; f < F; f++) {
    const floorOn = rnd() < 0.5 ? 0.06 : rnd() < 0.6 ? 0.25 : 0.55;
    for (let b = 0; b < B; b++) {
      const cx = b / B, cy = f / F;
      const [ax, ay, bx, by] = opts.window;
      const x0 = cx + ax / B, x1 = cx + bx / B, y0 = cy + ay / F, y1 = cy + by / F;
      // 창 둘레 그림자(들어간 창), 아래 턱 밝게
      if (opts.reveal) {
        day.rect(x0 - 0.002, y0 - 0.004, x1 + 0.002, y1 + 0.002, Object.assign([0.05, 0.05, 0.06, 0.55], { over: true }));
        day.rect(x0 - 0.003, y1, x1 + 0.003, y1 + 0.004, Object.assign([...opts.wall.map((v) => v * 1.18), 1], { over: true }));
      }
      const tint = rnd();
      const blind = rnd() < (opts.blinds ?? 0.2) ? rnd() * 0.6 : 0; // 내린 블라인드
      const a = opts.glassAlpha;
      day.rect(x0, y0, x1, y1, (u, v) => {
        const vv = (v - y0) / (y1 - y0);
        const down = vv < blind;
        const g = opts.glass.map((q) => q * (0.85 + tint * 0.3) * (1 + (vv - 0.5) * 0.12));
        if (down) return [0.74, 0.72, 0.66, 1];
        return [g[0], g[1], g[2], a];
      });
      // 칸살
      const mid = opts.mullions ?? 1;
      for (let m = 1; m < mid; m++) {
        const mx = mix(x0, x1, m / mid);
        day.rect(mx - 0.0012, y0, mx + 0.0012, y1, [...opts.frame, 1]);
      }
      // 에어컨 실외기 (옛 건물)
      if (opts.ac && rnd() < opts.ac) {
        const ux = mix(x0, x1, 0.15 + rnd() * 0.4);
        day.rect(ux, y1 + 0.003, ux + 0.022, y1 + 0.015, [0.68, 0.68, 0.66, 1]);
        day.rect(ux + 0.003, y1 + 0.005, ux + 0.012, y1 + 0.013, [0.25, 0.25, 0.26, 1]);
      }
      const lit = litColor(floorOn);
      if (lit) night.rect(x0, y0, x1, y1, lit);
    }
  }
  for (const line of opts.lines ?? []) {
    for (let i = 0; i < (line.vertical ? B : F) * (line.every ?? 1); i++) {
      const p = (i + (line.at ?? 0)) / ((line.vertical ? B : F) * (line.every ?? 1));
      if (line.vertical) day.rect(p - line.w / 2, 0, p + line.w / 2, 1, [...line.c, 1]);
      else day.rect(0, p - line.w / 2, 1, p + line.w / 2, [...line.c, 1]);
    }
  }
  day.save(`facade_${name}`);
  night.save(`lit_${name}`);
}

// 유리 커튼월: 칸마다 큰 유리, 층 사이 불투명 스팬드럴
gridFacade("glass", {
  wall: hex(0x3a4a58), amp: 0.03, streak: 0, window: [0.015, 0.2, 0.985, 0.985], glass: hex(0x26425a), glassAlpha: 0.42,
  frame: hex(0x8d99a3), mullions: 2, blinds: 0.12,
  lines: [{ vertical: true, w: 0.003, c: hex(0xa5afb6) }, { w: 0.0035, c: hex(0xa5afb6) }, { at: 0.2, w: 0.002, c: hex(0x7d8992) }],
});
gridFacade("darkglass", {
  wall: hex(0x171b20), amp: 0.02, streak: 0, window: [0.012, 0.12, 0.988, 0.985], glass: hex(0x101b24), glassAlpha: 0.3,
  frame: hex(0x2c3137), mullions: 3, blinds: 0.05,
  lines: [{ vertical: true, w: 0.0028, c: hex(0x3a4047) }, { w: 0.003, c: hex(0x3a4047) }],
});
// 화강석 사무동: 석재 띠 사이 큰 창 (1980~90년대 도심 빌딩)
gridFacade("stone", {
  wall: hex(0xb7ab9a), amp: 0.08, streak: 0.04, window: [0.14, 0.2, 0.86, 0.84], glass: hex(0x2c3a46), glassAlpha: 0.55,
  frame: hex(0x4a4f54), mullions: 2, reveal: true, blinds: 0.3,
  lines: [{ every: 2, at: 0.5, w: 0.0012, c: hex(0x8d8375) }, { w: 0.0022, c: hex(0x8d8375) }, { vertical: true, every: 2, w: 0.001, c: hex(0x9a8f80) }],
});
// 갈색 타일 띠창
gridFacade("tile", {
  wall: hex(0x7a5a48), amp: 0.1, streak: 0.04, window: [0.0, 0.26, 1.0, 0.76], glass: hex(0x22303a), glassAlpha: 0.6,
  frame: hex(0x34383c), mullions: 3, blinds: 0.35,
  lines: [{ w: 0.002, c: hex(0x5e4436) }, { vertical: true, w: 0.0035, c: hex(0x4a4f54) }],
});
// 흰 콘크리트 옛 건물: 작은 창, 때 자국, 실외기
gridFacade("concrete", {
  wall: hex(0xb2afa8), amp: 0.14, streak: 0.16, window: [0.2, 0.26, 0.8, 0.76], glass: hex(0x28323a), glassAlpha: 0.75,
  frame: hex(0x6a6e70), mullions: 2, reveal: true, blinds: 0.35, ac: 0.3,
  lines: [{ w: 0.002, c: hex(0x8b8780) }],
});

// 낮은 상가: 층마다 색 간판이 입면을 덮는다 (남대문시장 쪽). 글자 대신 덩어리 무늬 — 글자는 근처 간판(SurfaceGui)만
{
  const day = new Img(SIZE, SIZE), night = new Img(SIZE, SIZE);
  day.rect(0, 0, 1, 1, wall(hex(0xa9a196), 0.12, 0.12));
  nightBase(night, hex(0xa9a196));
  const COLORS = [0xc7362f, 0x1f5fa8, 0xf0c02a, 0xf4f1e6, 0x2c8a4b, 0xe46c1e, 0x222428, 0x7a2c8c].map(hex);
  for (let f = 0; f < 8; f++) {
    for (let b = 0; b < 8; b++) {
      const x0 = (b + 0.1) / 8, x1 = (b + 0.9) / 8, y0 = (f + 0.32) / 8, y1 = (f + 0.9) / 8;
      day.rect(x0, y0, x1, y1, [0.12, 0.17, 0.2, 0.6]);
      day.rect((x0 + x1) / 2 - 0.0012, y0, (x0 + x1) / 2 + 0.0012, y1, [0.35, 0.35, 0.36, 1]);
      const lit = litColor(0.25);
      if (lit) night.rect(x0, y0, x1, y1, lit);
    }
    // 간판: 층 위쪽 띠를 칸 몇 개씩 묶어 덮는다
    let b = 0;
    while (b < 8) {
      const w = 2 + Math.floor(rnd() * 3);
      if (rnd() < 0.7) {
        const c = COLORS[Math.floor(rnd() * COLORS.length)];
        const x0 = b / 8 + 0.004, x1 = Math.min(1, (b + w) / 8) - 0.004, y0 = (f + 0.03) / 8, y1 = (f + 0.28) / 8;
        day.rect(x0, y0, x1, y1, [...c, 1]);
        night.rect(x0, y0, x1, y1, [c[0] * 0.55, c[1] * 0.55, c[2] * 0.55, 1]);
        const ink = c[0] + c[1] + c[2] > 1.6 ? [0.1, 0.1, 0.12, 1] : [0.97, 0.97, 0.94, 1];
        // 글자 덩어리
        const n = 3 + Math.floor(rnd() * 5);
        for (let k = 0; k < n; k++) {
          const gx = mix(x0, x1, (k + 0.2) / n), gw = ((x1 - x0) / n) * 0.62;
          day.rect(gx, y0 + 0.006, gx + gw, y1 - 0.006, ink);
          night.rect(gx, y0 + 0.006, gx + gw, y1 - 0.006, ink.map((q, n) => (n < 3 ? q * 0.6 : q)));
        }
      }
      b += w;
    }
  }
  day.save("facade_market");
  night.save("lit_market");
}

// 1층 상점 띠: 8칸 × 1층 (1024 × 192). 위 간판, 아래 유리 진열창
{
  const W = 1024, H = 192;
  const day = new Img(W, H), night = new Img(W, H);
  day.rect(0, 0, 1, 1, wall(hex(0x8d877e), 0.1, 0));
  night.rect(0, 0, 1, 1, [0.07, 0.07, 0.1, 1]);
  const COLORS = [0xb8342c, 0x1d5a9e, 0xe8b820, 0xf0ede0, 0x2a7f46, 0xd9641b, 0x202226].map(hex);
  let b = 0;
  while (b < 8) {
    const w = 1 + Math.floor(rnd() * 3);
    const x0 = b / 8 + 0.004, x1 = Math.min(1, (b + w) / 8) - 0.004;
    const c = COLORS[Math.floor(rnd() * COLORS.length)];
    day.rect(x0, 0.03, x1, 0.27, [...c, 1]);
    night.rect(x0, 0.03, x1, 0.27, [...c.map((v) => v * 0.65), 1]);
    const ink = c[0] + c[1] + c[2] > 1.6 ? [0.1, 0.1, 0.12, 1] : [0.97, 0.97, 0.94, 1];
    const n = 2 + Math.floor(rnd() * 4);
    for (let k = 0; k < n; k++) {
      const gx = mix(x0, x1, (k + 0.25) / n), gw = ((x1 - x0) / n) * 0.5;
      day.rect(gx, 0.07, gx + gw, 0.23, ink);
      night.rect(gx, 0.07, gx + gw, 0.23, ink.map((q, n) => (n < 3 ? q * 0.7 : q)));
    }
    day.rect(x0, 0.31, x1, 0.97, [0.16, 0.22, 0.26, 0.5]);
    const on = rnd() < 0.85;
    const warm = WARM[Math.floor(rnd() * WARM.length)];
    if (on) night.rect(x0, 0.31, x1, 0.97, [warm[0] * 0.7, warm[1] * 0.68, warm[2] * 0.62, 1]);
    for (let m = 0; m <= w; m++) {
      const mx = mix(x0, x1, m / w);
      day.rect(mx - 0.0015, 0.31, mx + 0.0015, 0.97, [0.3, 0.3, 0.32, 1]);
      if (on) night.rect(mx - 0.0015, 0.31, mx + 0.0015, 0.97, [0.15, 0.13, 0.1, 1]);
    }
    b += w;
  }
  day.save("facade_shop");
  night.save("lit_shop");
}

// 박석: 크기가 조금씩 다른 화강석 판을 켜로 깐 바닥. 타일 하나 = 4 m × 4 m (Shared.Facades와 같아야 한다).
// 줄눈은 굵고 어두우면 벽돌처럼 보여 돌과 비슷한 색으로 가늘게 둔다
{
  const img = new Img(SIZE, SIZE);
  img.rect(0, 0, 1, 1, (u, v) => {
    const k = 0.46 + fine(u, v) * 0.12;
    return [k, k * 0.98, k * 0.94, 1];
  });
  const ROWS = 7;
  for (let r = 0; r < ROWS; r++) {
    const y0 = r / ROWS, y1 = (r + 1) / ROWS;
    const start = rnd() * 0.1;
    let x = start;
    while (x < start + 1 - 0.001) {
      const w = Math.min(0.13 + rnd() * 0.17, start + 1 - x);
      const tone = 0.6 + rnd() * 0.13;
      const warm = rnd() * 0.025;
      const j = () => 0.0012 + rnd() * 0.0016;
      const ax = x + j(), bx = x + w - j(), ay = y0 + j(), by = y1 - j();
      img.rect(ax, ay, bx, by, (u, v) => {
        const g = fine(u, v);
        const speck = n3((u * 768) % 256, (v * 768) % 256);
        const k = tone * (0.88 + g * 0.22) + (speck > 0.82 ? 0.05 : speck < 0.18 ? -0.05 : 0);
        return [k + warm, k + warm * 0.5, k - warm * 0.5, 1];
      });
      x += w;
    }
  }
  img.save("bakseok");
}

// 판문 철엽: 녹슨 철판과 광두정. 타일 = 판 4장 × 12줄 (Shared.Yukchuk gate.tile).
// 판 크기·광두정 자리는 S4 064 치수: 판 486.4 × 162.5 mm, 아랫이음에서 46 mm 위에 6개, 116 mm 위에 3개, 지름 33 mm.
// 색은 사진(S34)을 눈으로만 보고 정했다: 어두운 갈회색 바탕에 판마다 다른 녹.
{
  const COLS = 4, ROWS = 12;
  const tone = Array.from({ length: COLS * ROWS }, () => [rnd(), rnd(), rnd()]);
  const STUDS = [[60, 46], [135, 46], [211, 46], [286, 46], [361, 46], [436, 46], [135, 116], [286, 116], [436, 116]];
  const R = 16.5, PW = 486.4, PH = 162.5;
  const img = new Img(SIZE, SIZE);
  const L = [-0.35, 0.62, 0.7]; // 왼쪽 위 빛
  // 높이: 이음에서 내려앉고 광두정에서 솟는다. mm 좌표
  const height = (mx, my) => {
    const dx = Math.min(mx, PW - mx), dy = Math.min(my, PH - my);
    const edge = Math.min(dx, dy);
    let h = Math.min(edge / 5, 1) * 2;
    for (const s of STUDS) {
      const d2 = (mx - s[0]) ** 2 + (my - s[1]) ** 2;
      if (d2 < R * R) h = Math.max(h, 2 + Math.sqrt(R * R - d2) * 0.9);
    }
    return h;
  };
  for (let y = 0; y < SIZE; y++) {
    for (let x = 0; x < SIZE; x++) {
      const u = x / SIZE, v = y / SIZE;
      const col = Math.floor(u * COLS), row = Math.floor(v * ROWS);
      const mx = (u * COLS - col) * PW, my = (1 - (v * ROWS - row)) * PH; // my = 판 아래에서 위로
      const e = 1.2;
      const nx = (height(mx - e, my) - height(mx + e, my)) / (2 * e);
      const ny = (height(mx, my - e) - height(mx, my + e)) / (2 * e);
      const nz = 1;
      const len = Math.hypot(nx, ny, nz);
      const lit = clamp((nx * L[0] + ny * L[1] + nz * L[2]) / len);
      const [t0, t1, t2] = tone[row * COLS + col];
      const rust = clamp(fine(u, v) * 1.3 - 0.4 + t0 * 0.08); // 판마다 차이는 작게: 크면 벽돌 벽처럼 보인다
      const pit = n3((u * 512) % 256, (v * 512) % 256);
      // 어두운 갈회색 ↔ 녹 갈색, 판마다 명도가 다르다
      const a = [0.27, 0.25, 0.24], b = [0.33, 0.23, 0.18];
      const base = 0.95 + t1 * 0.08;
      const c = [mix(a[0], b[0], rust), mix(a[1], b[1], rust), mix(a[2], b[2], rust)].map((q) => q * base * (0.92 + pit * 0.16));
      const seam = Math.min(Math.min(mx, PW - mx), Math.min(my, PH - my));
      const dark = seam < 1.6 ? 0.45 : 1;
      const shade = (0.45 + lit * 0.95) * dark * (0.95 + t2 * 0.1);
      const i = (y * SIZE + x) * 4;
      img.d[i] = c[0] * shade * 1.15;
      img.d[i + 1] = c[1] * shade * 1.15;
      img.d[i + 2] = c[2] * shade * 1.15;
      img.d[i + 3] = 1;
    }
  }
  img.save("cheoryeop");
}
