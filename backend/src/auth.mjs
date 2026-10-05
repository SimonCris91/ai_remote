import { createHash, createHmac, createPublicKey, timingSafeEqual, verify } from "node:crypto";

let cachedJwks = null;
let cachedAt = 0;

function decodePart(value) {
  return JSON.parse(Buffer.from(value, "base64url").toString("utf8"));
}

function validAudience(actual, expected) {
  return Array.isArray(actual) ? actual.includes(expected) : actual === expected;
}

function isLoopback(address = "") {
  return address === "127.0.0.1" || address === "::1" || address === "::ffff:127.0.0.1";
}

function authError(message, status) {
  return Object.assign(new Error(message), { status });
}

function pairingSignature(subject, expiresAt, secret) {
  return createHmac("sha256", secret)
    .update(`${subject}.${expiresAt}`)
    .digest("base64url");
}

function safeEqual(left, right) {
  const a = Buffer.from(left);
  const b = Buffer.from(right);
  return a.length === b.length && timingSafeEqual(a, b);
}

export function issuePairingToken(pairingCode, env = process.env, now = Date.now()) {
  const expectedCode = env.AI_REMOTE_PAIRING_CODE;
  const sessionSecret = env.AI_REMOTE_SESSION_SECRET;
  if (!expectedCode || !sessionSecret) {
    throw authError("Pairing authentication is not configured", 503);
  }
  if (typeof pairingCode !== "string" || !safeEqual(pairingCode, expectedCode)) {
    throw authError("Pairing code rejected", 401);
  }
  const expiresAt = Math.floor(now / 1000) + 7 * 24 * 60 * 60;
  const subject = createHash("sha256").update(expectedCode).digest("hex").slice(0, 24);
  const signature = pairingSignature(subject, expiresAt, sessionSecret);
  return {
    accessToken: `arm1.${subject}.${expiresAt}.${signature}`,
    expiresAt,
  };
}

function authenticatePairingToken(token, env = process.env, now = Date.now()) {
  const sessionSecret = env.AI_REMOTE_SESSION_SECRET;
  if (!sessionSecret) throw authError("Pairing authentication is not configured", 503);
  const parts = token.split(".");
  if (parts.length !== 4 || parts[0] !== "arm1") throw authError("Invalid access token", 401);
  const [, subject, expiresText, signature] = parts;
  const expiresAt = Number(expiresText);
  if (!/^[a-f0-9]{24}$/.test(subject) || !Number.isSafeInteger(expiresAt)) {
    throw authError("Invalid access token", 401);
  }
  if (expiresAt <= Math.floor(now / 1000)) throw authError("Access token expired", 401);
  if (!safeEqual(signature, pairingSignature(subject, expiresAt, sessionSecret))) {
    throw authError("Access token rejected", 401);
  }
  return { sub: `pairing:${subject}` };
}

async function loadJwks(url) {
  if (cachedJwks && Date.now() - cachedAt < 300_000) return cachedJwks;
  const response = await fetch(url, { signal: AbortSignal.timeout(5000) });
  if (!response.ok) throw new Error("Unable to load OIDC signing keys");
  cachedJwks = await response.json();
  cachedAt = Date.now();
  return cachedJwks;
}

export async function authenticate(request, env = process.env) {
  if (env.ALLOW_INSECURE_DEV_AUTH === "true") {
    if (!isLoopback(request.socket.remoteAddress)) {
      throw Object.assign(new Error("Development auth is loopback-only"), { status: 403 });
    }
    return { sub: "local-development-user" };
  }

  if (env.AI_REMOTE_AUTH_MODE === "pairing") {
    const authorization = request.headers.authorization ?? "";
    if (!authorization.startsWith("Bearer ")) {
      throw authError("Bearer access token required", 401);
    }
    return authenticatePairingToken(authorization.slice(7), env);
  }

  const issuer = env.OIDC_ISSUER ?? "https://accounts.google.com";
  const isGoogleIssuer = ["https://accounts.google.com", "accounts.google.com"].includes(issuer);
  const audience = env.OIDC_AUDIENCE;
  const jwksUrl = env.OIDC_JWKS_URL ?? "https://www.googleapis.com/oauth2/v3/certs";
  if (!issuer || !audience || !jwksUrl) {
    throw Object.assign(new Error("OIDC authentication is not configured"), { status: 503 });
  }

  const authorization = request.headers.authorization ?? "";
  if (!authorization.startsWith("Bearer ")) {
    throw Object.assign(new Error("Bearer access token required"), { status: 401 });
  }
  const token = authorization.slice(7);
  const parts = token.split(".");
  if (parts.length !== 3) {
    throw Object.assign(new Error("Invalid access token"), { status: 401 });
  }

  const [encodedHeader, encodedPayload, encodedSignature] = parts;
  const header = decodePart(encodedHeader);
  const payload = decodePart(encodedPayload);
  if (header.alg !== "RS256" || typeof header.kid !== "string") {
    throw Object.assign(new Error("Unsupported access token"), { status: 401 });
  }
  const jwks = await loadJwks(jwksUrl);
  const jwk = jwks.keys?.find((candidate) => candidate.kid === header.kid);
  if (!jwk) throw Object.assign(new Error("Unknown signing key"), { status: 401 });

  const isValid = verify(
    "RSA-SHA256",
    Buffer.from(`${encodedHeader}.${encodedPayload}`),
    createPublicKey({ key: jwk, format: "jwk" }),
    Buffer.from(encodedSignature, "base64url"),
  );
  const now = Math.floor(Date.now() / 1000);
  if (
    !isValid ||
    (payload.iss !== issuer &&
      !(issuer === "https://accounts.google.com" && payload.iss === "accounts.google.com")) ||
    !validAudience(payload.aud, audience) ||
    typeof payload.sub !== "string" ||
    typeof payload.exp !== "number" ||
    payload.exp <= now ||
    (typeof payload.nbf === "number" && payload.nbf > now)
  ) {
    throw Object.assign(new Error("Access token rejected"), { status: 401 });
  }

  if (isGoogleIssuer) {
    const allowedSubject = env.GOOGLE_ALLOWED_SUBJECT;
    const allowedEmail = env.GOOGLE_ALLOWED_EMAIL?.trim().toLowerCase();
    if (!allowedSubject && !allowedEmail) {
      throw Object.assign(new Error("Google account allowlist is not configured"), { status: 503 });
    }
    if (allowedSubject && payload.sub !== allowedSubject) {
      throw Object.assign(new Error("Google account is not authorized"), { status: 403 });
    }
    if (
      allowedEmail &&
      (payload.email_verified !== true || payload.email?.toLowerCase() !== allowedEmail)
    ) {
      throw Object.assign(new Error("Google account is not authorized"), { status: 403 });
    }
  }
  return payload;
}
