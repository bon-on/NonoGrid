#!/usr/bin/env bash
# Checks that the Dart VM, dart2js and dart2wasm generate identical puzzles
# (feature-portal-quality-pass, adr-web-wasm-portal-build). Needs Node 22+
# for WasmGC. `flutter test --platform chrome --wasm` is the in-browser
# equivalent but can hang on some machines, so this runs the same
# fingerprints without a browser.
set -euo pipefail
cd "$(dirname "$0")/.."
PKG="$(pwd)/.dart_tool/package_config.json"
[[ -f "$PKG" ]] || flutter pub get >/dev/null
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
vm=$(dart run --packages="$PKG" tool/parity/main.dart)
dart compile js --packages="$PKG" -O4 -o "$TMP/out.js" tool/parity/main.dart >/dev/null
js=$(node "$TMP/out.js")
dart compile wasm --packages="$PKG" -o "$TMP/out.wasm" tool/parity/main.dart >/dev/null
wasm=$(cd "$TMP" && node --input-type=module -e "
import { readFileSync } from 'node:fs';
const m = await import('./out.mjs');
const mod = await WebAssembly.compile(readFileSync('out.wasm'), { builtins: ['js-string'] });
m.invoke(await m.instantiate(Promise.resolve(mod), {}));")
echo "vm:   $(echo $vm)"
echo "js:   $(echo $js)"
echo "wasm: $(echo $wasm)"
[[ "$vm" == "$js" && "$vm" == "$wasm" ]] || { echo "error: runtimes disagree" >&2; exit 1; }
echo "runtime parity: ok"
