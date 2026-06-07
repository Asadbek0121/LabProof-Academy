"use server";

import { Buffer } from "node:buffer";
import { randomUUID } from "node:crypto";
import { mkdir, writeFile } from "node:fs/promises";
import path from "node:path";
import { revalidatePath } from "next/cache";
import { z } from "zod";
import { assertAdmin, getSessionUser } from "@/lib/rbac";
import { getCloudinary, getResourceType, buildSignedUploadSignature, hasCloudinaryEnv } from "@/lib/cloudinary";
import { createClient } from "@/lib/supabase/server";
import type { MediaKind } from "@/lib/types";
import { absoluteUrl } from "@/lib/utils";

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

type UploadedMedia = {
  public_id: string;
  secure_url: string;
  resource_type: string;
  format: string;
  bytes: number;
  duration?: number;
  width?: number;
  height?: number;
};

function safeFileStem(fileName: string) {
  return path
    .basename(fileName, path.extname(fileName))
    .toLowerCase()
    .replace(/[^a-z0-9-_]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 60) || "upload";
}

async function uploadBufferToLocalPublic(
  buffer: Buffer,
  kind: MediaKind,
  fileName: string,
): Promise<UploadedMedia> {
  const extension = path.extname(fileName).toLowerCase() || ".bin";
  const stem = safeFileStem(fileName);
  const id = randomUUID();
  const relativePath = `/uploads/admin/${kind}/${id}-${stem}${extension}`;
  const outputPath = path.join(process.cwd(), "public", relativePath);

  await mkdir(path.dirname(outputPath), { recursive: true });
  await writeFile(outputPath, buffer);

  return {
    public_id: `local:${relativePath}`,
    secure_url: absoluteUrl(relativePath),
    resource_type: getResourceType(kind),
    format: extension.replace(".", "") || "bin",
    bytes: buffer.byteLength,
  };
}

async function uploadBufferToCloudinary(
  buffer: Buffer,
  kind: MediaKind,
  fileName: string,
): Promise<UploadedMedia> {
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
  const buffer = Buffer.from(bytes);
  const uploaded = hasCloudinaryEnv()
    ? await uploadBufferToCloudinary(buffer, kind, file.name)
    : await uploadBufferToLocalPublic(buffer, kind, file.name);

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
      source: hasCloudinaryEnv() ? "next-admin" : "next-admin-local",
      signed: hasCloudinaryEnv(),
      optimized: hasCloudinaryEnv(),
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
