---
id: feature-daily-puzzle
title: Daily puzzle, streak with one grace day, daily reward and copy-result text
status: active
owner: games
related_adrs:
  - adr-daily-puzzle
  - adr-line-solvable-generator
  - adr-nono-grid-crazygames-web
  - adr-nono-grid-gamepix-web
related_contracts:
  - contract-nono-grid-mvp
  - contract-nono-grid-crazygames
  - contract-nono-grid-gamepix
required_evidence:
  - flutter-analyze
  - flutter-tests
  - web-build
  - portal-builds
  - harness-audit
---

# 기능 명세: 데일리 퍼즐과 연속 기록(streak)

## Problem
CrazyGames Basic Launch 지표에서 플레이 시간과 D1 리텐션이 낮다(자매 게임 MergeCamp와 같은 패턴). 레벨은 끝없이 이어지지만
"내일 다시 올 이유"가 없다. 매일 하나의 같은 퍼즐, 끊기지 않게 지키고 싶은 연속 기록, 결과를 친구와 비교할 수 있는 텍스트를 더한다.

## Scope
1. 날짜와 퍼즐(`lib/src/meta/daily.dart`, 위젯 없음)
   - 날짜 기준은 기기의 **로컬 달력 날짜**다(결정과 이유: `adr-daily-puzzle`). 하루 번호 `day` = 그 날짜의 UTC 자정 기준
     1970-01-01부터의 일 수. 표시 이름은 `YYYY-MM-DD`.
   - 퍼즐은 기존 `generatePuzzle(sizeOverride, seed)`(줄 판정만으로 풀리는 생성기)로 만든다. 시드는 `day`에서 결정적으로 만들고
     (`SeededRng`만 사용, VM/웹 동일), 크기는 요일로 정한다(월-화 8x8, 수-금 10x10, 토-일 12x12). 같은 날짜면 모든 플레이어가
     같은 퍼즐을 받는다. 생성기, PRNG, 레벨 퍼즐은 바뀌지 않는다.
2. 상태와 연속 기록(순수 함수 + 저장)
   - 오늘의 상태: New(시작 전) / In progress(오늘 퍼즐의 저장된 보드가 있음) / Done(오늘 풀었음, 시간과 별 표시).
   - 연속 기록: 데일리를 푼 날을 하루씩 이어 센다. 하루를 빠뜨리면 **유예(grace) 1회**가 자동으로 그 하루를 메워 기록을
     지킨다(빠진 날은 기록 수에 더하지 않는다). 유예를 쓰면 데일리를 7번 더 풀어야 다시 채워진다. 이틀 이상 빠지거나 유예가 없으면
     기록은 1부터 다시 시작한다. 최고 기록(best streak)과 총 푼 횟수를 남긴다. 이 규칙은 데일리 화면에 한 문장으로 보여 준다.
   - 화면의 현재 기록: 마지막으로 푼 날이 오늘/어제면 유지, 그제이고 유예가 있으면 "유예가 어제를 지켜 준다"로 유지, 그 밖에는 0.
   - 시계 조작에 관대하게: 날짜가 마지막으로 푼 날보다 이전이면 퍼즐은 풀 수 있지만 보상과 기록 변화가 없다. 어떤 값도 음수가
     되지 않고 예외로 멈추지 않는다. 미래로 시계를 돌려 얻은 기록은 실제 날짜가 따라올 때까지 이후 보상을 막으므로 따로 막지 않는다.
   - 자정을 넘겨 푼 경우: 보드를 연 날짜(`day`)로 기록한다.
3. 보상(기존 XP/테마/앨범 체계와 일관)
   - 처음 푼 그날의 데일리는 기존 규칙대로 별(`starsFor`)과 첫 클리어 XP(`clearXp`, 크기 x 2 + 별 x 5)를 받는다.
   - 데일리 전용 보상: 데일리 보너스 XP = 10 + 5 x min(연속 기록 - 1, 4)(10~30 XP). XP는 화가 레벨과 테마 해금으로 이어진다.
   - 앨범 상단에 데일리 기록(총 푼 횟수, 최고 연속 기록)을 보여 준다.
   - 논리 힌트 연계(무료 도움 1회)는 새 경제 요소가 필요하므로 이번 범위에서 제외한다.
4. 화면
   - 시작 화면(게임 화면) 데일리 카드: 넓은 화면은 왼쪽 패널, 좁은 화면은 메타 버튼 아래 한 줄. 날짜/크기, 상태, 현재 연속 기록을 보인다.
     카드를 누르거나 `D` 키로 데일리 오버레이를 연다.
   - 데일리 오버레이: 날짜, 크기, 상태, 현재/최고 연속 기록, 유예 상태(준비됨 / N번 더 풀면 채워짐), 최근 7일 표시, 규칙 문장,
     보상 안내. Enter = Play/Continue(완료 시 닫기), `C` = 결과 복사(완료 시), `L` = 레벨로 돌아가기(데일리 플레이 중), Esc = 닫기.
   - 데일리 플레이: 같은 보드/도구/Check/논리 힌트/Undo를 쓴다. 상단은 "Daily YYYY-MM-DD"와 "Back to levels" 버튼. 레벨 진행 중
     보드는 따로 저장되어 돌아가면 그대로 이어진다. 오버레이가 열리면 기존처럼 시계가 멈추고 gameplayStop이 나간다.
   - 결과 요약(데일리): 시간, 별, XP(퍼즐 + 데일리 보너스), 연속 기록과 다음 목표("Come back tomorrow for streak N+1"),
     유예 사용 여부, Copy result 버튼. Enter = 레벨로 돌아가기, `C` = 복사, Esc = 그림 보기.
