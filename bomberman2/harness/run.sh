#!/bin/bash
# Run one harness task with the grok CLI in its own git worktree.
#
# Usage: harness/run.sh TASK            e.g. harness/run.sh T01-core
#
# - creates ../bm2-work/TASK (git worktree, branch bm2-task/TASK) if needed
# - grok runs headless with least privilege: it may only run tools/*, edit
#   harness/notes/**, and write inside the worktree (sandbox); no git, no web
# - afterwards the task's db shards and notes are copied back here and
#   tools/check.sh runs; the log goes to harness/logs/TASK.log
set -e -o pipefail
TASK=$1
[ -f "$(dirname "$0")/tasks/$TASK.md" ] || { echo "Usage: $0 TASK  (see harness/tasks/)"; exit 1; }

MAIN=$(cd "$(dirname "$0")/.." && pwd)                 # .../bomberman-nes/bomberman2
REPO=$(git -C "$MAIN" rev-parse --show-toplevel)
WTROOT=${BM2_WORKTREES:-$(cd "$REPO/.." && pwd)/bm2-work}
WT=$WTROOT/$TASK
export BM2_TASK=$TASK
export BM2_ROMDIR=${BM2_ROMDIR:-$(cd "$REPO/.." && pwd)}
export BEEBASM=${BEEBASM:-$(cd "$REPO/.." && pwd)/beebasm/beebasm}

if [ ! -d "$WT" ]; then
  mkdir -p "$WTROOT"
  git -C "$REPO" worktree add -b "bm2-task/$TASK" "$WT" HEAD
fi
W=$WT/bomberman2
ln -sfn "$MAIN/cov" "$W/cov"
# Start from the current accepted state (db shards, notes, harness files)
rsync -a "$MAIN/db/" "$W/db/"
rsync -a "$MAIN/harness/" "$W/harness/" --exclude logs
(cd "$W" && tools/regen.sh > /dev/null)

PROMPT="$(cat "$W/harness/RULES.md")

---

$(cat "$W/harness/tasks/$TASK.md")

---
你的任务名是 ${TASK}（环境变量 BM2_TASK 已设置）。当前目录是仓库的 bomberman2/ 目录。
先读 RULES 第 2 节的工具说明和 harness/notes/ 下已有的笔记，然后开始工作。
完成后运行 tools/check.sh，直到 CHECK PASSED，再在笔记末尾贴上结果。"

mkdir -p "$MAIN/harness/logs"
cd "$W"
grok -p "$PROMPT" \
  --sandbox workspace \
  --permission-mode dontAsk \
  --allow "Bash(python3 tools/*)" --allow "Bash(tools/*)" --allow "Bash(./tools/*)" \
  --allow "Edit(harness/notes/**)" --allow "Write(harness/notes/**)" \
  --deny "Bash(git*)" --deny "Bash(curl*)" --deny "Bash(wget*)" --deny "Bash(rm *)" \
  --disable-web-search \
  --max-turns "${BM2_MAX_TURNS:-400}" \
  2>&1 | tee "$MAIN/harness/logs/$TASK.log"

# Collect results into the main tree
for f in symbols comments pointers notptr; do
  [ -f "$W/db/$f.d/$TASK.tsv" ] && mkdir -p "$MAIN/db/$f.d" && cp "$W/db/$f.d/$TASK.tsv" "$MAIN/db/$f.d/"
done
[ -f "$W/harness/notes/$TASK.md" ] && cp "$W/harness/notes/$TASK.md" "$MAIN/harness/notes/"
[ "$TASK" == "T01-core" ] && [ -f "$W/harness/notes/glossary.md" ] && cp "$W/harness/notes/glossary.md" "$MAIN/harness/notes/"
echo "== results copied; running check in the main tree" | tee -a "$MAIN/harness/logs/$TASK.log"
(cd "$MAIN" && tools/check.sh) 2>&1 | tee -a "$MAIN/harness/logs/$TASK.log"
