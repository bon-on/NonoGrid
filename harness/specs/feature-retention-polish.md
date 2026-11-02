---
id: feature-retention-polish
title: NonoGrid 종이/잉크 시각 개편, 채우기 손맛, 재플레이 동기(별, 앨범, 레벨 지도, 화가 레벨)
status: active
owner: games
related_adrs:
  - adr-spec-driven-delivery
  - adr-line-solvable-generator
  - adr-nono-grid-crazygames-web
  - adr-nono-grid-gamepix-web
related_contracts:
  - contract-nono-grid-mvp
  - contract-nono-grid-crazygames
required_evidence:
  - flutter-analyze
  - flutter-tests
  - web-build
  - portal-builds
  - harness-audit
---

# 기능 명세: NonoGrid 종이/잉크 시각 개편, 채우기 손맛, 재플레이 동기

## Problem
CrazyGames가 같은 계열의 MergeCamp를 "The overall quality of the game does not yet meet the expectations of our
platform"으로 거절했다. NonoGrid도 어두운 단색 배경에 Material 버튼과 회색 격자만 있어 시제품처럼 보인다.
칸을 채우는 순간, 줄이 맞는 순간, 퍼즐을 푼 순간의 연출이 약하고 배경음악이 없다. 레벨마다 최고 기록만
남고 별, 수집, 성장 같은 다시 플레이할 이유가 없다.

## Scope
1. 시각 개편(종이와 잉크, 공예 느낌)
   - 외부 에셋 없이 `CustomPainter`로 그린다. 배경은 공예 책상(나뭇결 또는 크라프트지 질감, 종이 반점,
     연필, 잉크병, 종이학 같은 소품)이고, 보드는 마스킹 테이프로 붙인 종이 카드다.
   - 칸 채우기는 잉크 사각형(살짝 손으로 칠한 듯한 결과 하이라이트), X는 연필 X로 그린다.
   - 테마 4종(꾸미기 전용, 규칙 영향 없음): Notebook(기본, 크림 종이와 남색 잉크), Kraft(갈색 크라프트지와
     먹색), Washi(분홍 화지와 자주 잉크), Midnight(남색 종이와 금색 잉크).
   - 넓은 화면(1280x720, 1366x768 iframe)은 보드를 가운데 두고 왼쪽 패널(레벨, 별, 시간, 최고 기록, 화가 레벨
     바, Levels/Album/Themes 버튼)과 오른쪽 패널(도구, Undo, Check, Restart, 키 안내, 소리, 도움말)을 둔다.
     좁은 화면(390x844)은 위아래로 쌓는다. 어디서도 오버플로가 없다.
2. 손맛(연출은 입력을 막지 않는다. 규칙은 즉시 적용되고 연출은 뒤따른다)
   - 채우기: 새로 칠해진 칸이 획 순서대로 잉크가 번지듯 튀어 오른다. X는 두 획이 그려지듯 나타난다.
   - 줄 완성: 행이나 열의 단서가 맞는 순간 그 줄이 반짝이고 단서 옆에 체크 표시가 그려지며 짧은 차임이 난다.
   - 실수 흔들림: 한 줄의 칠한 칸 수가 단서 합을 넘거나 Check가 틀린 칸을 찾으면 보드가 흔들리고 해당 줄 단서가
     잠깐 빨갛게 표시되며 실수 효과음이 난다. 정답 정보는 새로 드러내지 않는다(넘침은 단서만으로 알 수 있다).
   - 승리: 풀린 그림이 대각선 물결로 레벨별 팔레트 색으로 피어나고(격자선과 X는 사라짐) 색종이 조각이 터진다.
     손으로 만든 그림(Heart, Arrow, House)은 고유 팔레트를 쓴다.
   - 효과는 하나의 시계(Ticker)와 repaint 전용 페인터로 처리하고, 시계는 보드가 다시 만들어져도 이어진다.
3. 레벨 안의 목표: 별 3개
   - 별 1: 퍼즐을 푼다. 별 2: Check가 틀린 칸을 한 번도 찾지 않았다(No mistakes). 별 3: 기준 시간 안에 푼다
     (기준 시간 = 칸 수 x 1.5초 + 20초, 반올림). 레벨 생성 규칙은 바꾸지 않는다.
   - 레벨별 최고 별 수를 저장하고, 진행 중 저장에도 실수 여부를 함께 저장한다(다시 열어도 유지).
