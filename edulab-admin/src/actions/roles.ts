"use server";

import { revalidatePath } from "next/cache";
import { z } from "zod";
import { assertAdmin } from "@/lib/rbac";
import { createClient } from "@/lib/supabase/server";

const roleSchema = z.object({
  name: z.string().min(2),
  description: z.string().min(2),
  color: z.string().regex(/^#[0-9A-Fa-f]{6}$/),
  permissions: z.array(z.string()).default([]),
  moduleAccess: z.array(z.string()).default([]),
});

export async function createRoleAction(input: unknown) {
  await assertAdmin();
  const payload = roleSchema.parse(input);
  const supabase = await createClient();

  const { data, error } = await supabase
    .from("roles")
    .insert({
      name: payload.name,
      description: payload.description,
      color: payload.color,
      module_access: payload.moduleAccess,
    })
    .select("id")
    .single();

  if (error || !data) return { ok: false, error: error?.message ?? "Rol yaratilmadi." };

  if (payload.permissions.length) {
    const rows = payload.permissions.map((permissionId) => ({
      role_id: data.id,
      permission_id: permissionId,
    }));
    const { error: permissionError } = await supabase
      .from("role_permissions")
      .insert(rows);
    if (permissionError) return { ok: false, error: permissionError.message };
  }

  revalidatePath("/roles");
  return { ok: true, roleId: data.id };
}
