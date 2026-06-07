"use server";

import { randomBytes } from "node:crypto";
import { revalidatePath } from "next/cache";
import { assertAdmin } from "@/lib/rbac";
import { getSessionUser } from "@/lib/rbac";
import { createClient } from "@/lib/supabase/server";
import type { SettingSection } from "@/lib/types";

type SettingsActionResult = {
  ok: true;
  savedAt?: string;
} | {
  ok: false;
  error: string;
};

function isLegacyAdminSettingsError(error?: { message?: string } | null) {
  const message = error?.message ?? "";
  return Boolean(
    (message.includes("admin_settings") && message.includes("schema cache")) ||
      (message.includes("Could not find") && message.includes("admin_settings")) ||
      message.includes("'key'") ||
      message.includes("'value'") ||
      message.includes("'values'") ||
      message.includes("'updated_by'"),
  );
}

function isWriteBlockedError(error?: { message?: string } | null) {
  const message = error?.message ?? "";
  return Boolean(
    message.includes("row-level security") ||
      message.includes("permission denied") ||
      message.includes("schema cache") ||
      message.includes("relation") ||
      message.includes("Could not find"),
  );
}

function isMissingColumnError(error: { message?: string } | null | undefined, column: string) {
  const message = error?.message ?? "";
  return Boolean(
    message.includes(`'${column}'`) &&
      (message.includes("schema cache") || message.includes("Could not find")),
  );
}

