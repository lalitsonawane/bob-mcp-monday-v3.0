# Local monday.com Platform MCP (IBM Bob)

Natural-language monday.com task management via the **official** Platform MCP package [`@mondaydotcomorg/monday-api-mcp`](https://github.com/mondaycom/mcp), running **locally** on this Mac and wired into **IBM Bob**.

## Auth decision

| Path | Status |
|------|--------|
| Hosted MCP + OAuth (`https://mcp.monday.com/mcp`) | Supported by monday; not used here (not local) |
| Local MCP + OAuth | **Not supported** by the official local server |
| **Local MCP + personal API token** | **Implemented** |

Token is loaded from macOS Keychain (`monday-api-token`) or `~/.bob/monday.env` (mode `600`). Nothing secret is committed.

## Prerequisites

- Node.js 20+ (this machine: Node 22)
- npm
- monday.com personal API token ([Developers → My access tokens](https://developer.monday.com/api-reference/docs/authentication))

```bash
cd /Users/lalit/Developments/bob-mcp-monday-v3.0
npm install
./scripts/store-monday-token.sh   # or: MONDAY_TOKEN='...' ./scripts/store-monday-token.sh
```

## IBM Bob MCP configuration (reference)

Official docs: [Using MCP in Bob](https://bob.ibm.com/docs/ide/configuration/mcp/mcp-in-bob) · [Bob Shell MCP](https://bob.ibm.com/docs/shell/configuration/mcp/mcp-bobshell) · [Server transports](https://bob.ibm.com/docs/ide/configuration/mcp/server-transports)

### Config file locations

Bob supports two MCP config levels. **Project overrides global** when the same server name appears in both.

| Level | Path on this machine | Scope |
|-------|----------------------|--------|
| **Global (Bob IDE)** | `/Users/lalit/.bob/mcp.json` | All workspaces |
| **Project** | `/Users/lalit/Developments/bob-mcp-monday-v3.0/.bob/mcp.json` | This repo only (can be shared via git; no secrets) |
| **Bob Shell / settings sync** | `/Users/lalit/.bob/settings/mcp_settings.json` | Kept in sync with the same `monday-api-mcp` entry for Shell |

Related (not Bob MCP JSON, but used by our launcher):

| File | Role |
|------|------|
| [`scripts/monday-mcp.sh`](scripts/monday-mcp.sh) | STDIO entrypoint Bob runs (`command`) |
| `/Users/lalit/.bob/monday.env` | Token fallback (`chmod 600`) — **never commit** |
| macOS Keychain service `monday-api-token` | Preferred token store |

### Edit config from Bob UI

1. Open the Bob panel → settings (gear) → **MCP** tab.
2. **Edit Global MCP** → opens `~/.bob/mcp.json`.
3. **Edit Project MCP** → opens `.bob/mcp.json` in the project root (created if missing).
4. Ensure **Use MCP Servers** is checked.
5. Expand `monday-api-mcp` to enable/disable individual tools if you want a smaller tool set.

After JSON edits: reload MCP or restart Bob so the server reconnects.

### Active server entry (copy/paste)

Transport: **STDIO** (local process). Format matches Bob’s `mcpServers` schema (`command`, `args`, `disabled`; optional `cwd`, `env`, `alwaysAllow`).

```json
{
  "mcpServers": {
    "monday-api-mcp": {
      "command": "/Users/lalit/Developments/bob-mcp-monday-v3.0/scripts/monday-mcp.sh",
      "args": ["--enable-dynamic-api-tools", "true"],
      "disabled": false
    }
  }
}
```

| Field | Value / notes |
|-------|----------------|
| Server name | `monday-api-mcp` (shown in Bob MCP tab) |
| `command` | Absolute path to the Keychain-backed launcher |
| `args` | Full CRUD + `all_monday_api` escape hatch |
| Read-only mode | Use `"args": ["--read-only"]` instead (cannot combine with dynamic API tools) |
| `disabled` | `true` to stop Bob from spawning the server |

Token is **not** in the JSON — the launcher loads `MONDAY_TOKEN` from Keychain / `~/.bob/monday.env`.

### Start / stop in Bob

There is no long-running daemon. Bob spawns the STDIO server when MCP is enabled.

1. Bob panel → **MCP** → **Use MCP Servers** = on.
2. Confirm `monday-api-mcp` is listed and not disabled.
3. After config or token changes: restart Bob or toggle MCP off/on.
4. To stop: uncheck **Use MCP Servers**, set `"disabled": true`, or remove the server entry.

Smoke test without Bob:

```bash
./scripts/verify-mcp.sh --enable-dynamic-api-tools true get_user_context '{}'
```
## Create / rotate credentials

1. monday avatar (bottom-left) → **Developers** → **My access tokens** → copy token.
2. Store securely:

```bash
./scripts/store-monday-token.sh
# or non-interactive:
MONDAY_TOKEN='paste_token_here' ./scripts/store-monday-token.sh
```

This updates Keychain service `monday-api-token` and `~/.bob/monday.env`.

3. Rotate: generate a new token in monday, re-run the store script, then reload Bob MCP. Revoke the old token in monday.

## Example natural-language commands

- “Who am I in monday?”
- “Show my boards”
- “Show schema for board project-tasks-update (columns and groups)”
- “Create a task on that board in group Y with status Working on it, due Friday”
- “Move item Z to Done and assign it to me”
- “List overdue items on the Marketing board”
- “Add a comment on item …”
- “Archive/delete this item” (assistant must confirm first)

See [`assistant-instructions.md`](assistant-instructions.md) for tool-mapping and safety rules.

## Capability checklist

| Area | Tools |
|------|--------|
| READ | `get_user_context`, `list_workspaces`, `search`, `get_board_info`, `get_board_schema`, `get_board_items_page`, `get_updates`, `list_users_and_teams`, … |
| CREATE | `create_board`, `create_group`, `create_item`, `create_update`, column values via create/change tools |
| UPDATE | `change_item_column_values`, `move_item_to_group`, item name via API tools |
| DELETE | `delete_item`, `delete_update` (confirm first); archive via dedicated tool or `all_monday_api` |
| Escape hatch | `all_monday_api`, `get_graphql_schema`, `get_type_details` |

Apps MCP (`--mode apps`) is **not** enabled — Platform workspace data only.

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| Bob doesn’t show `monday-api-mcp` | Check `/Users/lalit/.bob/mcp.json` and project `.bob/mcp.json`; Bob panel → MCP → **Use MCP Servers** on; restart Bob |
| Editing the wrong file | IDE global = `~/.bob/mcp.json`; project override = `.bob/mcp.json`; Shell also reads `~/.bob/settings/mcp_settings.json` |
| Project config ignored | Project entry wins only when this workspace is open; otherwise global applies |
| Auth / 401 / “not authenticated” | Re-run `./scripts/store-monday-token.sh` with a fresh token; reload Bob |
| Server won’t start | `npm install` in this repo; confirm `node_modules/@mondaydotcomorg/monday-api-mcp/dist/index.js` exists; `command` path must be absolute |
| Missing tools | Ensure args include `--enable-dynamic-api-tools true` (not `--read-only`); reload Bob; check per-tool toggles in Bob MCP tab |
| Rate limits | MCP calls count toward monday’s daily API limit — batch reads, avoid tight loops |
| Permission denied on a board | Token only sees boards your user can access; ask a board owner for access |
| Hosted OAuth preferred later | In Bob MCP JSON use streamable HTTP: `"type": "streamable-http", "url": "https://mcp.monday.com/mcp"` (see Bob transport docs); may require monday **AI Connectors** / [marketplace MCP app](https://monday.com/marketplace/listing/10000806/monday-mcp) |
| Disk full / npx slow | Prefer local `npm install` (wrapper already uses local `dist/index.js` when present) |

## Scripts

| Script | Purpose |
|--------|---------|
| `scripts/monday-mcp.sh` | Bob MCP command entrypoint |
| `scripts/store-monday-token.sh` | Save token to Keychain + `~/.bob/monday.env` |
| `scripts/verify-mcp.sh` | Stdio initialize + `tools/list` + optional `tools/call` |
| `scripts/run-acceptance-tests.sh` | Full CRUD acceptance suite |

Latest verified run: [`ACCEPTANCE_RESULTS.md`](ACCEPTANCE_RESULTS.md) (all 8 checks passed).

## References

**IBM Bob**

- [Using MCP in Bob](https://bob.ibm.com/docs/ide/configuration/mcp/mcp-in-bob) — global `~/.bob/mcp.json` vs project `.bob/mcp.json`
- [Bob Shell MCP](https://bob.ibm.com/docs/shell/configuration/mcp/mcp-bobshell)
- [MCP server transports](https://bob.ibm.com/docs/ide/configuration/mcp/server-transports) — STDIO vs streamable HTTP

**monday.com**

- Package: `@mondaydotcomorg/monday-api-mcp`
- Repo: https://github.com/mondaycom/mcp
- Hosted MCP: https://mcp.monday.com/mcp
- Platform MCP overview: https://developer.monday.com/api-reference/docs/monday-mcp-overview# bob-mcp-monday-v3.0
