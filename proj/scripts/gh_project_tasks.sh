#!/usr/bin/env bash
# gh_project_tasks.sh — list tasks on the butterfold Projects v2 board.
#
# Shows task title, description/body, comments, and the custom
# "AI Assistant" / "Status" fields. By default ONLY tasks tagged
# "AI Assistant = Hermes" are shown; pass --all to show every task.
#
# Usage:
#   proj/scripts/gh_project_tasks.sh               # Hermes-tagged tasks only
#   proj/scripts/gh_project_tasks.sh --all         # every task on the board
#   proj/scripts/gh_project_tasks.sh --json        # Hermes-tagged as JSON
#   proj/scripts/gh_project_tasks.sh --all --json  # every task as JSON
#
# Board identity can be overridden via:
#   BUTTERFOLD_PROJECT=4 BUTTERFOLD_OWNER=Eloquencere proj/scripts/gh_project_tasks.sh
set -euo pipefail

BOARD="${BUTTERFOLD_PROJECT:-4}"
OWNER="${BUTTERFOLD_OWNER:-Eloquencere}"

# Combine flags: --all (list every task) and --json (JSON output).
SHOW_ALL=""
JSON_OUT=""
for a in "$@"; do
    case "$a" in
        --all|all)   SHOW_ALL=1 ;;
        --json|json) JSON_OUT=1 ;;
    esac
done

MODE="hermes"
[ -n "$SHOW_ALL" ] && MODE="all"
[ -n "$JSON_OUT" ] && MODE="${MODE}_json"

# Resolve the board's node id.
BOARD_ID="$(gh project view "$BOARD" --owner "$OWNER" --format json --jq '.id')"

# Fetch all items: title/body/number/url (when issue-backed) + custom field values.
# Build the GraphQL request body, then POST it via --input (proven reliable).
BODY="$(mktemp)"
trap 'rm -f "$BODY"' EXIT
BOARD_ID="$BOARD_ID" python3 - "$BODY" <<'PY'
import json, os, sys
q = """
query($id: ID!){
  node(id: $id){
    ... on ProjectV2 {
      items(first: 100) {
        nodes {
          id
          content {
            __typename
            ... on DraftIssue { title body }
            ... on Issue {
              title body number url
              comments(first: 20) { nodes { body } }
            }
          }
          fieldValues(first: 40) {
            nodes {
              ... on ProjectV2ItemFieldSingleSelectValue {
                name
                field { ... on ProjectV2SingleSelectField { name } }
              }
              ... on ProjectV2ItemFieldTextValue {
                text
                field { ... on ProjectV2FieldCommon { name } }
              }
            }
          }
        }
      }
    }
  }
}
"""
body = {"query": q, "variables": {"id": os.environ["BOARD_ID"]}}
with open(sys.argv[1], "w") as f:
    json.dump(body, f)
PY

ITEM_JSON="$(gh api graphql --input "$BODY")"

# Pass the JSON by file path so python's stdin stays free for the heredoc below.
ITEM_FILE="$(mktemp)"
trap 'rm -f "$BODY" "$ITEM_FILE"' EXIT
printf '%s' "$ITEM_JSON" > "$ITEM_FILE"

ITEM_FILE="$ITEM_FILE" BOARD="${BOARD:-4}" OWNER="${OWNER:-Eloquencere}" MODE="$MODE" python3 - "$MODE" <<'PY'
import json, os, sys

mode = sys.argv[1]
with open(os.environ["ITEM_FILE"]) as _f:
    data = json.load(_f)
board = os.environ["BOARD"]
owner = os.environ["OWNER"]
items = data["data"]["node"]["items"]["nodes"]

def item_content(it):
    return it.get("content") or {}

def item_body(it):
    return item_content(it).get("body") or ""

def item_comments(it):
    return [n.get("body") or "" for n in (item_content(it).get("comments") or {}).get("nodes", [])]

def field_map(it):
    """Return all custom field values as {FieldName: value}, incl. AI Assistant."""
    fm = {}
    for fv in it.get("fieldValues", {}).get("nodes", []):
        name = (fv.get("field") or {}).get("name")
        if not name or name == "Title":
            continue
        fm[name] = fv.get("name") or fv.get("text")
    return fm

def typename(it):
    return item_content(it).get("__typename", "?")

# Filter: keep only Hermes-tagged tasks unless --all.
show_all = mode.startswith("all")
json_out = mode.endswith("_json")
selected = items if show_all else [
    it for it in items if field_map(it).get("AI Assistant") == "Hermes"
]

# --- JSON mode: dump clean records ---
if json_out:
    out = []
    for it in selected:
        fm = field_map(it)
        c = item_content(it)
        rec = {"id": it["id"], "type": typename(it),
               "title": c.get("title"), "description": item_body(it),
               "status": fm.get("Status"), "AI_Assistant": fm.get("AI Assistant"),
               "labels": {k: v for k, v in fm.items() if k not in ("Status", "AI Assistant")},
               "comments": item_comments(it)}
        out.append(rec)
    print(json.dumps(out, indent=2, ensure_ascii=False))
    sys.exit(0)

# --- human-readable mode ---
results = selected
if not results:
    print(f"No tasks matched (mode={mode}) on project {board}/{owner}")
    sys.exit(0)

for i, it in enumerate(results, 1):
    fm = field_map(it)
    print(f"{'='*72}")
    print(f"[{i}] {item_content(it).get('title')}")
    print(f"    type      : {typename(it)}")
    print(f"    id        : {it['id']}")
    print(f"    status    : {fm.get('Status')}")
    print(f"    AI Assis. : {fm.get('AI Assistant')}")
    others = {k: v for k, v in fm.items() if k not in ("Status", "AI Assistant")}
    for k, v in others.items():
        print(f"    {k:>10} : {v}")
    body = item_body(it).strip()
    if body:
        print(f"    --- description ---")
        for line in body.splitlines():
            print(f"    {line}")
    cmts = item_comments(it)
    if cmts:
        print(f"    --- comments ({len(cmts)}) ---")
        for j, c in enumerate(cmts, 1):
            print(f"    [{j}] {c}")
print(f"{'='*72}")
print(f"{len(results)} task(s) shown.")
PY