import { NextResponse } from "next/server";
import { cookies } from "next/headers";
import { createAdminClient } from "@/lib/supabase/admin";
import { createClient as createServerSupabaseClient } from "@/lib/supabase/server";
import {
  LOCAL_ADMIN_SESSION_COOKIE,
  verifyLocalAdminSession,
} from "@/lib/admin-local-session";
import { supportArchivedConversations } from "@/lib/support-archived-data";
import { getTelegramBotToken, getTelegramProfile } from "@/lib/telegram-server";
import type { ChatMessage, Conversation } from "@/lib/types";

type AnyRecord = Record<string, any>;

async function isAllowedAdmin() {
  const cookieStore = await cookies();
  const localSession = await verifyLocalAdminSession(
    cookieStore.get(LOCAL_ADMIN_SESSION_COOKIE)?.value,
  );
  if (localSession) return true;

  try {
    const supabase = await createServerSupabaseClient();
    const { data } = await supabase.auth.getUser();
    const user = data.user;
    if (!user) return false;
    const { data: profile } = await supabase
      .from("profiles")
      .select("role")
      .eq("id", user.id)
      .maybeSingle();
    return ["admin", "teacher"].includes(profile?.role ?? "");
  } catch {
    return false;
  }
}

function formatTime(value?: string | null) {
  if (!value) return "";
  return new Date(value).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" });
}

function formatSize(bytes?: number | null) {
  if (!bytes) return undefined;
  const mb = Number(bytes) / (1024 * 1024);
  return `${mb.toFixed(mb >= 10 ? 0 : 1)} MB`;
}

function messageKind(kind?: string | null): ChatMessage["kind"] {
  if (kind === "video_note") return "round_video";
  if (kind === "audio") return "voice";
  if (kind === "image" || kind === "video" || kind === "voice" || kind === "pdf" || kind === "document" || kind === "file" || kind === "round_video") {
    return kind;
  }
  return "text";
}

function lastSeenLabel(date?: string | null) {
  if (!date) return "Aniqlanmagan";
  const diffMs = Date.now() - new Date(date).getTime();
  if (diffMs < 90_000) return "Hozir faol";
  if (diffMs < 60 * 60 * 1000) return `${Math.max(1, Math.round(diffMs / 60_000))} daqiqa oldin`;
  if (diffMs < 24 * 60 * 60 * 1000) return `${Math.round(diffMs / (60 * 60 * 1000))} soat oldin`;
  return new Date(date).toLocaleDateString("uz-UZ");
}

function isOnline(conversation: AnyRecord, profile?: AnyRecord) {
  const metadata = conversation.metadata ?? {};
  const candidates = [
    conversation.typing_at,
    conversation.last_seen_at,
    metadata.telegram_last_seen_at,
    metadata.last_seen_at,
    profile?.telegram_last_seen_at,
  ].filter(Boolean) as string[];
  const latest = candidates
    .map((value) => new Date(value).getTime())
    .filter(Number.isFinite)
    .sort((a, b) => b - a)[0];
  if (!latest) return Boolean(conversation.is_online);
  return Boolean(conversation.is_online) || Date.now() - latest < 5 * 60 * 1000;
}

function profileName(profile?: AnyRecord, fallback?: string) {
  return profile?.full_name || fallback || profile?.telegram_username || "Noma'lum foydalanuvchi";
}

function profileAvatar(profile?: AnyRecord, metadata?: AnyRecord) {
  return (
    profile?.avatar_url ||
    metadata?.avatar_url ||
    metadata?.photo_url ||
    metadata?.telegram_photo_url ||
    metadata?.telegram_avatar_url ||
    (metadata?.telegram_photo_file_id
      ? `/api/support/telegram-file/${encodeURIComponent(metadata.telegram_photo_file_id)}`
      : null) ||
    null
  );
}

