import assert from "node:assert/strict";
import { generateKeyPairSync, sign } from "node:crypto";
import test from "node:test";
import { authenticate, issuePairingToken } from "../src/auth.mjs";

function jwt(payload, privateKey, kid) {
  const header = Buffer.from(JSON.stringify({ alg: "RS256", kid })).toString("base64url");
  const body = Buffer.from(JSON.stringify(payload)).toString("base64url");
  const input = `${header}.${body}`;
  const signature = sign("RSA-SHA256", Buffer.from(input), privateKey).toString("base64url");
  return `${input}.${signature}`;
}

const { publicKey, privateKey } = generateKeyPairSync("rsa", { modulusLength: 2048 });
const kid = "test-google-key";
const jwk = { ...publicKey.export({ format: "jwk" }), kid, use: "sig", alg: "RS256" };

test("Google ID tokens require the configured owner account", async (t) => {
  const originalFetch = globalThis.fetch;
  globalThis.fetch = async () => Response.json({ keys: [jwk] });
  t.after(() => {
    globalThis.fetch = originalFetch;
  });

  const env = {
    OIDC_AUDIENCE: "ai-remote-test-client",
    GOOGLE_ALLOWED_EMAIL: "owner@example.com",
  };
  const createRequest = (email) => ({
    headers: {
      authorization: `Bearer ${jwt({
        iss: "https://accounts.google.com",
        aud: "ai-remote-test-client",
        sub: "google-subject-1",
        email,
        email_verified: true,
        exp: Math.floor(Date.now() / 1000) + 60,
      }, privateKey, kid)}`,
    },
    socket: { remoteAddress: "203.0.113.10" },
  });

  const user = await authenticate(createRequest("owner@example.com"), env);
  assert.equal(user.sub, "google-subject-1");
  await assert.rejects(
    authenticate(createRequest("someone-else@example.com"), env),
    (error) => error.status === 403,
  );
});

test("Google authentication stays closed without an owner allowlist", async (t) => {
  const originalFetch = globalThis.fetch;
  globalThis.fetch = async () => Response.json({ keys: [jwk] });
  t.after(() => {
    globalThis.fetch = originalFetch;
  });

  const token = jwt({
    iss: "https://accounts.google.com",
    aud: "ai-remote-test-client",
    sub: "google-subject-1",
    email: "owner@example.com",
    email_verified: true,
    exp: Math.floor(Date.now() / 1000) + 60,
  }, privateKey, kid);
  await assert.rejects(
    authenticate(
      { headers: { authorization: `Bearer ${token}` }, socket: { remoteAddress: "203.0.113.10" } },
      { OIDC_AUDIENCE: "ai-remote-test-client" },
    ),
    (error) => error.status === 503,
  );
});

test("personal pairing issues and validates a short-lived bearer token", async () => {
  const env = {
    AI_REMOTE_AUTH_MODE: "pairing",
    AI_REMOTE_PAIRING_CODE: "test-pairing-code",
    AI_REMOTE_SESSION_SECRET: "test-session-secret",
  };
  const issued = issuePairingToken("test-pairing-code", env);
  const user = await authenticate(
    { headers: { authorization: `Bearer ${issued.accessToken}` }, socket: { remoteAddress: "203.0.113.10" } },
    env,
  );
  assert.match(user.sub, /^pairing:/);
  assert.throws(() => issuePairingToken("wrong-code", env), (error) => error.status === 401);
});
