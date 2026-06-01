"use server";

import QRCode from "qrcode";
import { revalidatePath } from "next/cache";
import { z } from "zod";
import { absoluteUrl } from "@/lib/utils";
import { assertAdmin } from "@/lib/rbac";
import { createClient } from "@/lib/supabase/server";

const certificateSchema = z.object({
  studentId: z.string().min(1),
  moduleId: z.string().min(1),
  title: z.string().min(2),
  certificateFileUrl: z.string().url().optional(),
});

export async function createCertificateAction(input: unknown) {
  await assertAdmin();
  const payload = certificateSchema.parse(input);
  const supabase = await createClient();
  const certificateId = `CERT-${new Date().getFullYear()}-${crypto.randomUUID().slice(0, 8).toUpperCase()}`;
  const verifyUrl = absoluteUrl(`/certificates/verify/${certificateId}`);
  const qrDataUrl = await QRCode.toDataURL(verifyUrl, {
    width: 320,
    margin: 1,
    color: {
      dark: "#0F172A",
      light: "#FFFFFF",
    },
  });

  const { error } = await supabase.from("certificates").insert({
    id: crypto.randomUUID(),
    user_id: payload.studentId,
    module_id: payload.moduleId,
    certificate_url: payload.certificateFileUrl ?? null,
    issued_at: new Date().toISOString(),
  });

  if (error) return { ok: false, error: error.message };
  revalidatePath("/certificates");
  return { ok: true, certificateId, qrDataUrl, verifyUrl };
}
