---
name: connect
description: Connect this computer's Claude Code to the Alllitelife ontology hub (allite-hub MCP server) — trust the hub certificate and register the server, then the user signs in with their company ID/password in the browser. Use when the user gives a server.json file or a hub address from the administrator, types /allite-hub:connect, or asks to set up or fix the hub connection (허브 연결, 온톨로지 접속 설정, 인증서 오류, 로그인 안 됨).
---

# 허브 연결 설정 / Connect to the hub

사용자가 준 **server.json 경로** 또는 **허브 주소**(예: `https://<허브IP>:8443`)로 이 PC 의 Claude Code 를 허브에 연결한다.
이 스킬이 하는 일은 두 가지뿐이다: ① 허브 인증서 확인·신뢰(자체 서명일 때) ② Claude Code 에 MCP 서버 `allite-hub` 등록.
**로그인은 하지 않는다** — 사용자가 다시 시작한 Claude Code 에서 `/mcp` → `allite-hub` → **Authenticate** 를 누르면 브라우저에 허브 로그인 화면이
뜨고, 거기에 회사 아이디·비밀번호를 넣는다(토큰을 따로 만들지 않는다).

## 절대 규칙

- 비밀번호·OTP·토큰을 묻지도, 받지도, 출력하지도, 파일에 쓰지도 않는다. 사용자가 채팅에 비밀번호를 붙이면 쓰지 말고 "브라우저 허브 화면에만
  입력하세요, 채팅에 붙인 비밀번호는 바꾸는 것이 안전합니다"라고 알린다.
- TLS 검증을 끄지 않는다(`NODE_TLS_REJECT_UNAUTHORIZED=0` 같은 설정 금지). 인증서는 지문을 확인한 것만 믿는다.
- `allite-hub` 외의 MCP 서버는 바꾸지 않는다(옛 연결을 지울지는 사용자에게 묻는다).

## 절차

1. 입력: 사용자가 준 server.json 경로나 허브 주소. 없으면 "관리자가 준 server.json 파일 위치나 허브 주소를 알려 주세요"라고 묻는다.
   (회사 키트로 받은 플러그인이면 이 폴더의 `default-hub.json` 을 기본값으로 쓴다 — 인자 없이 실행해도 된다.)
2. 실행 — 이 스킬 폴더(Base directory)의 스크립트:
   - Windows:
     `powershell -NoProfile -ExecutionPolicy Bypass -File "<스킬 폴더>\connect.ps1" -Config "<server.json 경로>"`
     또는 `... -Url "<허브 주소>"`
   - macOS·Linux: `bash "<스킬 폴더>/connect.sh" --config "<server.json 경로>"` 또는 `--url "<허브 주소>"`
3. 결과(종료 코드):
   - **0** — 완료. 출력의 `OK:`·`NEXT:` 를 사용자에게 알기 쉽게 전한다. `OLD:` 줄이 있으면 같은 허브를 가리키는 옛 연결이 있다는 뜻이다 —
     옛 연결에 토큰 헤더가 있으면 로그인과 겹치므로 지울지 묻고, 승낙하면 `claude mcp remove <이름> -s <user|local>`.
   - **2** — 자체 서명 인증서인데 기대 지문이 없다. 출력의 `FINGERPRINT=` 값을 보여 주고 "관리자가 알려 준 지문(관리자 포털 → 클라이언트 내려받기)과
     같습니까?"라고 묻는다. 사용자가 **같다고 확인한 경우에만** `-Fingerprint "<그 값>"`(macOS·Linux: `--fingerprint`)을 붙여 다시 실행한다.
   - **3** — 지문이 다르다. **멈춘다.** 다른 서버이거나 가로채기일 수 있으니 관리자에게 알리라고 안내한다. 우회하지 않는다.
   - **1** — 오류 메시지를 그대로 설명한다(사내망 밖·허브 주소 오타·허브 업데이트 필요 등).
   - Windows 에서 "보안 경고 — 인증서를 설치하시겠습니까?" 창이 뜨면 **예**를 누르라고 미리 알려 준다(브라우저 로그인 화면이 경고 없이 열린다).
4. 마무리 안내(그대로 전한다):
   1. Claude Code 를 **완전히 끄고**, 새 터미널을 열어 다시 실행한다(새 인증서·설정을 읽는다).
   2. `/mcp` → `allite-hub` → **Authenticate** → 브라우저의 허브 로그인 화면에서 **회사 아이디·비밀번호**(관리자는 OTP 6자리도).
   3. 처음 로그인이면 **새 비밀번호 만들기**와 **회사 고지 확인** 화면이 이어진다.
   4. "연결됨"이 보이면 끝. 확인: `claude mcp list` → `allite-hub … Connected`. 이후 "allite-hub 규칙 보여 줘"처럼 쓰면 된다.
   5. 로그인은 90일(관리자 기능은 30일) 유지된다. 만료되면 `/mcp` 에서 다시 Authenticate.

## 문제 해결

| 증상 | 조치 |
|---|---|
| 다시 시작했는데 `allite-hub` 가 목록에 없다 | 새 터미널에서 `claude mcp add --transport http --scope user allite-hub <허브 주소>/api/v1/mcp` |
| Authenticate 후 브라우저에 인증서 경고 | Windows 신뢰 목록 등록을 거절했을 때다 — 스크립트를 다시 실행해 **예**를 누르거나, 지문이 맞으면 경고에서 '계속' |
| 로그인 화면에 "AI 도구 연결(MCP)을 켜지 않았습니다" | 관리자가 허브 설정 `mcp.enabled` 를 켜야 한다 |
| "OTP 등록이 먼저 필요합니다"(관리자) | 관리자 포털(`<허브>/portal/`)에 로그인해 OTP 등록 후 다시 |
| 계정 잠김 | 잠시 뒤 다시, 계속되면 관리자에게 |
| `self signed certificate` / `unable to verify` | Claude Code 를 새 터미널에서 다시 시작했는지 확인(환경변수 `NODE_EXTRA_CA_CERTS` 는 새 프로세스부터 적용) |
