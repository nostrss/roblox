"""입면도 DXF의 선분을 닫힌 면(돌)으로 묶어 Luau 데이터로 출력한다.

필요: python 패키지 ezdxf, shapely. DWG는 먼저 LibreDWG `dwg2dxf`로 DXF로 바꾼다.
usage: python tools/dxf_stones.py <file.dxf> <layer> <x0> <y0> <x1> <y1> <centerX> [minArea=0.15] [minFill=0.6] [snap=0]
  x0..y1   : 석축 면을 감싸는 도면 좌표(mm) 범위
  centerX  : 월드 x=0 이 될 도면 x(주 건물 중심축)
출력 행: { x0, y0, x1, y1 } (m). x는 centerX 기준, y는 돌 꼭대기 줄 윗면 = 0 (아래로 음수).
ponytail: 돌을 감싸는 사각형만 낸다. 불규칙 윤곽이 필요하면 폴리곤 좌표 출력으로 확장.
"""
import sys
from ezdxf import recover, path
from shapely.geometry import LineString, box
from shapely.ops import unary_union, polygonize

f, layer = sys.argv[1], sys.argv[2]
x0, y0, x1, y1, cx = map(float, sys.argv[3:8])
min_area = float(sys.argv[8]) if len(sys.argv) > 8 else 0.15
min_fill = float(sys.argv[9]) if len(sys.argv) > 9 else 0.6
snap = float(sys.argv[10]) if len(sys.argv) > 10 else 0  # mm. 덜 닿은 선끝을 이 격자로 맞춘다

doc, _ = recover.readfile(f)
clip = box(x0, y0, x1, y1)
lines = []
for e in doc.modelspace().query(f'LINE ARC LWPOLYLINE POLYLINE SPLINE ELLIPSE[layer=="{layer}"]'):
    try:
        pts = [(v.x, v.y) for v in path.make_path(e).flattening(20)]
        if snap:
            pts = [(round(x / snap) * snap, round(y / snap) * snap) for x, y in pts]
    except Exception:
        continue
    if len(pts) > 1 and (ls := LineString(pts)).intersects(clip):
        lines.append(ls)

stones = []
for p in polygonize(unary_union(lines)):
    a, b, c, d = p.bounds
    if clip.contains(p.centroid) and p.area / 1e6 >= min_area and p.area / ((c - a) * (d - b)) >= min_fill:
        stones.append((a, b, c, d))
top = max(s[3] for s in stones if s[2] - s[0] >= 500)  # 작은 조각이 기준을 끌어올리지 않게 폭 0.5m 이상 돌만
print(f"-- {len(stones)} stones from {f.split('/')[-1]} (layer {layer})", file=sys.stderr)
for a, b, c, d in sorted(stones, key=lambda s: (-s[3], s[0])):
    print(f"\t\t{{ {(a-cx)/1000:.3f}, {(b-top)/1000:.3f}, {(c-cx)/1000:.3f}, {(d-top)/1000:.3f} }},")
