#!/usr/bin/env bash
# Regression gate: rerun the paper's tracking chain on cached inputs and check that the
# output is byte-identical to the result files submitted to the evaluation servers.
#
# Chain (all paper rows): online tracker -> interpolate (gap 10) -> offline tracklet merge
# (cos 0.85, gap 300, motion gate off, split).
#
# Usage:
#   scripts/regression_gate.sh CACHE_ROOT REF_ROOT [row ...]
#
#   CACHE_ROOT  directory with detections/, cmc_cache/, emb_cache/
#   REF_ROOT    directory with the reference submission zips
#   row         any of: sportsmot dancetrack sportsmot_deepeiou (default: all)
#
# Env: PYTHON (default: python), WORK (default: mktemp -d)
set -euo pipefail

if [[ $# -lt 2 ]]; then
    sed -n '2,16p' "$0"; exit 2
fi
CACHE=$(realpath "$1"); REF=$(realpath "$2"); shift 2
ROWS=("${@:-sportsmot dancetrack sportsmot_deepeiou}")
ROWS=(${ROWS[@]})
REPO=$(cd "$(dirname "$0")/.." && pwd)
PY=${PYTHON:-python}
WORK=${WORK:-$(mktemp -d)}
export PYTHONPATH="$REPO${PYTHONPATH:+:$PYTHONPATH}"

# row -> config | detections | cmc cache | embeddings | reference zip
declare -A ROW=(
    [sportsmot]="sportsmot.yaml|sportsmot_test_yolox_mix|sportsmot_test|sportsmot_test_osnet|arcsort_sportsmot_test_v8.zip"
    [dancetrack]="dancetrack.yaml|dancetrack_test_yolox_x_norm|dancetrack_test|dancetrack_test|arcsort_dancetrack_test_v7.zip"
    [sportsmot_deepeiou]="sportsmot_deepeiou_inputs.yaml|sportsmot_test_deepeiou|sportsmot_test|sportsmot_test_deepeiou|arcsort_sportsmot_test_v5.zip"
)

failed=0
for row in "${ROWS[@]}"; do
    IFS='|' read -r cfg det cmc emb zip <<< "${ROW[$row]:?unknown row: $row}"
    out="$WORK/$row"
    rm -rf "$out"; mkdir -p "$out"
    echo "[$row] online tracker ($cfg)"
    "$PY" "$REPO/tools/run_cached.py" --config "$REPO/configs/paper/$cfg" \
        --detections "$CACHE/detections/$det" --cmc-cache "$CACHE/cmc_cache/$cmc" \
        --emb-cache "$CACHE/emb_cache/$emb" --output "$out/online" > "$out/online.log" 2>&1
    echo "[$row] interpolate"
    "$PY" "$REPO/tools/interpolate_tracks.py" --input "$out/online" --output "$out/interp" \
        --max-gap 10 > "$out/interp.log" 2>&1
    echo "[$row] merge"
    "$PY" "$REPO/tools/merge_tracklets.py" --input "$out/interp" \
        --emb-cache "$CACHE/emb_cache/$emb" --output "$out/final" \
        --merge-thresh 0.85 --max-gap 300 --motion-tol inf --split > "$out/merge.log" 2>&1

    unzip -qo "$REF/$zip" -d "$out/ref"
    n=0; bad=0
    while IFS= read -r -d '' f; do
        n=$((n + 1))
        cmp -s "$f" "$out/final/$(basename "$f")" || { bad=$((bad + 1)); echo "  DIFF $(basename "$f")"; }
    done < <(find "$out/ref" -name '*.txt' -print0)
    if [[ $n -gt 0 && $bad -eq 0 ]]; then
        echo "[$row] PASS: $n/$n sequences byte-identical to $zip"
    else
        echo "[$row] FAIL: $bad of $n sequences differ from $zip"; failed=1
    fi
done
echo "work dir: $WORK"
exit $failed
