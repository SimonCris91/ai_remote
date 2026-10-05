import { createHash } from "node:crypto";
import { createServer } from "node:http";
import { pathToFileURL } from "node:url";
import { authenticate, issuePairingToken } from "./auth.mjs";
import { CodexAppServerClient } from "./codex_app_server.mjs";

const channelInstructions = {
  "general-chat": "Be a concise and helpful general voice assistant.",
  "lavormetal-daily": "Sei l'assistente operativo di LavorMetal. Trasforma appunti grezzi in report giornalieri compatti, pronti per Telegram. Organizza data e luogo, attività per persona, materiali, attrezzature, problemi, sospensioni e osservazioni. Non inventare persone, quantità, codici o attività mancanti: indica solo i dati disponibili e segnala ciò che va confermato. Rispondi in italiano.",
  "technical-agent": "Act as a practical technical assistant. Give safe, concise steps.",
};

const maxVoiceRequestBytes = 9 * 1024 * 1024;

function sendJson(response, status, value) {
  response.writeHead(status, {
    "content-type": "application/json; charset=utf-8",
    "cache-control": "no-store",
  });
  response.end(JSON.stringify(value));
}

async function readJson(request) {
  const chunks = [];
  let size = 0;
  for await (const chunk of request) {
    size += chunk.length;
    if (size > maxVoiceRequestBytes) throw Object.assign(new Error("Request too large"), { status: 413 });
    chunks.push(chunk);
  }
  if (chunks.length === 0) return {};
  return JSON.parse(Buffer.concat(chunks).toString("utf8"));
}

function safetyIdentifier(subject) {
  return createHash("sha256").update(subject).digest("hex");
}

async function requestOpenAiSecret(path, session, subject, env) {
  if (!env.OPENAI_API_KEY) {
    throw Object.assign(new Error("OpenAI is not configured"), { status: 503 });
  }
  const upstream = await fetch(`https://api.openai.com${path}`, {
    method: "POST",
    headers: {
      authorization: `Bearer ${env.OPENAI_API_KEY}`,
      "content-type": "application/json",
      "OpenAI-Safety-Identifier": safetyIdentifier(subject),
    },
    body: JSON.stringify({ session }),
    signal: AbortSignal.timeout(10_000),
  });
  const payload = await upstream.json();
  if (!upstream.ok) {
    throw Object.assign(new Error("OpenAI session creation failed"), {
      status: upstream.status >= 500 ? 502 : upstream.status,
    });
  }
  return payload;
}

async function processVoiceTurn(body, subject, env) {
  if (!env.OPENAI_API_KEY) {
    throw Object.assign(new Error("OpenAI is not configured"), { status: 503 });
  }
  const instructions = channelInstructions[body.channelId];
  if (!instructions) throw Object.assign(new Error("Unknown channel"), { status: 400 });
  if (typeof body.audioWavBase64 !== "string" || body.audioWavBase64.length > 8_500_000) {
    throw Object.assign(new Error("Invalid audio recording"), { status: 400 });
  }
  const audio = Buffer.from(body.audioWavBase64, "base64");
  if (
    audio.length < 46 ||
    audio.subarray(0, 4).toString() !== "RIFF" ||
    audio.subarray(8, 12).toString() !== "WAVE" ||
    audio.readUInt16LE(20) !== 1 ||
    audio.readUInt16LE(22) !== 1 ||
    audio.readUInt32LE(24) !== 24_000 ||
    audio.readUInt16LE(34) !== 16
  ) {
    throw Object.assign(new Error("Invalid WAV recording"), { status: 400 });
  }

  const history = Array.isArray(body.history) ? body.history.slice(-40) : [];
  if (history.some((message) =>
    !message || !["user", "assistant"].includes(message.role) ||
    typeof message.content !== "string" || message.content.length > 8_000
  )) {
    throw Object.assign(new Error("Invalid conversation history"), { status: 400 });
  }

  const safetyId = safetyIdentifier(subject);
  const form = new FormData();
  form.set("file", new Blob([audio], { type: "audio/wav" }), "turn.wav");
  form.set("model", env.OPENAI_TRANSCRIPTION_MODEL ?? "gpt-4o-mini-transcribe");
  const transcriptionResponse = await fetch("https://api.openai.com/v1/audio/transcriptions", {
    method: "POST",
    headers: {
      authorization: `Bearer ${env.OPENAI_API_KEY}`,
      "OpenAI-Safety-Identifier": safetyId,
    },
    body: form,
    signal: AbortSignal.timeout(60_000),
  });
  const transcription = await transcriptionResponse.json();
  if (!transcriptionResponse.ok || typeof transcription.text !== "string") {
    throw Object.assign(new Error("Audio transcription failed"), { status: 502 });
  }

  const response = await fetch("https://api.openai.com/v1/responses", {
    method: "POST",
    headers: {
      authorization: `Bearer ${env.OPENAI_API_KEY}`,
      "content-type": "application/json",
      "OpenAI-Safety-Identifier": safetyId,
    },
    body: JSON.stringify({
      model: env.OPENAI_RESPONSES_MODEL ?? "gpt-4.1-mini",
      instructions,
      input: [
        ...history.map(({ role, content }) => ({ role, content })),
        { role: "user", content: transcription.text },
      ],
      max_output_tokens: 160,
      store: false,
    }),
    signal: AbortSignal.timeout(60_000),
  });
  const result = await response.json();
  const responseText = result.output_text ?? result.output
    ?.flatMap((item) => item.content ?? [])
    .find((item) => item.type === "output_text")?.text;
  if (!response.ok || typeof responseText !== "string" || !responseText.trim()) {
    throw Object.assign(new Error("Assistant response failed"), { status: 502 });
  }
  return { transcript: transcription.text, responseText };
}

