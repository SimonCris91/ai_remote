const activitiesPath = "/api/v1/integrations/ai-remote/activities";

function configuredBaseUrl(value) {
  if (!value) {
    throw Object.assign(new Error("LumenSystem non è configurato sul server."), { status: 503 });
  }
  let url;
  try {
    url = new URL(value);
  } catch {
    throw Object.assign(new Error("Configurazione LumenSystem non valida."), { status: 503 });
  }
  const localHosts = new Set(["localhost", "127.0.0.1", "[::1]"]);
  if (
    !["http:", "https:"].includes(url.protocol) ||
    url.username || url.password || url.search || url.hash ||
    (url.protocol === "http:" && !localHosts.has(url.hostname))
  ) {
    throw Object.assign(new Error("LumenSystem deve usare HTTPS o HTTP locale."), { status: 503 });
  }
  return url;
}

export class LumenSystemClient {
  constructor({ env = process.env, fetchImpl = fetch } = {}) {
    this.env = env;
    this.fetchImpl = fetchImpl;
  }

  async listActivities({ from, to }) {
    const baseUrl = configuredBaseUrl(this.env.LUMEN_SYSTEM_BASE_URL?.trim());
    const token = this.env.LUMEN_AI_REMOTE_READ_TOKEN;
    if (!token) {
      throw Object.assign(new Error("Accesso di sola lettura a LumenSystem non configurato."), { status: 503 });
    }
    const url = new URL(activitiesPath, baseUrl);
    url.searchParams.set("from", from);
    url.searchParams.set("to", to);
    let response;
    try {
      response = await this.fetchImpl(url, {
        headers: { authorization: `Bearer ${token}` },
        signal: AbortSignal.timeout(5000),
      });
    } catch {
      throw Object.assign(new Error("LumenSystem non è raggiungibile dal backend."), { status: 502 });
    }
    if (response.status === 401 || response.status === 403) {
      throw Object.assign(new Error("Accesso AI Remote a LumenSystem rifiutato."), { status: 502 });
    }
    if (!response.ok) {
      throw Object.assign(new Error("Lettura attività LumenSystem non riuscita."), { status: 502 });
    }
    let payload;
    try {
      payload = await response.json();
    } catch {
      throw Object.assign(new Error("Risposta LumenSystem non valida."), { status: 502 });
    }
    if (!payload || !Array.isArray(payload.activities) || payload.activities.length > 50) {
      throw Object.assign(new Error("Risposta LumenSystem non valida."), { status: 502 });
    }
    return {
      from: typeof payload.from === "string" ? payload.from : from,
      to: typeof payload.to === "string" ? payload.to : to,
      activities: payload.activities.map((activity) => ({
        title: String(activity?.title ?? "").slice(0, 240),
        date: activity?.date ?? null,
        place: String(activity?.place ?? "").slice(0, 160),
        people: Array.isArray(activity?.people)
          ? activity.people.slice(0, 12).map((person) => String(person).slice(0, 80))
          : [],
        status: String(activity?.status ?? "").slice(0, 40),
        notes: String(activity?.notes ?? "").slice(0, 500),
      })),
    };
  }
}
