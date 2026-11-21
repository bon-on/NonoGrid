---
id: feature-next-session-hooks
title: 레벨별 미완성 보드, 결과 화면의 다음 데일리 안내, 한 번에 누르는 Next
status: active
owner: games
related_adrs:
  - adr-level-boards
  - adr-daily-puzzle
  - adr-line-solvable-generator
  - adr-nono-grid-crazygames-web
related_contracts:
  - contract-nono-grid-crazygames
required_evidence:
  - flutter-analyze
  - flutter-tests
  - web-build
---

# 기능 명세: 다음 세션으로 이어지는 장치

## Problem
CrazyGames 평균 플레이 시간, D1 재방문, 1분 넘게 플레이하는 비율을 올려야 한다.
- 진행 중 보드는 슬롯 하나(`progress`)뿐이라 레벨 8에서 한 수를 두면 풀다 만 레벨 9 보드가 사라진다.
  레벨을 오가며 푸는 플레이어가 진행을 잃는다.
- 결과 화면은 레벨 클리어 후 데일리를 언급하지 않는다. 내일 다시 올 이유(다음 데일리까지 남은 시간, 연속 기록)가
  데일리 패널 안에만 있다.
- 승리 후 다음 행동(Next)이 다른 버튼과 비슷하게 보이고, 다음 퍼즐은 Next를 누른 순간에 만들어진다.

## Scope
1. 레벨별 미완성 보드
   - 레벨마다 미완성 보드(칸, 경과 초, 실수 여부)를 따로 저장한다. 최근에 저장한 5개까지 두고, 6번째가 생기면
     가장 오래된 보드를 버린다. 다시 저장한 레벨은 가장 최근이 된다.
   - 푼 레벨은 자기 보드만 지운다. Restart도 그 레벨 보드만 지운다.
   - 보드는 그 레벨에 배정된 퍼즐(시드)에만 적용한다. 저장 형식과 호환성은 `adr-level-boards`.
   - 시작 레벨은 항상 열린 가장 높은 레벨(프런티어)이고, 그 레벨의 보드가 있으면 이어서 연다. 다른 레벨 보드는
     남아 있다가 그 레벨을 열면 이어진다(이전에는 마지막 보드가 있는 레벨로 시작했다).
   - 데일리 보드(`daily.progress`)와 CrazyGames 계정 저장(`prefs_v1`)은 바뀌지 않는다. 값은 같은 v2 JSON 문자열
     안에 있어 계정 저장소가 그대로 옮긴다.
2. 결과 화면의 데일리 안내(D1)
   - 레벨 클리어와 데일리 클리어 결과 화면 모두에 한 줄(`summary-daily-hook`)을 보인다. 시간은 주입된 `clock`으로
     계산한다(다음 지역 날짜 자정까지, 분 단위 올림).
     - 오늘 데일리를 풀었으면 `New daily in 8h 30m  -  Streak 4, grace ready`(또는 `grace refills in N`).
     - 어제까지 연속이면 `Solve today's daily to keep streak 3 (8h 30m left)`.
     - 유예가 어제를 덮으면 `Your grace saves streak 3: solve today's daily (8h 30m left)`.
     - 그 밖에는 `Today's daily is waiting (8h 30m left)`.
   - 결과 화면에 고정된 줄(최대 2줄, 13px)이라 내용 스크롤 영역만 줄어든다. 짧은 화면(560x315, 620x349, 640x480)에서도
     Next와 안내가 화면 안에 있다.
3. Next 한 번
   - Next(데일리는 Levels)는 테두리 링이 있는 큰 강조 버튼이고 나머지는 작은 버튼이다. Enter/Space는 결과 화면에서 Next다.
     결과 화면이 열릴 때 게임 화면이 키보드 포커스를 다시 잡아 패널 버튼으로 이긴 경우에도 Enter가 Next로 간다.
   - 세트 목표 줄(`Next: Level 8 - 3 more to complete Sketchbook (+50 XP)`, `ClearResult.setGoal`)은 기존대로 보인다.
   - 결과 화면의 별/XP 애니메이션이 끝난 뒤(`onFinished`) 다음 레벨 퍼즐을 미리 배정하고 만든다
     (`puzzleFor(level + 1)`, 이미 열린 레벨만, 데일리 제외). 이 레벨은 클리어로 이미 열렸으므로 시드를 일찍 뽑는 것
     외에 결과는 같다.
   - 비용 근거: Dart VM(JIT)에서 크기별 생성 시간 중앙값 44-289us, p95 0.2-1.1ms, 최대 5.1ms(5x5, 워밍업 포함).
     dart2js/wasm이 몇 배 느려도 대부분 한 프레임(16ms) 안이고, 애니메이션이 끝난 정지 화면에서만 돌므로 끊김 위험이
     작다. 생성기, PRNG, 크기 단계는 바꾸지 않는다.
- 범위 밖: 생성기 변경, 서버/네트워크, 새 의존성, 데일리 규칙 변경.

## Acceptance Criteria
- 레벨 2에서 한 수, 레벨 1로 가서 한 수, 다시 레벨 2로 오면 레벨 2 보드가 그대로이고 두 보드 모두 저장되어 있다.
- 보드는 JSON 문자열을 거쳐 다시 열어도 레벨별로 남는다. 5개를 넘으면 가장 오래된 것이 빠진다.
- 기존 단일 `progress`만 있는 JSON은 그 레벨 보드로 옮겨진다. 새 JSON의 `progress`는 가장 최근 보드이고 기존 4개 키만 가진다.
- 보드에 찍힌 시드가 현재 배정과 다르거나 배정이 없으면 그 보드는 쓰지 않는다(메타 진행은 유지). 레거시 레벨에 시드가
  찍힌 보드도 쓰지 않는다.
- 레벨을 풀면 그 레벨 보드만 지워진다. 시작 레벨은 프런티어이고 낮은 레벨 보드는 남는다. 데일리 보드는 영향이 없다.
- 결과 화면에 데일리 안내 줄과 세트 목표가 보이고, 1280x720, 390x844, 640x480, 620x349, 560x315에서 Next와 함께 화면 안에 있다.
- 결과 화면 애니메이션이 끝나면 다음 레벨 시드가 저장되어 있고 Enter로 연 퍼즐이 그 퍼즐이다.
- lib/ 문자열은 ASCII다.

## Constraints
- 새 의존성 없음. `nonogrid_progress_v2`의 version은 2 그대로.
- 퍼즐 생성 규칙은 바꾸지 않는다(`adr-line-solvable-generator`).
- 날짜는 지역 달력 날짜(`adr-daily-puzzle`).

## Evidence
- `flutter analyze`, `flutter build web --release`
- `test/level_boards_test.dart`, 수정한 `test/random_assignment_test.dart`
- `reports/next-session-hooks-verification.md`
