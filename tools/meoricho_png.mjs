// 숭례문 머리초 문양 SVG → PNG (작업 표 25-②, 1단계 하층 바깥 Part).
// 그림은 시안 「숭례문 단청 머리초 시안」(https://claude.ai/artifact/2WKGSL8nynTnYkoioX3jcX)의 그리기 코드를 그대로 옮겼다.
// S7 수리보고서 pp.451~457 본문 서술(구성·색)을 따라 다시 그린 것이고 도판 픽셀은 쓰지 않는다 (SOURCES.md S7).
// 뇌록(가칠 바탕) 자리는 투명으로 굽는다: 같은 그림을 뇌록 = 검정, 나머지 = 흰색으로 한 번 더 그려 luminance mask로 쓴다.
// Decal은 뒤집을 수 없어서 한쪽 끝(_a: 기둥이 왼쪽)과 거울상(_b: 기둥이 오른쪽)을 따로 굽는다.
// 실행: node tools/meoricho_png.mjs   (Google Chrome 헤드리스로 PNG를 찍는다)
import { writeFileSync, mkdirSync } from "node:fs";
import { execFileSync } from "node:child_process";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const OUT = join(dirname(fileURLToPath(import.meta.url)), "../landmarks/sungnyemun/textures/meoricho");
const CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";
const PX = 512; // 가로 픽셀 (사용자 확정: 중간 상세도, 512 px)

// 색: [키, 도판 판독값, 게임 값(null이면 도판 값을 뇌록과 같은 비율로 낮춤 — 추정)]. 시안 COLORS와 같다
const COLORS = [
  ["noerok", "#258A79", "#34645A"], ["nok", "#55B685"], ["nokD", "#389862"], ["noksil", "#ADD3BC"],
  ["hayeop", "#479098"], ["samcheong", "#1F84B8"], ["gunchung", "#233A8C"], ["yuksaek", "#F7CBC2"],
  ["yeonhwa", "#C37B59"], ["juhong", "#E83F32"], ["meok", "#0D0C0E", "#141315"], ["baek", "#F4F1EA", "#E6E1D3"],
];
function hexToHsl(h) {
  const r = parseInt(h.slice(1, 3), 16) / 255, g = parseInt(h.slice(3, 5), 16) / 255, b = parseInt(h.slice(5, 7), 16) / 255;
  const mx = Math.max(r, g, b), mn = Math.min(r, g, b), l = (mx + mn) / 2, d = mx - mn;
  let hh = 0, s = 0;
  if (d) {
    s = d / (1 - Math.abs(2 * l - 1));
    hh = mx === r ? ((g - b) / d) % 6 : mx === g ? (b - r) / d + 2 : (r - g) / d + 4;
  }
  return [hh * 60, s, l];
}
function hslToHex(hh, s, l) {
  const c = (1 - Math.abs(2 * l - 1)) * s, x = c * (1 - Math.abs(((hh / 60) % 2) - 1)), m = l - c / 2;
  const [r, g, b] = hh < 60 ? [c, x, 0] : hh < 120 ? [x, c, 0] : hh < 180 ? [0, c, x] : hh < 240 ? [0, x, c] : hh < 300 ? [x, 0, c] : [c, 0, x];
  return "#" + [r, g, b].map(v => Math.round((v + m) * 255).toString(16).padStart(2, "0")).join("").toUpperCase();
}
const GAME = Object.fromEntries(COLORS.map(([k, plate, game]) => {
  const [hh, s, l] = hexToHsl(plate);
  return [k, game || hslToHex((hh + 360) % 360, s * 0.55, l * 0.87)];
}));
const MASK = Object.fromEntries(COLORS.map(([k]) => [k, k === "noerok" ? "#000" : "#fff"]));
let pal = GAME; // var() 대신 지금 팔레트의 값을 바로 넣는다

