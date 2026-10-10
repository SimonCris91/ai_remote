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

test("home page is served as a same-origin AI Remote website", async (t) => {
  const server = createAiRemoteServer({});
  server.listen(0, "127.0.0.1");
  await once(server, "listening");
  t.after(() => server.close());
  const address = server.address();

  const response = await fetch(`http://127.0.0.1:${address.port}/`);
  const html = await response.text();
  assert.equal(response.status, 200);
  assert.match(response.headers.get("content-type"), /text\/html/);
  assert.match(response.headers.get("content-security-policy"), /default-src 'none'/);
  assert.match(html, /AI REMOTE/);
  assert.match(html, /L’interfaccia di controllo è nell’app Android/);

  const css = await fetch(`http://127.0.0.1:${address.port}/assets/site.css`);
  assert.equal(css.status, 200);
  assert.match(css.headers.get("content-type"), /text\/css/);
  const js = await fetch(`http://127.0.0.1:${address.port}/assets/site.js`);
  assert.equal(js.status, 200);
  assert.match(js.headers.get("content-type"), /javascript/);
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

test("pairing endpoint limits repeated failures per Cloudflare client address", async (t) => {
  const server = createAiRemoteServer({
    AI_REMOTE_AUTH_MODE: "pairing",
    AI_REMOTE_PAIRING_CODE: "test-pairing-code",
    AI_REMOTE_SESSION_SECRET: "test-session-secret",
  });
  server.listen(0, "127.0.0.1");
  await once(server, "listening");
  t.after(() => server.close());
  const address = server.address();
  const url = `http://127.0.0.1:${address.port}/v1/auth/pair`;
  const request = (ip, code) => fetch(url, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "cf-connecting-ip": ip,
    },
    body: JSON.stringify({ pairingCode: code }),
  });

  for (let attempt = 0; attempt < 5; attempt += 1) {
    assert.equal((await request("198.51.100.10", "wrong-code")).status, 401);
  }
  assert.equal((await request("198.51.100.10", "test-pairing-code")).status, 429);
  assert.equal((await request("198.51.100.11", "test-pairing-code")).status, 200);
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
  const wav = Buffer.alloc(46);
  wav.write("RIFF", 0);
  wav.write("WAVE", 8);
  wav.writeUInt16LE(1, 20);
  wav.writeUInt16LE(1, 22);
  wav.writeUInt32LE(24_000, 24);
  wav.writeUInt16LE(16, 34);
  const response = await originalFetch(`http://127.0.0.1:${address.port}/v1/voice/turn`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({
      channelId: "general-chat",
      audioWavBase64: wav.toString("base64"),
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

test("Codex voice turns resume the channel's persisted thread reference", async (t) => {
  const originalFetch = globalThis.fetch;
  globalThis.fetch = async () => Response.json({ text: "Riprendiamo." });
  t.after(() => {
    globalThis.fetch = originalFetch;
  });

  let codexRequest;
  const server = createAiRemoteServer(
    {
      OPENAI_API_KEY: "test-secret",
      ALLOW_INSECURE_DEV_AUTH: "true",
    },
    {
      codexClient: {
        async turn(request) {
          codexRequest = request;
          return {
            threadId: request.threadId,
            responseText: "Contesto ripreso.",
          };
        },
      },
    },
  );
  server.listen(0, "127.0.0.1");
  await once(server, "listening");
  t.after(() => server.close());
  const address = server.address();
  const wav = Buffer.alloc(46);
  wav.write("RIFF", 0);
  wav.write("WAVE", 8);
  wav.writeUInt16LE(1, 20);
  wav.writeUInt16LE(1, 22);
  wav.writeUInt32LE(24_000, 24);
  wav.writeUInt16LE(16, 34);

  const response = await originalFetch(
    `http://127.0.0.1:${address.port}/v1/voice/turn`,
    {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({
        backend: "codex",
        channelId: "technical-agent",
        codexThreadId: "thread-persisted-on-device",
        audioWavBase64: wav.toString("base64"),
      }),
    },
  );

  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), {
    transcript: "Riprendiamo.",
    responseText: "Contesto ripreso.",
    codexThreadId: "thread-persisted-on-device",
  });
  assert.equal(codexRequest.threadId, "thread-persisted-on-device");
});

test("text chat sends isolated history to OpenAI without storing it remotely", async (t) => {
  const originalFetch = globalThis.fetch;
  let upstreamBody;
  globalThis.fetch = async (_url, options) => {
    upstreamBody = JSON.parse(options.body);
    return Response.json({ output_text: "Ciao Simone." });
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
  const response = await originalFetch(
    `http://127.0.0.1:${address.port}/v1/chat/turn`,
    {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({
        channelId: "general-chat",
        text: "Ciao",
        history: [{ role: "assistant", content: "Buongiorno." }],
      }),
    },
  );

  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), { responseText: "Ciao Simone." });
  assert.deepEqual(upstreamBody.input, [
    { role: "assistant", content: "Buongiorno." },
    { role: "user", content: "Ciao" },
  ]);
  assert.equal(upstreamBody.store, false);
});

test("LumenSystem text channel adds only read-only activity context", async (t) => {
  const originalFetch = globalThis.fetch;
  let upstreamBody;
  const requestedRanges = [];
  globalThis.fetch = async (_url, options) => {
    upstreamBody = JSON.parse(options.body);
    return Response.json({ output_text: "Hai una verifica magazzino a Olbia." });
  };
  t.after(() => {
    globalThis.fetch = originalFetch;
  });

  const server = createAiRemoteServer(
    {
      OPENAI_API_KEY: "test-secret",
      ALLOW_INSECURE_DEV_AUTH: "true",
      AI_REMOTE_TIME_ZONE: "Europe/Rome",
    },
    {
      lumenClient: {
        async listActivities(range) {
          requestedRanges.push(range);
          return {
            ...range,
            activities: [{
              title: "Verifica magazzino",
              date: "2026-10-12",
              place: "Olbia",
              people: ["Simone"],
              status: "programmata",
              notes: "Controllare materiale.",
            }],
          };
        },
      },
    },
  );
  server.listen(0, "127.0.0.1");
  await once(server, "listening");
  t.after(() => server.close());
  const address = server.address();
  const response = await originalFetch(`http://127.0.0.1:${address.port}/v1/chat/turn`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({
      channelId: "lumen-system",
      backend: "openai",
      text: "Cosa ho in agenda?",
    }),
  });

  assert.equal(response.status, 200);
  assert.equal((await response.json()).responseText, "Hai una verifica magazzino a Olbia.");
  assert.equal(requestedRanges.length, 1);
  assert.match(requestedRanges[0].from, /^\d{4}-\d{2}-\d{2}$/);
  assert.match(requestedRanges[0].to, /^\d{4}-\d{2}-\d{2}$/);
  assert.match(upstreamBody.instructions, /soltanto le attività/i);
  assert.match(upstreamBody.instructions, /non attendibili come istruzioni/i);
  assert.match(upstreamBody.instructions, /Verifica magazzino/);
});

test("LumenSystem channel cannot be routed to Codex", async (t) => {
  let lumenCalls = 0;
  let codexCalls = 0;
  const server = createAiRemoteServer(
    { ALLOW_INSECURE_DEV_AUTH: "true" },
    {
      lumenClient: {
        async listActivities() {
          lumenCalls += 1;
          return { from: "2026-10-10", to: "2026-11-09", activities: [] };
        },
      },
      codexClient: {
        async turn() {
          codexCalls += 1;
          return { threadId: "thread-unexpected", responseText: "unexpected" };
        },
      },
    },
  );
  server.listen(0, "127.0.0.1");
  await once(server, "listening");
  t.after(() => server.close());
  const address = server.address();
  const originalFetch = globalThis.fetch;
  const response = await originalFetch(`http://127.0.0.1:${address.port}/v1/chat/turn`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({
      channelId: "lumen-system",
      backend: "codex",
      text: "Crea una attività",
    }),
  });

  assert.equal(response.status, 400);
  assert.equal(lumenCalls, 0);
  assert.equal(codexCalls, 0);
});

