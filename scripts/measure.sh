#!/bin/sh
# measure.sh: how many tokens OpenCode sends before you type anything.
#
# Runs one tiny prompt ("Reply with exactly: OK") in an empty temporary git repository and
# prints the input tokens of that first request: system prompt, tool definitions, skills,
# global AGENTS.md, MCP tools, plus about a dozen tokens for the prompt itself.
#
#   scripts/measure.sh                   default model and agent
#   scripts/measure.sh -m provider/model -a plan
#
# Compare runs with the same model only: tokenizers differ between models.
# Each run costs one small request.
set -eu

model=""
agent=""
while [ $# -gt 0 ]; do
  case "$1" in
    -m|--model) model="$2"; shift 2 ;;
    -a|--agent) agent="$2"; shift 2 ;;
    -h|--help) sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "measure.sh: unknown option $1" >&2; exit 2 ;;
  esac
done

command -v opencode >/dev/null || { echo "measure.sh: opencode not found" >&2; exit 1; }
command -v python3 >/dev/null || { echo "measure.sh: python3 not found" >&2; exit 1; }

dir=$(mktemp -d "${TMPDIR:-/tmp}/opencode-measure.XXXXXX")
out="$dir.jsonl"
trap 'rm -rf "$dir" "$out"' EXIT
git -C "$dir" init -q

(cd "$dir" && opencode run --format json ${model:+-m "$model"} ${agent:+--agent "$agent"} \
  "Reply with exactly: OK" >"$out" 2>/dev/null </dev/null) || true

python3 - "$out" <<'EOF'
import json, sys
for line in open(sys.argv[1]):
    try:
        event = json.loads(line)
    except ValueError:
        continue
    if event.get("type") == "step_finish":
        t = event["part"]["tokens"]
        print(t["input"] + t["cache"]["read"] + t["cache"]["write"])
        sys.exit(0)
    if event.get("type") == "error":
        print("measure.sh: " + json.dumps(event.get("error"))[:300], file=sys.stderr)
        sys.exit(1)
print("measure.sh: no response; check `opencode run \"hi\"` works with this model", file=sys.stderr)
sys.exit(1)
EOF
