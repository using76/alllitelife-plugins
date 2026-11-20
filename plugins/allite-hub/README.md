# Claude Code 플러그인 — `allite-hub` (사내 전용)

올라이트라이프 허브의 MCP 게이트웨이(`https://<허브>/api/v1/mcp`)를 Claude Code 에 연결하는 플러그인이다. 형식은 Claude Code 플러그인 문서
(plugins-reference·marketplace-reference, 2026-11 확인)를 따른다.

```
claude-plugin/
  .claude-plugin/plugin.json          매니페스트(name·version — workspace/VERSION 과 같아야 한다: workspace/tools/version.py --check)
  skills/connect/                     /allite-hub:connect — 허브 인증서 확인·신뢰 + MCP 서버 allite-hub 등록(connect.ps1 · connect.sh)
  skills/allite-hub-rules/SKILL.md    허브 내장 규칙(contracts/mcp_rules.yaml 에서 생성 — build_claude_plugin.py)
  skills/allite-hub-monitor/SKILL.md  실시간 감시 도구 사용법(관리자 계정)
```

MCP 서버는 플러그인의 `.mcp.json` 이 아니라 **연결 스킬이 사용자 범위로 등록**한다(허브 주소가 회사마다 다르고, 자체 서명 인증서 신뢰가 먼저
필요하기 때문). 인증은 **MCP 로그인(OAuth)** — 토큰을 따로 만들지 않는다(서버: ws_hub/oauth/README.md).

## 사원 PC 설치

1. 플러그인 설치(둘 중 하나)
   - 공개 마켓플레이스(git 필요 없음): Claude Code 에서
     `/plugin marketplace add https://raw.githubusercontent.com/using76/alllitelife-plugins/main/dist/marketplace.json` →
     `/plugin install allite-hub@alllitelife`. (git 이 있는 PC 는 `/plugin marketplace add using76/alllitelife-plugins` 도 된다)
   - 회사 키트: 관리자 포털 → 클라이언트 내려받기 → `ows-claude-plugin-<ver>.zip` 을 `C:\ows\` 에 풀고
     `claude plugin marketplace add C:\ows\ows-marketplace` → `claude plugin install allite-hub@alllitelife`
2. `/allite-hub:connect <server.json 경로 또는 허브 주소>` — 관리자 포털의 `server.json`(주소 + 인증서 지문)을 주면 지문을 대조해 인증서를 믿고
   `allite-hub` 를 등록한다(회사 키트는 기본값이 들어 있어 인자 없이도 된다). Windows 가 인증서 설치 확인 창을 띄우면 **예**.
3. Claude Code 를 완전히 끄고 새 터미널에서 다시 실행 → `/mcp` → `allite-hub` → **Authenticate** → 브라우저의 허브 화면에서 회사 아이디·비밀번호
   (관리자는 OTP). 처음이면 새 비밀번호 만들기·회사 고지 확인.
4. 확인: `claude mcp list` → `allite-hub … Connected`.

옛 방식(앱에서 만든 개인 토큰을 `Authorization` 헤더로)으로 등록한 연결이 남아 있으면 지운다 — 헤더가 있으면 Claude Code 는 로그인을 쓰지 않는다.

## 빌드·배포

```
python workspace/tools/build_claude_plugin.py zip --out dist --hub-url https://<허브>:8443 --fingerprint AA:BB:…   # 회사 키트(기본 허브 포함)
python workspace/tools/build_claude_plugin.py marketplace --out <폴더> --repo using76/alllitelife-plugins   # 공개 저장소용(회사 주소 없음,
                                                                       # dist/ = git 없이 받는 URL 카탈로그 + zip)
```

허브와 같은 버전으로 함께 올린다(`workspace/VERSION`). 플러그인 `version` 을 올리지 않으면 Claude Code 가 업데이트로 보지 않는다.
