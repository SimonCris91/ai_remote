import test from "node:test";
import assert from "node:assert/strict";
import { EventEmitter } from "node:events";
import { PassThrough } from "node:stream";
import { CodexAppServerClient } from "../src/codex_app_server.mjs";

test("Codex App Server bridge stays disabled without explicit opt-in", async () => {
  const client = new CodexAppServerClient({ env: {} });
  await assert.rejects(() => client.turn({ channelId: "general-chat", message: "ciao" }), /disabled/);
});

test("Codex App Server starts with workspace-write and on-request approvals", async () => {
  let spawned;
  const spawnProcess = (binary, args, options) => {
    spawned = { binary, args, options };
    const child = new EventEmitter();
    child.stdin = new PassThrough();
    child.stdout = new PassThrough();
    child.stderr = new PassThrough();
    child.kill = () => {};
    child.stdin.on("data", (chunk) => {
      for (const line of chunk.toString().trim().split("\n")) {
        const request = JSON.parse(line);
        if (request.id) {
          child.stdout.write(`${JSON.stringify({ jsonrpc: "2.0", id: request.id, result: {} })}\n`);
        }
      }
    });
    return child;
  };
  const client = new CodexAppServerClient({
    env: { CODEX_APP_SERVER_ENABLED: "true", CODEX_BINARY: "codex" },
    spawnProcess,
  });

  await client.start();

  assert.equal(spawned.binary, "codex");
  assert.deepEqual(spawned.args, [
    "app-server",
    "--listen",
    "stdio://",
    "-c",
    'sandbox_mode="workspace-write"',
    "-c",
    'approval_policy="on-request"',
  ]);
  assert.equal(spawned.options.stdio.join(","), "pipe,pipe,pipe");
  client.close();
});