async function sendTelegramReply(chatId: string | number | null | undefined, text: string) {
  const token = getTelegramBotToken();
  if (!token || !chatId) return;

  const response = await fetch(`https://api.telegram.org/bot${token}/sendMessage`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      chat_id: chatId,
      text,
      parse_mode: "HTML",
    }),
  });

  if (!response.ok) {
    const payload = await response.text();
    throw new Error(`Telegramga yuborilmadi: ${payload}`);
  }
}

function toChatMessage(row: AnyRecord): ChatMessage {
  const kind = messageKind(row.message_kind);
  return {
    id: row.id,
    author:
      row.sender_type === "admin" || row.author === "admin"
        ? "admin"
        : row.sender_type === "bot"
          ? "bot"
          : "student",
    body: row.body || "",
    time: formatTime(row.created_at),
    kind,
    fileName: row.attachment_name || undefined,
    fileSize: formatSize(row.attachment_size),
    previewUrl: kind === "image" ? row.attachment_url || undefined : undefined,
    attachmentUrl: row.attachment_url || undefined,
    duration: row.duration ? `${Math.round(Number(row.duration))}s` : undefined,
    read: Boolean(row.read_at || row.is_read),
    createdAt: row.created_at,
  };
}

async function loadProfiles(admin: ReturnType<typeof createAdminClient>, userIds: string[], telegramChatIds: string[]) {
  const byId = new Map<string, AnyRecord>();
  const byTelegramChat = new Map<string, AnyRecord>();

  if (userIds.length) {
    const { data } = await admin
      .from("profiles")
      .select("id, full_name, phone, avatar_url, telegram_chat_id, telegram_user_id, telegram_username, telegram_last_seen_at")
      .in("id", userIds);
    data?.forEach((profile) => {
      byId.set(profile.id, profile);
      if (profile.telegram_chat_id) byTelegramChat.set(String(profile.telegram_chat_id), profile);
    });
  }

  const missingTelegramIds = telegramChatIds.filter((id) => !byTelegramChat.has(id));
  if (missingTelegramIds.length) {
    const { data } = await admin
      .from("profiles")
      .select("id, full_name, phone, avatar_url, telegram_chat_id, telegram_user_id, telegram_username, telegram_last_seen_at")
      .in("telegram_chat_id", missingTelegramIds);
    data?.forEach((profile) => {
      byId.set(profile.id, profile);
      if (profile.telegram_chat_id) byTelegramChat.set(String(profile.telegram_chat_id), profile);
    });
  }

  return { byId, byTelegramChat };
}

async function enrichTelegramConversation(conversation: Conversation) {
  if (conversation.source !== "telegram" || !conversation.telegramChatId) {
    return conversation;
  }

  const telegramProfile = await getTelegramProfile(conversation.telegramChatId);
  if (!telegramProfile) return conversation;

  return {
    ...conversation,
    name: telegramProfile.name || conversation.name,
    username: telegramProfile.username || conversation.username,
    avatar: telegramProfile.avatar || conversation.avatar,
    about: [
      telegramProfile.username
        ? `Username: @${telegramProfile.username}`
        : conversation.username
          ? `Username: @${conversation.username}`
          : "Telegram username: yo'q",
      conversation.telegramChatId
        ? `Telegram chat ID: ${conversation.telegramChatId}`
        : "Telegram chat ID aniqlanmagan",
    ],
  };
}

async function enrichTelegramConversations(conversations: Conversation[]) {
  return Promise.all(conversations.map(enrichTelegramConversation));
}

