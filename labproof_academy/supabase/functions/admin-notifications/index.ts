import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.4";

Deno.serve(async (request) => {
  if (request.method !== "POST") {
    return Response.json({ ok: false, error: "method_not_allowed" }, { status: 405 });
  }

  const payload = await request.json();
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
  );

  const { data: conversation, error: conversationError } = await supabase
    .from("notification_conversations")
    .upsert(
      {
        source: payload.source ?? "student_app",
        participant_user_id: payload.participant_user_id ?? null,
        telegram_chat_id: payload.telegram_chat_id ?? null,
        title: payload.title ?? "Yangi suhbat",
        is_online: true,
        typing_at: null,
        last_message_at: new Date().toISOString(),
      },
      { onConflict: "id" },
    )
    .select("id")
    .single();

  if (conversationError) {
    return Response.json({ ok: false, error: conversationError.message }, { status: 500 });
  }

  const { error } = await supabase.from("notification_messages").insert({
    conversation_id: payload.conversation_id ?? conversation.id,
    sender_user_id: payload.sender_user_id ?? null,
    sender_type: payload.sender_type ?? "student",
    message_kind: payload.message_kind ?? "text",
    body: payload.body ?? "",
    attachment_url: payload.attachment_url ?? null,
    attachment_name: payload.attachment_name ?? null,
    attachment_size: payload.attachment_size ?? null,
    duration: payload.duration ?? null,
    metadata: payload.metadata ?? {},
  });

  if (error) {
    return Response.json({ ok: false, error: error.message }, { status: 500 });
  }

  return Response.json({ ok: true, conversation_id: payload.conversation_id ?? conversation.id });
});