5. 결과 복사(텍스트만)
   - `NonoGrid Daily YYYY-MM-DD: NxN in M:SS, S/3 stars, streak K` + 빌드별 링크.
   - 빌드별 링크(`GamePlatform.shareLink`): Pages/모바일 `https://bon-on.github.io/NonoGrid/`, CrazyGames는 SDK가 알려 주는
     CrazyGames 게임 페이지 주소(`SDK.game.link`, https이고 crazygames 호스트일 때만)이고 없으면 링크 없음, GamePix는 항상 없음.
     링크는 텍스트일 뿐 게임이 열거나 이동하지 않는다.
   - Flutter `Clipboard` 실패 시 웹에서는 숨긴 textarea + `execCommand('copy')`를 한 번 더 시도한다. 성공 "Copied!", 실패 "Could not copy"
     토스트. 예외로 멈추지 않는다.
6. 저장: 기존 `nonogrid_progress_v2` JSON 안의 선택 키 `daily`(`last`, `streak`, `best`, `grace`, `refill`, `total`, `days`,
   `result`, `progress`). 없으면 기본값, 손상된 필드는 그 필드만 기본값. 레벨 데이터 파싱에 영향을 주지 않는다. CrazyGames 빌드에서는
   기존 CloudPrefsStore 경로로 자동 동기화된다.

## Acceptance Criteria
- 같은 날짜는 항상 같은 퍼즐(시드, 크기, 해답)이고 날짜가 다르면 대체로 다르다. 1년치(366일) 데일리가 모두 줄 판정으로 풀리고
  대체 패턴(fallback)을 쓰지 않는다. 레벨 퍼즐(`puzzleForLevel`, 할당 시드)은 바뀌지 않는다.
- 연속 기록 규칙: 연속 날 +1, 하루 빠짐 + 유예 있음 → +1 하고 유예 사용, 유예 없음 또는 이틀 이상 빠짐 → 1, 같은 날 다시 → 변화 없음,
  과거 날짜 → 보상 0과 변화 없음, 유예는 7번 풀면 다시 준비됨, 최고 기록 유지. 화면용 현재 기록(오늘/어제/그제+유예/끊김)과
  보너스 XP 공식이 단위 테스트로 확인된다. 음수나 예외가 없다.
- 데일리 카드가 New/In progress/Done과 현재 연속 기록을 보이고, 데일리를 풀면 Done과 늘어난 기록, 결과 요약(다음 목표, 보너스, 복사)이 보인다.
- 데일리 진행 중 보드와 레벨 진행 중 보드가 서로 덮어쓰지 않고, 앱을 다시 열어도 데일리 보드가 이어진다(같은 날일 때만).
- `daily` 키가 없거나 손상되어도 레벨 진행도는 그대로 읽히고, 새 키는 CloudPrefsStore 계정 사본(`prefs_v1`)에 들어간다.
- 결과 텍스트에 Pages 링크(기본), GamePix 링크 없음, CrazyGames는 유효한 SDK 링크만 들어간다. 복사 실패는 토스트만 보인다.
  GamePix `main.dart.js`에는 `crazygames`, `bon-on.github.io` 문자열이 없다(빌드 스크립트가 검사).
- 키보드만으로 데일리 열기(D), 시작(Enter), 복사(C), 돌아가기(L/Enter), 닫기(Esc)가 된다.
- 390x844, 1280x720, 1366x768, 844x390에서 메인 화면, 데일리 오버레이, 데일리 결과 요약이 오버플로 없이 보인다.
- lib/ 문자열은 영어 ASCII. 광고, 리더보드, 네트워크 동작은 바뀌지 않는다. 기존 테스트가 통과한다.

## Plan / check mapping
| Requirement | Files | Check |
|---|---|---|
| 날짜, 시드, 크기, 연속 기록, 보너스 | `lib/src/meta/daily.dart` | `test/daily_test.dart` |
| 저장, 보상, 클라우드 키 | `lib/src/storage.dart`, `lib/src/meta/progress_rules.dart` | `test/daily_test.dart`, `test/crazygames_prefs_store_test.dart` |
| 카드, 오버레이, 데일리 플레이, 요약, 키보드, 레이아웃 | `lib/src/ui/game_screen.dart`, `lib/src/ui/daily_ui.dart`, `lib/src/ui/overlays.dart` | `test/daily_screen_test.dart` |
| 결과 복사, 빌드별 링크 | `lib/src/share/*`, `lib/src/platform/*` | `test/daily_screen_test.dart`, `test/web/*`, `tool/build_gamepix.sh` |

## Constraints
- 새 패키지 없음, 네트워크 요청 없음, 광고/리더보드 변화 없음.
- 생성기와 PRNG는 그대로(`adr-line-solvable-generator`). 데일리는 새 시드 입력만 쓴다.
- 저장 형식은 하위 호환(버전 2 유지, 선택 키 추가).

## Evidence
- `flutter analyze`, `flutter test`, `flutter test --platform chrome test/web`
- `flutter build web --release --base-href /NonoGrid/`, `tool/build_crazygames.sh`, `tool/build_gamepix.sh`
- `node <harness-lab>/dist/index.js audit . --format md`
