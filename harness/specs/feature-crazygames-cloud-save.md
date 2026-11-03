---
id: feature-crazygames-cloud-save
title: CrazyGames 빌드의 진행도를 SDK Data 모듈(계정 저장)로 저장
status: active
owner: games
related_adrs:
  - adr-nono-grid-crazygames-web
related_contracts:
  - contract-nono-grid-crazygames
required_evidence:
  - flutter-analyze
  - flutter-tests
  - crazygames-web-build
  - harness-audit
---

# 기능 명세: CrazyGames 계정 저장

## Problem
모든 진행도(클리어 기록, 진행도, 튜토리얼, 소리 설정)는 `shared_preferences`, 즉 브라우저 localStorage에만 있다.
CrazyGames에 로그인한 플레이어도 기기나 브라우저를 바꾸면 진행도가 사라진다. CrazyGames SDK의 Data 모듈은
로그인 사용자의 데이터를 계정에 동기화하고, 게스트는 localStorage에 두었다가 로그인 시 계정으로 옮긴다.

## Scope
- `--dart-define=CRAZYGAMES=true` 빌드에서 SDK 초기화가 성공하면 `SharedPreferencesStorePlatform.instance`를
  Data 모듈 기반 저장소로 바꾼다. 게임 코드의 저장소 클래스는 그대로 `SharedPreferences`를 쓴다.
- 모든 환경설정 값은 Data 모듈의 키 하나(`prefs_v1`, JSON 객체)에 저장한다. 같은 값을 기존 localStorage에도 계속 써서
  Data 모듈이 꺼져도 로컬 진행도가 남는다.
- 스냅샷은 `{rev, owner, values}`다. 매 쓰기마다 `rev`가 오르고, localStorage `cg_prefs_stamp_v1`에 로컬 사본의
  `rev`와 `owner`(사용자 이름, 게스트 null)를 남긴다.
- 시작 값 선택: 로컬 사본이 현재 사용자 것이고 `rev`가 계정 사본 이상이면 로컬(SDK 디바운스로 못 올라간 저장 보호),
  아니면 계정 사본, 둘 다 아니면 빈 값. 다른 사용자의 로컬 사본은 쓰지 않는다. 표식 없는 이전 버전 로컬 진행도는 계정 사본이
  없을 때만 이어받는다(이미 다른 기기에서 계정 사본을 만든 경우 그 기기의 이전 로컬 진행도는 이어받지 않는다는 절충).
- 로컬 사본을 고르지 않은 경우(계정 사본 또는 빈 값) 로컬 사본을 그 값으로 통째로 바꾼 뒤 표식을 남긴다. 남은 예전 키가 다음
  실행에서 이기지 않게 하기 위해서다.
- 다른 사용자로 바뀌면(로그아웃 포함) 이전 사용자의 로컬 사본은 지워진다. 계정에 올라가지 못한 저장(쓰기 실패, SDK 디바운스
  직후 로그아웃)은 그때 잃을 수 있다. 드문 경우라 받아들인다.
- 리비전은 충돌 해결이 아니라 단순 카운터다. 두 기기에서 동시에 플레이하면 마지막에 쓴 쪽이 이긴다(last writer wins).
- 로그인/로그아웃(`user.addAuthListener`)으로 사용자가 바뀌면 페이지를 다시 읽어 오래된 메모리 값이 다른 사용자의 데이터를
  덮어쓰지 않게 한다. 리스너는 처음 사용자를 확인하기 전에 등록하고, 그 사이 이벤트는 기록했다가 계정 저장이 켜진 뒤 비교한다.
  처음 사용자를 알 수 없으면 계정 저장을 켜지 않고, 지킬 계정 상태가 없으므로 다시 읽지도 않는다.
- Data 모듈 호출이 실패하거나(`dataModuleDisabled` 등) SDK가 없으면 기존 localStorage 저장을 그대로 쓴다.
- 모바일, GitHub Pages, GamePix 빌드는 바뀌지 않는다.

## Acceptance Criteria
- CrazyGames 빌드에서 저장한 값이 Data 모듈 `prefs_v1`과 localStorage 양쪽에 기록된다.
- 같은 사용자의 더 새로운 로컬 사본은 계정 사본보다 우선하고, 그 외에는 계정 사본이 우선한다. 다른 사용자의 로컬 사본은
  쓰이지 않는다. 계정 사본이 없고 로컬 표식도 없으면 기존 localStorage 값을 읽는다.
- 같은 사용자의 인증 이벤트는 다시 읽기를 일으키지 않고, 다른 사용자나 로그아웃은 다시 읽는다.
- 손상된 `prefs_v1`(JSON 아님, 객체 아님)은 무시하고 localStorage 값으로 대체한다.
- Data 모듈 `getItem`이 예외를 던지면 저장소를 바꾸지 않는다.
- SDK가 없거나 환경이 `crazygames`/`local`이 아니면 저장소를 바꾸지 않는다.
- 업로드 시 포털 제출 화면에서 Progress Save를 "Data Module 사용"으로 선택해야 한다(docs/crazygames.md에 기록).

## Constraints
- 새 패키지를 추가하지 않는다. 이미 잠금 파일에 있는 `shared_preferences_platform_interface`를 직접 의존성으로만 올린다.
- 저장 데이터는 1 MB 한도보다 훨씬 작아야 한다.

## Evidence
- `flutter analyze`, `flutter test`, `flutter test --platform chrome test/web`
- `tool/build_crazygames.sh`
- `node <harness-lab>/dist/index.js audit . --format md`
