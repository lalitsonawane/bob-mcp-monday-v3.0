#!/usr/bin/env bash
# Smoke-test monday Platform MCP over stdio: initialize + tools/list (+ optional tool call).
# Usage: ./scripts/verify-mcp.sh [--read-only] [tool_name] [tool_args_json]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WRAPPER="$ROOT/scripts/monday-mcp.sh"
ARGS=()
TOOL_NAME=""
TOOL_ARGS="{}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --read-only|-ro)
      ARGS+=(--read-only)
      shift
      ;;
    --enable-dynamic-api-tools)
      ARGS+=(--enable-dynamic-api-tools "$2")
      shift 2
      ;;
    *)
      if [[ -z "$TOOL_NAME" ]]; then
        TOOL_NAME="$1"
      else
        TOOL_ARGS="$1"
      fi
      shift
      ;;
  esac
done

export MONDAY_TOKEN
if [[ -z "${MONDAY_TOKEN:-}" ]]; then
  if [[ -f "${HOME}/.bob/monday.env" ]]; then
    # shellcheck disable=SC1091
    set -a
    source "${HOME}/.bob/monday.env"
    set +a
  elif TOKEN="$(security find-generic-password -s monday-api-token -w 2>/dev/null)"; then
    MONDAY_TOKEN="$TOKEN"
  fi
fi

export VERIFY_TOOL="$TOOL_NAME"
export VERIFY_TOOL_ARGS="$TOOL_ARGS"

node --input-type=module - "$WRAPPER" "${ARGS[@]}" <<'NODE'
import { spawn } from "node:child_process";
import readline from "node:readline";

const [wrapper, ...mcpArgs] = process.argv.slice(2);
const toolName = process.env.VERIFY_TOOL || "";
const toolArgs = process.env.VERIFY_TOOL_ARGS || "{}";

const child = spawn(wrapper, mcpArgs, {
  stdio: ["pipe", "pipe", "pipe"],
  env: process.env,
});

let stderr = "";
child.stderr.on("data", (d) => {
  stderr += d.toString();
});

const rl = readline.createInterface({ input: child.stdout });
let nextId = 1;
const pending = new Map();

function send(method, params) {
  const id = nextId++;
  const msg = { jsonrpc: "2.0", id, method, params };
  child.stdin.write(JSON.stringify(msg) + "\n");
  return new Promise((resolve, reject) => {
    pending.set(id, { resolve, reject });
    setTimeout(() => {
      if (pending.has(id)) {
        pending.delete(id);
        reject(new Error(`Timeout waiting for ${method}`));
      }
    }, 60000);
  });
}

rl.on("line", (line) => {
  if (!line.trim()) return;
  let msg;
  try {
    msg = JSON.parse(line);
  } catch {
    return;
  }
  if (msg.id != null && pending.has(msg.id)) {
    const { resolve, reject } = pending.get(msg.id);
    pending.delete(msg.id);
    if (msg.error) reject(new Error(JSON.stringify(msg.error)));
    else resolve(msg.result);
  }
});

child.on("error", (err) => {
  console.error("spawn_error", err.message);
  process.exit(1);
});

try {
  const init = await send("initialize", {
    protocolVersion: "2024-11-05",
    capabilities: {},
    clientInfo: { name: "monday-mcp-verify", version: "1.0.0" },
  });
  child.stdin.write(
    JSON.stringify({ jsonrpc: "2.0", method: "notifications/initialized" }) + "\n"
  );

  const toolsResult = await send("tools/list", {});
  const tools = toolsResult.tools || [];
  console.log("initialize_ok=true");
  console.log("server=", init.serverInfo?.name || "unknown", init.serverInfo?.version || "");
  console.log("tool_count=", tools.length);
  console.log(
    "sample_tools=",
    tools
      .slice(0, 15)
      .map((t) => t.name)
      .join(", ")
  );

  const names = new Set(tools.map((t) => t.name));
  for (const need of [
    "get_user_context",
    "get_board_info",
    "create_item",
    "change_item_column_values",
    "create_update",
    "list_workspaces",
    "search",
  ]) {
    console.log(`has_${need}=${names.has(need)}`);
  }
  console.log(`has_all_monday_api=${names.has("all_monday_api")}`);
  console.log(`has_get_graphql_schema=${names.has("get_graphql_schema")}`);

  if (toolName) {
    if (!names.has(toolName)) {
      console.error(`tool_missing=${toolName}`);
      process.exit(2);
    }
    const result = await send("tools/call", {
      name: toolName,
      arguments: JSON.parse(toolArgs),
    });
    const text = (result.content || [])
      .filter((c) => c.type === "text")
      .map((c) => c.text)
      .join("\n");
    console.log("tool_call_ok=true");
    console.log("tool_result_preview=");
    console.log(text.slice(0, 2000));
  }

  child.kill();
  process.exit(0);
} catch (err) {
  console.error("verify_failed=", err.message);
  if (stderr) console.error("stderr_preview=", stderr.slice(0, 1500));
  child.kill();
  process.exit(1);
}
NODE
