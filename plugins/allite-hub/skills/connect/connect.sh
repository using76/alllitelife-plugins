#!/usr/bin/env bash
# 이 컴퓨터(macOS·Linux)의 Claude Code 를 올라이트라이프 온톨로지 허브에 연결 — 허브 인증서 확인·신뢰 + MCP 서버 'allite-hub' 등록.
# 로그인은 하지 않는다: 다시 시작한 Claude Code 에서 /mcp → allite-hub → Authenticate → 브라우저의 허브 화면에서 아이디·비밀번호.
#   bash connect.sh --config ~/Downloads/server.json
#   bash connect.sh --url https://<허브IP>:8443 [--fingerprint AA:BB:…]
# 종료 코드: 0 완료 · 1 오류 · 2 지문 확인 필요(FINGERPRINT= 값을 관리자 값과 대조 후 --fingerprint 로 다시) · 3 지문 불일치(중단)
set -euo pipefail
NAME=allite-hub
URL=""
FP=""
CONFIG=""
MCP_PATH=/api/v1/mcp
die() { echo "ERROR: $2"; exit "$1"; }

while [ $# -gt 0 ]; do
  case "$1" in
    --config) CONFIG="$2"; shift 2 ;;
    --url) URL="$2"; shift 2 ;;
    --fingerprint) FP="$2"; shift 2 ;;
    --name) NAME="$2"; shift 2 ;;
    *) die 1 "알 수 없는 인자: $1" ;;
  esac
done

json_field() { # 파일 키 — python3 가 있으면 그것으로, 없으면 단순 추출
  if command -v python3 >/dev/null 2>&1; then
    python3 -I -c 'import json,sys; v=json.load(open(sys.argv[1],encoding="utf-8")).get(sys.argv[2]); print(v or "")' "$1" "$2"
  else
    sed -n "s/.*\"$2\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" "$1" | head -n 1
  fi
}

DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -z "$CONFIG" ] && [ -z "$URL" ] && [ -f "$DIR/default-hub.json" ]; then CONFIG="$DIR/default-hub.json"; fi
if [ -n "$CONFIG" ]; then
  [ -f "$CONFIG" ] || die 1 "설정 파일을 찾을 수 없습니다: $CONFIG"
  [ -n "$URL" ] || URL="$(json_field "$CONFIG" url)"
  [ -n "$FP" ] || FP="$(json_field "$CONFIG" fingerprint)"
fi
[ -n "$URL" ] || die 1 "허브 주소가 없습니다. --config <server.json> 또는 --url https://<허브>:8443"
URL="${URL%/}"; URL="${URL%$MCP_PATH}"
case "$URL" in http://*|https://*) ;; *) URL="https://$URL" ;; esac
HOSTPORT="${URL#*://}"; HOSTPORT="${HOSTPORT%%/*}"
HOST="${HOSTPORT%:*}"; PORT="${HOSTPORT##*:}"; [ "$PORT" != "$HOSTPORT" ] || PORT=443
URL="${URL%%://*}://$HOSTPORT"
echo "== 허브: $URL"
META="$URL/.well-known/oauth-protected-resource$MCP_PATH"
CURL_CA=()

