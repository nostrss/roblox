// 판문 철엽 타일: 철판 한 장(이음선)과 광두정을 코드로 그린 PNG. 사진 픽셀은 쓰지 않는다. 실행: swift tools/cheoryeop_png.swift   (저장소 루트에서)
// 치수 근거 S4 064 성문 투상도를 면으로 펴서 잰 값(Shared.Yukchuk gate.tile): 판 486.4 × 162.5 mm, 판마다 광두정 두 줄.
//   아랫이음에서 46 mm 위 줄 = 6개 (왼쪽 이음에서 60, 135, 211, 286, 361, 436 mm), 116 mm 위 줄 = 3개 (135, 286, 436 mm), 머리 지름 약 33 mm.
// 출력은 색이 없다: 검정·흰색 반투명 음영만 그리고 색은 Cheoryeop 파트가 정한다 (Palette). 위 = 판 위쪽. 판 이음은 타일 네 변에 걸쳐 반복이 이어진다.
import CoreGraphics
import Foundation
import ImageIO

let (W, H) = (384, 128)
let pxPerMm = Double(W) / 486.4
let R = 16.5 * pxPerMm
var heads: [(Double, Double)] = []
for u in [60.0, 135, 211, 286, 361, 436] { heads.append((u, 162.5 - 46)) }
for u in [135.0, 286, 436] { heads.append((u, 162.5 - 116)) }
let centers = heads.map { ($0.0 * pxPerMm, $0.1 * Double(H) / 162.5) }
let light = (x: -0.35, y: -0.62, z: 0.7) // 왼쪽 위에서 오는 빛 (이미지 y는 아래로)

func smooth(_ a: Double, _ b: Double, _ x: Double) -> Double {
	let k = min(max((x - a) / (b - a), 0), 1)
	return k * k * (3 - 2 * k)
}

var px = [UInt8](repeating: 0, count: W * H * 4)
for y in 0..<H {
	for x in 0..<W {
		let (fx, fy) = (Double(x) + 0.5, Double(y) + 0.5)
		var s = 0.0 // 얼룩은 넣지 않는다: 타일 주기와 맞물려 멀리서 대각선 무늬로 이어졌다 (Play 확인)
		// 이음: 판 경계의 어두운 틈 + 아래·오른쪽으로 비친 밝은 턱
		let (dx, dy) = (min(fx, Double(W) - fx), min(fy, Double(H) - fy))
		s -= 0.6 * exp(-pow(min(dx, dy) / 1.3, 2))
		if fy < 5 { s += 0.1 * (1 - fy / 5) }
		for c in centers { // 광두정 그림자 (오른쪽 아래)
			let r = hypot(fx - c.0 - 1.5, fy - c.1 - 2.5)
			s -= 0.35 * (1 - smooth(R * 0.9, R * 1.35, r))
		}
		for c in centers { // 둥근 머리
			let (ux, uy) = ((fx - c.0) / R, (fy - c.1) / R)
			let r = hypot(ux, uy)
			if r < 1.05 {
				let z = sqrt(max(1 - r * r, 0))
				let lit = ux * light.x + uy * light.y + z * light.z
				let head = -0.62 + 0.62 * max(lit, 0) + 0.3 * pow(max(lit, 0), 12)
				let t = min(max((1.05 - r) * R, 0), 1)
				s = s * (1 - t) + head * t
			}
		}
		let i = (y * W + x) * 4
		let alpha = min(abs(s), 0.9)
		let v = s > 0 ? alpha * 255 : 0 // 미리 곱한 값
		px[i] = UInt8(v); px[i + 1] = UInt8(v); px[i + 2] = UInt8(v); px[i + 3] = UInt8(alpha * 255)
	}
}
let cg = CGContext(data: &px, width: W, height: H, bitsPerComponent: 8, bytesPerRow: W * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
let out = URL(fileURLWithPath: "landmarks/sungnyemun/textures/cheoryeop_tile.png") as CFURL
let dest = CGImageDestinationCreateWithURL(out, "public.png" as CFString, 1, nil)!
CGImageDestinationAddImage(dest, cg.makeImage()!, nil)
CGImageDestinationFinalize(dest)
