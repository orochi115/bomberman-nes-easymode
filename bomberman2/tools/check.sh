#!/bin/bash
set -o pipefail
# Self-check after editing db/: lint, regenerate, byte-exact US, JP and EU builds,
# and a quick relocation test.   Usage: tools/check.sh [--full]
#   --full  run every relocation scenario for both regions (slow, ~15 min)
cd "$(dirname "$0")/.."
fail=0
step() { echo "== $*"; }

step "db lint"
python3 tools/db.py lint | tail -20 || fail=1

step "regenerate"
python3 tools/merge.py | grep -v "^  pass " || fail=1

for r in us jp eu; do
  step "build $r"
  ./make.sh $r > /tmp/bm2check_$$.log 2>&1 || { cat /tmp/bm2check_$$.log | tail -20; fail=1; }
  tail -1 /tmp/bm2check_$$.log
done
rm -f /tmp/bm2check_$$.log

if [ $fail -eq 0 ]; then
  step "relocation test"
  if [ "$1" == "--full" ]; then
    scen="attract normal vs battle continue menu_random stage0 stage1 stage2 stage3 stage4 stage5"
    regions="us jp eu"; shifts="1 256"
  else
    scen="quick"; regions="us"; shifts="1"
  fi
  jobs=""
  for r in $regions; do
    for s in $shifts; do
      ./make.sh $r shift $s > /dev/null 2>&1 || { echo "shift build $r $s failed"; fail=1; continue; }
      for sc in $scen; do jobs="$jobs $r:$s:$sc"; done
    done
  done
  # one emulator pair per job, in parallel
  results=$(echo $jobs | tr ' ' '\n' | xargs -P ${BM2_JOBS:-12} -I{} sh -c '
    IFS=: read r s sc <<EOT
{}
EOT
    out=$(python3 tools/shifttest.py $r build/bomberman2_${r}_shift$s.nes $sc 2>&1) || echo "FAIL"
    echo "$out" | sed "s/^/  $r shift $s: /"')
  echo "$results" | grep -v "^FAIL$"
  echo "$results" | grep -q "^FAIL$\|DIFF" && fail=1
fi

if [ $fail -eq 0 ]; then echo "CHECK PASSED"; else echo "CHECK FAILED"; exit 1; fi
