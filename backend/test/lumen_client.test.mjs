import assert from "node:assert/strict";
import test from "node:test";
import { LumenSystemClient } from "../src/lumen_client.mjs";

test("Lumen client calls only the scoped read endpoint over loopback or HTTPS", async () => {
  let requestedUrl;
  let requestedOptions;
  const client = new LumenSystemClient({
    env: {
      LUMEN_SYSTEM_BASE_URL: "http://127.0.0.1:8789",
      LUMEN_AI_REMOTE_READ_TOKEN: "server-only-test-token",
    },
    fetchImpl: async (url, options) => {
      requestedUrl = new URL(url);
      requestedOptions = options;
      return Response.json({
        from: "2026-10-10",
        to: "2026-11-09",
        activities: [{
          title: "Attività",
          date: "2026-10-12",
          place: "Olbia",
          people: ["Simone"],
          status: "programmata",
          notes: "Nota",
          ignored: "not forwarded",
        }],
      });
    },
  });

  const result = await client.listActivities({ from: "2026-10-10", to: "2026-11-09" });
  assert.equal(requestedUrl.pathname, "/api/v1/integrations/ai-remote/activities");
  assert.equal(requestedUrl.searchParams.get("from"), "2026-10-10");
  assert.equal(requestedUrl.searchParams.get("to"), "2026-11-09");
  assert.equal(requestedOptions.headers.authorization, "Bearer server-only-test-token");
  assert.equal(requestedUrl.href.includes("server-only-test-token"), false);
  assert.deepEqual(result.activities[0], {
    title: "Attività",
    date: "2026-10-12",
    place: "Olbia",
    people: ["Simone"],
    status: "programmata",
    notes: "Nota",
  });
});

test("Lumen client refuses remote plaintext HTTP and missing credentials", async () => {
  const remoteHttp = new LumenSystemClient({
    env: {
      LUMEN_SYSTEM_BASE_URL: "http://lumen.example.com",
      LUMEN_AI_REMOTE_READ_TOKEN: "test-token",
    },
  });
  await assert.rejects(
    remoteHttp.listActivities({ from: "2026-10-10", to: "2026-11-09" }),
    /HTTPS o HTTP locale/,
  );

  const missingToken = new LumenSystemClient({
    env: { LUMEN_SYSTEM_BASE_URL: "http://127.0.0.1:8789" },
  });
  await assert.rejects(
    missingToken.listActivities({ from: "2026-10-10", to: "2026-11-09" }),
    /non configurato/,
  );
});
