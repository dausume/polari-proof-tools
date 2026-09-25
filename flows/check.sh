#!/bin/sh
# check.sh <file.lean> [timeout_s] — check ONE theorem file against the pinned toolchain and print the verdict line the
# framework parses, plus the pins the ProofRun cites:
#   POLARI_PROOF ok|error <statement_hash-from-the-file-header|->
#   POLARI_PINS lean=<lean-toolchain> mathlib=<rev from lake-manifest.json>
# Runs `lake env lean` inside the project (so Mathlib's oleans resolve); exit code = lean's (124 on timeout).
set -u
PROJ="${POLARI_PROOF_PROJECT:-/proofs}"
FILE="$1"; TO="${2:-600}"
cd "$PROJ" || { echo "POLARI_PROOF error -"; exit 2; }
HASH=$(grep -m1 '^POLARI_STATEMENT_HASH ' "$FILE" 2>/dev/null | awk '{print $2}')
[ -n "$HASH" ] || HASH=-
LEAN=$(cat lean-toolchain 2>/dev/null)
ML=$(python3 -c "import json;m=json.load(open('lake-manifest.json'));print(next(p['rev'] for p in m['packages'] if p['name']=='mathlib'))" 2>/dev/null || echo -)
timeout "$TO" lake env lean "$FILE"
RC=$?
if [ "$RC" -eq 0 ]; then echo "POLARI_PROOF ok $HASH"; else echo "POLARI_PROOF error $HASH"; fi
echo "POLARI_PINS lean=$LEAN mathlib=$ML"
exit $RC