export async function GET() {
  if (!(await isAllowedAdmin())) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const admin = createAdminClient();
  const conversations: Conversation[] = [];

  const { data: notificationConversations } = await admin
    .from("notification_conversations")
    .select("*")
    .order("last_message_at", { ascending: false });

  const notificationIds = notificationConversations?.map((item) => item.id) ?? [];
  const { data: notificationMessages } = notificationIds.length
    ? await admin
        .from("notification_messages")
        .select("*")
        .in("conversation_id", notificationIds)
        .order("created_at", { ascending: true })
    : { data: [] as AnyRecord[] };

  const userIds = [
    ...new Set(
      (notificationConversations ?? [])
        .map((item) => item.participant_user_id)
        .filter(Boolean),
    ),
  ];
  const telegramIds = [
    ...new Set(
      (notificationConversations ?? [])
        .map((item) => item.telegram_chat_id)
        .filter(Boolean)
        .map(String),
    ),
  ];

  const { data: legacyMessages } = await admin
    .from("admin_inbox_messages")
    .select("*")
    .order("created_at", { ascending: true });

  legacyMessages?.forEach((message) => {
    if (message.sender_user_id) userIds.push(message.sender_user_id);
    if (message.telegram_chat_id) telegramIds.push(String(message.telegram_chat_id));
  });

  const profiles = await loadProfiles(admin, [...new Set(userIds)], [...new Set(telegramIds)]);
  const messagesByConversation = new Map<string, AnyRecord[]>();
  notificationMessages?.forEach((message) => {
    const list = messagesByConversation.get(message.conversation_id) ?? [];
    list.push(message);
    messagesByConversation.set(message.conversation_id, list);
  });

  notificationConversations?.forEach((conversation) => {
    const metadata = conversation.metadata ?? {};
    const profile = conversation.participant_user_id
      ? profiles.byId.get(conversation.participant_user_id)
      : conversation.telegram_chat_id
        ? profiles.byTelegramChat.get(String(conversation.telegram_chat_id))
        : undefined;
    const messages = messagesByConversation.get(conversation.id) ?? [];
    const lastMessage = messages[messages.length - 1];
    const source = conversation.source === "telegram" ? "telegram" : "student_app";
    conversations.push({
      id: conversation.id,
      backend: "notification",
      name: profileName(profile, conversation.title || metadata.full_name || metadata.sender_name),
      label: source === "telegram" ? "TELEGRAM" : "APK",
      lastMessage:
        lastMessage?.body ||
        lastMessage?.attachment_name ||
        (lastMessage?.message_kind ? "Media xabar yuborildi" : "Suhbat boshlandi"),
      time: formatTime(conversation.last_message_at),
      unread: Number(conversation.unread_admin_count ?? 0),
      online: isOnline(conversation, profile),
      source,
      avatar: profileAvatar(profile, metadata) || undefined,
      participantUserId: conversation.participant_user_id,
      telegramChatId: conversation.telegram_chat_id,
      phone: profile?.phone || metadata.phone || "",
      username: profile?.telegram_username || metadata.telegram_username || metadata.username || "",
      lastSeenLabel: lastSeenLabel(conversation.typing_at || profile?.telegram_last_seen_at || conversation.last_message_at),
      about:
        source === "telegram"
          ? [
              profile?.telegram_username ? `Username: @${profile.telegram_username}` : "Telegram username: yo'q",
              conversation.telegram_chat_id ? `Chat ID: ${conversation.telegram_chat_id}` : "Chat ID aniqlanmagan",
            ]
          : [
              profile?.phone ? `Telefon: ${profile.phone}` : "Telefon aniqlanmagan",
              conversation.participant_user_id ? `User ID: ${conversation.participant_user_id}` : "User ID aniqlanmagan",
            ],
      messages: messages.map(toChatMessage),
    });
  });

  const legacyMap = new Map<string, Conversation>();
  legacyMessages?.forEach((message) => {
    const key = `legacy:${message.sender_user_id || message.telegram_chat_id || message.sender_name || message.id}`;
    const metadata = message.metadata ?? {};
    const profile = message.sender_user_id
      ? profiles.byId.get(message.sender_user_id)
      : message.telegram_chat_id
        ? profiles.byTelegramChat.get(String(message.telegram_chat_id))
        : undefined;
    if (!legacyMap.has(key)) {
      const source = message.source === "telegram" ? "telegram" : "student_app";
      legacyMap.set(key, {
        id: key,
        backend: "legacy_inbox",
        name: profileName(profile, message.sender_name || metadata.full_name || metadata.sender_name),
        label: source === "telegram" ? "TELEGRAM" : "APK",
        lastMessage: message.body || "",
        time: formatTime(message.created_at),
        unread: 0,
        online: isOnline({ ...message, last_seen_at: metadata.telegram_last_seen_at, is_online: false }, profile),
        source,
        avatar: profileAvatar(profile, metadata) || undefined,
        participantUserId: message.sender_user_id,
        telegramChatId: message.telegram_chat_id,
        phone: profile?.phone || message.sender_phone || "",
        username: profile?.telegram_username || metadata.telegram_username || "",
        lastSeenLabel: lastSeenLabel(
          profile?.telegram_last_seen_at ||
            metadata.telegram_last_seen_at ||
            metadata.last_seen_at ||
            message.created_at,
        ),
        about:
          source === "telegram"
            ? [
                profile?.telegram_username || metadata.telegram_username
                  ? `Username: @${profile?.telegram_username || metadata.telegram_username}`
                  : "Telegram username: yo'q",
                message.telegram_chat_id ? `Chat ID: ${message.telegram_chat_id}` : "Chat ID aniqlanmagan",
              ]
            : [
                profile?.phone || message.sender_phone ? `Telefon: ${profile?.phone || message.sender_phone}` : "Telefon aniqlanmagan",
                message.sender_user_id ? `User ID: ${message.sender_user_id}` : "User ID aniqlanmagan",
              ],
        messages: [],
      });
    }
    const conversation = legacyMap.get(key)!;
    conversation.lastMessage = message.body || message.attachment_name || "Media xabar yuborildi";
    conversation.time = formatTime(message.created_at);
    if (!message.is_read) conversation.unread += 1;
    conversation.messages.push(toChatMessage({ ...message, sender_type: "student" }));
    if (message.admin_reply) {
      conversation.messages.push({
        id: `${message.id}_reply`,
        author: "admin",
        body: message.admin_reply,
        time: formatTime(message.replied_at || message.created_at),
        kind: "text",
        read: Boolean(message.recipient_read_at),
        createdAt: message.replied_at || message.created_at,
      });
    }
  });

  conversations.push(...legacyMap.values());
  conversations.sort((a, b) => {
    const aDate = a.messages[a.messages.length - 1]?.createdAt ?? "";
    const bDate = b.messages[b.messages.length - 1]?.createdAt ?? "";
    return new Date(bDate).getTime() - new Date(aDate).getTime();
  });

  if (!conversations.length) {
    return NextResponse.json(await enrichTelegramConversations(supportArchivedConversations));
  }

  return NextResponse.json(await enrichTelegramConversations(conversations));
}