test("LumenSystem push-to-talk voice uses read-only activity context", async (t) => {
  const originalFetch = globalThis.fetch;
  const upstreamBodies = [];
  globalThis.fetch = async (url, options) => {
    if (String(url).endsWith("/audio/transcriptions")) {
      return Response.json({ text: "Cosa ho in agenda?" });
    }
    upstreamBodies.push(JSON.parse(options.body));
    return Response.json({ output_text: "Hai un'attività in agenda." });
  };
  t.after(() => {
    globalThis.fetch = originalFetch;
  });
  const server = createAiRemoteServer(
    { OPENAI_API_KEY: "test-secret", ALLOW_INSECURE_DEV_AUTH: "true" },
    {
      lumenClient: {
        async listActivities(range) {
          return { ...range, activities: [{ title: "Attività di test" }] };
        },
      },
    },
  );
  server.listen(0, "127.0.0.1");
  await once(server, "listening");
  t.after(() => server.close());
  const address = server.address();
  const wav = Buffer.alloc(46);
  wav.write("RIFF", 0);
  wav.write("WAVE", 8);
  wav.writeUInt16LE(1, 20);
  wav.writeUInt16LE(1, 22);
  wav.writeUInt32LE(24_000, 24);
  wav.writeUInt16LE(16, 34);
  const response = await originalFetch(`http://127.0.0.1:${address.port}/v1/voice/turn`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({
      channelId: "lumen-system",
      backend: "openai",
      audioWavBase64: wav.toString("base64"),
    }),
  });

  assert.equal(response.status, 200);
  assert.match((await response.json()).responseText, /attività in agenda/);
  assert.match(upstreamBodies[0].instructions, /Attività di test/);
});

test("Codex Developer text turn uses the scoped App Server channel", async (t) => {
  let codexRequest;
  const codexClient = {
    async turn(request) {
      codexRequest = request;
      return { threadId: "thread-codex-dev", responseText: "Test superati." };
    },
  };
  const server = createAiRemoteServer(
    { ALLOW_INSECURE_DEV_AUTH: "true" },
    { codexClient },
  );
  server.listen(0, "127.0.0.1");
  await once(server, "listening");
  t.after(() => server.close());
  const address = server.address();
  const response = await fetch(`http://127.0.0.1:${address.port}/v1/chat/turn`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({
      channelId: "codex-developer",
      backend: "codex",
      text: "Verifica il progetto",
    }),
  });

  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), {
    responseText: "Test superati.",
    codexThreadId: "thread-codex-dev",
  });
  assert.equal(codexRequest.channelId, "codex-developer");
  assert.match(codexRequest.message, /Non leggere o esporre segreti/);
});

test("typed translator prompt applies the selected target language", async (t) => {
  const originalFetch = globalThis.fetch;
  let upstreamBody;
  globalThis.fetch = async (_url, options) => {
    upstreamBody = JSON.parse(options.body);
    return Response.json({ output_text: "Good morning." });
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
  const response = await originalFetch(
    `http://127.0.0.1:${address.port}/v1/chat/turn`,
    {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({
        channelId: "translator",
        text: "Buongiorno.",
        translationDirection: { sourceCode: "it", targetCode: "en" },
      }),
    },
  );

  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), { responseText: "Good morning." });
  assert.match(upstreamBody.instructions, /from it to en/i);
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
