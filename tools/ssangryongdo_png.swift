// 숭례문 홍예 반자 쌍룡도 사진 → 펴진 PNG (SOURCES.md S27, 공공누리 제1유형, ccimId 6309895). 빛 번짐을 뺀다. 사진에 없던 자리는 먹으로 둔다.
// 실행: swift tools/ssangryongdo_png.swift   (저장소 루트에서. 원본은 refs/ssangryong/, git 제외)
// 출력 위 = 남쪽 끝(성문), 아래 = 북쪽 끝, 왼쪽 = 서. 폭 5.52 × 길이 7.857 (Yukchuk.passage).
import CoreImage
import Foundation

let H = 2670.0 // 원본 세로 픽셀. 아래 좌표는 모두 원본 픽셀(위 = 0)
// 천장·벽 모서리 직선 x = a y + b (북쪽 벽 가까운 구간 맞춤), 두 선의 교점이 남북 소실점
let (La, Lb, Ra, Rb) = (0.6946563, 677.711, -0.583518, 3268.985)
let Vy = (Rb - Lb) / (La - Ra)
let slope = -0.0025 // 이음선 기울기 (사진 롤)
let c0 = 1078 - slope * 1436 // 북쪽 끝 선: y = slope x + c0
// 이음선 16개를 세어 맞춘 깊이 계수 (여의주 가로세로 비 1.00으로 교차 확인): 1/(Vy - y) = 1/(Vy - yN) - k q, k = 북쪽 끝에서 센 널 장수
let q = 3.35e-5
let plankCount = 19.0

func onEdge(_ a: Double, _ b: Double, _ c: Double) -> CGPoint {
	let y = (slope * b + c) / (1 - slope * a)
	return CGPoint(x: a * y + b, y: H - y) // CI 좌표는 아래가 0
}
let nl = onEdge(La, Lb, c0), nr = onEdge(Ra, Rb, c0)
let yN = H - (nl.y + nr.y) / 2
let yS = Vy - 1 / (1 / (Vy - yN) - plankCount * q)
let Vx = La * Vy + Lb
let cS = yS - slope * Vx
let sl = onEdge(La, Lb, cS), sr = onEdge(Ra, Rb, cS)

// 천장이 실제로 보이는 다각형: 북쪽 끝 → 서쪽 벽 → 판문 → 홍예석 → 사진 위 끝 → 동쪽. 바깥은 먹으로 메운다
let visible: [(Double, Double)] = [
	(1426.6, 1078), (1276, 846), (1295, 596), (922, 266), (952, 238), (1002, 197), (1052, 161), (1150, 127), (1250, 91),
	(1290, 71), (1370, 51), (1450, 25), (1500, 11), (1540, 3), (1600, 1), (2300, 1), (2400, 12), (2480, 45), (2560, 58),
	(2645, 98), (2710, 138), (2790, 178), (2870, 223), (2960, 288), (3004, 322), (2776, 600), (2768, 851), (2641.7, 1075),
]
let meok = CIColor(red: 0.075, green: 0.07, blue: 0.075) // 사진의 먹 바탕 판독값

let photo = CIImage(contentsOf: URL(fileURLWithPath: "landmarks/sungnyemun/refs/ssangryong/khs_6309895_kogl1.jpg"))!
let out = URL(fileURLWithPath: "landmarks/sungnyemun/textures/ssangryongdo.png")

let cg = CGContext(data: nil, width: 4000, height: Int(H), bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)!
cg.setFillColor(gray: 1, alpha: 1)
cg.addLines(between: visible.map { CGPoint(x: $0.0, y: H - $0.1) })
cg.closePath()
cg.fillPath()
let mask = CIImage(cgImage: cg.makeImage()!).clampedToExtent().applyingGaussianBlur(sigma: 2)
let canvas = CGRect(x: -1500, y: -500, width: 7000, height: 4500) // 남쪽 끝 모서리가 사진 밖이라 넉넉히
let bg = CIImage(color: meok).cropped(to: canvas)
let filled = photo.clampedToExtent().cropped(to: canvas).applyingFilter("CIBlendWithMask", parameters: ["inputBackgroundImage": bg, "inputMaskImage": mask])

