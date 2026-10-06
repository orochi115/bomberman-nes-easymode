"""Summarise a grok streaming-json log: tool calls, failures, final texts.

Usage: harness/logview.py logs/TASK.jsonl [--tail N]
"""
import json
import sys

path = sys.argv[1]
tail = int(sys.argv[3]) if len(sys.argv) > 3 and sys.argv[2] == "--tail" else 40
events, text = [], []
calls = fails = 0
for line in open(path, encoding="utf-8", errors="replace"):
    try:
        e = json.loads(line)
    except ValueError:
        continue
    t = e.get("type")
    if t == "text":
        text.append(e.get("data", ""))
        continue
    if text:
        events.append("TEXT  " + "".join(text).strip().replace("\n", " ")[:300])
        text = []
    if t == "tool_call":
        calls += 1
        ri = e.get("rawInput", {})
        events.append("CALL  " + str(ri.get("command") or ri.get("target_file") or ri.get("pattern") or ri)[:200])
    elif t == "tool_call_update" and e.get("status") == "failed":
        fails += 1
        events.append("FAIL  " + json.dumps(e.get("content"), ensure_ascii=False)[:200])
    elif t == "end":
        events.append("END   %s" % e.get("stopReason"))
if text:
    events.append("TEXT  " + "".join(text).strip().replace("\n", " ")[:300])
print("\n".join(events[-tail:]))
print("-- %d tool calls, %d failed" % (calls, fails))
