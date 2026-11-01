# 랜드마크 시리즈

사찰·건축물·랜드마크를 실측 비율로 로블록스에 재현해, 답사하듯 걸어보는 Place의 묶음.

- 기획: [기획 메모](https://claude.ai/artifact/NbrSpp5L8zZ1pjh85ezd4R)
- 규칙: [CLAUDE.md](../CLAUDE.md), 용어: [CONTEXT.md](../CONTEXT.md)

하나의 Experience 안에 랜드마크마다 Place 하나를 둔다. 답사 노트·배지는 Universe 단위 DataStore로 모든 Place가 공유한다.

## 공통 규칙

자세한 건 [CLAUDE.md](../CLAUDE.md)의 "공간 규칙".

- **단위:** 1스터드 = 0.34m (R15 캐릭터 약 5스터드 = 170cm). 데이터는 실측값(m)으로 적고 core의 상수로 환산한다.
- **원점·방위:** 원점은 주 건물 중심의 지면(Y = 0). 북쪽 = -Z, 동쪽 = +X.
- **건물 자리:** 건물은 자기 축(정면 = +Z)으로 짓고, Place마다 정면 방위각 하나로 통째로 돌린다 ([ADR 0004](../docs/adr/0004-build-on-axis-then-rotate-to-true-north.md)).
- **걷기·카메라:** 모든 Place가 core의 같은 값을 쓴다. 장소마다 따로 조정하지 않는다.

## 장소

| 장소 | 폴더 | 상태 | 로컬 포트 |
|---|---|---|---|
| 숭례문 | [sungnyemun](sungnyemun/) | 진행 중 | 34872 |
| 광화문 | — | 예정 | — |
| 불국사 | — | 예정 | — |

## 새 Place 추가

1. `landmarks/sungnyemun/`을 복사해 `landmarks/<이름>/`을 만들고, `default.project.json`의 `name`을 바꾸고 `src/`를 비운다. 이름은 로마자 소문자 한 단어이고 폴더명·pm2 이름(`roblox-<이름>`)·Rojo `name`을 같게 맞춘다.
2. `~/github/ecosystem.config.js`에 pm2 항목을 추가한다. 포트는 34872부터 하나씩 늘린다 (`args: 'serve --port 3487x'`).
3. pm2는 `~/github`에서 실행한다 (cwd가 상대 경로).
4. `SOURCES.md`를 만든다.