// ---- 아래는 시안 그리기 코드 (fill="var(--x)" → 팔레트 값) ----
const f = n => +n.toFixed(1);
const col = k => pal[k];
function lobed(r, n, depth, rot) {
  const ri = r * (1 - depth), step = 2 * Math.PI / n;
  const c = 2 * ri * Math.sin(step / 2), h = r - ri * Math.cos(step / 2);
  const rr = (c * c / 4 + h * h) / (2 * h), large = h > rr ? 1 : 0;
  let d = "";
  for (let k = 0; k <= n; k++) {
    const a = (rot || 0) + k * step, x = ri * Math.cos(a), y = ri * Math.sin(a);
    d += k === 0 ? `M${f(x)} ${f(y)}` : `A${f(rr)} ${f(rr)} 0 ${large} 1 ${f(x)} ${f(y)}`;
  }
  return d + "Z";
}
const P = (d, fill, extra) => `<path d="${d}" fill="${col(fill)}"${extra || ""}/>`;
const C = (x, y, r, fill) => `<circle cx="${f(x)}" cy="${f(y)}" r="${f(r)}" fill="${col(fill)}"/>`;
function petals(r, n, w, fill, inner, rot) {
  let s = "";
  for (let k = 0; k < n; k++) {
    const a = (rot || 0) + k * 360 / n;
    s += `<g transform="rotate(${f(a)})"><ellipse cx="${f(r / 2)}" cy="0" rx="${f(r / 2)}" ry="${f(w)}" fill="${col(fill)}"/>`;
    if (inner) s += `<ellipse cx="${f(r * 0.45)}" cy="0" rx="${f(r * 0.3)}" ry="${f(w * 0.5)}" fill="${col(inner)}"/>`;
    s += "</g>";
  }
  return s;
}
function eyes(r, n, size, rot, outer, inner) {
  let s = "";
  for (let k = 0; k < n; k++) {
    const a = (rot || 0) + k * 2 * Math.PI / n, x = r * Math.cos(a), y = r * Math.sin(a);
    s += C(x, y, size, outer) + C(x + size * 0.15, y - size * 0.1, size * 0.55, inner) + C(x + size * 0.25, y - size * 0.2, size * 0.25, outer);
  }
  return s;
}
// 원바탕 (S7 p.452)
function wonbatang(R, detail) {
  let s = P(lobed(R, 10, 0.1), "gunchung") + P(lobed(R * 0.91, 10, 0.11), "samcheong")
    + P(lobed(R * 0.83, 10, 0.12), "noksil") + P(lobed(R * 0.8, 10, 0.12), "nok");
  if (detail) {
    s += eyes(R * 0.67, 10, R * 0.085, Math.PI / 10, "nokD", "noksil");
    for (let k = 0; k < 10; k++) s += `<g transform="rotate(${k * 36})"><ellipse cx="${f(R * 0.735)}" cy="0" rx="${f(R * 0.05)}" ry="${f(R * 0.025)}" fill="${col("samcheong")}"/></g>`;
  }
  s += P(lobed(R * 0.58, 8, 0.16, Math.PI / 8), "samcheong", ` stroke="${col("noksil")}" stroke-width="${f(R * 0.022)}"`)
    + P(lobed(R * 0.48, 8, 0.16, Math.PI / 8), "noerok")
    + petals(R * 0.44, 8, R * 0.11, "nok", "hayeop", 22.5)
    + C(0, 0, R * 0.14, "hayeop") + C(0, 0, R * 0.08, "nok");
  if (detail) for (let k = 0; k < 8; k++) { const a = k * Math.PI / 4; s += C(R * 0.11 * Math.cos(a), R * 0.11 * Math.sin(a), R * 0.02, "noksil"); }
  return s;
}
// 반바탕 (S7 p.453)
function banbatang(R, detail) {
  let s = P(lobed(R, 10, 0.1), "noksil") + P(lobed(R * 0.95, 10, 0.11), "samcheong");
  if (detail) s += eyes(R * 0.78, 10, R * 0.09, 0, "gunchung", "noksil");
  return s + P(lobed(R * 0.62, 8, 0.15), "nok") + P(lobed(R * 0.5, 8, 0.15), "noerok")
    + petals(R * 0.46, 8, R * 0.11, "nok", "hayeop", 22.5) + C(0, 0, R * 0.13, "hayeop");
}
// 방석초 (S7 p.453). 주화는 본문대로 녹 (p.453)
function juhwa(r) {
  let s = "";
  for (let k = 0; k < 6; k++) { const a = k * Math.PI / 3; s += C(r * 0.5 * Math.cos(a), r * 0.5 * Math.sin(a), r * 0.42, "nok"); }
  return s + C(0, 0, r * 0.45, "nokD") + C(0, 0, r * 0.22, "hayeop");
}
function bangseok(R, kind, detail) {
  let s;
  if (kind === 1) {
    s = P(lobed(R, 10, 0.1), "noksil") + P(lobed(R * 0.95, 10, 0.1), "samcheong") + P(lobed(R * 0.82, 10, 0.12), "nok");
    if (detail) s += eyes(R * 0.66, 10, R * 0.085, Math.PI / 10, "nokD", "noksil");
  } else {
    s = P(lobed(R, 10, 0.1), "samcheong") + P(lobed(R * 0.88, 10, 0.1), "noksil") + P(lobed(R * 0.84, 10, 0.1), "hayeop")
      + P(lobed(R * 0.72, 10, 0.12), "samcheong", ` stroke="${col("noksil")}" stroke-width="${f(R * 0.03)}"`);
    if (detail) s += eyes(R * 0.6, 10, R * 0.075, Math.PI / 10, "gunchung", "noksil");
  }
  return s + P(lobed(R * 0.5, 8, 0.12), "noerok") + juhwa(R * 0.4);
}
// 뒷목 결련직휘
function dwitmok(H, w) {
  let s = `<rect x="14" y="0" width="${w}" height="${H}" fill="${col("nok")}"/>`;
  const r = w * 0.36, cx = 14 + w / 2;
  for (let y = -r; y < H + r; y += r * 1.5) s += `<circle cx="${f(cx)}" cy="${f(y)}" r="${f(r)}" fill="none" stroke="${col("samcheong")}" stroke-width="${f(w * 0.14)}"/><circle cx="${f(cx)}" cy="${f(y)}" r="${f(r)}" fill="none" stroke="${col("noksil")}" stroke-width="${f(w * 0.03)}"/>`;
  const x = 14 + w;
  return `<rect x="0" y="0" width="14" height="${H}" fill="${col("meok")}"/>` + s
    + `<rect x="${x}" y="0" width="12" height="${H}" fill="${col("hayeop")}"/><rect x="${x + 12}" y="0" width="6" height="${H}" fill="${col("noksil")}"/><rect x="${x + 18}" y="0" width="12" height="${H}" fill="${col("nok")}"/>`;
}
function bracket(x, H, inset, slope, waves) {
  const y1 = inset + slope, y2 = H - inset - slope, seg = (y2 - y1) / waves;
  let d = `M${f(x + slope * 0.75)} ${f(inset - 40)} L${f(x + slope * 0.75)} ${f(inset)} L${f(x)} ${f(y1)}`;
  for (let k = 1; k <= waves; k++) d += ` A${f(seg * 0.62)} ${f(seg * 0.62)} 0 0 1 ${f(x)} ${f(y1 + seg * k)}`;
  return d + ` L${f(x + slope * 0.75)} ${f(H - inset)} L${f(x + slope * 0.75)} ${f(H + 40)}`;
}
const NULHWI = ["hayeop", "noksil", "samcheong", "gunchung", "noksil", "samcheong", "noksil"];
const LINES = [["samcheong", 16], ["meok", 7], ["baek", 2.5]]; // 계풍 경계 색긋기
// 머리초 한쪽 끝. 원점 = 부재 끝 윗모서리, 오른쪽이 계풍. 단위 mm
function head(type, H, L, uid) {
  const isB = type === "byeong";
  const xb = L - 46, inset = isB ? 16 : 12, slope = isB ? 54 : 36, bw = isB ? 17 : 13;
  let s = `<clipPath id="cl${uid}"><rect x="0" y="0" width="${L}" height="${H}"/></clipPath><g clip-path="url(#cl${uid})">`;
  s += `<rect x="0" y="0" width="${L}" height="${H}" fill="${col("noerok")}"/>`;
  if (isB) {
    s += dwitmok(H, 120);
    s += `<g transform="translate(420 ${H / 2})">${wonbatang(222, true)}</g>`;
    for (const y of [0, H]) s += `<g transform="translate(770 ${y})">${banbatang(176, true)}</g>`;
    s += `<rect x="752" y="${H / 2 - 22}" width="36" height="44" rx="10" fill="${col("nok")}" stroke="${col("samcheong")}" stroke-width="7"/>`;
  } else {
    s += dwitmok(H, 70);
    s += `<g transform="translate(262 ${H / 2}) scale(1.22 1)">${bangseok(124, 1, true)}</g>`;
    s += `<g transform="translate(560 ${H / 2}) scale(1.22 1)">${bangseok(124, 2, true)}</g>`;
    for (const y of [0, H]) s += `<g transform="translate(800 ${y}) scale(1.1 1)">${bangseok(104, 1, false)}</g>`;
  }
  const n = isB ? 7 : 6;
  for (let i = n - 1; i >= 0; i--) s += `<path d="${bracket(xb - (i + 1) * bw, H, inset, slope, 3)}" fill="none" stroke="${col(NULHWI[i])}" stroke-width="${bw + 0.5}"/>`;
  s += `<path d="${bracket(xb, H, inset, slope, 3)} L${L + 50} ${H + 40} L${L + 50} -40 Z" fill="${col("noerok")}"/>`;
  s += LINES.map(([c, w]) => `<path d="${bracket(xb, H, inset, slope, 3)}" fill="none" stroke="${col(c)}" stroke-width="${w}"/>`).join("");
  // 계풍 위아래 색긋기를 머리초 끝까지 (계풍 Part의 줄과 이어지게)
  s += gyepungLines(xb + slope * 0.75, L, H, inset);
  return s + "</g>";
}
function gyepungLines(x0, x1, H, inset) {
  return LINES.map(([c, w]) =>
    `<line x1="${x0}" x2="${x1}" y1="${inset}" y2="${inset}" stroke="${col(c)}" stroke-width="${w}"/><line x1="${x0}" x2="${x1}" y1="${H - inset}" y2="${H - inset}" stroke="${col(c)}" stroke-width="${w}"/>`).join("");
}
// ---- 시안 코드 끝 ----