export async function PATCH(request: Request) {
  if (!(await isAllowedAdmin())) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }
  const body = await request.json();
  const admin = createAdminClient();
  if (body.backend === "archive") {
    return NextResponse.json({ ok: true, archive: true });
  }
  if (body.backend === "notification") {
    await admin
      .from("notification_messages")
      .update({ read_at: new Date().toISOString() })
      .eq("conversation_id", body.id)
      .neq("sender_type", "admin")
      .is("read_at", null);
    await admin
      .from("notification_conversations")
      .update({ unread_admin_count: 0 })
      .eq("id", body.id);
  } else if (body.backend === "legacy_inbox") {
    const messageIds = Array.isArray(body.messageIds)
      ? body.messageIds.map(String).filter(Boolean)
      : [];
    if (messageIds.length) {
      await admin
        .from("admin_inbox_messages")
        .update({ is_read: true, admin_read_at: new Date().toISOString() })
        .in("id", messageIds);
      return NextResponse.json({ ok: true });
    }
    const rawId = String(body.id ?? "").replace(/^legacy:/, "");
    await admin
      .from("admin_inbox_messages")
      .update({ is_read: true, admin_read_at: new Date().toISOString() })
      .or(`sender_user_id.eq.${rawId},telegram_chat_id.eq.${rawId}`);
  }
  return NextResponse.json({ ok: true });
}