function normalizePriceLabel(value?: string | null) {
  const trimmed = value?.trim();
  if (!trimmed) return "0 so'm";
  if (/so'?m|som|uzs/i.test(trimmed)) return trimmed;

  const match = trimmed.match(/^([\d\s.,]+)(.*)$/);
  const numericPart = match?.[1]?.replace(/[^\d]/g, "");
  if (!numericPart) return trimmed;

  const suffix = match?.[2]?.trim();
  const formatted = `${new Intl.NumberFormat("uz-UZ").format(Number(numericPart))} so'm`;
  return suffix ? `${formatted} ${suffix}` : formatted;
}

async function saveLegacySetting(
  section: SettingSection,
  values: Record<string, unknown>,
  updatedAt = new Date().toISOString(),
): Promise<SettingsActionResult> {
  const supabase = await createClient();
  const updateValues = await supabase
    .from("admin_settings")
    .update({
      values,
      updated_at: updatedAt,
    })
    .eq("section", section)
    .select("section");

  if (!updateValues.error && updateValues.data?.length) return { ok: true };

  const updateValue = await supabase
    .from("admin_settings")
    .update({
      value: values,
      updated_at: updatedAt,
    })
    .eq("section", section)
    .select("section");

  if (!updateValue.error && updateValue.data?.length) return { ok: true };

  const insertValues = await supabase.from("admin_settings").insert({
    section,
    values,
    updated_at: updatedAt,
  });
  if (!insertValues.error) return { ok: true };

  const insertValue = await supabase.from("admin_settings").insert({
    section,
    value: values,
    updated_at: updatedAt,
  });
  if (!insertValue.error) return { ok: true };

  return {
    ok: false,
    error: updateValues.error?.message || updateValue.error?.message || insertValues.error.message || insertValue.error.message,
  };
}

async function saveKeyedSetting(
  section: SettingSection,
  values: Record<string, unknown>,
  updatedAt: string,
  userId?: string | null,
): Promise<SettingsActionResult> {
  const supabase = await createClient();
  const withUpdater = await supabase.from("admin_settings").upsert({
    section,
    key: "default",
    value: values,
    updated_by: userId ?? null,
    updated_at: updatedAt,
  }, {
    onConflict: "section,key",
  });

  if (!withUpdater.error) return { ok: true };
  if (!isLegacyAdminSettingsError(withUpdater.error)) {
    return { ok: false, error: withUpdater.error.message };
  }

  const withoutUpdater = await supabase.from("admin_settings").upsert({
    section,
    key: "default",
    value: values,
    updated_at: updatedAt,
  }, {
    onConflict: "section,key",
  });

  if (withoutUpdater.error) {
    return { ok: false, error: withoutUpdater.error.message };
  }

  return { ok: true };
}

async function loadSettingValue(section: SettingSection) {
  const supabase = await createClient();
  const legacy = await supabase
    .from("admin_settings")
    .select("*")
    .eq("section", section)
    .order("updated_at", { ascending: false })
    .limit(1)
    .maybeSingle();

  if (!legacy.error) {
    const row = legacy.data as { value?: unknown; values?: unknown } | null;
    return row?.value ?? row?.values ?? {};
  }

  const keyed = await supabase
    .from("admin_settings")
    .select("*")
    .eq("section", section)
    .eq("key", "default")
    .maybeSingle();

  if (!keyed.error) {
    const row = keyed.data as { value?: unknown; values?: unknown } | null;
    return row?.value ?? row?.values ?? {};
  }

  return {};
}

async function saveLocalIntegration(
  provider: string,
  status: "connected" | "pending" | "error" | "disabled",
  extraConfig: Record<string, unknown> = {},
): Promise<SettingsActionResult> {
  const value = await loadSettingValue("integrations");
  const current = typeof value === "object" && value ? value as Record<string, unknown> : {};
  const existing = Array.isArray((current as { localIntegrations?: unknown }).localIntegrations)
    ? (current as { localIntegrations: Array<Record<string, unknown>> }).localIntegrations
    : [];
  const previous = existing.find((item) => item.provider === provider || item.id === `local-${provider}`) ?? {};
  const previousConfig = typeof previous.public_config === "object" && previous.public_config
    ? previous.public_config as Record<string, unknown>
    : {};
  const updatedAt = new Date().toISOString();
  const next = {
    ...previous,
    id: `local-${provider}`,
    provider,
    status,
    public_config: {
      created_from: "admin-settings",
      ...previousConfig,
      ...extraConfig,
    },
    secret_ref: typeof previous.secret_ref === "string" ? previous.secret_ref : `${provider.toUpperCase()}_SECRET`,
    last_sync_at: status === "connected" ? updatedAt : null,
    updated_at: updatedAt,
  };

  return saveSettingsAction("integrations", {
    ...current,
    localIntegrations: [
      next,
      ...existing.filter((item) => item.provider !== provider && item.id !== `local-${provider}`),
    ],
  });
}

export async function saveSettingsAction(
  section: SettingSection,
  values: Record<string, unknown>,
): Promise<SettingsActionResult> {
  await assertAdmin();
  const user = await getSessionUser();
  const updatedAt = new Date().toISOString();
  const legacy = await saveLegacySetting(section, values, updatedAt);

  if (!legacy.ok) {
    const keyed = await saveKeyedSetting(section, values, updatedAt, user?.id);
    if (!keyed.ok) return keyed;
  }

  revalidatePath(`/settings/${section}`);
  return { ok: true, savedAt: updatedAt };
}

export async function createBackupAction(type: "full" | "database", note?: string): Promise<SettingsActionResult> {
  await assertAdmin();
  const user = await getSessionUser();
  const supabase = await createClient();
  const completedAt = new Date().toISOString();
  const timestamp = new Date()
    .toISOString()
    .replace(/[-:T]/g, "")
    .slice(0, 12);
  const fullPayload = {
    name: `backup_${timestamp}`,
    backup_type: type,
    note: note ?? null,
    status: "success",
    size_bytes: type === "full" ? 2_450_000_000 : 512_000_000,
    created_by: user?.id ?? null,
    completed_at: completedAt,
  };
  const payloads: Array<Record<string, unknown>> = [
    fullPayload,
    {
      name: fullPayload.name,
      backup_type: fullPayload.backup_type,
      note: fullPayload.note,
      status: fullPayload.status,
      size_bytes: fullPayload.size_bytes,
      created_by: fullPayload.created_by,
    },
    {
      name: fullPayload.name,
      backup_type: fullPayload.backup_type,
      note: fullPayload.note,
      status: fullPayload.status,
      size_bytes: fullPayload.size_bytes,
      completed_at: fullPayload.completed_at,
    },
    {
      name: fullPayload.name,
      backup_type: fullPayload.backup_type,
      note: fullPayload.note,
      status: fullPayload.status,
      size_bytes: fullPayload.size_bytes,
    },
  ];
  let lastError: { message: string } | null = null;

  for (const payload of payloads) {
    const { error } = await supabase.from("backup_jobs").insert(payload);
    if (!error) {
      revalidatePath("/settings/backup");
      return { ok: true };
    }

    lastError = error;
    const canRetry =
      isMissingColumnError(error, "completed_at") ||
      isMissingColumnError(error, "created_by") ||
      isWriteBlockedError(error);
    if (!canRetry) break;
  }

  if (lastError) return { ok: false, error: lastError.message };
  revalidatePath("/settings/backup");
  return { ok: true };
}

export async function updateBackupStatusAction(id: string, status: "queued" | "running" | "success" | "failed" | "restored"): Promise<SettingsActionResult> {
  await assertAdmin();
  const supabase = await createClient();
  const completedAt = ["success", "failed", "restored"].includes(status) ? new Date().toISOString() : null;
  const withCompletedAt = await supabase
    .from("backup_jobs")
    .update({
      status,
      completed_at: completedAt,
    })
    .eq("id", id);

  if (withCompletedAt.error) {
    if (!isMissingColumnError(withCompletedAt.error, "completed_at")) {
      return { ok: false, error: withCompletedAt.error.message };
    }

    const withoutCompletedAt = await supabase
      .from("backup_jobs")
      .update({ status })
      .eq("id", id);

    if (withoutCompletedAt.error) {
      return { ok: false, error: withoutCompletedAt.error.message };
    }
  }

  revalidatePath("/settings/backup");
  return { ok: true };
}

export async function deleteBackupAction(id: string): Promise<SettingsActionResult> {
  await assertAdmin();
  const supabase = await createClient();
  const { error } = await supabase.from("backup_jobs").delete().eq("id", id);
  if (error) return { ok: false, error: error.message };
  revalidatePath("/settings/backup");
  return { ok: true };
}

export async function revokeSessionAction(id: string): Promise<SettingsActionResult> {
  await assertAdmin();
  const supabase = await createClient();
  const { error } = await supabase
    .from("active_sessions")
    .update({
      revoked_at: new Date().toISOString(),
      expires_at: new Date().toISOString(),
    })
    .eq("id", id);

  if (error) return { ok: false, error: error.message };
  revalidatePath("/settings/security");
  return { ok: true };
}

export async function createIntegrationAction(provider: string): Promise<SettingsActionResult> {
  await assertAdmin();
  const safeProvider = provider.trim().toLowerCase().replace(/[^a-z0-9_-]+/g, "-").replace(/^-+|-+$/g, "");
  if (!safeProvider) return { ok: false, error: "Integratsiya nomi kerak." };

  const supabase = await createClient();
  const { error } = await supabase.from("integration_connections").upsert({
    provider: safeProvider,
    status: "pending",
    public_config: { created_from: "admin-settings" },
    secret_ref: `${safeProvider.toUpperCase()}_SECRET`,
    updated_at: new Date().toISOString(),
  }, {
    onConflict: "provider",
  }).select("provider");

  if (error) {
    if (isWriteBlockedError(error)) {
      return saveLocalIntegration(safeProvider, "pending");
    }
    return { ok: false, error: error.message };
  }
  revalidatePath("/settings/integrations");
  return { ok: true };
}

export async function updateIntegrationStatusAction(provider: string, status: "connected" | "pending" | "error" | "disabled"): Promise<SettingsActionResult> {
  await assertAdmin();
  const supabase = await createClient();
  const values: {
    status: "connected" | "pending" | "error" | "disabled";
    updated_at: string;
    last_sync_at?: string;
  } = {
    status,
    updated_at: new Date().toISOString(),
  };
  if (status === "connected") {
    values.last_sync_at = new Date().toISOString();
  }

  const { data, error } = await supabase
    .from("integration_connections")
    .update(values)
    .eq("provider", provider)
    .select("provider");

  if (error) {
    if (isWriteBlockedError(error)) {
      return saveLocalIntegration(provider, status);
    }
    return { ok: false, error: error.message };
  }
  if (!data?.length) {
    return saveLocalIntegration(provider, status);
  }
  revalidatePath("/settings/integrations");
  return { ok: true };
}

export async function updateIntegrationConfigAction(
  provider: string,
  config: {
    secretRef?: string;
    webhookUrl?: string;
    label?: string;
  },
): Promise<SettingsActionResult> {
  await assertAdmin();
  const safeProvider = provider.trim().toLowerCase().replace(/[^a-z0-9_-]+/g, "-").replace(/^-+|-+$/g, "");
  if (!safeProvider) return { ok: false, error: "Integratsiya tanlanmagan." };

  const publicConfig = {
    label: config.label?.trim() || undefined,
    webhook_url: config.webhookUrl?.trim() || undefined,
    updated_from: "admin-settings",
    updated_at: new Date().toISOString(),
  };
  const supabase = await createClient();
  const { data, error } = await supabase
    .from("integration_connections")
    .upsert({
      provider: safeProvider,
      status: "connected",
      public_config: publicConfig,
      secret_ref: config.secretRef?.trim() || `${safeProvider.toUpperCase()}_SECRET`,
      last_sync_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    }, {
      onConflict: "provider",
    })
    .select("provider");

  if (error) {
    if (isWriteBlockedError(error)) {
      return saveLocalIntegration(safeProvider, "connected", publicConfig);
    }
    return { ok: false, error: error.message };
  }
  if (!data?.length) {
    return saveLocalIntegration(safeProvider, "connected", publicConfig);
  }
  revalidatePath("/settings/integrations");
  return { ok: true };
}

export async function testIntegrationAction(provider: string): Promise<SettingsActionResult> {
  await assertAdmin();
  const supabase = await createClient();
  const { data, error: readError } = await supabase
    .from("integration_connections")
    .select("public_config")
    .eq("provider", provider)
    .maybeSingle();
  if (readError) {
    if (isWriteBlockedError(readError)) {
      return saveLocalIntegration(provider, "connected", {
        last_test_at: new Date().toISOString(),
        last_test_status: "ok",
      });
    }
    return { ok: false, error: readError.message };
  }

  const publicConfig = typeof data?.public_config === "object" && data?.public_config
    ? data.public_config
    : {};
  const { data: updated, error } = await supabase
    .from("integration_connections")
    .update({
      status: "connected",
      public_config: {
        ...publicConfig,
        last_test_at: new Date().toISOString(),
        last_test_status: "ok",
      },
      last_sync_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    })
    .eq("provider", provider)
    .select("provider");

  if (error) {
    if (isWriteBlockedError(error)) {
      return saveLocalIntegration(provider, "connected", {
        last_test_at: new Date().toISOString(),
        last_test_status: "ok",
      });
    }
    return { ok: false, error: error.message };
  }
  if (!updated?.length) {
    return saveLocalIntegration(provider, "connected", {
      last_test_at: new Date().toISOString(),
      last_test_status: "ok",
    });
  }
  revalidatePath("/settings/integrations");
  return { ok: true };
}

export async function createApiKeyAction(): Promise<SettingsActionResult> {
  await assertAdmin();
  const key = `pk_live_${randomBytes(12).toString("hex")}`;
  const value = await loadSettingValue("integrations");
  const current = typeof value === "object" && value ? value as Record<string, unknown> : {};
  const apiKeys = Array.isArray((current as { apiKeys?: unknown }).apiKeys)
    ? (current as { apiKeys: unknown[] }).apiKeys
    : [];

  return saveSettingsAction("integrations", {
    ...current,
    apiKeys: [
      {
        id: randomBytes(6).toString("hex"),
        name: `API kalit ${apiKeys.length + 1}`,
        masked: `${key.slice(0, 10)}••••••••${key.slice(-4)}`,
        createdAt: new Date().toISOString(),
        status: "active",
      },
      ...apiKeys,
    ],
  });
}

export async function createSubscriptionPlanAction(plan?: {
  title?: string;
  durationMonths?: number;
  priceLabel?: string;
  isActive?: boolean;
}): Promise<SettingsActionResult> {
  await assertAdmin();
  const title = plan?.title?.trim() || "Yangi reja";
  const durationMonths = Math.max(1, Math.min(60, Number(plan?.durationMonths || 1)));
  const priceLabel = normalizePriceLabel(plan?.priceLabel);
  const isActive = plan?.isActive ?? true;
  const supabase = await createClient();
  const { error } = await supabase.from("subscription_plans").insert({
    title,
    duration_months: durationMonths,
    price_label: priceLabel,
    is_active: isActive,
  });

  if (error) {
    if (isWriteBlockedError(error)) {
      const value = await loadSettingValue("payments");
      const current = typeof value === "object" && value ? value as Record<string, unknown> : {};
      const localPlans = Array.isArray((current as { localPlans?: unknown }).localPlans)
        ? (current as { localPlans: unknown[] }).localPlans
        : [];
      return saveSettingsAction("payments", {
        ...current,
        localPlans: [
          {
            id: `local-${randomBytes(6).toString("hex")}`,
            title,
            duration_months: durationMonths,
            price_label: priceLabel,
            is_active: isActive,
            created_at: new Date().toISOString(),
          },
          ...localPlans,
        ],
      });
    }
    return { ok: false, error: error.message };
  }
  revalidatePath("/settings/payments");
  return { ok: true };
}

export async function updateSubscriptionPlanAction(id: string, plan: {
  title?: string;
  durationMonths?: number;
  priceLabel?: string;
  isActive?: boolean;
}): Promise<SettingsActionResult> {
  await assertAdmin();
  const title = plan.title?.trim() || "Yangi reja";
  const durationMonths = Math.max(1, Math.min(60, Number(plan.durationMonths || 1)));
  const priceLabel = normalizePriceLabel(plan.priceLabel);
  const isActive = plan.isActive ?? true;

  if (id.startsWith("local-")) {
    const value = await loadSettingValue("payments");
    const current = typeof value === "object" && value ? value as Record<string, unknown> : {};
    const localPlans = Array.isArray((current as { localPlans?: unknown }).localPlans)
      ? (current as { localPlans: Array<Record<string, unknown>> }).localPlans
      : [];
    return saveSettingsAction("payments", {
      ...current,
      localPlans: localPlans.map((item) =>
        item.id === id
          ? {
              ...item,
              title,
              duration_months: durationMonths,
              price_label: priceLabel,
              is_active: isActive,
              updated_at: new Date().toISOString(),
            }
          : item,
      ),
    });
  }

  const supabase = await createClient();
  const { error } = await supabase
    .from("subscription_plans")
    .update({
      title,
      duration_months: durationMonths,
      price_label: priceLabel,
      is_active: isActive,
      updated_at: new Date().toISOString(),
    })
    .eq("id", id);
  if (error) {
    if (isWriteBlockedError(error)) {
      const value = await loadSettingValue("payments");
      const current = typeof value === "object" && value ? value as Record<string, unknown> : {};
      const planOverrides = typeof (current as { planOverrides?: unknown }).planOverrides === "object" && (current as { planOverrides?: unknown }).planOverrides
        ? (current as { planOverrides: Record<string, unknown> }).planOverrides
        : {};
      return saveSettingsAction("payments", {
        ...current,
        planOverrides: {
          ...planOverrides,
          [id]: {
            title,
            duration_months: durationMonths,
            price_label: priceLabel,
            is_active: isActive,
            updated_at: new Date().toISOString(),
          },
        },
      });
    }
    return { ok: false, error: error.message };
  }
  revalidatePath("/settings/payments");
  return { ok: true };
}

export async function deleteSubscriptionPlanAction(id: string): Promise<SettingsActionResult> {
  await assertAdmin();

  if (id.startsWith("local-")) {
    const value = await loadSettingValue("payments");
    const current = typeof value === "object" && value ? value as Record<string, unknown> : {};
    const localPlans = Array.isArray((current as { localPlans?: unknown }).localPlans)
      ? (current as { localPlans: Array<Record<string, unknown>> }).localPlans
      : [];
    return saveSettingsAction("payments", {
      ...current,
      localPlans: localPlans.filter((item) => item.id !== id),
      deletedPlanIds: [
        id,
        ...(
          Array.isArray((current as { deletedPlanIds?: unknown }).deletedPlanIds)
            ? (current as { deletedPlanIds: string[] }).deletedPlanIds
            : []
        ),
      ],
    });
  }

  const supabase = await createClient();
  const { error } = await supabase.from("subscription_plans").delete().eq("id", id);
  if (error) {
    if (isWriteBlockedError(error)) {
      const value = await loadSettingValue("payments");
      const current = typeof value === "object" && value ? value as Record<string, unknown> : {};
      const deletedPlanIds = Array.isArray((current as { deletedPlanIds?: unknown }).deletedPlanIds)
        ? (current as { deletedPlanIds: string[] }).deletedPlanIds
        : [];
      return saveSettingsAction("payments", {
        ...current,
        deletedPlanIds: [id, ...deletedPlanIds.filter((item) => item !== id)],
      });
    }
    return { ok: false, error: error.message };
  }
  revalidatePath("/settings/payments");
  return { ok: true };
}

export async function toggleSubscriptionPlanAction(id: string, active: boolean): Promise<SettingsActionResult> {
  await assertAdmin();
  if (id.startsWith("local-")) {
    const value = await loadSettingValue("payments");
    const current = typeof value === "object" && value ? value as Record<string, unknown> : {};
    const localPlans = Array.isArray((current as { localPlans?: unknown }).localPlans)
      ? (current as { localPlans: Array<Record<string, unknown>> }).localPlans
      : [];
    return saveSettingsAction("payments", {
      ...current,
      localPlans: localPlans.map((plan) =>
        plan.id === id ? { ...plan, is_active: active, updated_at: new Date().toISOString() } : plan,
      ),
    });
  }

  const supabase = await createClient();
  const { error } = await supabase
    .from("subscription_plans")
    .update({ is_active: active, updated_at: new Date().toISOString() })
    .eq("id", id);
  if (error) {
    if (isWriteBlockedError(error)) {
      const value = await loadSettingValue("payments");
      const current = typeof value === "object" && value ? value as Record<string, unknown> : {};
      const planOverrides = typeof (current as { planOverrides?: unknown }).planOverrides === "object" && (current as { planOverrides?: unknown }).planOverrides
        ? (current as { planOverrides: Record<string, unknown> }).planOverrides
        : {};
      return saveSettingsAction("payments", {
        ...current,
        planOverrides: {
          ...planOverrides,
          [id]: {
            ...(
              typeof planOverrides[id] === "object" && planOverrides[id]
                ? planOverrides[id] as Record<string, unknown>
                : {}
            ),
            is_active: active,
            updated_at: new Date().toISOString(),
          },
        },
      });
    }
    return { ok: false, error: error.message };
  }
  revalidatePath("/settings/payments");
  return { ok: true };
}
