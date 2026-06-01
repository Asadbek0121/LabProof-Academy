import { NextResponse } from "next/server";
import { deleteMediaAction } from "@/actions/media";

export async function POST(request: Request) {
  const body = (await request.json()) as { id?: string };
  if (!body.id) {
    return NextResponse.json({ ok: false, error: "Media ID kerak." }, { status: 400 });
  }
  const result = await deleteMediaAction(body.id);
  return NextResponse.json(result, { status: result.ok ? 200 : 400 });
}
