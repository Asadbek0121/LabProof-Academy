import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.4";

type UploadPayload = {
  fileBase64?: string;
  fileName?: string;
  extension?: string;
  kind?: "image" | "video" | "round_video" | "voice" | "pdf" | "document" | "text" | "file";
  folder?: string;
};

const encoder = new TextEncoder();

async function sha1Hex(input: string) {
  const digest = await crypto.subtle.digest("SHA-1", encoder.encode(input));
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

function contentTypeFor(extension = "", kind = "file") {
  const ext = extension.toLowerCase().replace(".", "");
  if (ext === "png") return "image/png";
  if (ext === "jpg" || ext === "jpeg") return "image/jpeg";
  if (ext === "webp") return "image/webp";
  if (ext === "gif") return "image/gif";
  if (ext === "mp4") return "video/mp4";
  if (ext === "mov") return "video/quicktime";
  if (ext === "webm") return "video/webm";
  if (ext === "mp3") return "audio/mpeg";
  if (ext === "wav") return "audio/wav";
  if (ext === "ogg" || ext === "oga") return "audio/ogg";
  if (ext === "m4a") return "audio/x-m4a";
  if (ext === "pdf") return "application/pdf";
  if (kind === "text") return "text/plain";
  return "application/octet-stream";
}

function resourceTypeFor(kind = "file") {
  if (kind === "image") return "image";
  if (kind === "video" || kind === "round_video" || kind === "voice") return "video";
  return "raw";
}

Deno.serve(async (request) => {
  if (request.method !== "POST") {
    return Response.json({ ok: false, error: "method_not_allowed" }, { status: 405 });
  }

  const authHeader = request.headers.get("Authorization") ?? "";
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    { global: { headers: { Authorization: authHeader } } },
  );
  const { data: userResult } = await supabase.auth.getUser(authHeader.replace("Bearer ", ""));
  const user = userResult.user;
  if (!user) return Response.json({ ok: false, error: "unauthorized" }, { status: 401 });

  const { data: profile } = await supabase
    .from("profiles")
    .select("role")
    .eq("id", user.id)
    .maybeSingle();
  if (!["admin", "teacher"].includes(profile?.role ?? "")) {
    return Response.json({ ok: false, error: "admin_required" }, { status: 403 });
  }

  const payload = (await request.json()) as UploadPayload;
  if (!payload.fileBase64) {
    return Response.json({ ok: false, error: "file_required" }, { status: 400 });
  }

  const cloudName = Deno.env.get("CLOUDINARY_CLOUD_NAME");
  const apiKey = Deno.env.get("CLOUDINARY_API_KEY");
  const apiSecret = Deno.env.get("CLOUDINARY_API_SECRET");
  if (!cloudName || !apiKey || !apiSecret) {
    return Response.json({ ok: false, error: "cloudinary_env_missing" }, { status: 500 });
  }

  const kind = payload.kind ?? "file";
  const extension = (payload.extension ?? "bin").replace(".", "").toLowerCase();
  const timestamp = Math.floor(Date.now() / 1000).toString();
  const folder = payload.folder ?? `labproof-academy/admin/${kind}`;
  const publicId = `${user.id}/${crypto.randomUUID()}`;
  const tags = `labproof,admin,${kind}`;
  const signatureBase = `folder=${folder}&public_id=${publicId}&tags=${tags}&timestamp=${timestamp}${apiSecret}`;
  const signature = await sha1Hex(signatureBase);

  const bytes = Uint8Array.from(atob(payload.fileBase64), (char) => char.charCodeAt(0));
  const form = new FormData();
  form.set("file", new Blob([bytes], { type: contentTypeFor(extension, kind) }), payload.fileName ?? `upload.${extension}`);
  form.set("api_key", apiKey);
  form.set("timestamp", timestamp);
  form.set("folder", folder);
  form.set("public_id", publicId);
  form.set("tags", tags);
  form.set("signature", signature);

  const resourceType = resourceTypeFor(kind);
  const uploadResponse = await fetch(`https://api.cloudinary.com/v1_1/${cloudName}/${resourceType}/upload`, {
    method: "POST",
    body: form,
  });
  const uploaded = await uploadResponse.json();
  if (!uploadResponse.ok) {
    return Response.json({ ok: false, error: uploaded.error?.message ?? "cloudinary_upload_failed" }, { status: 502 });
  }

  const { error } = await supabase.from("media_library").insert({
    public_id: uploaded.public_id,
    secure_url: uploaded.secure_url,
    resource_type: uploaded.resource_type,
    format: uploaded.format,
    kind,
    bytes: uploaded.bytes ?? bytes.length,
    duration: uploaded.duration ?? null,
    width: uploaded.width ?? null,
    height: uploaded.height ?? null,
    original_filename: payload.fileName ?? null,
    uploaded_by: user.id,
    metadata: { source: "flutter-admin", signed: true, folder },
  });

  if (error) return Response.json({ ok: false, error: error.message }, { status: 500 });

  return Response.json({
    ok: true,
    public_id: uploaded.public_id,
    secure_url: uploaded.secure_url,
    resource_type: uploaded.resource_type,
    format: uploaded.format,
    bytes: uploaded.bytes ?? bytes.length,
    duration: uploaded.duration ?? null,
    width: uploaded.width ?? null,
    height: uploaded.height ?? null,
  });
});
