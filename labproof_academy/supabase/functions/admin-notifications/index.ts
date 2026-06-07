import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.4";

Deno.serve(async (request) => {
  if (request.method !== "POST") {
    return Response.json({ ok: false, error: "method_not_allowed" }, { status: 405 });
  }

  const authHeader = request.headers.get("Authorization") ?? "";
  const accessToken = authHeader.replace("Bearer ", "").trim();
  if (!accessToken) {
    return Response.json({ ok: false, error: "unauthorized" }, { status: 401 });
  }

  const payload = await request.json();
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
  );
  const { data: userResult, error: authError } = await supabase.auth.getUser(accessToken);
  const user = userResult.user;
  if (authError || !user) {
    return Response.json({ ok: false, error: "unauthorized" }, { status: 401 });
  }

  const { data: profile } = await supabase
    .from("profiles")
    .select("role")
    .eq("id", user.id)
    .maybeSingle();
  const isAdmin = ["admin", "teacher"].includes(profile?.role ?? "");
  const conversationId = typeof payload.conversation_id === "string" && payload.conversation_id
    ? payload.conversation_id
    : undefined;
  const participantUserId = isAdmin
    ? payload.participant_user_id ?? null
    : user.id;
  const senderUserId = isAdmin
    ? payload.sender_user_id ?? user.id
    : user.id;
  const senderType = isAdmin
    ? payload.sender_type ?? "admin"
    : "student";
  const now = new Date().toISOString();
  const messageMetadata = {
    ...(payload.metadata && typeof payload.metadata === "object" ? payload.metadata : {}),
    app_user_id: senderUserId,
    participant_user_id: participantUserId,
    last_seen_at: now,
    source_device: payload.source ?? "student_app",
  };

  const { data: conversation, error: conversationError } = await supabase
    .from("notification_conversations")
    .upsert(
      {
        ...(conversationId ? { id: conversationId } : {}),
        source: payload.source ?? "student_app",
        participant_user_id: participantUserId,
        telegram_chat_id: payload.telegram_chat_id ?? null,
        title: payload.title ?? "Yangi suhbat",
        is_online: senderType !== "admin",
        typing_at: null,
        last_message_at: now,
      },
      { onConflict: "id" },
    )
    .select("id")
    .single();

  if (conversationError) {
    return Response.json({ ok: false, error: conversationError.message }, { status: 500 });
  }

  const { error } = await supabase.from("notification_messages").insert({
    conversation_id: conversationId ?? conversation.id,
    sender_user_id: senderUserId,
    sender_type: senderType,
    message_kind: payload.message_kind ?? "text",
    body: payload.body ?? "",
    attachment_url: payload.attachment_url ?? null,
    attachment_name: payload.attachment_name ?? null,
    attachment_size: payload.attachment_size ?? null,
    duration: payload.duration ?? null,
    metadata: messageMetadata,
  });

  if (error) {
    return Response.json({ ok: false, error: error.message }, { status: 500 });
  }

  const { data: counters } = await supabase
    .from("notification_conversations")
    .select("unread_admin_count, unread_student_count")
    .eq("id", conversationId ?? conversation.id)
    .maybeSingle();

  await supabase
    .from("notification_conversations")
    .update({
      last_message_at: now,
      is_online: senderType !== "admin",
      unread_admin_count:
        senderType === "admin"
          ? Number(counters?.unread_admin_count ?? 0)
          : Number(counters?.unread_admin_count ?? 0) + 1,
      unread_student_count:
        senderType === "admin"
          ? Number(counters?.unread_student_count ?? 0) + 1
          : Number(counters?.unread_student_count ?? 0),
    })
    .eq("id", conversationId ?? conversation.id);

  return Response.json({ ok: true, conversation_id: conversationId ?? conversation.id });
});
