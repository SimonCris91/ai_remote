import assert from "node:assert/strict";
import { once } from "node:events";
import test from "node:test";
import { createAiRemoteServer } from "../src/server.mjs";

test("health works without exposing a secret", async (t) => {
  const server = createAiRemoteServer({});
  server.listen(0, "127.0.0.1");
  await once(server, "listening");
  t.after(() => server.close());
  const address = server.address();
  const response = await fetch(`http://127.0.0.1:${address.port}/health`);
  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), {
    status: "ok",
    openaiConfigured: false,
  });
});

test("session endpoint is closed when auth is not configured", async (t) => {
  const server = createAiRemoteServer({});
  server.listen(0, "127.0.0.1");
  await once(server, "listening");
  t.after(() => server.close());
  const address = server.address();
  const response = await fetch(
    `http://127.0.0.1:${address.port}/v1/realtime/client-secret`,
    { method: "POST", body: JSON.stringify({ channelId: "general-chat" }) },
  );
  assert.equal(response.status, 503);
});

test("pairing endpoint returns a bearer token without exposing the pairing code", async (t) => {
  const server = createAiRemoteServer({
    AI_REMOTE_AUTH_MODE: "pairing",
    AI_REMOTE_PAIRING_CODE: "test-pairing-code",
    AI_REMOTE_SESSION_SECRET: "test-session-secret",
  });
  server.listen(0, "127.0.0.1");
  await once(server, "listening");
  t.after(() => server.close());
  const address = server.address();
  const response = await fetch(`http://127.0.0.1:${address.port}/v1/auth/pair`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ pairingCode: "test-pairing-code" }),
  });
  assert.equal(response.status, 200);
  const payload = await response.json();
  assert.match(payload.accessToken, /^arm1\./);
  assert.equal(JSON.stringify(payload).includes("test-pairing-code"), false);
});

test("voice turns require auth before contacting OpenAI", async (t) => {
  const server = createAiRemoteServer({ OPENAI_API_KEY: "test-secret" });
  server.listen(0, "127.0.0.1");
  await once(server, "listening");
  t.after(() => server.close());
  const address = server.address();
  const response = await fetch(`http://127.0.0.1:${address.port}/v1/voice/turn`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ channelId: "general-chat" }),
  });
  assert.equal(response.status, 503);
});

function testWav() {
  const wav = Buffer.alloc(46);
  wav.write("RIFF", 0);
  wav.write("WAVE", 8);
  wav.writeUInt16LE(1, 20);
  wav.writeUInt16LE(1, 22);
  wav.writeUInt32LE(24_000, 24);
  wav.writeUInt16LE(16, 34);
  return wav;
}

test("voice turns transcribe bounded WAV then request an isolated channel response", async (t) => {
  const originalFetch = globalThis.fetch;
  const calls = [];
  globalThis.fetch = async (url, options) => {
    calls.push({ url: String(url), options });
    if (String(url).endsWith("/audio/transcriptions")) {
      return Response.json({ text: "Ciao, come stai?" });
    }
    return Response.json({ output_text: "Sto bene, grazie." });
  };
  t.after(() => {
    globalThis.fetch = originalFetch;
  });

  const server = createAiRemoteServer({
    OPENAI_API_KEY: "test-secret",
    ALLOW_INSECURE_DEV_AUTH: "true",
  });
  server.listen(0, "127.0.0.1");
  await once(server, "listening");
  t.after(() => server.close());
  const address = server.address();
  const response = await originalFetch(`http://127.0.0.1:${address.port}/v1/voice/turn`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({
      channelId: "general-chat",
      audioWavBase64: testWav().toString("base64"),
      history: [{ role: "assistant", content: "Ciao." }],
    }),
  });

  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), {
    transcript: "Ciao, come stai?",
    responseText: "Sto bene, grazie.",
  });
  assert.equal(calls.length, 2);
  assert.match(calls[0].url, /audio\/transcriptions$/);
  assert.match(calls[1].url, /\/responses$/);
  const responseBody = JSON.parse(calls[1].options.body);
  assert.equal(responseBody.input[0].content, "Ciao.");
  assert.equal(responseBody.input[1].content, "Ciao, come stai?");
  assert.equal(responseBody.store, false);
});

test("Codex-routed voice turns fall back to OpenAI when Codex is unavailable", async (t) => {
  const originalFetch = globalThis.fetch;
  const calls = [];
  globalThis.fetch = async (url, options) => {
    calls.push({ url: String(url), options });
    if (String(url).endsWith("/audio/transcriptions")) {
      return Response.json({ text: "Preparami il report." });
    }
    return Response.json({ output_text: "Report pronto tramite fallback OpenAI." });
  };
  t.after(() => {
    globalThis.fetch = originalFetch;
  });

  const server = createAiRemoteServer({
    OPENAI_API_KEY: "test-secret",
    ALLOW_INSECURE_DEV_AUTH: "true",
    CODEX_APP_SERVER_ENABLED: "false",
  });
  server.listen(0, "127.0.0.1");
  await once(server, "listening");
  t.after(() => server.close());
  const address = server.address();
  const response = await originalFetch(`http://127.0.0.1:${address.port}/v1/voice/turn`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({
      channelId: "lavormetal-daily",
      backend: "codex",
      audioWavBase64: testWav().toString("base64"),
      history: [],
    }),
  });

  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), {
    transcript: "Preparami il report.",
    responseText: "Report pronto tramite fallback OpenAI.",
    fallbackFrom: "codex",
  });
  assert.equal(calls.length, 2);
  assert.match(calls[0].url, /audio\/transcriptions$/);
  assert.match(calls[1].url, /\/responses$/);
});

test("voice turns reject channel ids outside the server allowlist", async (t) => {
  const server = createAiRemoteServer({
    OPENAI_API_KEY: "test-secret",
    ALLOW_INSECURE_DEV_AUTH: "true",
  });
  server.listen(0, "127.0.0.1");
  await once(server, "listening");
  t.after(() => server.close());
  const address = server.address();
  const response = await fetch(`http://127.0.0.1:${address.port}/v1/voice/turn`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ channelId: "translator" }),
  });
  assert.equal(response.status, 400);
});
