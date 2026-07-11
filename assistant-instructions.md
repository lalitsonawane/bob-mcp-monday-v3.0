# monday.com Platform MCP — assistant operating rules

Use these rules whenever you manage monday.com work through the local Platform MCP (`monday-api-mcp`) in **IBM Bob**.

**Bob config (do not put tokens here):**

- Global: `~/.bob/mcp.json`
- Project: `.bob/mcp.json` (overrides global for this workspace)
- Shell sync: `~/.bob/settings/mcp_settings.json`
- Docs: [Using MCP in Bob](https://bob.ibm.com/docs/ide/configuration/mcp/mcp-in-bob)

Server name in Bob: `monday-api-mcp` (STDIO → `scripts/monday-mcp.sh`).

## Prefer MCP tools

1. Prefer named Platform MCP tools over raw GraphQL.
2. Use `all_monday_api` / `get_graphql_schema` / `get_type_details` only when a dedicated tool is missing.
3. Never invent board IDs, group IDs, column IDs, or status labels — discover them first.

## Before any write

1. Resolve the board (search / `get_user_context` / `list_workspaces` / `workspace_info`).
2. Fetch schema with `get_board_info` or `get_board_schema` (columns, groups, status labels).
3. Map natural-language fields to real column IDs and types (status, people, date, text, etc.).
4. Then call `create_item`, `change_item_column_values`, `move_item_to_group`, `create_update`, etc.

## Destructive actions

- **Always confirm** with the user before `delete_item`, `delete_update`, archive, or any irreversible mutation.
- Do not archive/delete “to clean up” unless the user explicitly asked.

## After every write

Summarize what changed:

- Board name + id
- Item name + id
- Fields updated (column id → value)
- Group moves / comments added

## Natural language → tools (examples)

| User says | Tools |
|-----------|--------|
| Who am I in monday? | `get_user_context` |
| Show my boards | `get_user_context` / `search` / `list_workspaces` + `workspace_info` |
| Schema for board X | `get_board_info` or `get_board_schema` |
| Create task … status … due … | schema → `create_item` → `change_item_column_values` |
| Move item to Done / assign me | schema → `change_item_column_values` (and/or `move_item_to_group`) |
| Add a comment | `create_update` |
| Delete/archive this item | confirm → `delete_item` or `all_monday_api` archive mutation |

## Safety defaults

- Start exploratory sessions with reads only until the board schema is known.
- Respect monday permissions; if a call fails with auth/permission errors, report them — do not invent success.
- MCP calls count toward the account’s daily monday API limit.
