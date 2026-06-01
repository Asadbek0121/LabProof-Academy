"use server";

import { revalidatePath } from "next/cache";
import { z } from "zod";
import { assertAdmin, getSessionUser } from "@/lib/rbac";
import { createClient } from "@/lib/supabase/server";

const messageSchema = z.object({
  conversationId: z.string().min(1),
  body: z.string().min(1).max(4000),
  kind: z
    .enum(["text", "image", "video", "round_video", "voice", "pdf", "document", "file"])
    .default("text"),
  mediaId: z.string().uuid().optional(),
});

export async function sendNotificationMessageAction(input: unknown) {
  await assertAdmin();
  const user = await getSessionUser();
  const payload = messageSchema.parse(input);
  const supabase = await createClient();

  const { error } = await supabase.from("notifications").insert({
    target_user_id: payload.conversationId,
    title: "Tizim xabarnomasi",
    body: payload.body,
    message_kind: payload.kind,
    created_at: new Date().toISOString(),
  });

  if (error) return { ok: false, error: error.message };
  revalidatePath("/notifications");
  return { ok: true };
}
