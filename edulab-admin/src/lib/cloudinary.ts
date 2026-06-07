import { v2 as cloudinary } from "cloudinary";
import { getRequiredEnv } from "@/lib/env";
import type { MediaKind } from "@/lib/types";

let configured = false;

export function hasCloudinaryEnv() {
  return Boolean(
    process.env.CLOUDINARY_CLOUD_NAME &&
      process.env.CLOUDINARY_API_KEY &&
      process.env.CLOUDINARY_API_SECRET,
  );
}

export function getCloudinary() {
  if (!configured) {
    cloudinary.config({
      cloud_name: getRequiredEnv("CLOUDINARY_CLOUD_NAME"),
      api_key: getRequiredEnv("CLOUDINARY_API_KEY"),
      api_secret: getRequiredEnv("CLOUDINARY_API_SECRET"),
      secure: true,
    });
    configured = true;
  }

  return cloudinary;
}

export function getResourceType(kind: MediaKind) {
  if (kind === "image") return "image";
  if (kind === "video" || kind === "round_video" || kind === "voice") {
    return "video";
  }
  return "raw";
}

export function buildOptimizedUrl(publicId: string, kind: MediaKind) {
  const client = getCloudinary();
  if (kind === "image") {
    return client.url(publicId, {
      fetch_format: "auto",
      quality: "auto",
      width: 1440,
      crop: "limit",
      secure: true,
      resource_type: "image",
    });
  }

  if (kind === "video" || kind === "round_video") {
    return client.url(publicId, {
      resource_type: "video",
      format: "mp4",
      quality: "auto",
      secure: true,
    });
  }

  return client.url(publicId, {
    resource_type: getResourceType(kind),
    secure: true,
  });
}

export function buildThumbnailUrl(publicId: string, kind: MediaKind) {
  const client = getCloudinary();
  if (kind === "video" || kind === "round_video") {
    return client.url(publicId, {
      resource_type: "video",
      format: "jpg",
      start_offset: "auto",
      width: 720,
      height: 405,
      crop: "fill",
      quality: "auto",
      secure: true,
    });
  }

  if (kind === "image") {
    return client.url(publicId, {
      resource_type: "image",
      fetch_format: "auto",
      quality: "auto",
      width: 720,
      height: 405,
      crop: "fill",
      secure: true,
    });
  }

  return "";
}

export function buildSignedUploadSignature(folder = "labproof-academy/admin") {
  const timestamp = Math.round(Date.now() / 1000);
  const client = getCloudinary();
  const signature = client.utils.api_sign_request(
    {
      timestamp,
      folder,
      overwrite: false,
    },
    getRequiredEnv("CLOUDINARY_API_SECRET"),
  );
  return {
    timestamp,
    folder,
    signature,
    apiKey: getRequiredEnv("CLOUDINARY_API_KEY"),
    cloudName: getRequiredEnv("CLOUDINARY_CLOUD_NAME"),
  };
}
