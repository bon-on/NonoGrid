#!/usr/bin/env bash
# Builds the CrazyGames upload bundle: build/crazygames/ and
# build/nono-grid-crazygames.zip. See docs/crazygames.md.
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$(pwd)"
OUT="$ROOT/build/crazygames"
ZIP="$ROOT/build/nono-grid-crazygames.zip"
SDK_URL="https://sdk.crazygames.com/crazygames-sdk-v3.js"

rm -rf "$OUT" "$ZIP"
# --wasm: Chromium browsers (Chrome, Edge) load the smaller dart2wasm + skwasm
# build; Firefox, Safari and older browsers use dart2js + CanvasKit (Flutter's
# default wasm allow list; feature-portal-quality-pass).
flutter build web --release --wasm \
  --base-href / \
  --no-web-resources-cdn \
  --dart-define=CRAZYGAMES=true \
  --output "$OUT"

INDEX="$OUT/index.html"
# CrazyGames serves the bundle from an unknown sub path: use a relative base.
perl -pi -e 's#<base href="/">#<base href="./">#' "$INDEX"
# Portal builds must not link out: drop the Bon-on hub nav bar and the space
# reserved for it (see feature-game-hub-navigation).
perl -0pi -e 's#\s*<nav class="games-nav-bar".*?</nav>##s' "$INDEX"
perl -pi -e 's#--games-nav-height: calc\([^;]*\);#--games-nav-height: 0px;#' "$INDEX"
if grep -q -e 'games-nav-bar"' "$INDEX"; then echo "error: hub navigation bar still present in index.html" >&2; exit 1; fi
grep -q -e '--games-nav-height: 0px;' "$INDEX" || { echo "error: hub navigation height was not reset" >&2; exit 1; }
# The SDK must be loaded before the Flutter bootstrap script runs main().
perl -pi -e "s#^(\\s*)(<script src=\"flutter_bootstrap.js\")#\$1<script src=\"$SDK_URL\"></script>\n\$1\$2#" "$INDEX"

grep -q '<base href="./">' "$INDEX" || { echo "error: relative base href missing" >&2; exit 1; }
sdk_line=$(grep -n -m1 -F "$SDK_URL" "$INDEX" | cut -d: -f1 || true)
boot_line=$(grep -n -m1 -F '<script src="flutter_bootstrap.js"' "$INDEX" | cut -d: -f1 || true)
if [[ -z "$sdk_line" || -z "$boot_line" || "$sdk_line" -ge "$boot_line" ]]; then
  echo "error: SDK script must precede flutter_bootstrap.js" >&2
  exit 1
fi

if grep -q -e 'bon-on.github.io' "$INDEX"; then
  echo "error: outbound hub link present in index.html" >&2
  exit 1
fi

# Copied daily results may only carry the CrazyGames page (from the SDK),
# never the GitHub Pages link (feature-daily-puzzle).
[[ -s "$OUT/main.dart.js" ]] || { echo "error: main.dart.js missing" >&2; exit 1; }
for code in main.dart.js main.dart.wasm main.dart.mjs; do
  if grep -a -q -e 'bon-on.github.io' "$OUT/$code"; then
    echo "error: hub link present in $code" >&2
    exit 1
  fi
done

if ! grep -q -e 'user-select: none' "$INDEX"; then
  echo "error: user-select rule missing from index.html" >&2
  exit 1
fi

# Renderer files: the loader picks skwasm (or skwasm_heavy on Chromium builds
# without codecs/break iterators) for the wasm build and canvaskit (chromium/
# or generic) for the JavaScript fallback. wimp is only used with an explicit opt-in flag.
find "$OUT/canvaskit" -name 'wimp.*' -delete
for f in main.dart.js main.dart.wasm main.dart.mjs canvaskit/skwasm.wasm canvaskit/skwasm_heavy.wasm \
  canvaskit/canvaskit.wasm canvaskit/chromium/canvaskit.wasm; do
  [[ -s "$OUT/$f" ]] || { echo "error: $f missing" >&2; exit 1; }
done
grep -q '"compileTarget":"dart2wasm"' "$OUT/flutter_bootstrap.js" || { echo "error: wasm build missing from bootstrap" >&2; exit 1; }
grep -q '"compileTarget":"dart2js"' "$OUT/flutter_bootstrap.js" || { echo "error: JavaScript fallback missing from bootstrap" >&2; exit 1; }
grep -q "renderer: 'canvaskit'" "$OUT/flutter_bootstrap.js" || { echo "error: JavaScript retry missing from bootstrap" >&2; exit 1; }
# Fonts are downloaded before the first frame: keep the subset fonts small.
shopt -s nullglob
fonts=("$OUT"/assets/assets/fonts/Roboto-*.ttf)
shopt -u nullglob
(( ${#fonts[@]} == 4 )) || { echo "error: expected 4 Roboto fonts, found ${#fonts[@]}" >&2; exit 1; }
for font in "${fonts[@]}"; do
  size=$(wc -c <"$font")
  if (( size > 60000 )); then echo "error: $font is not the subset font (tool/subset_fonts.sh)" >&2; exit 1; fi
done

# Debug symbol files are not needed at runtime.
find "$OUT" -name '*.symbols' -delete

file_count=$(find "$OUT" -type f | wc -l | tr -d ' ')
total_kb=$(du -sk "$OUT" | cut -f1)
if (( file_count > 1500 )); then
  echo "error: $file_count files exceeds the CrazyGames limit of 1500" >&2
  exit 1
fi
if (( total_kb > 50 * 1024 )); then
  echo "error: bundle is ${total_kb}KB, above the 50MB limit" >&2
  exit 1
fi

(cd "$OUT" && zip -qr "$ZIP" .)
echo "CrazyGames bundle: $OUT ($file_count files, ${total_kb}KB)"
echo "Upload zip: $ZIP"