// 색 그림 + 같은 그림의 마스크(뇌록 = 투명). body(uid)는 팔레트를 바꿔 두 번 부른다
function svgFile(W, H, px, body) {
  const py = Math.round(px * H / W);
  pal = MASK; const mask = body("m");
  pal = GAME; const color = body("c");
  return { py, text: `<svg xmlns="http://www.w3.org/2000/svg" width="${px}" height="${py}" viewBox="0 0 ${W} ${H}" preserveAspectRatio="none">`
    + `<mask id="noerok" maskUnits="userSpaceOnUse" x="0" y="0" width="${W}" height="${H}">${mask}</mask><g mask="url(#noerok)">${color}</g></svg>\n` };
}
const flip = (L, s) => `<g transform="translate(${L} 0) scale(-1 1)">${s}</g>`;

const L = 1100; // 머리초 길이 mm (시안 추정, Shared.Meoricho)
const jobs = [];
for (const [type, H] of [["byeong", 477], ["juhwa", 277]]) {
  jobs.push([`${type}_a`, svgFile(L, H, PX, u => head(type, H, L, u + "a"))]);
  jobs.push([`${type}_b`, svgFile(L, H, PX, u => flip(L, head(type, H, L, u + "b")))]);
  // 계풍 색긋기 줄 (길이 방향으로 늘여도 같은 그림). 가로 8 px, 세로는 머리초와 같은 해상도
  const inset = type === "byeong" ? 16 : 12;
  jobs.push([`${type}_gyepung`, svgFile(8 * L / PX, H, 8, () => gyepungLines(0, 8 * L / PX, H, inset))]);
}

mkdirSync(OUT, { recursive: true });
for (const [name, { py, text }] of jobs) {
  const svg = join(OUT, `${name}.svg`);
  writeFileSync(svg, text);
  const w = name.endsWith("_gyepung") ? 8 : PX;
  execFileSync(CHROME, ["--headless=new", "--disable-gpu", "--hide-scrollbars", "--force-device-scale-factor=1",
    "--default-background-color=00000000", `--window-size=${w},${py}`, `--screenshot=${join(OUT, `${name}.png`)}`, "file://" + svg], { stdio: "ignore" });
  console.log(`${name}.png ${w}x${py}`);
}
