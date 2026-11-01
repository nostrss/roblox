# 숭례문

서울 숭례문과 숭례문 광장을 실측 비율로 재현한 Place.

- **재현 기준 시점:** 2013 복구 이후 모습 ([ADR 0001](../../docs/adr/0001-sungnyemun-post-restoration.md))
- **건물 자리:** 정면 방위각 222° (정남에서 서쪽으로 약 42°, [ADR 0004](../../docs/adr/0004-build-on-axis-then-rotate-to-true-north.md))

## 들어간 것

| PR | 내용 |
|---|---|
| #1 | 도면 실측 기반 석축·공포·축부 |
| #2 | 처마·지붕(기와골·막새·마루·잡상)·현판, 건물 자리 |
| #3 | 재질 — 부재 칠(가칠)을 한 표(Palette)로 |
| #4 | 숭례문 광장(광장 옹벽·보도·도로·횡단보도)과 복원 성곽 |
| #5 | 육축 — 네 면 무사석, 홍예, 통로, 판문, 여장, 석누조, 계단 |
| #6 | 문루 장마루·문루 계단·난간·상층 벽 |
| #7 | 주변 건물 실루엣, 보행 경계, 스폰 위치 |
| #8 | 시간대(서울 시각 기준, 노을·밤 선택)와 야간 조명 |
| #9 | 환경음(바람·차 소리·새·풀벌레)과 홍예 울림 구역 |
| #10 | 도로 차량(세종대로·소월로)과 차선 |

## 실행

pm2로 Rojo 서버를 띄운다 (포트 34872).

```sh
cd ~/github
pm2 start ecosystem.config.js --only roblox-sungnyemun
```

Studio에서 숭례문 Place를 열고 **Plugins → Rojo → Connect**.

## 자료

쓴 자료와 라이선스는 [SOURCES.md](SOURCES.md). 치수는 `src/shared/Dimensions.luau`에 출처 ID와 함께 적는다.

## 남은 작업

[남은 작업](https://claude.ai/artifact/VpXgtHEivdnSdrNMDb2AAN)