export function createAiRemoteServer(env = process.env) {
  const codex = new CodexAppServerClient({ env });
  return createServer(async (request, response) => {
    try {
      const url = new URL(request.url ?? "/", "http://localhost");
      if (request.method === "GET" && url.pathname === "/health") {
        sendJson(response, 200, { status: "ok", openaiConfigured: Boolean(env.OPENAI_API_KEY) });
        return;
      }
      if (request.method !== "POST") {
        sendJson(response, 404, { error: "Not found" });
        return;
      }

      if (url.pathname === "/v1/auth/pair") {
        const body = await readJson(request);
        const result = issuePairingToken(body.pairingCode, env);
        sendJson(response, 200, result);
        return;
      }

      const user = await authenticate(request, env);
      const body = await readJson(request);
      if (url.pathname === "/v1/realtime/client-secret") {
        const instructions = channelInstructions[body.channelId];
        if (!instructions) throw Object.assign(new Error("Unknown channel"), { status: 400 });
        const result = await requestOpenAiSecret(
          "/v1/realtime/client_secrets",
          {
            type: "realtime",
            model: env.OPENAI_REALTIME_MODEL ?? "gpt-realtime-2.1",
            instructions,
            audio: { output: { voice: env.OPENAI_REALTIME_VOICE ?? "marin" } },
          },
          user.sub,
          env,
        );
        sendJson(response, 200, result);
        return;
      }
      if (url.pathname === "/v1/voice/turn") {
        const result = await processVoiceTurn(body, user.sub, env);
        sendJson(response, 200, result);
        return;
      }
      if (url.pathname === "/v1/codex/turn") {
        if (typeof body.channelId !== "string" || typeof body.message !== "string" || !body.message.trim()) {
          throw Object.assign(new Error("Invalid Codex turn"), { status: 400 });
        }
        const result = await codex.turn({
          channelId: body.channelId,
          message: body.message.slice(0, 8_000),
          threadId: typeof body.threadId === "string" ? body.threadId : undefined,
        });
        sendJson(response, 200, result);
        return;
      }
      if (url.pathname === "/v1/realtime/translation-client-secret") {
        const targetLanguage = String(body.targetLanguage ?? "");
        if (!/^[a-z]{2}(-[A-Z]{2})?$/.test(targetLanguage)) {
          throw Object.assign(new Error("Invalid target language"), { status: 400 });
        }
        const result = await requestOpenAiSecret(
          "/v1/realtime/translations/client_secrets",
          {
            model: env.OPENAI_TRANSLATION_MODEL ?? "gpt-realtime-translate",
            audio: { output: { language: targetLanguage } },
          },
          user.sub,
          env,
        );
        sendJson(response, 200, result);
        return;
      }
      sendJson(response, 404, { error: "Not found" });
    } catch (error) {
      const status = Number.isInteger(error.status) ? error.status : 500;
      sendJson(response, status, { error: status >= 500 ? "Service unavailable" : error.message });
    }
  });
}

const invokedScript = process.argv[1];
if (invokedScript && import.meta.url === pathToFileURL(invokedScript).href) {
  const port = Number(process.env.PORT ?? 8787);
  // Containers (including Cloud Run) must listen on all interfaces. Local
  // development keeps HOST=127.0.0.1 in .env.local when loopback is desired.
  const host = process.env.HOST ?? "0.0.0.0";
  createAiRemoteServer().listen(port, host, () => {
    console.log(`AI Remote backend listening on http://${host}:${port}`);
  });
}
