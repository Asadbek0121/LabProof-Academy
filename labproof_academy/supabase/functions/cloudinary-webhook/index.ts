import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.4";

type CloudinaryPayload = {
  public_id?: string;
  secure_url?: string;
  resource_type?: "image" | "video" | "raw";
  format?: string;
  bytes?: number;
  duration?: number;
  width?: number;
  height?: number;
  original_filename?: string;
};

const encoder = new TextEncoder();

async function digestHex(input: string, algorithm: "SHA-1" | "SHA-256") {
  const digest = await crypto.subtle.digest(algorithm, encoder.encode(input));
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

function timingSafeEqual(left: string, right: string) {
  if (left.length !== right.length) return false;
  let mismatch = 0;
  for (let i = 0; i < left.length; i += 1) {
    mismatch |= left.charCodeAt(i) ^ right.charCodeAt(i);
  }
  return mismatch === 0;
}

async function verifyCloudinarySignature(request: Request, rawBody: string) {
  const apiSecret = Deno.env.get("CLOUDINARY_API_SECRET");
  if (!apiSecret) return false;

  const timestamp = request.headers.get("X-Cld-Timestamp") ?? "";
  const signature = request.headers.get("X-Cld-Signature") ?? "";
  if (!timestamp || !signature) return false;

  const timestampSeconds = Number(timestamp);
  if (!Number.isFinite(timestampSeconds)) return false;

  const maxAgeSeconds = 2 * 60 * 60;
  const ageSeconds = Math.abs(Date.now() / 1000 - timestampSeconds);
  if (ageSeconds > maxAgeSeconds) return false;

  const signedPayload = `${rawBody}${timestamp}${apiSecret}`;
  const sha1 = await digestHex(signedPayload, "SHA-1");
  const sha256 = await digestHex(signedPayload, "SHA-256");
  return timingSafeEqual(signature, sha1) || timingSafeEqual(signature, sha256);
}

Deno.serve(async (request) => {
  if (request.method !== "POST") {
    return Response.json({ ok: false, error: "method_not_allowed" }, { status: 405 });
  }

  const rawBody = await request.text();
  if (!(await verifyCloudinarySignature(request, rawBody))) {
    return Response.json({ ok: false, error: "invalid_signature" }, { status: 401 });
  }

  const payload = JSON.parse(rawBody) as CloudinaryPayload;
  if (!payload.public_id || !payload.secure_url || !payload.resource_type) {
    return Response.json({ ok: false, error: "invalid_cloudinary_payload" }, { status: 400 });
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
  );

  const kind = payload.resource_type === "image"
    ? "image"
    : payload.resource_type === "video"
      ? "video"
      : payload.format === "pdf"
        ? "pdf"
        : "file";

  const { error } = await supabase.from("media_library").upsert(
    {
      public_id: payload.public_id,
      secure_url: payload.secure_url,
      resource_type: payload.resource_type,
      format: payload.format,
      kind,
      bytes: payload.bytes ?? 0,
      duration: payload.duration ?? null,
      width: payload.width ?? null,
      height: payload.height ?? null,
      original_filename: payload.original_filename ?? null,
      metadata: { source: "cloudinary-webhook" },
    },
    { onConflict: "public_id" },
  );

  if (error) {
    return Response.json({ ok: false, error: error.message }, { status: 500 });
  }

  return Response.json({ ok: true });
});
