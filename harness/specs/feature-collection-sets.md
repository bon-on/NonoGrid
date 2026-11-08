---
id: feature-collection-sets
title: Album picture sets with completion progress, next-picture goal and set reward
status: active
owner: games
related_adrs:
  - adr-daily-puzzle
  - adr-line-solvable-generator
related_contracts:
  - contract-nono-grid-mvp
required_evidence:
  - flutter-analyze
  - flutter-tests
  - web-build
  - portal-builds
  - harness-audit
---

# 기능 명세: 앨범 세트 완성

## Problem
앨범은 푼 그림을 나열할 뿐 "얼마나 모았고 무엇을 더 풀면 무언가를 완성하는지"가 보이지 않는다. 수집 완성 목표와 보상을 더해
한 판 더 하게 만든다.

## Scope
- 세트: 레벨 10개씩 하나의 세트(Set 1 = 레벨 1-10, Set 2 = 11-20, ...). 이름은 고정 목록(Sketchbook, Garden, Seaside, Orchard,
  Workshop, Night Sky, Harbor, Meadow, Old Town, Festival)을 순환하고 11번째부터는 "II"처럼 회차를 붙인다. 순수 로직은
  `lib/src/meta/collection.dart`.
- 진행도: 세트마다 푼 그림 수/10, 진행 바, 완성 표시(코드로 그린 금색 도장). 데이터는 기존 레벨 기록(별 > 0)만 쓴다.
- 다음 목표: 지금 열 수 있는(<= unlocked) 안 푼 레벨이 있는 미완성 세트 중 남은 그림이 가장 적은 세트(동점은 앞 세트)의
  가장 낮은 안 푼 레벨. "Solve Level N: K more to complete <Set> (+50 XP)". 앨범 맨 위와 레벨 결과 요약에 보인다.
- 보상: 세트를 완성하면 세트 보너스 50 XP(기존 화가 레벨/테마 해금으로 이어짐). 받은 세트 번호는 `nonogrid_progress_v2`의 선택 키
  `setsAwarded`에 남겨 한 번만 받는다. 이 기능 이전에 이미 완성한 세트도 다음 클리어 때 같은 방식으로 받는다(요약에 보임).
- 앨범: 세트별 구역(이름, N/10, 바, 도장)과 10칸. 푼 칸은 기존 썸네일과 별, 안 푼 칸은 그림을 드러내지 않는 빈 칸(레벨 번호, 열 수 있으면
  누르면 그 레벨로 이동). 기존 명세의 "안 푼 레벨은 보이지 않는다"는 "안 푼 그림은 보이지 않는다"로 좁혀진다(빈 칸만 보인다).
  보이는 세트는 Set 1부터 현재 열린 레벨이 속한 세트까지. 앨범에서 Enter = 다음 목표 레벨 열기(없으면 닫기), Esc = 닫기.
- 결과 요약: 이번 클리어로 완성한 세트가 있으면 "Set complete: <name> +50 XP" 줄, 없으면 다음 목표 한 줄.

## Acceptance Criteria
- 세트 범위, 이름(회차 포함), 진행도, 다음 목표 선택(동점 규칙, 잠긴 레벨 제외, 모두 완성 시 없음), 보너스가 단위 테스트로 확인된다.
- 세트의 마지막 그림을 풀면 XP가 퍼즐 XP + 50만큼 오르고 요약에 세트 완성이 보이며, 같은 세트로 두 번 받지 않는다(다시 열어도).
- `setsAwarded`가 없거나 손상되어도(배열 아님, 음수, 문자열) 레벨 진행도는 그대로이고 예외가 없다.
- 앨범에 세트 진행도/바/다음 목표가 보이고, 안 푼 그림의 모양과 이름은 보이지 않으며 기존 앨범 테스트(푼 그림만 이름 표시)가 통과한다.
- 1280x720, 1366x768, 390x844, 844x390에서 앨범과 요약이 오버플로 없이 보인다. 새 문자열은 영어 ASCII.

## Plan / check mapping
| Requirement | Files | Check |
|---|---|---|
| 세트 계산, 다음 목표, 보너스 | `lib/src/meta/collection.dart` | `test/collection_test.dart` |
| 보상 지급과 저장 | `lib/src/storage.dart`, `lib/src/meta/progress_rules.dart` | `test/collection_test.dart` |
| 앨범/요약 UI, 키보드 | `lib/src/ui/overlays.dart`, `lib/src/ui/game_screen.dart` | `test/collection_screen_test.dart`, `test/screen_meta_test.dart` |

## Constraints
- 새 아트 에셋 없음(도장은 CustomPainter). 새 패키지와 네트워크 없음. 레벨 생성과 별 규칙은 바뀌지 않는다.

## Evidence
- `flutter analyze`, `flutter test`, `flutter test --platform chrome test/web`
- Pages/CrazyGames/GamePix 빌드 스크립트, harness audit
