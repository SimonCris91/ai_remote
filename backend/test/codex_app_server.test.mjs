import test from "node:test";
import assert from "node:assert/strict";
import { CodexAppServerClient } from "../src/codex_app_server.mjs";

test("Codex App Server bridge stays disabled without explicit opt-in", async () => {
  const client = new CodexAppServerClient({ env: {} });
  await assert.rejects(() => client.turn({ channelId: "general-chat", message: "ciao" }), /disabled/);
});
