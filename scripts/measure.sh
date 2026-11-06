#!/bin/sh
# measure.sh: how many tokens OpenCode 2 sends before you type anything.
#
# Runs one tiny prompt in an empty temporary git repository, on a private server (--standalone)
# so the shared background service and its loaded config are left alone, and prints the input
# tokens of the request: system prompt, tool definitions, Code Mode catalog, skills, global
# AGENTS.md, plus a few dozen tokens for the prompt itself.
#
# MCP servers connect in the background, so the very first request may not include their tools
# yet. The prompt asks for one short shell command first; the number printed is the larger of
# the two requests, which includes every MCP server that connected within a few seconds.
#
#   scripts/measure.sh                   default model and agent
#   scripts/measure.sh -m provider/model -a plan
#
# Compare runs with the same model only: tokenizers differ between models.
# Each run costs two small requests.
set -eu

model=""
agent=""
while [ $# -gt 0 ]; do
  case "$1" in
    -m|--model) model="$2"; shift 2 ;;
    -a|--agent) agent="$2"; shift 2 ;;
    -h|--help) sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "measure.sh: unknown option $1" >&2; exit 2 ;;
  esac
done

command -v opencode >/dev/null || { echo "measure.sh: opencode not found" >&2; exit 1; }
command -v python3 >/dev/null || { echo "measure.sh: python3 not found" >&2; exit 1; }

dir=$(mktemp -d "${TMPDIR:-/tmp}/opencode-measure.XXXXXX")
out="$dir.jsonl"
trap 'rm -rf "$dir" "$out"' EXIT
git -C "$dir" init -q

(cd "$dir" && opencode run --standalone --auto --format json ${model:+-m "$model"} ${agent:+--agent "$agent"} \
  "First run the shell command: sleep 4. Then reply with exactly: OK" >"$out" 2>/dev/null </dev/null) || true

python3 - "$out" <<'EOF'
import json, sys
steps = []
for line in open(sys.argv[1]):
    try:
        event = json.loads(line)
    except ValueError:
        continue
    if event.get("type") == "step_finish":
        t = event["part"]["tokens"]
        steps.append(t["input"] + t["cache"]["read"] + t["cache"]["write"])
    if event.get("type") == "error":
        print("measure.sh: " + json.dumps(event.get("error"))[:300], file=sys.stderr)
        sys.exit(1)
if not steps:
    print("measure.sh: no response; check `opencode run \"hi\"` works with this model", file=sys.stderr)
    sys.exit(1)
print(max(steps))
EOF
