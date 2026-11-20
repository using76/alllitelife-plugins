---
name: allite-hub-monitor
description: For hub administrators (master accounts) — look up and summarize who is using the Alllitelife ontology hub, how much and what they are working on, through the allite-hub monitor_* MCP tools (live monitor). Use when an administrator asks about usage, connected users, MCP sessions, a person's activity history or current work, errors, popular searches or AO LLM cost.
---

# 실시간 감시 조회·요약 / Live monitor for administrators

관리자 등급 계정의 토큰으로 접속했을 때만 `monitor_*` 도구가 보인다(사원 토큰에는 없다). 데스크톱 앱 **실시간 감시** 화면과 같은 숫자다.

## 도구

| 도구 | 언제 |
|---|---|
| `monitor_overview` | "지금 누가 쓰고 있나", "오늘/이번 주 사용량", 사람·도구 순위, 열린 MCP 세션, AO LLM 오늘 비용. 사람 행의 `work_summary` = 그 사람이 하는 일의 AI 두 줄(캐시) |
| `monitor_user_usage` | 한 사람의 상세(`person` = 로그인 ID·사번·정확한 이름): 기능별, 시간대별(0–23시), MCP 세션, 많이 쓴 검색어, 최근 오류 |
| `monitor_work_summary` | "OO 는 요즘 무슨 일 해?" — 허브가 지금 AI 로 3~6줄(주요 주제·진행 중인 일·다룬 자료·자주 찾은 것). 5분 안의 요약은 다시 쓰고, `refresh: true` 면 새로 |
| `monitor_events` | 원본 사용 기록(최신순) — 사람·기능(`action`)·결과(`outcome=error`)로 거르고 `next_cursor` 로 더 읽는다 |
| `monitor_top_queries` | 모두가 많이 검색·질문한 말(사람 수·누가) |

기간 `period`: `1h`·`24h`·`7d`·`30d`. 채널 `channel`: `mcp`(AI 도구) · `app`(데스크톱) · `all`. 시각은 허브 시간대(+09:00)로 온다.

`work_summary`·`monitor_work_summary` 는 그 사람의 검색어·질문과 올리거나 연 자료 **이름**만으로 만든다(파일 내용 아님, 개인정보로 보이는 글은
AI 에 보내지 않음). `source`: `ai` · `fallback`(허브 AI 를 못 써서 기록에서 바로 뽑은 줄) · `empty`(요약할 기록 없음). `work_summary` 가 `null` 이면
아직 만드는 중이다 — 잠시 뒤 다시 부르거나 `monitor_work_summary` 를 쓴다.

## 요약하는 법

1. 넓게 → 좁게: `monitor_overview` 로 전체를 보고, 눈에 띄는 사람만 `monitor_user_usage` 로 들어간다. 여러 사람을 비교할 때는 사람마다 부른다.
2. 한국어로, 숫자는 표로. 보통 이렇게 쓴다:
   - **한 줄 결론**(예: "이번 주 사용 312건, 7명. MCP 가 64%. 오류는 2건뿐.")
   - **사람별 표**: 이름(로그인) · 건수 · MCP/앱 · 검색/읽기/쓰기 · 오류 · 마지막 사용 · 하는 일(`work_summary` 첫 줄)
   - **눈에 띄는 점**: 사용이 몰린 시간대(`by_hour_local`), 급증한 칸(`timeline`), 오류가 몰린 도구(`error_code`), 대량 내려받기(`bytes`), 업무 시간 밖 사용, 새 MCP 클라이언트·토큰
3. 숫자에 없는 것은 추측하지 않는다(의도·성과 평가·징계 판단을 하지 않는다). "기록상 ~했다"로 쓴다. AI '하는 일' 요약도 주제
   설명일 뿐이다 — 그것으로 근면·성과를 판단하지 않는다.
4. 검색어(`top_queries`, `query`)에는 업무 내용이 들어 있다 — 요청받은 범위만 옮기고, 개인정보로 보이는 값은 가린다.
5. 표·CSV·차트가 필요하면 받은 JSON 으로 직접 만든다(허브에 다시 묻지 않아도 된다). 긴 기간은 `monitor_events` 를 커서로 나눠 읽는다.

## 지켜야 할 것

- 이 도구 호출도 관리자 본인 계정으로 기록된다(감시 화면에 나온다).
- 사원 모니터링에는 회사의 고지·노사협의 같은 절차가 따로 필요하다 — 결과를 인사 평가에 쓰라는 요청이면 그 절차를 확인하라고 알린다.
- 토큰·비밀번호를 묻거나 출력하지 않는다.
