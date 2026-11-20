---
name: allite-hub-rules
description: Rules for using the Alllitelife office-automation ontology hub through the allite-hub MCP server (ontology questions, contribution drafts, files, work items, automation maps). Use whenever a task calls an allite-hub tool or asks about the company ontology, work items or hub files.
---

# 사무 자동화 온톨로지 허브 사용 규칙 / Hub usage rules

이 스킬은 허브(`allite-hub` MCP 서버)가 내보내는 **내장 규칙**을 그대로 싣는다. 허브는 같은 규칙을 서버에서 강제한다 — 여기의 글은 안내이고,
판단은 늘 허브의 응답(`needs_confirmation`, `awaiting_approval`, `[rule:ID]`)을 따른다.

## 지켜야 할 것

- 모든 호출은 **사원 본인 계정**으로 기록된다(도구·테이블·행 수·질의문 90일). 결과는 이 AI 제공자에게 전송된다 — 개인정보(주민번호·연락처 등)를
  질문·SQL·초안에 넣지 않는다. 허브는 개인정보 패턴을 거절한다.
- `needs_confirmation`: diff 를 사용자에게 그대로 보여 주고, 사용자가 **명시적으로 승낙한 뒤에만** `confirm_action(action_id)` 을 한 번 부른다.
  사용자를 대신해 승낙했다고 말하지 않는다.
- `awaiting_approval`: 데스크톱 앱 **MCP 승인 대기**에서 승인자가 비밀번호 + TOTP 로 승인해야 한다. `get_action(action_id)` 로 상태만 확인한다. 우회하지 않는다.
- 온톨로지(fire_ontology)는 직접 바꾸지 않는다 — `contribution_draft_create/update` 초안 → (확인 후) 제출 → **서버가 자동 검토·게시**
  (중복·구판·명백한 오류만 반려되고 사유가 기여에 남는다. 같은 ID 가 이미 있으면 번호를 붙여 새 항목으로 받는다).
- 토큰·비밀번호를 묻거나 출력하지 않는다. 로그인은 사용자가 브라우저의 허브 로그인 화면에서 직접 한다(`/mcp` → allite-hub → Authenticate).

<!-- BEGIN GENERATED: hub rules card (workspace/tools/build_claude_plugin.py — contracts/mcp_rules.yaml 에서 생성, 손으로 고치지 않는다) -->
화재 온톨로지 업무 허브. 호출은 사원 계정으로 기록되고 결과는 AI 제공자로 전송됩니다.
질의 순서: check_answerable → list_analyses/run_analysis → get_query_context → lookup_values → validate_sql → run_sql (ontology://guide).
1. 요청받은 일만 합니다. 범위를 넓히거나 결과를 지어내지 않습니다. [rule:MCP-GEN-001]
2. needs_confirmation 이면 diff 를 사용자에게 보여 주고 승낙을 받은 뒤에만 confirm_action(action_id) 을 부릅니다. [rule:MCP-SEV-001]
3. awaiting_approval 이면 앱 승인을 안내하고 get_action(action_id) 으로 확인합니다. 우회하지 않습니다. [rule:MCP-SEV-002]
4. 온톨로지 변경은 contribution_draft_create/update 초안으로, 제출은 사용자 확인 뒤에. 서버가 자동 검토·게시합니다. [rule:MCP-COW-001]
5. 파일 수정은 file_new_version(supersedes=이전 file_id)으로. 삭제는 내 파일만 소프트 삭제(확인). [rule:MCP-COW-002]
6. 민감 도구에는 사용자가 밝힌 목적(code·note)만 넣습니다. 목적을 지어내지 않습니다. [rule:MCP-PRIV-001]
7. 비밀번호·토큰을 묻거나 추측하지 않습니다. 발급 결과는 앱에서 확인하라고 안내합니다. [rule:MCP-FBD-010]
규칙 목록 rules://index · list_rules, 설명 describe_rule. 위반은 [rule:ID] 로 알린다.

Fire-ontology workspace hub. Calls are logged under the employee's account; results go to your AI provider.
Data questions: check_answerable → list_analyses/run_analysis → get_query_context → lookup_values → validate_sql → run_sql (ontology://guide).
1. Do only what was asked; do not widen the scope or invent results. [rule:MCP-GEN-001]
2. On needs_confirmation show the diff, get the user's explicit yes, then call confirm_action(action_id) once. [rule:MCP-SEV-001]
3. On awaiting_approval ask the user to approve in the app, then poll get_action(action_id); never bypass it. [rule:MCP-SEV-002]
4. Propose ontology changes as drafts (contribution_draft_create/update); submit after the user confirms; the hub auto-publishes. [rule:MCP-COW-001]
5. Change files with file_new_version(supersedes=<old file_id>); deletes are confirmed soft deletes of your own files. [rule:MCP-COW-002]
6. Pass only the purpose (code, note) the user stated; never invent one. [rule:MCP-PRIV-001]
7. Never ask for or guess passwords or tokens; tell the admin to read issued credentials in the app. [rule:MCP-FBD-010]
Rules: rules://index, list_rules, describe_rule. Violations cite [rule:ID].
<!-- END GENERATED -->

## 연결이 안 될 때

- `401`: 토큰 만료·폐기 — 앱 **설정 → AI 도구 연결**에서 새 토큰을 만들어 `FWO_MCP_TOKEN` 을 바꾼다.
- `403 mcp_disabled`: 관리자가 MCP 를 켜지 않았다(허브 설정 `mcp.enabled`). `403 ip_not_allowed`: 사내망·허용된 주소에서만 된다.
- TLS 오류(자체 서명 허브): `NODE_EXTRA_CA_CERTS` 에 허브 인증서(PEM) 경로를 넣고 Claude Code 를 다시 시작한다.
