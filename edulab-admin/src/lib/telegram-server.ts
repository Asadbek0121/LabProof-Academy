import { readFileSync } from "node:fs";
import path from "node:path";

type TelegramChat = {
  id: number;
  first_name?: string;
  last_name?: string;
  username?: string;
  title?: string;
  photo?: {
    small_file_id?: string;
    big_file_id?: string;
  };
};

type TelegramFile = {
  file_id: string;
  file_path?: string;
};

const chatCache = new Map<string, Promise<TelegramChat | null>>();
const fileCache = new Map<string, Promise<TelegramFile | null>>();

function readEnvValue(filePath: string, key: string) {
  try {
    const content = readFileSync(filePath, "utf8");
    const match = content.match(new RegExp(`^${key}=(.*)$`, "m"));
    return match?.[1]?.trim().replace(/^["']|["']$/g, "") || "";
  } catch {
    return "";
  }
}

export function getTelegramBotToken() {
  if (process.env.TELEGRAM_BOT_TOKEN) return process.env.TELEGRAM_BOT_TOKEN;

  // Local dev fallback: the Flutter/server side already keeps the Telegram token here.
  // Production should set TELEGRAM_BOT_TOKEN directly in the admin environment.
  return readEnvValue(
    path.join(process.cwd(), "..", "labproof_academy", "server", ".env"),
    "TELEGRAM_BOT_TOKEN",
  );
}

async function telegramApi<T>(method: string, payload: Record<string, unknown>) {
  const token = getTelegramBotToken();
  if (!token) return null;

  const response = await fetch(`https://api.telegram.org/bot${token}/${method}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(payload),
    cache: "no-store",
  });
  if (!response.ok) return null;

  const json = (await response.json()) as { ok?: boolean; result?: T };
  return json.ok ? (json.result ?? null) : null;
}

export function getTelegramChat(chatId: string | number) {
  const key = String(chatId);
  if (!chatCache.has(key)) {
    chatCache.set(key, telegramApi<TelegramChat>("getChat", { chat_id: key }));
  }
  return chatCache.get(key)!;
}

export function getTelegramFile(fileId: string) {
  if (!fileCache.has(fileId)) {
    fileCache.set(fileId, telegramApi<TelegramFile>("getFile", { file_id: fileId }));
  }
  return fileCache.get(fileId)!;
}

export async function getTelegramProfile(chatId?: string | number | null) {
  if (!chatId) return null;
  const chat = await getTelegramChat(chatId);
  if (!chat) return null;

  const fullName = [chat.first_name, chat.last_name].filter(Boolean).join(" ").trim();
  const photoFileId = chat.photo?.big_file_id || chat.photo?.small_file_id || "";

  return {
    name: fullName || chat.title || "",
    username: chat.username || "",
    avatar: photoFileId
      ? `/api/support/telegram-file/${encodeURIComponent(photoFileId)}`
      : "",
  };
}