4. 레벨 사이의 동기: 결과 화면, 앨범, 레벨 지도, 화가 레벨, 테마
   - 결과 화면(승리 후 그림이 피어난 뒤): 그림 이름 또는 레벨, 시간, 최고 기록, "New best!", 획득 별, 획득 XP,
     화가 레벨 진행 바, 새로 열린 테마, Next(Enter)와 Replay, Album 버튼. Esc는 결과 화면을 닫고 피어난 그림과
     기존 Next 막대를 보여준다.
   - 화가 레벨(XP): 처음 푼 레벨은 크기 x 2 + 별 x 5 XP, 다시 풀면 새로 얻은 별마다 5 XP와 기본 3 XP를 준다.
     레벨 L에서 L+1로 가는 데 40 + 20 x (L-1) XP가 든다. 테마는 Notebook Lv1, Kraft Lv3, Washi Lv6, Midnight Lv10에
     열린다. 열린 테마만 고를 수 있다.
   - 앨범: 푼 퍼즐을 레벨별 팔레트로 색칠한 썸네일과 별로 보여준다. 아직 안 푼 레벨은 보이지 않는다.
   - 레벨 지도: 레벨을 15개씩 페이지로 나눠 구불구불한 길 위의 점으로 보여준다. 푼 레벨은 별, 열린 레벨은 번호,
     잠긴 레벨은 자물쇠로 표시한다. 방향키로 고르고 Enter로 연다.
   - 오버레이(튜토리얼, 결과, 앨범, 지도, 테마)가 열려 있으면 보드 입력이 막히고 시계가 멈추며 gameplayStop이
     나간다. Esc로 닫고, 지도/테마는 Enter로 고른다.
   - 저장: `shared_preferences` 키 `nonogrid_progress_v2`(JSON 하나)에 현재 레벨, 최대 클리어, 레벨별 최고 시간과
     별, XP, 테마, 진행 중 보드를 저장한다. 이 키가 없으면 기존 키(`level`, `maxCleared`, `best_<n>`,
     `progressLevel`, `progressCells`, `progressElapsed`)에서 옮겨 온다. 이미 푼 레벨은 별 1개로 옮기고 XP는
     그 레벨들을 처음 푼 것으로 계산한다. 기존 키는 지우지 않는다. 손상된 값은 기존 키 이전으로, 그것도 없으면
     기본값으로 대체하고 플레이를 막지 않는다. 쓰기 실패는 무시한다. 저장소는 앱 시작 전에 다 읽어 두므로
     읽기 전에 저장하는 일은 없다.
5. 소리
   - 배경음악: 잔잔한 오르골/로파이 루프를 `tool/generate_sounds.py`(표준 라이브러리, 결정적)로 합성한다.
     16000 Hz 모노 16비트, 1 MB 이하, 끊김 없이 반복된다. 웹은 첫 사용자 입력 후 시작하고 탭이 숨으면 멈춘다.
     사용자 소리 토글(효과음과 음악 하나로)과 CrazyGames `muteAudio`(설정 변경 리스너 포함)를 따른다.
     이 게임에는 광고가 없으므로 광고 전후 정지는 해당 없다. iOS/Android는 네이티브 `startLoop`/`stopLoop`로
     반복 재생한다(iOS는 통화 등 중단 후 다시 재생).
   - 새 효과음: `line_done`(줄 완성), `mistake`(실수), `star`(결과 화면 별), `level_up`(화가 레벨 업). 기존
     fill, mark, undo, level_clear는 유지한다. 줄 완성 차임은 fill 소리 위에 겹쳐 난다.

## Acceptance Criteria
- 4개 테마 모두에서 배경, 보드, 칸(빈 칸, 채움, X, 줄 완성, 실수, 승리 색)이 오류 없이 그려진다.
- 칸을 칠하면 즉시 저장/판정되고 연출이 뒤따른다. 줄이 맞으면 반짝임과 체크 표시, 넘치면 흔들림과 실수음.
- 승리하면 그림이 팔레트 색으로 피어나고 색종이가 터진 뒤 결과 화면이 열린다. 결과 화면에 시간, 최고 기록,
  New best, 별, XP, 레벨 바, 새 테마가 보이고 Enter/Next는 다음 레벨, Esc는 닫기다.
- 별 계산(1/2/3), 기준 시간, XP 계산, 레벨 곡선, 테마 해금은 순수 로직이며 단위 테스트가 있다.
- `nonogrid_progress_v2`가 없을 때 기존 키에서 레벨, 최대 클리어, 최고 시간, 진행 중 보드가 그대로 옮겨진다.
  손상된 JSON은 기존 키 이전 또는 기본값으로 대체된다.
- 앨범은 푼 레벨만 색 썸네일과 별로 보이고, 지도는 별/번호/자물쇠를 보이며 잠긴 레벨은 열 수 없다.
- 테마는 요구 레벨 미만이면 고를 수 없고, 고른 테마는 다시 열어도 유지된다.
- 배경음악은 음소거(사용자/플랫폼) 시 멈추고, 웹에서 첫 입력 전에는 시작하지 않으며 탭이 숨으면 멈춘다.
- 키보드 조작(방향키, Space, X, U, R, Enter), 튜토리얼(새 모양), CrazyGames gameplayStart/Stop, GamePix 흐름,
  허브 링크, 기존 테스트가 유지된다(UI가 실제로 바뀐 부분만 테스트를 고친다).
- 1280x720, 1366x768, 390x844에서 메인 화면과 결과 화면, 오버레이가 오버플로 없이 표시된다.
- lib/ 문자열은 영어 ASCII다.

## Constraints
- 새 패키지 의존성 없음. 그림은 코드, 소리는 생성기.
- 퍼즐 생성기, PRNG, 크기 단계, 줄 판정 규칙은 바꾸지 않는다(`adr-line-solvable-generator`). Check는 기존처럼
  자유 모드이고 별 계산에만 쓰인다.
- GamePix: 외부 요청 없음. 음악 루프는 1 MB 이하.
- 단서 글꼴은 11 논리 픽셀 아래로 내려가지 않는다.

## Evidence
- `flutter analyze`, `flutter test`, `flutter test --platform chrome test/web`
- `flutter build web --release --base-href /NonoGrid/`, `tool/build_crazygames.sh`, `tool/build_gamepix.sh`
- 임시 골든 테스트로 1280x720, 390x844, 결과 화면, 테마별 미리보기 PNG 확인
- `node <harness-lab>/dist/index.js audit . --format md`
