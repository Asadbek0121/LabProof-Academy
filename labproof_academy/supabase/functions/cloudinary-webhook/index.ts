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

Deno.serve(async (request) => {
  if (request.method !== "POST") {
    return Response.json({ ok: false, error: "method_not_allowed" }, { status: 405 });
  }

  const payload = (await request.json()) as CloudinaryPayload;
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