let (W, Hh) = (720, 1024)
let ctx = CIContext(options: [.workingColorSpace: NSNull()])
func flatten(_ image: CIImage) -> [Float] { // 펴서 720×1024 RGBA(0~1), 위 = 남쪽
	let flat = image.applyingFilter("CIPerspectiveCorrection", parameters: [
		"inputTopLeft": CIVector(cgPoint: sl), "inputTopRight": CIVector(cgPoint: sr),
		"inputBottomLeft": CIVector(cgPoint: nl), "inputBottomRight": CIVector(cgPoint: nr),
	])
	let e = flat.extent
	let scaled = flat.transformed(by: CGAffineTransform(translationX: -e.minX, y: -e.minY))
		.applyingFilter("CILanczosScaleTransform", parameters: ["inputScale": Double(Hh) / e.height, "inputAspectRatio": (Double(W) / e.width) / (Double(Hh) / e.height)])
		.cropped(to: CGRect(x: 0, y: 0, width: W, height: Hh))
	var px = [UInt8](repeating: 0, count: W * Hh * 4)
	ctx.render(scaled, toBitmap: &px, rowBytes: W * 4, bounds: CGRect(x: 0, y: 0, width: W, height: Hh), format: .RGBA8, colorSpace: nil)
	return px.map { Float($0) / 255 }
}
var img = flatten(filled)
let seen = flatten(mask.cropped(to: canvas)) // 사진에 실제로 보인 정도 (R 채널)
let bgColor: [Float] = [18 / 255, 17 / 255, 16 / 255] // 먹 바탕 판독값

func boxBlur(_ a: [Float], _ r: Int) -> [Float] { // 상자 흐림 3번 ≈ 가우스
	var cur = a
	for _ in 0..<3 {
		for (w, h, dx, dy) in [(W, Hh, 1, W), (Hh, W, W, 1)] { // 가로, 세로
			var next = cur
			for line in 0..<h {
				var sum: Float = 0
				for i in -r...r { sum += cur[line * dy + max(0, min(w - 1, i)) * dx] }
				for i in 0..<w {
					next[line * dy + i * dx] = sum / Float(2 * r + 1)
					sum += cur[line * dy + min(w - 1, i + r + 1) * dx] - cur[line * dy + max(0, i - r) * dx]
				}
			}
			cur = next
		}
	}
	return cur
}

// 빛 번짐: 번들거림은 칠 위에 더해진 빛이다. 바탕(어둡고 색 없는 곳)으로 번들거림 양을 재서 전체에서 뺀다. 밝은 칠은 덜 뺀다
var weight = [Float](repeating: 0, count: W * Hh)
for i in 0..<W * Hh {
	let (r, g, b) = (img[i * 4], img[i * 4 + 1], img[i * 4 + 2])
	let mx = max(r, g, b), mn = min(r, g, b)
	weight[i] = seen[i * 4] > 0.95 && mx < 0.45 && mx > 0 && (mx - mn) / mx < 0.22 ? 1 : 0
}
let wBlur = boxBlur(weight, 25)
let before = img
for c in 0..<3 {
	let est = boxBlur((0..<W * Hh).map { before[$0 * 4 + c] * weight[$0] }, 25)
	for i in 0..<W * Hh where wBlur[i] > 0.003 {
		let glare = max(0, est[i] / wBlur[i] - bgColor[c])
		img[i * 4 + c] = max(before[i * 4 + c] - glare * (weight[i] > 0 ? 1 : 0.3), before[i * 4 + c] * 0.5) // 칠은 조금만 뺀다 (탁해지지 않게)
	}
}

let seenSoft = boxBlur((0..<W * Hh).map { seen[$0 * 4] }, 2)
for i in 0..<W * Hh { // 사진에 없던 곳 = 먹
	let t = seenSoft[i]
	for c in 0..<3 { img[i * 4 + c] = img[i * 4 + c] * t + bgColor[c] * (1 - t) }
}
var bytes = img.enumerated().map { $0.offset % 4 == 3 ? UInt8(255) : UInt8(max(0, min(255, $0.element * 255))) }
let outImage = CIImage(bitmapData: Data(bytes: &bytes, count: bytes.count), bytesPerRow: W * 4, size: CGSize(width: W, height: Hh), format: .RGBA8, colorSpace: nil)
try! CIContext(options: [.workingColorSpace: NSNull()]).writePNGRepresentation(of: outImage, to: out, format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!)
print("written", out.path)
