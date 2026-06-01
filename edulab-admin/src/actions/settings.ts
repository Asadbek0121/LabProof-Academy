"use server";

import { revalidatePath } from "next/cache";
import { assertAdmin } from "@/lib/rbac";
import { createClient } from "@/lib/supabase/server";
import type { SettingSection } from "@/lib/types";

export async function saveSettingsAction(
  section: SettingSection,
  values: Record<string, unknown>,
) {
  await assertAdmin();
  const supabase = await createClient();
  const { error } = await supabase.from("admin_settings").upsert({
    section,
    values,
    updated_at: new Date().toISOString(),
  });

  if (error) return { ok: false, error: error.message };
  revalidatePath(`/settings/${section}`);
  return { ok: true, savedAt: new Date().toISOString() };
}

export async function createBackupAction(type: "full" | "database", note?: string) {
  await assertAdmin();
  const supabase = await createClient();
  const { error } = await supabase.from("backup_jobs").insert({
    backup_type: type,
    note: note ?? null,
    status: "queued",
  });
  if (error) return { ok: false, error: error.message };
  revalidatePath("/settings/backup");
  return { ok: true };
}
