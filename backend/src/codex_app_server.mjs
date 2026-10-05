import { spawn } from "node:child_process";
import { randomUUID } from "node:crypto";

// Optional bridge to a local Codex App Server. It is deliberately disabled by
// default: the ChatGPT OAuth token must remain on the trusted backend host.
export class CodexAppServerClient {
  constructor({ env = process.env, spawnProcess = spawn } = {}) {
    this.env = env;
    this.spawnProcess = spawnProcess;
    this.child = null;
    this.pending = new Map();
    this.buffer = "";
    this.initialized = false;
    this.activeTurn = null;
  }

  get enabled() {
    return this.env.CODEX_APP_SERVER_ENABLED === "true";
  }

  async start() {
    if (!this.enabled) throw Object.assign(new Error("Codex App Server is disabled"), { status: 503 });
    if (!this.env.CODEX_ACCESS_TOKEN) {
      throw Object.assign(new Error("Codex App Server credentials are not configured"), { status: 503 });
    }
    if (this.child) return;
    const binary = this.env.CODEX_BINARY ?? "codex";
    this.child = this.spawnProcess(binary, [
      "app-server", "--listen", "stdio://",
      "-c", "model_provider=\"openai_chatgpt_plan\"",
      "-c", "model_providers.openai_chatgpt_plan.name=\"ChatGPT plan\"",
      "-c", "model_providers.openai_chatgpt_plan.base_url=\"https://api.openai.com/v1\"",
      "-c", "model_providers.openai_chatgpt_plan.env_key=\"ACCESS_TOKEN\"",
      "-c", "model_providers.openai_chatgpt_plan.wire_api=\"responses\"",
      "-c", "model_providers.openai_chatgpt_plan.requires_openai_auth=false",
      "-c", "model_providers.openai_chatgpt_plan.supports_websockets=false",
    ], { env: { ...this.env, ACCESS_TOKEN: this.env.CODEX_ACCESS_TOKEN }, stdio: ["pipe", "pipe", "pipe"] });
    this.child.stdout.setEncoding("utf8");
    this.child.stdout.on("data", (chunk) => this.#onData(chunk));
    this.child.on("exit", () => this.#stop(new Error("Codex App Server stopped")));
    await this.#request("initialize", {
      clientInfo: { name: "ai_remote", title: "AI Remote", version: "0.1.0" },
    });
    this.#notify("initialized", {});
    this.initialized = true;
  }

  async turn({ channelId, message, threadId }) {
    await this.start();
    let currentThreadId = threadId;
    if (!currentThreadId) {
      const result = await this.#request("thread/start", {
        model: this.env.CODEX_MODEL ?? "gpt-5-codex",
        cwd: this.env.CODEX_WORKSPACE_ROOT,
      });
      currentThreadId = result?.thread?.id;
      if (!currentThreadId) throw new Error("Codex thread was not created");
    } else {
      await this.#request("thread/resume", { threadId: currentThreadId });
    }
    this.activeTurn = { chunks: [], resolve: null, reject: null };
    const completion = new Promise((resolve, reject) => {
      this.activeTurn.resolve = resolve;
      this.activeTurn.reject = reject;
      setTimeout(() => reject(Object.assign(new Error("Codex turn timed out"), { status: 504 })), 120_000);
    });
    const result = await this.#request("turn/start", {
      threadId: currentThreadId,
      input: [{ type: "text", text: `[AI Remote channel: ${channelId}]\n${message}` }],
    });
    if (result?.turn?.status === "completed") this.activeTurn.resolve(result.turn);
    const turn = await completion;
    const responseText = this.activeTurn?.chunks.join("") ?? "";
    this.activeTurn = null;
    return { threadId: currentThreadId, responseText, turn };
  }

  close() {
    this.#stop(new Error("Codex App Server closed"));
  }

  #notify(method, params) {
    this.child?.stdin.write(`${JSON.stringify({ jsonrpc: "2.0", method, params })}\n`);
  }

  #request(method, params) {
    const id = randomUUID();
    return new Promise((resolve, reject) => {
      this.pending.set(id, { resolve, reject });
      this.child.stdin.write(`${JSON.stringify({ jsonrpc: "2.0", id, method, params })}\n`);
    });
  }

  #onData(chunk) {
    this.buffer += chunk;
    let newline;
    while ((newline = this.buffer.indexOf("\n")) >= 0) {
      const line = this.buffer.slice(0, newline).trim();
      this.buffer = this.buffer.slice(newline + 1);
      if (!line) continue;
      let message;
      try { message = JSON.parse(line); } catch { continue; }
      if (message.id && this.pending.has(message.id)) {
        const pending = this.pending.get(message.id);
        this.pending.delete(message.id);
        if (message.error) pending.reject(Object.assign(new Error(message.error.message ?? "Codex RPC failed"), { status: 502 }));
        else pending.resolve(message.result);
      } else if (message.method === "item/agentMessage/delta") {
        const delta = message.params?.delta ?? message.params?.text;
        if (typeof delta === "string") this.activeTurn?.chunks.push(delta);
      } else if (message.method === "turn/completed") {
        const turn = message.params?.turn ?? message.params;
        if (turn?.status === "completed") this.activeTurn?.resolve(turn);
        else this.activeTurn?.reject(Object.assign(new Error(`Codex turn ${turn?.status ?? "failed"}`), { status: 502 }));
      }
    }
  }

  #stop(error) {
    for (const pending of this.pending.values()) pending.reject(error);
    this.pending.clear();
    this.child?.kill();
    this.child = null;
    this.initialized = false;
  }
}
