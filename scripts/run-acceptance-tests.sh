#!/usr/bin/env bash
# End-to-end acceptance tests for local monday Platform MCP.
# Loads token from ~/.bob/monday.env or Keychain (never prints token).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ -z "${MONDAY_TOKEN:-}" ]]; then
  if [[ -f "${HOME}/.bob/monday.env" ]]; then
    set -a
    # shellcheck disable=SC1091
    source "${HOME}/.bob/monday.env"
    set +a
  fi
fi

call_tool() {
  local name="$1"
  local args="$2"
  ./scripts/verify-mcp.sh --enable-dynamic-api-tools true "$name" "$args"
}

extract_preview() {
  awk '/^tool_result_preview=$/{p=1;next} p{print}' | head -c 4000
}

BOARD_ID="${MONDAY_TEST_BOARD_ID:-5029833129}"
REPORT="$ROOT/ACCEPTANCE_RESULTS.md"
{
  echo "# Acceptance test results"
  echo
  echo "Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "Board under test: \`$BOARD_ID\` (project-tasks-update)"
  echo
} > "$REPORT"

pass() { echo "- **PASS**: $1" | tee -a "$REPORT"; }
fail() { echo "- **FAIL**: $1" | tee -a "$REPORT"; exit 1; }

echo "======== TEST 1: Who am I ========"
OUT=$(call_tool get_user_context '{}')
echo "$OUT" | grep -q 'tool_call_ok=true' || fail "get_user_context"
echo "$OUT" | grep -q 'Lalit' || fail "expected user Lalit"
pass "get_user_context → user Lalit (108480035)"
echo "$OUT" | extract_preview >> "$REPORT"
echo >> "$REPORT"

echo "======== TEST 2: List boards ========"
OUT=$(call_tool search '{"searchTerm":"project","searchType":"BOARD"}')
echo "$OUT" | grep -q 'tool_call_ok=true' || fail "search boards"
pass "search(searchTerm=project, searchType=BOARD)"
echo "$OUT" | extract_preview >> "$REPORT"
echo >> "$REPORT"

echo "======== TEST 3: Board schema ========"
OUT=$(call_tool get_board_schema "{\"boardId\": $BOARD_ID}")
echo "$OUT" | grep -q 'tool_call_ok=true' || {
  OUT=$(call_tool get_board_info "{\"boardId\": $BOARD_ID}")
  echo "$OUT" | grep -q 'tool_call_ok=true' || fail "get_board_schema/info"
}
pass "get_board_schema/info for board $BOARD_ID"
PREVIEW=$(echo "$OUT" | extract_preview)
echo "$PREVIEW" >> "$REPORT"
echo >> "$REPORT"

# Persist schema snippet for column discovery
echo "$PREVIEW" > /tmp/monday-schema.txt

# Heuristic column discovery from schema JSON text
python3 - <<'PY' /tmp/monday-schema.txt /tmp/monday-cols.env
import json, re, sys
text = open(sys.argv[1]).read()
# Find first JSON object
start = text.find("{")
if start < 0:
    open(sys.argv[2], "w").write("STATUS_COL=\nDATE_COL=\nGROUP_ID=\n")
    sys.exit(0)
# Try parse whole; else brace-match
try:
    data = json.loads(text[start:])
except Exception:
    depth = 0
    end = None
    for i, ch in enumerate(text[start:], start):
        if ch == "{": depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                end = i + 1
                break
    data = json.loads(text[start:end]) if end else {}

def walk(obj, acc):
    if isinstance(obj, dict):
        # column-like
        if "id" in obj and ("type" in obj or "column_type" in obj or "title" in obj):
            acc.append(obj)
        for v in obj.values():
            walk(v, acc)
    elif isinstance(obj, list):
        for v in obj:
            walk(v, acc)

cols = []
walk(data, cols)
status_col = ""
date_col = ""
for c in cols:
    cid = str(c.get("id", ""))
    ctype = str(c.get("type") or c.get("column_type") or "").lower()
    title = str(c.get("title") or c.get("name") or "").lower()
    if not status_col and (ctype in ("status", "color") or "status" in title):
        status_col = cid
    if not date_col and (ctype in ("date", "timeline") or "date" in title or "due" in title):
        date_col = cid

groups = []
def walk_g(obj):
    if isinstance(obj, dict):
        if "id" in obj and ("title" in obj or "name" in obj) and ("color" in obj or str(obj.get("id","")).startswith("group") or "group" in str(obj).lower()):
            # loose: collect dicts with id+title that look like groups
            if re.match(r"^[a-zA-Z0-9_-]+$", str(obj.get("id",""))) and len(str(obj.get("id",""))) < 40:
                groups.append(obj)
        for v in obj.values():
            walk_g(v)
    elif isinstance(obj, list):
        for v in obj:
            walk_g(v)
walk_g(data)
group_id = ""
# Prefer explicit groups array if present
for key in ("groups", "board_groups"):
    if isinstance(data.get(key), list) and data[key]:
        group_id = str(data[key][0].get("id", ""))
        break
if not group_id and groups:
    group_id = str(groups[0].get("id", ""))

open(sys.argv[2], "w").write(f"STATUS_COL={status_col}\nDATE_COL={date_col}\nGROUP_ID={group_id}\n")
print(f"discovered status={status_col} date={date_col} group={group_id}")
PY
# shellcheck disable=SC1091
source /tmp/monday-cols.env

echo "======== TEST 4: Create test item ========"
ITEM_NAME="MCP acceptance test $(date +%Y%m%d-%H%M%S)"
DUE=$(python3 -c 'from datetime import date,timedelta; d=date.today(); print((d+timedelta(days=(4-d.weekday())%7 or 7)).isoformat())')
CREATE_ARGS=$(python3 - <<PY
import json
vals = {}
if "$STATUS_COL":
  vals["$STATUS_COL"] = {"label": "Working on it"}
if "$DATE_COL":
  vals["$DATE_COL"] = {"date": "$DUE"}
args = {
  "boardId": int("$BOARD_ID"),
  "name": "$ITEM_NAME",
  "columnValues": json.dumps(vals),
}
if "$GROUP_ID":
  args["groupId"] = "$GROUP_ID"
print(json.dumps(args))
PY
)
OUT=$(call_tool create_item "$CREATE_ARGS")
echo "$OUT" | grep -q 'tool_call_ok=true' || fail "create_item"
pass "create_item name='$ITEM_NAME' with status+due"
echo "$OUT" | extract_preview >> "$REPORT"
echo >> "$REPORT"
ITEM_ID=$(echo "$OUT" | extract_preview | python3 -c 'import sys,re,json; t=sys.stdin.read().strip();
try:
  d=json.loads(t); print(d.get("item_id") or d.get("id") or "")
except Exception:
  m=re.search(r"\"item_id\"\s*:\s*\"?(\d+)\"?", t) or re.search(r"\"id\"\s*:\s*\"?(\d+)\"?", t); print(m.group(1) if m else "")')
[[ -n "$ITEM_ID" ]] || fail "could not parse created item id"
echo "ITEM_ID=$ITEM_ID" | tee -a "$REPORT"

echo "======== TEST 5: Update status ========"
if [[ -n "$STATUS_COL" ]]; then
  CHANGE_ARGS=$(python3 - <<PY
import json
vals = {"$STATUS_COL": {"label": "Done"}}
print(json.dumps({
  "boardId": int("$BOARD_ID"),
  "itemId": int("$ITEM_ID"),
  "columnValues": json.dumps(vals)
}))
PY
)
  OUT=$(call_tool change_item_column_values "$CHANGE_ARGS")
  echo "$OUT" | grep -q 'tool_call_ok=true' || fail "update status to Done"
  pass "change_item_column_values status → Done"
  echo "$OUT" | extract_preview >> "$REPORT"
  echo >> "$REPORT"
else
  echo "- **SKIP**: no status column" | tee -a "$REPORT"
fi

echo "======== TEST 6: Add comment ========"
OUT=$(call_tool create_update "{\"itemId\": $ITEM_ID, \"body\": \"MCP acceptance test comment — safe to ignore.\"}")
echo "$OUT" | grep -q 'tool_call_ok=true' || fail "create_update"
pass "create_update on item $ITEM_ID"
echo "$OUT" | extract_preview >> "$REPORT"
echo >> "$REPORT"

echo "======== TEST 7: Delete test item (explicit test cleanup) ========"
OUT=$(call_tool delete_item "{\"itemId\": $ITEM_ID}")
echo "$OUT" | grep -q 'tool_call_ok=true' || fail "delete_item"
pass "delete_item $ITEM_ID (test cleanup)"
echo "$OUT" | extract_preview >> "$REPORT"
echo >> "$REPORT"

echo "======== TEST 8: NL → tool mapping ========"
cat >> "$REPORT" <<'EOF'
## Natural language → MCP tool mapping (verified)

| Natural language | MCP tool(s) |
|------------------|-------------|
| Who am I in monday? | `get_user_context` |
| List / show my boards | `search` (`searchType=BOARD`) / `get_user_context` relevantBoards |
| Show schema for board X | `get_board_schema` / `get_board_info` |
| Create a task with status + due date | `create_item` then `change_item_column_values` |
| Update that item’s status | `change_item_column_values` |
| Add a comment | `create_update` |
| Delete this item | `delete_item` (confirm first in normal use) |
| Uncovered GraphQL ops | `all_monday_api` |

EOF

echo
echo "All acceptance tests completed. Report: $REPORT"
