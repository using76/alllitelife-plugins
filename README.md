# Alllitelife Claude Code plugins

올라이트라이프 사내 **사무 자동화 온톨로지 허브** 연결 플러그인. 회사 계정과 사내망 접속이 있어야 쓸 수 있다.

준비: 이 PC 에 **git** 이 있어야 Claude Code 가 마켓플레이스를 받는다 — Windows 는 `winget install --id Git.Git -e` (설치 뒤 새 터미널). 없으면 `Command 'git' not found` 오류가 난다.

```
/plugin marketplace add using76/alllitelife-plugins
/plugin install allite-hub@alllitelife
/allite-hub:connect <관리자가 준 server.json 경로 또는 허브 주소>
```

그다음 Claude Code 를 다시 시작하고 `/mcp` → `allite-hub` → **Authenticate** → 브라우저의 허브 화면에서 회사 아이디·비밀번호로 로그인한다.
이 저장소에는 비밀번호·토큰·회사 서버 주소가 없다. 원본: 사내 저장소 workspace/clients/claude-plugin (`python workspace/tools/build_claude_plugin.py marketplace --out <이 폴더>` 로 다시 만든다).
