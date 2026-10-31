# 한국 문화유산 가상답사 (Roblox)

한국의 사찰·건축물·랜드마크를 실측 비율로 로블록스에 재현해, 답사하듯 걸어보는 공간을 만든다.
첫 번째 랜드마크는 숭례문.

- 기획: [기획 메모](https://claude.ai/artifact/NbrSpp5L8zZ1pjh85ezd4R)
- 용어: [CONTEXT.md](CONTEXT.md) — 대화·코드·문서에서 이 용어를 쓴다
- 규칙: [CLAUDE.md](CLAUDE.md) — 구조, 단위·좌표, 코드, 해설, 자료 출처, Git 규칙
- 결정 기록: [docs/adr/](docs/adr/)

## 구조

```
core/            모든 Place가 공유하는 Luau 코드 (Studio에서 ReplicatedStorage.Core)
places/<이름>/   랜드마크 하나 = Place 하나 = Rojo 프로젝트 하나
docs/adr/        결정 기록
```

하나의 Experience 안에 랜드마크마다 Place를 둔다. 자세한 규칙은 CLAUDE.md.

## 준비물

- [Roblox Studio](https://create.roblox.com/docs/studio/setup) 최신 버전
- [Rojo](https://rojo.space) 7.7 — macOS: `brew install rojo`
- Studio용 Rojo 플러그인 — `rojo plugin install`
- (선택) [Claude Code](https://claude.com/claude-code) — AI 협업용

## 개발 시작

1. 저장소를 클론한다.
2. 작업할 Place 폴더에서 Rojo 서버를 띄운다.
   ```sh
   cd places/sungnyemun
   rojo serve            # 기본 포트 34872
   ```
3. Studio에서 해당 Place를 열고 **Plugins → Rojo → Connect**.
4. 이제 `core/`, `places/<이름>/src/`의 `.luau` 파일을 고치면 Studio에 실시간 반영된다.

### 코드와 Studio 작업의 차이

Rojo는 `.luau` 코드 파일만 Studio로 보낸다. Studio에서 손으로 만든 것(지형, 직접 배치한 파트·메시, 조명 조정)은 코드 파일이 아니라 Place 안에만 저장되고, Place 파일(`.rbxl`)은 git에서 제외한다. 이것들은 Studio에서 **Save to Roblox**로 Roblox 클라우드에 보관한다.

| 무엇 | 어디서 만드나 | 어디에 남나 |
|---|---|---|
| 기능(해설, 답사 노트 등), 코드로 생성하는 건물 뼈대 | `.luau` 파일 | git |
| 지형, 직접 배치한 메시·파트, 조명 | Studio | Place (Roblox 클라우드) |

그래서 건물은 가능한 한 실측 데이터로 코드가 생성하게 만들고, Studio에서는 코드로 만들기 어려운 것만 직접 배치한다.

## Claude Code + Studio MCP

Studio에 내장된 MCP 서버로 Claude가 Studio 안을 직접 조회·조작·테스트할 수 있다. 저장소의 `.mcp.json`에 설정이 들어 있다 (macOS 경로 기준).

1. Studio에서 **Assistant 열기 → … → Manage MCP Servers → Enable Studio as MCP server** 켜기
2. 이 저장소에서 `claude` 실행 → 프로젝트 MCP 서버 `Roblox_Studio` 사용을 승인
3. `claude mcp list`에서 `Roblox_Studio`가 Connected인지 확인

Windows는 `.mcp.json`의 경로가 다르므로 [공식 문서](https://create.roblox.com/docs/studio/mcp)를 참고한다.
MCP에 연결된 클라이언트는 열린 Place를 읽고 수정할 수 있으니 신뢰하는 도구만 연결한다.

## 기여 방식

- 작업은 새 브랜치에서 하고 PR로 main에 머지한다 (머지 후 브랜치 자동 삭제).
- 커밋 메시지는 Conventional Commits, scope는 Place 이름 또는 `core` — 예: `feat(sungnyemun): ...`
- 자료(사진·도면)를 쓰면 해당 Place의 `SOURCES.md`에 출처와 라이선스를 적는다.