if [ "${URL%%://*}" = https ]; then
  command -v openssl >/dev/null || die 1 "openssl 이 필요합니다"
  PEM="$(openssl s_client -connect "$HOST:$PORT" -servername "$HOST" </dev/null 2>/dev/null | openssl x509 -outform PEM 2>/dev/null || true)"
  [ -n "$PEM" ] || die 1 "허브에 연결할 수 없습니다($HOST:$PORT). 사내망·주소를 확인하세요."
  GOT="$(printf '%s\n' "$PEM" | openssl x509 -noout -fingerprint -sha256 | cut -d= -f2)"
  norm() { printf '%s' "$1" | tr -cd '0-9A-Fa-f' | tr 'a-f' 'A-F'; }
  if curl -fsS -o /dev/null "$META" 2>/dev/null; then TRUSTED=1; else TRUSTED=0; fi
  if [ -n "$FP" ]; then
    if [ "$(norm "$FP")" != "$(norm "$GOT")" ]; then echo "FINGERPRINT=$GOT"; die 3 "허브 인증서 지문이 관리자 값과 다릅니다. 연결을 멈췄습니다 — 관리자에게 알리세요."; fi
    echo "== 인증서 지문 일치: $GOT"
  elif [ "$TRUSTED" = 0 ]; then
    echo "FINGERPRINT=$GOT"
    echo "CONFIRM: 자체 서명 인증서입니다. 위 지문이 관리자가 알려 준 값과 같은지 확인한 뒤 --fingerprint 로 다시 실행하세요."
    exit 2
  fi
  if [ "$TRUSTED" = 0 ]; then
    mkdir -p "$HOME/.allite-hub"
    CRT="$HOME/.allite-hub/hub.crt"
    printf '%s\n' "$PEM" > "$CRT"
    echo "== 인증서 저장: $CRT"
    TARGET="$CRT"
    CUR="${NODE_EXTRA_CA_CERTS:-}"
    if [ -n "$CUR" ] && [ "$CUR" != "$CRT" ] && [ -f "$CUR" ] && [ "$CUR" != "$HOME/.allite-hub/ca-bundle.pem" ]; then
      cat "$CUR" "$CRT" > "$HOME/.allite-hub/ca-bundle.pem"
      TARGET="$HOME/.allite-hub/ca-bundle.pem"
    fi
    LINE="export NODE_EXTRA_CA_CERTS=\"$TARGET\"  # allite-hub"
    for RC in "$HOME/.zshrc" "$HOME/.bashrc"; do
      if [ -f "$RC" ] || [ "$RC" = "$HOME/.zshrc" -a "$(basename "${SHELL:-}")" = zsh ] || [ "$RC" = "$HOME/.bashrc" -a "$(basename "${SHELL:-}")" = bash ]; then
        touch "$RC"
        grep -v '# allite-hub$' "$RC" > "$RC.allite-tmp" || true
        printf '%s\n' "$LINE" >> "$RC.allite-tmp" && mv "$RC.allite-tmp" "$RC"
        echo "== $RC 에 NODE_EXTRA_CA_CERTS 설정"
      fi
    done
    export NODE_EXTRA_CA_CERTS="$TARGET"
    CURL_CA=(--cacert "$CRT")
    echo "   (브라우저 로그인 화면에서 인증서 경고가 보이면 지문이 같은 것을 확인하고 계속하세요 — macOS 는 키체인에 hub.crt 를 '항상 신뢰'로 추가할 수 있습니다)"
  else
    echo "== 공인 인증서 — 추가 설정이 필요 없습니다."
  fi
fi

BODY="$(curl -sS ${CURL_CA[@]+"${CURL_CA[@]}"} -w '\n%{http_code}' "$META" 2>&1 || true)"
CODE="${BODY##*$'\n'}"
case "$CODE" in
  200) printf '%s' "$BODY" | grep -q authorization_servers || die 1 "허브가 아이디·비밀번호 로그인 연결을 지원하지 않습니다(허브 업데이트 필요)" ;;
  403) die 1 "허브가 이 컴퓨터의 접속을 막았습니다(허용 대역 밖)" ;;
  *) die 1 "허브가 아이디·비밀번호 로그인 연결을 지원하지 않거나 응답하지 않습니다(HTTP $CODE)" ;;
esac
echo "== 허브 로그인 연결 지원 확인"

MCP_URL="$URL$MCP_PATH"
if command -v claude >/dev/null 2>&1; then
  claude mcp remove "$NAME" -s user >/dev/null 2>&1 || true
  claude mcp add --transport http --scope user "$NAME" "$MCP_URL" || die 1 "MCP 서버 등록 실패 — 직접: claude mcp add --transport http --scope user $NAME $MCP_URL"
  echo "== Claude Code 에 '$NAME' 등록: $MCP_URL"
else
  echo "WARN: claude 명령을 찾지 못했습니다. 새 터미널에서: claude mcp add --transport http --scope user $NAME $MCP_URL"
fi
echo "OK: 연결 설정을 마쳤습니다 ($MCP_URL)."
echo "NEXT: Claude Code 를 완전히 끄고 새 터미널에서 다시 실행 → /mcp → allite-hub → Authenticate → 브라우저의 허브 화면에서 회사 아이디·비밀번호로 로그인"
