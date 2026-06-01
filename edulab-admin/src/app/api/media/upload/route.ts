import { NextResponse } from "next/server";
import { uploadMediaAction } from "@/actions/media";

export async function POST(request: Request) {
  const formData = await request.formData();
  const result = await uploadMediaAction(formData);
  return NextResponse.json(result, { status: result.ok ? 200 : 400 });
}
