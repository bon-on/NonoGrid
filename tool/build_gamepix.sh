#!/usr/bin/env bash
# Builds the GamePix upload bundle (no portal SDK): build/gamepix/ and
# build/nono-grid-gamepix.zip. See docs/gamepix.md.
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$(pwd)"
OUT="$ROOT/build/gamepix"
ZIP="$ROOT/build/nono-grid-gamepix.zip"

rm -rf "$OUT" "$ZIP"
# --wasm: Chromium browsers (Chrome, Edge) load the smaller dart2wasm + skwasm
# build; Firefox, Safari and older browsers use dart2js + CanvasKit (Flutter's
# default wasm allow list; feature-portal-quality-pass).
flutter build web --release --wasm \
  --base-href / \
  --no-web-resources-cdn \
  --dart-define=GAMEPIX=true \
  --output "$OUT"

INDEX="$OUT/index.html"
# GamePix serves the bundle from an unknown sub path: use a relative base.
perl -pi -e 's#<base href="/">#<base href="./">#' "$INDEX"
# Portal builds must not link out: drop the Bon-on hub nav bar and the space
# reserved for it (see feature-game-hub-navigation).
perl -0pi -e 's#\s*<nav class="games-nav-bar".*?</nav>##s' "$INDEX"
perl -pi -e 's#--games-nav-height: calc\([^;]*\);#--games-nav-height: 0px;#' "$INDEX"
if grep -q -e 'games-nav-bar"' "$INDEX"; then echo "error: hub navigation bar still present in index.html" >&2; exit 1; fi
grep -q -e '--games-nav-height: 0px;' "$INDEX" || { echo "error: hub navigation height was not reset" >&2; exit 1; }

fail() { echo "error: $1" >&2; exit 1; }

# Glyphs Roboto lacks make Flutter fetch a fallback font from fonts.gstatic.com.
if find lib -name '*.dart' -print0 | xargs -0 perl -ne 'print "$ARGV:$.: $_" if /[^\x00-\x7F]/' | grep -q .; then
  fail "non-ASCII characters in lib/ may trigger external fallback font requests"
fi

grep -q '<base href="./">' "$INDEX" || fail "relative base href missing"
grep -q -e 'user-select: none' "$INDEX" || fail "user-select rule missing from index.html"
grep -q -e 'user-scalable=no' "$INDEX" || fail "viewport user-scalable=no missing"
grep -q -e 'touch-action: none' "$INDEX" || fail "touch-action rule missing"
if grep -q -e 'crazygames-sdk' "$INDEX"; then fail "CrazyGames SDK script present"; fi
if grep -q -e 'bon-on.github.io' "$INDEX"; then fail "outbound hub link present in index.html"; fi
if grep -Eq -e '(src|href)="https?://' "$INDEX"; then fail "external resource in index.html"; fi
grep -q '"family":"Roboto"' "$OUT/assets/FontManifest.json" || fail "Roboto missing from FontManifest.json"

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

(cd "$OUT" && zip -qr "$ZIP" .)
zip_list=$(unzip -Z1 "$ZIP")
grep -qx 'index.html' <<<"$zip_list" || fail "index.html is not at the zip root"

file_count=$(find "$OUT" -type f | wc -l | tr -d ' ')
total_kb=$(du -sk "$OUT" | cut -f1)
zip_kb=$(du -sk "$ZIP" | cut -f1)
JS="$OUT/main.dart.js"
[[ -s "$JS" ]] || fail "main.dart.js missing"
cg_count=0
# GamePix forbids outbound links: no portal or hub URL may ship in the code
# (feature-daily-puzzle copy text has no link in this build). The wasm build
# keeps string literals in main.dart.wasm and main.dart.mjs.
for code in main.dart.js main.dart.wasm main.dart.mjs; do
  n=$(grep -a -ci crazygames "$OUT/$code" || true)
  (( n == 0 )) || fail "'crazygames' found in $code"
  cg_count=$((cg_count + n))
  if grep -a -q -e 'bon-on.github.io' "$OUT/$code"; then fail "hub link found in $code"; fi
done
echo "GamePix bundle: $OUT ($file_count files, ${total_kb}KB)"
echo "Upload zip: $ZIP (${zip_kb}KB)"
echo "'crazygames' matches in main.dart.js/.wasm/.mjs: $cg_count"
