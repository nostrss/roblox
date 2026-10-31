# 한국 문화유산 가상답사 (Roblox)

사찰·건축물·랜드마크를 실측 비율로 재현해 "답사하듯" 걷는 공간. 쇼케이스 이상, 게임 미만.
기획 메모: https://claude.ai/artifact/NbrSpp5L8zZ1pjh85ezd4R

목표는 **랜드마크를 일관되게, 빠르게 찍어내는 것**. 판단이 갈리면 "다음 랜드마크가 이걸 그대로 재사용할 수 있나?"로 고른다.

## 용어와 결정 기록

**CONTEXT.md**는 이 프로젝트의 용어집이다. 대화·코드·문서에서 이 용어를 그대로 쓴다.
- 사용자가 CONTEXT.md와 다른 뜻으로 용어를 쓰면 바로 짚어서 어느 쪽인지 확정한다.
- 새 용어가 확정되면 그 자리에서 CONTEXT.md에 추가한다 (용어당 1~2문장, 피할 말은 `_Avoid_`). 구현 내용은 적지 않는다.

**ADR**은 `docs/adr/NNNN-slug.md` (번호는 기존 최대값 + 1). 아래 세 조건이 모두 맞는 결정이 내려지면 그 자리에서 작성한다:
1. 되돌리기 비싸다
2. 맥락 없이 보면 "왜 이렇게 했지?" 싶다
3. 실제 대안이 있었고 이유를 갖고 골랐다

형식은 제목 + 맥락·결정·이유 1~3문장. 기각한 대안은 다시 제안될 만할 때만 적는다.

## 구조

하나의 Experience(Universe) 안에 랜드마크마다 Place 하나. 답사 노트·배지는 Universe 단위 DataStore로 공유.

```
CONTEXT.md            용어집
docs/adr/             결정 기록 (ADR)
core/                 모든 Place 공유 Luau (ReplicatedStorage.Core)
places/<이름>/        Place 하나 = Rojo 프로젝트 하나
  default.project.json  core를 "../../core"로 매핑
  src/{server,client,shared}  이 Place 전용 코드
  SOURCES.md          이 장소에 쓴 자료 목록 (아래 "자료 출처")
```

- 랜드마크 하나 = **데이터 + Studio 배치**. 동작은 core가 하고, Place는 core에 데이터를 넘겨 부르기만 한다.
- 두 번째 Place가 같은 코드를 원하는 순간 그 코드는 core로 올린다. core는 places를 참조하지 않는다.
- Place 이름은 로마자 소문자 한 단어(`sungnyemun`, `bulguksa`). 폴더명·pm2 이름(`roblox-<이름>`)·Rojo `name`을 같게 맞춘다.
- 맵·모델(.rbxl)은 git에 없음 → Studio "Save to Roblox"로 보관.

## 새 Place 추가

1. `places/sungnyemun/` 를 복사해 `places/<이름>/` 생성, `default.project.json`의 `name` 변경, `src/` 비우기
2. `~/github/ecosystem.config.js`에 pm2 항목 추가, 포트는 34872부터 하나씩 증가 (`args: 'serve --port 3487x'`)
3. pm2는 `~/github`에서 실행 (cwd가 상대 경로)
4. `SOURCES.md` 생성

## 공간 규칙

- **단위:** R15 캐릭터 약 5스터드 = 170cm, **1스터드 = 0.34m**. 데이터는 실측값(m) 그대로 적고, 스터드 환산은 core의 상수 하나를 거친다.
- **좌표:** 원점 = 주 건물 중심의 지면, 지면 높이 Y = 0. **북쪽 = -Z, 동쪽 = +X** (실제 방위 그대로. 숭례문은 남향이므로 정면이 +Z).
- **걷는 속도·카메라:** 모든 Place가 core의 같은 값을 쓴다. 장소마다 따로 조정하지 않는다.

## Studio ↔ 코드 경계

- **Studio(사용자):** 지형, 메시·모델 배치, 조명 미세 조정.
- **코드(Claude):** 생성되는 뼈대, 상호작용, UI, 저장, 소리·시간 연출.
- 코드는 Studio 오브젝트를 **CollectionService 태그와 Attribute**로 찾는다. 경로(`workspace.A.B`)에 기대지 않으므로 Studio에서 자유롭게 옮기고 묶어도 된다. 새 태그를 쓰면 core에 태그 이름 상수로 등록한다.

## 코드 규칙

- 모든 파일 `--!strict`, 확장자 `.luau`. ModuleScript 파일명은 PascalCase.
- 서버가 판정, 클라이언트는 표시. 도장·배지·저장은 항상 서버에서 확정한다.
- 화면에 보이는 문장은 전부 다국어 테이블의 키로 참조한다 (코드에 문장 직접 쓰지 않음).

## 해설과 다국어

- 기본 언어는 한국어(원문)와 영어. 문장은 한국어로 먼저 쓰고 영어는 번역이 아니라 외국인 답사객 기준으로 다시 쓴다.
- 해설 데이터는 한 곳에 모아 안내자 대사, 해설 패널, 답사 노트가 같은 원본을 공유한다.
- 해설문은 직접 작성한다. 안내판·홈페이지 문구는 사실 확인용으로만 읽는다.
- 톤: 문화재 답사. 종교 시설에서는 애니메이션을 차분하게 하고, 인물은 가상의 인물로 만든다.

## 자료 출처

- 각 Place의 `SOURCES.md`에 쓴 자료마다 한 줄: 무엇 · 어디서(URL) · 라이선스(공공누리 유형 등) · 어디에 썼나.
- 상업 이용 가능한 자료(공공누리 1유형, 직접 촬영·실측)만 반영한다. 유형을 모르면 반영 전에 사용자에게 묻는다.

## Git

- Conventional Commits, scope는 Place 이름 또는 `core` (`feat(sungnyemun): ...`, `fix(core): ...`).
