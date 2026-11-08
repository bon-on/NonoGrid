# CrazyGames build

Building with `--dart-define=CRAZYGAMES=true` enables the CrazyGames HTML5 SDK v3
gameplay events. Builds without the flag (GitHub Pages, mobile) never touch the SDK.

## Build

```sh
tool/build_crazygames.sh
```

Output:

- `build/crazygames/`: bundle folder
- `build/nono-grid-crazygames.zip`: zip to upload

The script runs `flutter build web --release --base-href / --no-web-resources-cdn
--dart-define=CRAZYGAMES=true`, switches `<base href>` to `./`, inserts the SDK script
before `flutter_bootstrap.js`, removes `*.symbols` and checks the limits (at most 1500
files, 50MB) and the result. It fails loudly if any check fails.

## Tests

```sh
flutter test                              # game flow with a recording fake platform
flutter test --platform chrome test/web   # SDK adapter against a fake window.CrazyGames
```

## Local check

```sh
cd build && python3 -m http.server 8765
# open http://localhost:8765/crazygames/index.html
```

On `localhost` the SDK environment is `local`; the console logs
`Requesting gameplay start` style messages.

## SDK events

| When | Call |
|---|---|
| App start | `SDK.init()`; SDK disabled unless environment is `crazygames` or `local` |
| Playing (tutorial closed, puzzle not cleared) | `gameplayStart()` |
| How-to-play overlay opens | `gameplayStop()` |
| Overlay closes | `gameplayStart()` |
| puzzle cleared | `gameplayStop()` |
| Next puzzle / restart after clear | `gameplayStart()` |

Only transitions are reported. On first launch the first start comes after the tutorial
closes.

## Progress Save

Progress is saved through the SDK Data module (`feature-crazygames-cloud-save`). On the submission screen, **Progress Save**
must be set to "Yes, using the Data Module from the CrazyGames SDK"; otherwise the Data module is disabled and progress
stays in browser localStorage only.

- All preferences are stored in one Data module key, `prefs_v1`, as `{rev, owner, values}`, and mirrored to localStorage.
  localStorage `cg_prefs_stamp_v1` records the mirror's owner (username, null for guests) and revision.
- At startup the local mirror wins when it belongs to the same player and its revision is not older than the account copy;
  otherwise the account copy wins. Another player's mirror is never used. Progress from before this feature is adopted only
  when no account copy exists.
- While cloud save is active, the page reloads (`user.addAuthListener`) only when the player changes
  to a different player or logs out. If the initial user cannot be read, cloud save stays off.

## Daily puzzle, streak and album sets

- The daily streak, the daily board/result (`daily`) and rewarded album sets
  (`setsAwarded`) live inside `nonogrid_progress_v2`, so they are part of the
  `prefs_v1` Data module snapshot like the rest of the progress
  (`test/crazygames_prefs_store_test.dart` checks the sync).
- The daily uses the player's local date (`adr-daily-puzzle`); no network.
- Copy result puts plain text on the clipboard. The only link it may contain
  is `SDK.game.link` when the SDK reports an https CrazyGames URL; otherwise
  the text has no link. The GitHub Pages link is not in this bundle
  (`tool/build_crazygames.sh` fails if `bon-on.github.io` appears in
  `main.dart.js`). The game never navigates to the link.
- Clipboard access inside the portal iframe depends on its permissions
  policy; when both the async clipboard and the `execCommand` fallback are
  blocked the player sees "Could not copy". Not verified on the live portal.

## Disabled in the CrazyGames build

Nothing needs disabling: the game has no ads, no leaderboard or result upload and no
hub navigation bar, and `index.html` contains no outbound links.

## Upload checklist

- [ ] Submit through Basic Launch first (ads are not allowed there).
- [ ] Orientation: portrait and landscape both work; the board fits any size.
- [ ] Input: mouse/touch and keyboard (see README).
- [ ] Prepared covers: 1920x1080, 800x1200, 800x800.
- [ ] Check loading and gameplay events in the portal QA tool.
- [ ] Progress Save: set to "Yes, using the Data Module from the CrazyGames SDK".
- [ ] In portal QA: solve the daily, check the streak survives a reload and a second device (logged in), and try Copy result.

## Launch verification — 2026-11-06

- Covers are maintained in the workspace marketing folder (`../_marketing/NonoGrid/crazygames-launch/`) in landscape 1920x1080, portrait 800x1200 and square 800x800 sizes.
- Backgrounding or losing focus pauses SDK gameplay and sound; resume starts gameplay only if no tutorial/menu/result is open. Repeated lifecycle transitions do not duplicate events.
- Local automated SDK tests use a fake SDK. Final portal QA must still confirm the real uploaded build's loading, inputs, audio mute and account progress persistence.
- The self-contained release packet is prepared at `../_marketing/crazygames-launch-2026-11-06/NonoGrid/` (ZIP, media and submission metadata). Portal upload and real QA are pending authenticated portal access.
