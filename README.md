# Alllitelife Claude Code plugins

올라이트라이프 사내 **사무 자동화 온톨로지 허브** 연결 플러그인. 회사 계정과 사내망 접속이 있어야 쓸 수 있다.

## 설치(git 필요 없음)

```
/plugin marketplace add https://raw.githubusercontent.com/using76/alllitelife-plugins/main/dist/marketplace.json
/plugin install allite-hub@alllitelife
/allite-hub:connect <관리자가 준 server.json 경로 또는 허브 주소>
```

그다음 Claude Code 를 다시 시작하고 `/mcp` → `allite-hub` → **Authenticate** → 브라우저의 허브 화면에서 회사 아이디·비밀번호로 로그인한다.

git 이 있는 PC 는 `/plugin marketplace add using76/alllitelife-plugins` 로 추가해도 된다(같은 플러그인).

이 저장소에는 비밀번호·토큰·회사 서버 주소가 없다. 원본: 사내 저장소 workspace/clients/claude-plugin (`python workspace/tools/build_claude_plugin.py marketplace --out <이 폴더> --repo <owner/repo>` 로 다시 만든다 — 새 버전은 plugin.json 의 version 을 올려야 사용자에게 간다).
