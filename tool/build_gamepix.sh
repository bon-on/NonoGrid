#!/usr/bin/env bash
# Builds the GamePix upload bundle (no portal SDK): build/gamepix/ and
# build/nono-grid-gamepix.zip. See docs/gamepix.md.
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$(pwd)"
OUT="$ROOT/build/gamepix"
ZIP="$ROOT/build/nono-grid-gamepix.zip"

rm -rf "$OUT" "$ZIP"
flutter build web --release \
  --base-href / \
  --no-web-resources-cdn \
  --dart-define=GAMEPIX=true \
  --output "$OUT"

INDEX="$OUT/index.html"
# GamePix serves the bundle from an unknown sub path: use a relative base.
perl -pi -e 's#<base href="/">#<base href="./">#' "$INDEX"

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

# Debug symbol files are not needed at runtime.
find "$OUT" -name '*.symbols' -delete

(cd "$OUT" && zip -qr "$ZIP" .)
unzip -Z1 "$ZIP" | grep -qx 'index.html' || fail "index.html is not at the zip root"

file_count=$(find "$OUT" -type f | wc -l | tr -d ' ')
total_kb=$(du -sk "$OUT" | cut -f1)
zip_kb=$(du -sk "$ZIP" | cut -f1)
cg_count=$(grep -ci crazygames "$OUT/main.dart.js" || true)
echo "GamePix bundle: $OUT ($file_count files, ${total_kb}KB)"
echo "Upload zip: $ZIP (${zip_kb}KB)"
echo "'crazygames' matches in main.dart.js: $cg_count"
