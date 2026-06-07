import { NextResponse } from "next/server";
import { uploadMediaAction } from "@/actions/media";

export async function POST(request: Request) {
  try {
    const formData = await request.formData();
    const result = await uploadMediaAction(formData);
    return NextResponse.json(result, { status: result.ok ? 200 : 400 });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Fayl yuklashda server xatoligi yuz berdi.";
    const isCloudinaryConfigError = message.includes("CLOUDINARY_");

    console.error("[media/upload]", error);

    return NextResponse.json(
      {
        ok: false,
        error: isCloudinaryConfigError
          ? "Cloudinary sozlamalari topilmadi. Fayl yuklash uchun CLOUDINARY_CLOUD_NAME, CLOUDINARY_API_KEY va CLOUDINARY_API_SECRET ni .env faylga qo'shing yoki sertifikat URL manzilini kiriting."
          : message,
      },
      { status: isCloudinaryConfigError ? 503 : 500 },
    );
  }
}
