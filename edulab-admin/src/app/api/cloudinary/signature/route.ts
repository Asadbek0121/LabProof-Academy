import { NextResponse } from "next/server";
import { createSignedUploadAction } from "@/actions/media";

export async function POST() {
  try {
    const signature = await createSignedUploadAction();
    return NextResponse.json(signature);
  } catch (error) {
    return NextResponse.json(
      { error: error instanceof Error ? error.message : "Signature yaratilmadi." },
      { status: 401 },
    );
  }
}
