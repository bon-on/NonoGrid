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
flutter build web --release \
  --base-href / \
  --no-web-resources-cdn \
  --dart-define=CRAZYGAMES=true \
  --output "$OUT"

INDEX="$OUT/index.html"
# CrazyGames serves the bundle from an unknown sub path: use a relative base.
perl -pi -e 's#<base href="/">#<base href="./">#' "$INDEX"
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

if ! grep -q -e 'user-select: none' "$INDEX"; then
  echo "error: user-select rule missing from index.html" >&2
  exit 1
fi

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
