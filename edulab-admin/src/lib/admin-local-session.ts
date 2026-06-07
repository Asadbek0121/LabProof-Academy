export const LOCAL_ADMIN_SESSION_COOKIE = "labproof_admin_local_session";

const encoder = new TextEncoder();
const decoder = new TextDecoder();
const sessionMaxAgeSeconds = 60 * 60 * 8;

type LocalAdminPayload = {
  login: string;
  role: "admin";
  exp: number;
};

function getSessionSecret() {
  return (
    process.env.ADMIN_LOCAL_SESSION_SECRET ||
    process.env.ADMIN_SIMPLE_PASSWORD ||
    "labproof-local-admin-session"
  );
}

function base64UrlFromBytes(bytes: Uint8Array) {
  let value = "";
  for (const byte of bytes) value += String.fromCharCode(byte);
  return btoa(value).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "");
}

function bytesFromBase64Url(value: string) {
  const padded = value.replace(/-/g, "+").replace(/_/g, "/").padEnd(
    Math.ceil(value.length / 4) * 4,
    "=",
  );
  return Uint8Array.from(atob(padded), (char) => char.charCodeAt(0));
}

function base64UrlFromString(value: string) {
  return base64UrlFromBytes(encoder.encode(value));
}

function stringFromBase64Url(value: string) {
  return decoder.decode(bytesFromBase64Url(value));
}

async function sign(value: string) {
  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(getSessionSecret()),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign("HMAC", key, encoder.encode(value));
  return base64UrlFromBytes(new Uint8Array(signature));
}

export async function createLocalAdminSession(login: string) {
  const payload: LocalAdminPayload = {
    login,
    role: "admin",
    exp: Date.now() + sessionMaxAgeSeconds * 1000,
  };
  const encodedPayload = base64UrlFromString(JSON.stringify(payload));
  const signature = await sign(encodedPayload);
  return `${encodedPayload}.${signature}`;
}

export async function verifyLocalAdminSession(token?: string) {
  if (!token) return false;
  const [payload, signature] = token.split(".");
  if (!payload || !signature) return false;

  const expectedSignature = await sign(payload);
  if (expectedSignature !== signature) return false;

  try {
    const parsed = JSON.parse(stringFromBase64Url(payload)) as LocalAdminPayload;
    return parsed.role === "admin" && parsed.exp > Date.now();
  } catch {
    return false;
  }
}

export function getLocalAdminCookieOptions() {
  return {
    httpOnly: true,
    sameSite: "lax" as const,
    secure: process.env.NODE_ENV === "production",
    path: "/",
    maxAge: sessionMaxAgeSeconds,
  };
}
