import { NextResponse } from "next/server";
import { getTelegramBotToken, getTelegramFile } from "@/lib/telegram-server";

export const runtime = "nodejs";

function contentTypeFromPath(filePath: string) {
  const extension = filePath.split("?")[0].split(".").pop()?.toLowerCase();
  switch (extension) {
    case "jpg":
    case "jpeg":
      return "image/jpeg";
    case "png":
      return "image/png";
    case "webp":
      return "image/webp";
    case "gif":
      return "image/gif";
    default:
      return "application/octet-stream";
  }
}

export async function GET(
  _request: Request,
  { params }: { params: Promise<{ fileId: string }> },
) {
  const token = getTelegramBotToken();
  if (!token) {
    return NextResponse.json({ error: "Telegram token topilmadi" }, { status: 404 });
  }

  const { fileId } = await params;
  const file = await getTelegramFile(decodeURIComponent(fileId));
  if (!file?.file_path) {
    return NextResponse.json({ error: "Telegram fayl topilmadi" }, { status: 404 });
  }

  const response = await fetch(`https://api.telegram.org/file/bot${token}/${file.file_path}`, {
    cache: "no-store",
  });
  if (!response.ok || !response.body) {
    return NextResponse.json({ error: "Telegram fayl yuklanmadi" }, { status: 502 });
  }

  const upstreamContentType = response.headers.get("Content-Type");
  const contentType =
    upstreamContentType && upstreamContentType !== "application/octet-stream"
      ? upstreamContentType
      : contentTypeFromPath(file.file_path);

  return new Response(response.body, {
    status: 200,
    headers: {
      "Content-Type": contentType,
      "Cache-Control": "private, max-age=3600",
    },
  });
}
