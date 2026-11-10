#!/usr/bin/env bash
# Subsets the bundled Roboto fonts to Basic Latin + Latin-1 + common
# punctuation. The web engine downloads every bundled font before the first
# frame, so smaller files shorten loading (feature-portal-quality-pass).
#
# Usage: tool/subset_fonts.sh <dir-with-original-Roboto-*.ttf>
# Needs fonttools (`pip install fonttools`). The originals are the upstream
# Roboto release files (Apache License 2.0, assets/fonts/Roboto_LICENSE.txt);
# they are also in this repository's history before the subset commit.
# lib/ must stay ASCII-only (tool/build_gamepix.sh checks it), so this range
# covers every string the game draws.
set -euo pipefail

SRC="${1:?usage: tool/subset_fonts.sh <dir-with-original-fonts>}"
cd "$(dirname "$0")/.."
UNICODES="U+0020-007E,U+00A0-00FF,U+2013-2014,U+2018-201D,U+2022,U+2026"
for weight in Regular Medium Bold Black; do
  pyftsubset "$SRC/Roboto-$weight.ttf" \
    --unicodes="$UNICODES" \
    --layout-features='kern,liga,calt,tnum,lnum' \
    --no-hinting \
    --output-file="assets/fonts/Roboto-$weight.ttf"
done
ls -l assets/fonts/Roboto-*.ttf