export async function POST(request: Request) {
  if (!(await isAllowedAdmin())) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }
  const body = await request.json();
  const replyText = String(body.replyText ?? "").trim();
  if (!replyText) return NextResponse.json({ error: "Javob matnini kiriting." }, { status: 400 });

  const admin = createAdminClient();
  if (body.backend === "archive") {
    return NextResponse.json({ ok: true, archive: true });
  }
  if (body.backend === "notification") {
    const { data: conversation } = await admin
      .from("notification_conversations")
      .select("source, telegram_chat_id")
      .eq("id", body.id)
      .maybeSingle();
    const { error } = await admin.from("notification_messages").insert({
      conversation_id: body.id,
      sender_type: "admin",
      message_kind: "text",
      body: replyText,
      metadata: { source: "edulab-admin" },
    });
    if (error) return NextResponse.json({ error: error.message }, { status: 500 });
    await admin
      .from("notification_conversations")
      .update({ last_message_at: new Date().toISOString(), unread_student_count: 1 })
      .eq("id", body.id);
    if (conversation?.source === "telegram") {
      await sendTelegramReply(conversation.telegram_chat_id, replyText);
    }
    return NextResponse.json({ ok: true });
  }

  const messageId = String(body.messageId ?? "").replace(/_reply$/, "");
  if (!messageId) return NextResponse.json({ error: "Javob beriladigan xabar topilmadi." }, { status: 400 });
  const { data: inboxMessage } = await admin
    .from("admin_inbox_messages")
    .select("source, telegram_chat_id")
    .eq("id", messageId)
    .maybeSingle();
  const { error } = await admin
    .from("admin_inbox_messages")
    .update({
      admin_reply: replyText,
      replied_at: new Date().toISOString(),
      is_read: true,
      admin_read_at: new Date().toISOString(),
    })
    .eq("id", messageId);
  if (error) return NextResponse.json({ error: error.message }, { status: 500 });
  if (inboxMessage?.source === "telegram") {
    await sendTelegramReply(inboxMessage.telegram_chat_id, replyText);
  }

  return NextResponse.json({ ok: true });
}

export async function DELETE(request: Request) {
  if (!(await isAllowedAdmin())) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const body = await request.json();
  const action = body.action === "delete" ? "delete" : "clear";
  const backend = String(body.backend ?? "");
  const id = String(body.id ?? "");
  const messageIds = Array.isArray(body.messageIds)
    ? [...new Set(body.messageIds.map((item: unknown) => String(item).replace(/_reply$/, "")).filter(Boolean))]
    : [];

  if (!id) {
    return NextResponse.json({ error: "Suhbat topilmadi." }, { status: 400 });
  }

  if (backend === "archive") {
    return NextResponse.json({ ok: true, archive: true });
  }

  const admin = createAdminClient();

  if (backend === "notification") {
    if (action === "delete") {
      const { error } = await admin
        .from("notification_conversations")
        .delete()
        .eq("id", id);
      if (error) return NextResponse.json({ error: error.message }, { status: 500 });
      return NextResponse.json({ ok: true });
    }

    const { error: messagesError } = await admin
      .from("notification_messages")
      .delete()
      .eq("conversation_id", id);
    if (messagesError) {
      return NextResponse.json({ error: messagesError.message }, { status: 500 });
    }

    const { error: conversationError } = await admin
      .from("notification_conversations")
      .update({
        unread_admin_count: 0,
        unread_student_count: 0,
        last_message_at: new Date().toISOString(),
      })
      .eq("id", id);
    if (conversationError) {
      return NextResponse.json({ error: conversationError.message }, { status: 500 });
    }

    return NextResponse.json({ ok: true });
  }

  if (backend === "legacy_inbox") {
    if (!messageIds.length) {
      return NextResponse.json({ error: "O'chiriladigan xabarlar topilmadi." }, { status: 400 });
    }

    const { error } = await admin
      .from("admin_inbox_messages")
      .delete()
      .in("id", messageIds);
    if (error) return NextResponse.json({ error: error.message }, { status: 500 });
    return NextResponse.json({ ok: true });
  }

  return NextResponse.json({ error: "Noma'lum suhbat turi." }, { status: 400 });
}
