"use server";

import { Buffer } from "node:buffer";
import { revalidatePath } from "next/cache";
import { z } from "zod";
import { assertAdmin, getSessionUser } from "@/lib/rbac";
import { getCloudinary, getResourceType, buildSignedUploadSignature } from "@/lib/cloudinary";
import { createClient } from "@/lib/supabase/server";
import type { MediaKind } from "@/lib/types";

const mediaKindSchema = z.enum([
  "image",
  "video",
  "round_video",
  "voice",
  "pdf",
  "document",
  "text",
  "file",
]);

async function uploadBufferToCloudinary(
  buffer: Buffer,
  kind: MediaKind,
  fileName: string,
) {
  const client = getCloudinary();
  const resourceType = getResourceType(kind);

  return new Promise<{
    public_id: string;
    secure_url: string;
    resource_type: string;
    format: string;
    bytes: number;
    duration?: number;
    width?: number;
    height?: number;
  }>((resolve, reject) => {
    const upload = client.uploader.upload_stream(
      {
        resource_type: resourceType,
        folder: `labproof-academy/admin/${kind}`,
        use_filename: true,
        unique_filename: true,
        overwrite: false,
        tags: ["labproof", "admin", kind],
        context: {
          alt: fileName,
          source: "next-server-action",
        },
        eager:
          kind === "video" || kind === "round_video"
            ? [
                { format: "mp4", quality: "auto" },
                { format: "jpg", width: 720, height: 405, crop: "fill" },
              ]
            : kind === "image"
              ? [{ fetch_format: "auto", quality: "auto", width: 1440, crop: "limit" }]
              : undefined,
      },
      (error, result) => {
        if (error || !result) {
          reject(error ?? new Error("Cloudinary upload failed."));
          return;
        }
        resolve({
          public_id: result.public_id,
          secure_url: result.secure_url,
          resource_type: result.resource_type,
          format: result.format,
          bytes: result.bytes,
          duration: result.duration,
          width: result.width,
          height: result.height,
        });
      },
    );
    upload.end(buffer);
  });
}

export async function uploadMediaAction(formData: FormData) {
  await assertAdmin();
  const user = await getSessionUser();
  const file = formData.get("file");
  const kind = mediaKindSchema.parse(formData.get("kind") ?? "file");

  if (!(file instanceof File)) {
    return { ok: false, error: "Fayl tanlanmagan." };
  }

  const bytes = await file.arrayBuffer();
  const uploaded = await uploadBufferToCloudinary(
    Buffer.from(bytes),
    kind,
    file.name,
  );

  const supabase = await createClient();
  const { error } = await supabase.from("media_library").insert({
    public_id: uploaded.public_id,
    secure_url: uploaded.secure_url,
    resource_type: uploaded.resource_type,
    format: uploaded.format,
    bytes: uploaded.bytes,
    duration: uploaded.duration ?? null,
    width: uploaded.width ?? null,
    height: uploaded.height ?? null,
    kind,
    original_filename: file.name,
    uploaded_by: user?.id ?? null,
    metadata: {
      source: "next-admin",
      signed: true,
      optimized: true,
    },
  });

  if (error) {
    return { ok: false, error: error.message };
  }

  revalidatePath("/media-library");
  return { ok: true, media: uploaded };
}

export async function deleteMediaAction(mediaId: string) {
  await assertAdmin();
  const supabase = await createClient();
  const { data, error } = await supabase
    .from("media_library")
    .select("public_id, resource_type")
    .eq("id", mediaId)
    .maybeSingle();

  if (error || !data) {
    return { ok: false, error: error?.message ?? "Media topilmadi." };
  }

  await getCloudinary().uploader.destroy(data.public_id, {
    resource_type: data.resource_type,
    invalidate: true,
  });

  const { error: deleteError } = await supabase
    .from("media_library")
    .delete()
    .eq("id", mediaId);

  if (deleteError) return { ok: false, error: deleteError.message };
  revalidatePath("/media-library");
  return { ok: true };
}

export async function createSignedUploadAction() {
  await assertAdmin();
  return buildSignedUploadSignature();
}
