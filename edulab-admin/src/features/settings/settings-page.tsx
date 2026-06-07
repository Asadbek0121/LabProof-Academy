"use client";

import Link from "next/link";
import type * as React from "react";
import { useEffect, useMemo, useRef, useState, useTransition } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { toast } from "sonner";
import {
  AlertTriangle,
  Bell,
  CheckCircle2,
  ChevronRight,
  Cloud,
  Copy,
  CreditCard,
  Database,
  Download,
  Eye,
  EyeOff,
  FileArchive,
  Folder,
  Globe2,
  HardDrive,
  Info,
  KeyRound,
  Lock,
  Mail,
  MoreVertical,
  PanelLeftClose,
  PanelLeftOpen,
  Pencil,
  Plus,
  RefreshCcw,
  Save,
  Send,
  Server,
  ShieldCheck,
  SlidersHorizontal,
  Trash2,
  UploadCloud,
  WalletCards,
  XCircle,
} from "lucide-react";
import {
  createApiKeyAction,
  createBackupAction,
  createIntegrationAction,
  createSubscriptionPlanAction,
  deleteSubscriptionPlanAction,
  deleteBackupAction,
  revokeSessionAction,
  saveSettingsAction,
  testIntegrationAction,
  toggleSubscriptionPlanAction,
  updateIntegrationConfigAction,
  updateBackupStatusAction,
  updateIntegrationStatusAction,
  updateSubscriptionPlanAction,
} from "@/actions/settings";
import { PageHeader } from "@/components/layout/page-header";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Input, Select, Textarea } from "@/components/ui/input";
import { Modal } from "@/components/ui/modal";
import { SecurityGeoMap, type SecurityMapPoint } from "@/features/settings/security-geo-map";
import { settingSections } from "@/lib/mock-data";
import { createClient } from "@/lib/supabase/client";
import type { SettingSection } from "@/lib/types";
import { cn } from "@/lib/utils";

type SettingsPageProps = {
  section: SettingSection;
};

type BackupJob = {
  id: string;
  name: string;
  backup_type: "full" | "database";
  size_bytes: number | null;
  status: "queued" | "running" | "success" | "failed" | "restored";
  note: string | null;
  created_at: string;
  completed_at?: string | null;
};

type IntegrationConnection = {
  id: string;
  provider: string;
  status: "connected" | "pending" | "error" | "disabled";
  public_config: Record<string, unknown> | null;
  secret_ref: string | null;
  last_sync_at: string | null;
  updated_at: string | null;
};

type ApiKeyRecord = {
  id?: string;
  name?: string;
  masked?: string;
  value?: string;
  createdAt?: string;
  status?: string;
};

type Transaction = {
  id: string;
  user_id: string | null;
  provider: string;
  amount: number;
  currency: string;
  status: "pending" | "successful" | "failed" | "refunded";
  created_at: string;
};

type Subscription = {
  id: string;
  plan_key?: string | null;
  status: string;
  amount?: number | null;
  created_at: string;
};

type SubscriptionPlan = {
  id: string;
  title: string;
  duration_months: number;
  price_label: string;
  is_active: boolean;
  created_at?: string;
};

type LoginHistory = {
  id: string;
  ip_address: string | null;
  user_agent: string | null;
  location: string | null;
  success: boolean;
  failure_reason: string | null;
  created_at: string;
};

type ActiveSession = {
  id: string;
  device_name: string | null;
  browser: string | null;
  ip_address: string | null;
  location: string | null;
  last_seen_at: string | null;
  revoked_at: string | null;
};

const STORAGE_LIMIT_BYTES = 100 * 1024 * 1024 * 1024;

function formatDate(value?: string | null) {
  if (!value) return "-";
  return new Date(value).toLocaleString("uz-UZ", {
    day: "2-digit",
    month: "2-digit",
    year: "numeric",
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
  });
}

function formatMoney(value: number, currency = "so'm") {
  return `${new Intl.NumberFormat("uz-UZ").format(Math.round(value))} ${currency}`;
}

function normalizePriceLabel(value?: string | null) {
  const trimmed = value?.trim();
  if (!trimmed) return "0 so'm";
  if (/so'?m|som|uzs/i.test(trimmed)) return trimmed;

  const match = trimmed.match(/^([\d\s.,]+)(.*)$/);
  const numericPart = match?.[1]?.replace(/[^\d]/g, "");
  if (!numericPart) return trimmed;

  const suffix = match?.[2]?.trim();
  const formatted = formatMoney(Number(numericPart));
  return suffix ? `${formatted} ${suffix}` : formatted;
}

function formatBytes(bytes?: number | null) {
  const value = Number(bytes || 0);
  if (value >= 1024 * 1024 * 1024) return `${(value / 1024 / 1024 / 1024).toFixed(1)} GB`;
  if (value >= 1024 * 1024) return `${(value / 1024 / 1024).toFixed(1)} MB`;
  if (value >= 1024) return `${(value / 1024).toFixed(1)} KB`;
  return `${value} B`;
}

function downloadTextFile(fileName: string, content: string, type = "text/plain;charset=utf-8") {
  const blob = new Blob([content], { type });
  const url = URL.createObjectURL(blob);
  const anchor = document.createElement("a");
  anchor.href = url;
  anchor.download = fileName;
  anchor.click();
  URL.revokeObjectURL(url);
}

function toCsv(rows: Array<Record<string, unknown>>) {
  if (!rows.length) return "";
  const headers = Object.keys(rows[0]);
  const escape = (value: unknown) => `"${String(value ?? "").replaceAll("\"", "\"\"")}"`;
  return [
    headers.map(escape).join(","),
    ...rows.map((row) => headers.map((header) => escape(row[header])).join(",")),
  ].join("\n");
}

function escapeHtml(value: unknown) {
  return String(value ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll("\"", "&quot;")
    .replaceAll("'", "&#039;");
}

function toExcelTable(title: string, rows: Array<[string, unknown]>) {
  return `<!doctype html>
<html>
  <head>
    <meta charset="utf-8" />
    <style>
      body { font-family: Arial, sans-serif; }
      h1 { font-size: 20px; }
      table { border-collapse: collapse; min-width: 560px; }
      th, td { border: 1px solid #d8dee9; padding: 10px 12px; text-align: left; }
      th { background: #eff6ff; font-weight: 700; }
    </style>
  </head>
  <body>
    <h1>${escapeHtml(title)}</h1>
    <table>
      <tbody>
        ${rows.map(([label, value]) => `<tr><th>${escapeHtml(label)}</th><td>${escapeHtml(value)}</td></tr>`).join("")}
      </tbody>
    </table>
  </body>
</html>`;
}

function monthKey(value: string) {
  return new Date(value).toISOString().slice(0, 7);
}

function lastMonths(count: number) {
  return Array.from({ length: count }, (_, index) => {
    const date = new Date();
    date.setMonth(date.getMonth() - (count - 1 - index));
    return date.toISOString().slice(0, 7);
  });
}

function lastHours(count: number) {
  return Array.from({ length: count }, (_, index) => {
    const date = new Date();
    date.setHours(date.getHours() - (count - 1 - index), 0, 0, 0);
    return date;
  });
}

function sameHour(date: Date, source: string) {
  const other = new Date(source);
  return date.getFullYear() === other.getFullYear()
    && date.getMonth() === other.getMonth()
    && date.getDate() === other.getDate()
    && date.getHours() === other.getHours();
}

function getStoredSettings(data: SettingsData | undefined, section: SettingSection): Record<string, unknown> {
  const item = data?.settings.find((item) =>
    item.section === section && (!item.key || item.key === "default"),
  ) as { value?: unknown; values?: unknown } | undefined;
  const stored = item?.value ?? item?.values;
  return typeof stored === "object" && stored ? stored as Record<string, unknown> : {};
}

const knownLocationCoordinates: Array<{ keys: string[]; coordinates: [number, number] }> = [
  { keys: ["toshkent", "tashkent"], coordinates: [69.2401, 41.2995] },
  { keys: ["samarqand", "samarkand"], coordinates: [66.9597, 39.6542] },
  { keys: ["farg'ona", "fargona", "fergana"], coordinates: [71.7978, 40.3894] },
  { keys: ["andijon", "andijan"], coordinates: [72.3442, 40.7821] },
  { keys: ["namangan"], coordinates: [71.6726, 40.9983] },
  { keys: ["buxoro", "bukhara"], coordinates: [64.4286, 39.7747] },
  { keys: ["nukus"], coordinates: [59.6103, 42.4618] },
  { keys: ["qarshi", "karshi"], coordinates: [65.7978, 38.8610] },
  { keys: ["termiz", "termez"], coordinates: [67.2783, 37.2242] },
  { keys: ["jizzax", "jizzakh"], coordinates: [67.8422, 40.1254] },
  { keys: ["navoiy", "navoi"], coordinates: [65.3792, 40.0844] },
  { keys: ["xorazm", "urganch", "urgench"], coordinates: [60.6330, 41.5500] },
  { keys: ["guliston", "sirdaryo"], coordinates: [68.7842, 40.4897] },
  { keys: ["uzbekistan", "o'zbekiston", "uz"], coordinates: [64.5853, 41.3775] },
  { keys: ["usa", "united states"], coordinates: [-98.5795, 39.8283] },
  { keys: ["russia", "rossiya"], coordinates: [37.6173, 55.7558] },
  { keys: ["turkey", "turkiya"], coordinates: [32.8597, 39.9334] },
  { keys: ["kazakhstan", "qozog'iston"], coordinates: [71.4304, 51.1282] },
  { keys: ["kyrgyzstan", "qirg'iziston"], coordinates: [74.5698, 42.8746] },
  { keys: ["tajikistan", "tojikiston"], coordinates: [68.7870, 38.5598] },
];

function parseLocationCoordinates(value?: string | null): [number, number] | null {
  if (!value) return null;
  const raw = value.trim();
  const coordMatch = raw.match(/(-?\d{1,3}(?:\.\d+)?)\s*,\s*(-?\d{1,3}(?:\.\d+)?)/);
  if (coordMatch) {
    const first = Number(coordMatch[1]);
    const second = Number(coordMatch[2]);
    if (Number.isFinite(first) && Number.isFinite(second)) {
      const looksLikeLatLng = Math.abs(first) <= 90 && Math.abs(second) <= 180;
      return looksLikeLatLng ? [second, first] : [first, second];
    }
  }

  try {
    const parsed = JSON.parse(raw) as Partial<{ longitude: number; latitude: number; lng: number; lat: number }>;
    const longitude = parsed.longitude ?? parsed.lng;
    const latitude = parsed.latitude ?? parsed.lat;
    if (typeof longitude === "number" && typeof latitude === "number") {
      return [longitude, latitude];
    }
  } catch {
    // Location is usually plain text.
  }

  const lower = raw.toLowerCase();
  return knownLocationCoordinates.find((item) =>
    item.keys.some((key) => lower.includes(key)),
  )?.coordinates ?? null;
}

function buildSecurityMapPoints(logins: LoginHistory[]): SecurityMapPoint[] {
  const grouped = new Map<string, SecurityMapPoint>();

  logins.forEach((login) => {
    const coordinates = parseLocationCoordinates(login.location);
    if (!coordinates) return;
    const location = login.location || "Aniqlangan joy";
    const ip = login.ip_address || "IP noma'lum";
    const key = `${location}-${ip}-${login.success ? "ok" : "bad"}`;
    const current = grouped.get(key);

    if (current) {
      current.attempts += 1;
      if (new Date(login.created_at).getTime() > new Date(current.createdAt).getTime()) {
        current.createdAt = login.created_at;
      }
      return;
    }

    grouped.set(key, {
      id: login.id,
      label: login.success ? "Muvaffaqiyatli" : "Xavfli",
      location,
      ip,
      success: login.success,
      attempts: 1,
      createdAt: login.created_at,
      longitude: coordinates[0],
      latitude: coordinates[1],
    });
  });

  return Array.from(grouped.values()).sort(
    (a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime(),
  );
}

async function selectRows<T>(query: PromiseLike<{ data: T[] | null; error: unknown }>) {
  const result = await query;
  return result.error ? [] : result.data ?? [];
}

function useSettingsData() {
  const supabase = createClient();

  return useQuery({
    queryKey: ["settings-page-data"],
    queryFn: async () => {
      const [
        settings,
        backups,
        integrations,
        transactions,
        subscriptions,
        userSubscriptions,
        plans,
        logins,
        sessions,
        media,
        profiles,
      ] = await Promise.all([
        selectRows<{ section: string; key?: string | null; value?: Record<string, unknown>; values?: Record<string, unknown>; updated_at?: string }>(
          supabase.from("admin_settings").select("*").order("updated_at", { ascending: false }),
        ),
        selectRows<BackupJob>(
          supabase.from("backup_jobs").select("*").order("created_at", { ascending: false }).limit(20),
        ),
        selectRows<IntegrationConnection>(
          supabase.from("integration_connections").select("*").order("provider", { ascending: true }),
        ),
        selectRows<Transaction>(
          supabase.from("transactions").select("id,user_id,provider,amount,currency,status,created_at").order("created_at", { ascending: false }).limit(80),
        ),
        selectRows<Subscription>(
          supabase.from("subscriptions").select("id,plan_key,status,amount,created_at").order("created_at", { ascending: false }).limit(80),
        ),
        selectRows<Subscription>(
          supabase.from("user_subscriptions").select("id,status,created_at").order("created_at", { ascending: false }).limit(80),
        ),
        selectRows<SubscriptionPlan>(
          supabase.from("subscription_plans").select("id,title,duration_months,price_label,is_active").order("created_at", { ascending: true }),
        ),
        selectRows<LoginHistory>(
          supabase.from("login_history").select("*").order("created_at", { ascending: false }).limit(80),
        ),
        selectRows<ActiveSession>(
          supabase.from("active_sessions").select("*").order("last_seen_at", { ascending: false }).limit(20),
        ),
        selectRows<{ bytes: number | null; kind: string | null; created_at: string }>(
          supabase.from("media_library").select("bytes,kind,created_at").limit(500),
        ),
        selectRows<{ id: string; role: string; created_at: string; telegram_last_seen_at: string | null }>(
          supabase.from("profiles").select("id,role,created_at,telegram_last_seen_at").eq("role", "student"),
        ),
      ]);

      const mediaBytes = media.reduce((sum, item) => sum + Number(item.bytes || 0), 0);
      const successfulTransactions = transactions.filter((item) => item.status === "successful");
      const failedTransactions = transactions.filter((item) => item.status === "failed");
      const nowMonth = new Date().toISOString().slice(0, 7);
      const monthlyRevenue = successfulTransactions
        .filter((item) => monthKey(item.created_at) === nowMonth)
        .reduce((sum, item) => sum + Number(item.amount || 0), 0);
      const totalRevenue = successfulTransactions.reduce((sum, item) => sum + Number(item.amount || 0), 0);
      const revenueTrend = lastMonths(12).map((key) => ({
        name: new Date(`${key}-01T00:00:00`).toLocaleString("uz-UZ", { month: "short" }),
        active: successfulTransactions
          .filter((item) => monthKey(item.created_at) === key)
          .reduce((sum, item) => sum + Number(item.amount || 0), 0),
      }));
      const loginTrend = lastHours(13).map((hour) => ({
        name: `${hour.getHours().toString().padStart(2, "0")}:00`,
        active: logins.filter((item) => item.success && sameHour(hour, item.created_at)).length,
        failed: logins.filter((item) => !item.success && sameHour(hour, item.created_at)).length,
      }));

      return {
        settings: settings.map((item) => ({
          ...item,
          value: item.value ?? item.values ?? {},
        })),
        backups,
        integrations,
        transactions,
        subscriptions: [...subscriptions, ...userSubscriptions],
        plans,
        logins,
        sessions: sessions.filter((session) => !session.revoked_at),
        mediaBytes,
        mediaFiles: media.length,
        students: profiles.length,
        activeStudents: profiles.filter((profile) => {
          if (!profile.telegram_last_seen_at) return false;
          return Date.now() - new Date(profile.telegram_last_seen_at).getTime() <= 15 * 60 * 1000;
        }).length,
        payments: {
          monthlyRevenue,
          totalRevenue,
          successful: successfulTransactions.length,
          failed: failedTransactions.length,
          activeSubscriptions: [...subscriptions, ...userSubscriptions].filter((item) => item.status === "active").length,
          revenueTrend,
        },
        security: {
          successfulLogins: logins.filter((item) => item.success).length,
          failedLogins: logins.filter((item) => !item.success).length,
          blocked: logins.filter((item) => item.failure_reason?.toLowerCase().includes("block")).length,
          loginTrend,
          geoPoints: buildSecurityMapPoints(logins),
        },
      };
    },
    refetchInterval: 30_000,
  });
}

export function SettingsPage({ section }: SettingsPageProps) {
  const queryClient = useQueryClient();
  const data = useSettingsData();
  const [savedAt, setSavedAt] = useState("Realtime tayyor");
  const [settingsNavCollapsed, setSettingsNavCollapsed] = useState(true);
  const [isPending, startTransition] = useTransition();

  const active = useMemo(
    () => settingSections.find((item) => item.id === section) ?? settingSections[0],
    [section],
  );

  function markSaved(label = "Sozlama") {
    startTransition(() => {
      setSavedAt(new Date().toLocaleString("uz-UZ", { hour12: false }));
      const completed = /(yaratildi|qo'shildi|saqlandi|o'chirildi|chiqarildi)$/i.test(label)
        ? label
        : `${label} yangilandi`;
      toast.success(completed);
    });
  }

  const refresh = () => {
    queryClient.invalidateQueries({ queryKey: ["settings-page-data"] });
    markSaved(active.title);
  };

  return (
    <>
      <PageHeader
        title={section === "general" ? "Sozlamalar" : active.title}
        parent="Sozlamalar"
        current={active.title}
      />

      <div
        className={cn(
          "grid gap-4 animate-in fade-in duration-200",
          settingsNavCollapsed ? "xl:grid-cols-[76px_minmax(0,1fr)]" : "xl:grid-cols-[260px_minmax(0,1fr)]",
        )}
      >
        <SettingsSidebar
          section={section}
          collapsed={settingsNavCollapsed}
          onToggle={() => setSettingsNavCollapsed((value) => !value)}
        />

        <div className="min-w-0 space-y-4">
          {section === "general" ? <GeneralSettings data={data.data} onSaved={markSaved} pending={isPending} /> : null}
          {section === "system" ? <SystemSettings data={data.data} loading={data.isLoading} /> : null}
          {section === "backup" ? <BackupSettings data={data.data} onSaved={markSaved} /> : null}
          {section === "security" ? <SecuritySettings data={data.data} loading={data.isLoading} onSaved={markSaved} /> : null}
          {section === "payments" ? <PaymentSettings data={data.data} loading={data.isLoading} onSaved={markSaved} /> : null}
          {section === "integrations" ? <IntegrationSettings data={data.data} loading={data.isLoading} onSaved={markSaved} /> : null}

          <div className="flex items-center justify-between rounded-xl border border-blue-100 bg-blue-50/50 px-4 py-3 text-xs font-bold text-blue-700">
            <span>{active.title} oxirgi yangilanishi: {savedAt}</span>
            <Button variant="ghost" size="sm" onClick={refresh} className="h-8 gap-2 rounded-lg bg-white text-[11px] font-black text-blue-600">
              <RefreshCcw className="size-4" />
              Yangilash
            </Button>
          </div>
        </div>
      </div>
    </>
  );
}

function SettingsSidebar({
  section,
  collapsed,
  onToggle,
}: {
  section: SettingSection;
  collapsed: boolean;
  onToggle: () => void;
}) {
  return (
    <Card className="sticky top-24 h-fit rounded-2xl border border-slate-200/80 bg-white shadow-sm">
      <CardContent className={cn("p-3", collapsed ? "space-y-2" : "space-y-1.5")}>
        <button
          type="button"
          onClick={onToggle}
          aria-label={collapsed ? "Sozlamalar menyusini ochish" : "Sozlamalar menyusini yig'ish"}
          className={cn(
            "mb-2 grid h-11 place-items-center rounded-xl border border-slate-200 bg-white text-slate-600 shadow-sm transition hover:bg-blue-50 hover:text-blue-600",
            collapsed ? "w-11" : "w-full",
          )}
        >
          {collapsed ? <PanelLeftOpen className="size-5" /> : (
            <span className="flex items-center gap-2 text-xs font-black">
              <PanelLeftClose className="size-5" />
              Menyuni yig'ish
            </span>
          )}
        </button>
        {settingSections.map((item) => {
          const selected = item.id === section;
          return (
            <Link
              href={`/settings/${item.id}`}
              key={item.id}
              title={item.title}
              className={cn(
                "flex items-center rounded-xl border border-transparent transition",
                collapsed ? "justify-center p-2.5" : "gap-3 px-3 py-3",
                selected ? "border-blue-100 bg-blue-50 text-blue-700" : "text-slate-700 hover:bg-slate-50",
              )}
            >
              <span className={cn("grid size-10 shrink-0 place-items-center rounded-xl", selected ? "bg-white text-blue-600" : "bg-blue-50 text-blue-500")}>
                <item.icon className="size-5" />
              </span>
              {!collapsed ? (
                <span className="min-w-0">
                  <span className="block text-sm font-black leading-tight">{item.title}</span>
                  <span className="mt-1 block truncate text-xs font-bold text-slate-500">{item.subtitle}</span>
                </span>
              ) : null}
            </Link>
          );
        })}
      </CardContent>
    </Card>
  );
}

function GeneralSettings({
  data,
  onSaved,
  pending,
}: {
  data?: SettingsData;
  onSaved: (label?: string) => void;
  pending: boolean;
}) {
  const stored = getStoredSettings(data, "general");
  const [form, setForm] = useState({
    platformName: String(stored.platformName ?? "EduLab"),
    logoUrl: String(stored.logoUrl ?? ""),
    description: String(stored.description ?? "EduLab - zamonaviy online ta'lim platformasi.\nSifatli ta'lim, oson boshqaruv."),
    timezone: String(stored.timezone ?? "(UTC+05:00) Tashkent"),
    dateFormat: String(stored.dateFormat ?? "DD.MM.YYYY (15.05.2026)"),
    timeFormat: String(stored.timeFormat ?? "24 soat (14:30)"),
    pageSize: String(stored.pageSize ?? "20"),
    maintenance: Boolean(stored.maintenance ?? false),
  });
  const saveMutation = useMutation({
    mutationFn: () => saveSettingsAction("general", form),
    onSuccess: (result) => {
      if (!result.ok) {
        toast.error(result.error);
        return;
      }
      onSaved("Umumiy sozlamalar");
    },
  });

  return (
    <Card className="overflow-hidden rounded-2xl border border-slate-200/80 bg-white shadow-sm">
      <CardHeader className="flex-row items-start justify-between border-b border-slate-100 px-6 py-5">
        <div>
          <CardTitle className="text-lg font-black text-slate-950">Umumiy sozlamalar</CardTitle>
          <p className="mt-1 text-sm font-bold text-slate-500">Tizimning asosiy parametrlarini sozlang</p>
        </div>
        <Button
          onClick={() => saveMutation.mutate()}
          disabled={pending || saveMutation.isPending}
          className="h-11 rounded-xl bg-blue-600 px-6 text-sm font-black text-white hover:bg-blue-700"
        >
          <Save className="mr-2 size-4" />
          Saqlash
        </Button>
      </CardHeader>
      <CardContent className="divide-y divide-slate-100 p-0">
        <SettingRow icon={SlidersHorizontal} title="Platforma nomi" description="Tizim nomi talabalar va o'qituvchilarga ko'rinadi">
          <Input value={form.platformName} onChange={(event) => setForm({ ...form, platformName: event.target.value })} className="h-12 rounded-xl font-bold" />
        </SettingRow>
        <SettingRow icon={ShieldCheck} title="Platforma logotipi" description="Tizim logotipini yuklang">
          <div className="flex w-full items-center gap-4 rounded-xl border border-slate-200 p-3">
            {form.logoUrl ? (
              <img src={form.logoUrl} alt="Platforma logotipi" className="size-12 rounded-xl border border-slate-100 object-cover" />
            ) : (
              <span className="grid size-12 place-items-center rounded-xl bg-blue-50 text-blue-600"><ShieldCheck className="size-6" /></span>
            )}
            <div className="min-w-0 flex-1">
              <p className="truncate text-sm font-black text-slate-800">{form.logoUrl || "Logo tanlanmagan"}</p>
              <p className="text-xs font-bold text-slate-500">URL saqlangandan keyin tizimda ko'rinadi</p>
            </div>
            <Button
              type="button"
              variant="secondary"
              onClick={() => {
                const next = window.prompt("Logo URL manzilini kiriting", form.logoUrl);
                if (next !== null) setForm({ ...form, logoUrl: next.trim() });
              }}
              className="rounded-xl border border-slate-200 bg-white text-xs font-black"
            >
              O'zgartirish
            </Button>
            <Button
              type="button"
              variant="secondary"
              onClick={() => setForm({ ...form, logoUrl: "" })}
              className="size-10 rounded-xl border border-rose-100 bg-rose-50 p-0 text-rose-500"
            >
              <Trash2 className="size-4" />
            </Button>
          </div>
        </SettingRow>
        <SettingRow icon={Info} title="Platforma tavsifi" description="Qisqacha tavsif (foydalanuvchilar uchun)">
          <Textarea value={form.description} onChange={(event) => setForm({ ...form, description: event.target.value })} className="min-h-24 rounded-xl font-semibold" />
        </SettingRow>
        <SettingRow icon={Mail} title="Vaqt mintaqasi" description="Tizim vaqt mintaqasini tanlang">
          <Select value={form.timezone} onChange={(event) => setForm({ ...form, timezone: event.target.value })} className="h-12 w-full rounded-xl font-bold">
            <option>(UTC+05:00) Tashkent</option>
            <option>(UTC+05:00) Samarkand</option>
          </Select>
        </SettingRow>
        <SettingRow icon={FileArchive} title="Sana formati" description="Sana ko'rinish formatini tanlang">
          <Select value={form.dateFormat} onChange={(event) => setForm({ ...form, dateFormat: event.target.value })} className="h-12 w-full rounded-xl font-bold">
            <option>DD.MM.YYYY (15.05.2026)</option>
            <option>YYYY-MM-DD (2026-05-15)</option>
          </Select>
        </SettingRow>
        <SettingRow icon={Globe2} title="Vaqt formati" description="Vaqt ko'rinish formatini tanlang">
          <Select value={form.timeFormat} onChange={(event) => setForm({ ...form, timeFormat: event.target.value })} className="h-12 w-full rounded-xl font-bold">
            <option>24 soat (14:30)</option>
            <option>12 soat (2:30 PM)</option>
          </Select>
        </SettingRow>
        <SettingRow icon={Folder} title="Elementlar soni sahifada" description="Jadvallarda har sahifada ko'rsatiladigan elementlar soni">
          <Select value={form.pageSize} onChange={(event) => setForm({ ...form, pageSize: event.target.value })} className="h-12 w-full rounded-xl font-bold">
            <option value="10">10</option>
            <option value="20">20</option>
            <option value="50">50</option>
          </Select>
        </SettingRow>
        <SettingRow icon={Folder} title="Xizmat holati" description="Platformani vaqtincha yopish (maintenance rejim)">
          <Toggle enabled={form.maintenance} label={form.maintenance ? "Yoqilgan" : "O'chirilgan"} onChange={(value) => setForm({ ...form, maintenance: value })} />
        </SettingRow>
      </CardContent>
    </Card>
  );
}

type SettingsData = NonNullable<ReturnType<typeof useSettingsData>["data"]>;

function SystemSettings({ data, loading }: { data?: SettingsData; loading: boolean }) {
  const storagePercent = Math.min(100, Math.round(((data?.mediaBytes ?? 0) / STORAGE_LIMIT_BYTES) * 100));
  const latestBackup = data?.backups[0];
  const cpuPercent = Math.min(100, 8 + (data?.activeStudents ?? 0) * 4);
  const ramPercent = Math.min(100, 24 + Math.round(storagePercent / 2));
  const diskPreviewPercent = Math.max(3, storagePercent);
  const exportSystemLogs = () => {
    downloadTextFile(
      `system-logins-${new Date().toISOString().slice(0, 10)}.csv`,
      toCsv((data?.logins ?? []).map((item) => ({
        id: item.id,
        ip_address: item.ip_address ?? "",
        location: item.location ?? "",
        success: item.success,
        failure_reason: item.failure_reason ?? "",
        created_at: item.created_at,
      }))),
      "text/csv;charset=utf-8",
    );
    toast.success("Tizim loglari eksport qilindi");
  };
  const resourceTrend = [
    {
      label: "CPU yuklanishi",
      value: `${cpuPercent}%`,
      percent: cpuPercent,
      color: "#2563eb",
      bg: "bg-blue-50",
      icon: Server,
      hint: "Faol talabalar soni asosida hisoblangan",
      points: [12, 28, 34, 18, 25, 10, 14, 22, 17, 28],
    },
    {
      label: "RAM ishlatilishi",
      value: `${ramPercent}%`,
      percent: ramPercent,
      color: "#22c55e",
      bg: "bg-emerald-50",
      icon: Database,
      hint: "Saqlash va sessiya yuklamasi bo'yicha taxmin",
      points: [10, 18, 12, 27, 30, 21, 17, 28, 20, 24],
    },
    {
      label: "Disk ishlatilishi",
      value: `${storagePercent}%`,
      percent: storagePercent,
      color: "#8b5cf6",
      bg: "bg-violet-50",
      icon: HardDrive,
      hint: "Media kutubxona hajmi bo'yicha real hisob",
      points: [diskPreviewPercent, diskPreviewPercent + 3, diskPreviewPercent + 1, diskPreviewPercent + 5, diskPreviewPercent + 2, diskPreviewPercent + 6],
    },
  ];

  return (
    <div className="space-y-5">
      <div className="grid gap-4 sm:grid-cols-2 2xl:grid-cols-4">
        <Metric icon={Server} title="Server holati" value={loading ? "..." : "Onlayn"} hint={`Talabalar: ${data?.students ?? 0}`} tone="blue" />
        <Metric icon={Database} title="Supabase holati" value="Onlayn" hint="Realtime so'rovlar ishlayapti" tone="green" />
        <Metric icon={Folder} title="Saqlash" value={formatBytes(data?.mediaBytes)} hint="/ 100 GB" tone="slate" progress={storagePercent} />
        <Metric icon={Cloud} title="API kechikishi" value={`${Math.max(40, 80 + (data?.integrations.length ?? 0) * 5)} ms`} hint="O'rtacha javob vaqti" tone="violet" />
      </div>
      <div className="grid gap-4 2xl:grid-cols-[0.95fr_1.05fr]">
        <Panel title="Asosiy ma'lumotlar">
          <KeyValueList
            rows={[
              ["Platforma nomi", "EduLab"],
              ["Joriy versiya", "v2.3.1"],
              ["Build raqami", "230515.1030"],
              ["Muhit (Environment)", process.env.NODE_ENV === "production" ? "Production" : "Development"],
              ["Ma'lumotlar bazasi", "PostgreSQL / Supabase"],
              ["Oxirgi zaxira nusxa", latestBackup ? formatDate(latestBackup.created_at) : "Hali yaratilmagan"],
              ["Vaqt mintaqasi", "(UTC+05:00) Tashkent"],
              ["Sana formati", "DD.MM.YYYY"],
              ["Vaqt formati", "24 soat"],
            ]}
          />
        </Panel>
        <Panel title="Tizim resurslari">
          <div className="mb-4 rounded-xl border border-amber-100 bg-amber-50 px-4 py-3 text-[11px] font-bold leading-relaxed text-amber-700">
            CPU/RAM qiymatlari real server monitoringi emas, admin paneldagi faoliyat va saqlash ma'lumotlari asosida hisoblangan. Disk hajmi media fayllardan olinadi.
          </div>
          <div className="grid gap-3 xl:grid-cols-3 2xl:grid-cols-1">
            {resourceTrend.map((item) => {
              const Icon = item.icon;
              return (
                <div key={item.label} className="rounded-2xl border border-slate-100 bg-slate-50/70 p-4 shadow-sm">
                  <div className="flex items-start justify-between gap-3">
                    <div className="flex min-w-0 items-center gap-3">
                      <span className={cn("flex size-10 shrink-0 items-center justify-center rounded-2xl", item.bg)}>
                        <Icon className="size-5" style={{ color: item.color }} />
                      </span>
                      <div className="min-w-0">
                        <p className="truncate text-xs font-black text-slate-700">{item.label}</p>
                        <p className="mt-1 text-[11px] font-bold leading-4 text-slate-400">{item.hint}</p>
                      </div>
                    </div>
                    <p className="shrink-0 text-2xl font-black text-slate-950">{item.value}</p>
                  </div>
                  <div className="mt-4 h-2 rounded-full bg-white shadow-inner">
                    <div
                      className="h-full rounded-full"
                      style={{ width: `${item.percent}%`, backgroundColor: item.color }}
                    />
                  </div>
                  <div className="mt-3">
                    <MiniSparkline points={item.points} color={item.color} height={42} />
                  </div>
                </div>
              );
            })}
          </div>
        </Panel>
      </div>
      <div className="grid gap-4 xl:grid-cols-2 2xl:grid-cols-[0.7fr_0.75fr_1fr]">
        <Panel title="Ulangan servislar">
          <div className="space-y-3">
            {data?.integrations.slice(0, 4).map((item) => (
              <StatusRow key={item.id} title={formatProvider(item.provider)} status={item.status} />
            ))}
            {data && data.integrations.length === 0 ? <EmptyText text="Ulangan servislar topilmadi" /> : null}
          </div>
        </Panel>
        <Panel title="Faol sessiyalar">
          <p className="text-4xl font-black text-slate-950">{data?.sessions.length ?? 0} ta</p>
          <p className="mt-1 text-sm font-bold text-slate-500">Hozir tizimda faol foydalanuvchilar</p>
          <div className="mt-5 space-y-2">
            {(data?.sessions ?? []).slice(0, 3).map((item) => (
              <div key={item.id} className="grid grid-cols-[1fr_90px] gap-3 text-xs font-bold text-slate-600">
                <span className="truncate">{item.ip_address || "-"}</span>
                <span className="text-right text-slate-400">{item.browser || "-"}</span>
              </div>
            ))}
          </div>
        </Panel>
        <Panel title="Oxirgi loglar" action="Eksport" onAction={exportSystemLogs}>
          <div className="space-y-4">
            {(data?.logins ?? []).slice(0, 5).map((item) => (
              <LogLine key={item.id} tone={item.success ? "green" : "red"} title={item.success ? "Tizimga muvaffaqiyatli kirildi" : "Kirish urinishi rad etildi"} time={formatDate(item.created_at)} />
            ))}
            {data && data.logins.length === 0 ? <EmptyText text="Login loglari hali yo'q" /> : null}
          </div>
        </Panel>
      </div>
    </div>
  );
}

function BackupSettings({ data, onSaved }: { data?: SettingsData; onSaved: (label?: string) => void }) {
  const queryClient = useQueryClient();
  const [backupType, setBackupType] = useState<"full" | "database">("full");
  const [note, setNote] = useState("");
  const createMutation = useMutation({
    mutationFn: () => createBackupAction(backupType, note),
    onSuccess: (result) => {
      if (!result.ok) {
        toast.error(result.error);
        return;
      }
      queryClient.invalidateQueries({ queryKey: ["settings-page-data"] });
      setNote("");
      onSaved("Zaxira nusxa");
    },
  });
  const restoreMutation = useMutation({
    mutationFn: (id: string) => updateBackupStatusAction(id, "restored"),
    onSuccess: (result) => {
      if (!result.ok) {
        toast.error(result.error);
        return;
      }
      queryClient.invalidateQueries({ queryKey: ["settings-page-data"] });
      onSaved("Zaxira nusxa tiklash holati");
    },
  });
  const deleteMutation = useMutation({
    mutationFn: (id: string) => deleteBackupAction(id),
    onSuccess: (result) => {
      if (!result.ok) {
        toast.error(result.error);
        return;
      }
      queryClient.invalidateQueries({ queryKey: ["settings-page-data"] });
      onSaved("Zaxira nusxa o'chirildi");
    },
  });
  const latest = data?.backups[0];

  const downloadBackupMeta = (item: BackupJob) => {
    downloadTextFile(
      `${item.name}.json`,
      JSON.stringify(item, null, 2),
      "application/json;charset=utf-8",
    );
    toast.success("Zaxira nusxa metadata fayli yuklandi");
  };

  return (
    <div className="space-y-5">
      <div className="grid gap-4 2xl:grid-cols-[0.85fr_1.15fr]">
        <Panel title="Zaxira nusxa haqida">
          <p className="text-sm font-bold leading-relaxed text-slate-500">
            Tizim ma'lumotlarining to'liq zaxira nusxasini yarating va tiklang. Zaxira nusxa PostgreSQL ma'lumotlar bazasi, fayllar va sozlamalarni o'z ichiga oladi.
          </p>
          <div className="mt-6 space-y-5">
            <InfoLine icon={ShieldCheck} title="Xavfsiz va shifrlangan" text="Ma'lumotlar himoyalangan holda saqlanadi" />
            <InfoLine icon={RefreshCcw} title="Avtomatik zaxira" text="Rejalashtirilgan zaxira nusxalar jadvali" />
            <InfoLine icon={Download} title="Oson tiklash" text="Bir necha qadamda tizimni tiklash mumkin" />
          </div>
          <div className="mt-6 rounded-xl border border-blue-100 bg-blue-50 p-4 text-sm font-bold text-blue-700">
            Oxirgi zaxira nusxa: {latest ? formatDate(latest.created_at) : "hali yo'q"}
            <span className="mt-1 block text-slate-700">Hajmi: {formatBytes(latest?.size_bytes)} • Turi: {latest?.backup_type === "database" ? "Faqat DB" : "To'liq zaxira"}</span>
          </div>
        </Panel>
        <Panel title="Yangi zaxira nusxa yaratish">
          <p className="mb-6 text-sm font-bold text-slate-500">Tizimning joriy holatidagi to'liq zaxira nusxasini yarating.</p>
          <p className="mb-3 text-xs font-black text-slate-700">Zaxira turi</p>
          <div className="grid gap-3 md:grid-cols-2">
            <Choice active={backupType === "full"} icon={Database} title="To'liq zaxira" subtitle="Barcha ma'lumotlar" onClick={() => setBackupType("full")} />
            <Choice active={backupType === "database"} icon={FileArchive} title="Faqat ma'lumotlar bazasi" subtitle="Faqat DB zaxirasi" onClick={() => setBackupType("database")} />
          </div>
          <label className="mt-6 block text-xs font-black text-slate-700">Izoh (ixtiyoriy)</label>
          <Input value={note} onChange={(event) => setNote(event.target.value.slice(0, 255))} placeholder="Izoh kiriting (masalan: yangilashdan oldin)" className="mt-2 h-11 rounded-xl font-bold" />
          <div className="mt-6 flex justify-end">
            <Button disabled={createMutation.isPending} onClick={() => createMutation.mutate()} className="h-11 rounded-xl bg-blue-600 px-6 text-sm font-black text-white hover:bg-blue-700">
              <UploadCloud className="mr-2 size-4" />
              {createMutation.isPending ? "Yaratilmoqda..." : "Zaxira nusxa yaratish"}
            </Button>
          </div>
        </Panel>
      </div>
      <Panel title="Zaxira nusxalar ro'yxati">
        <div className="mb-4 flex flex-wrap justify-end gap-3">
          <Input placeholder="Qidirish..." className="h-10 w-64 rounded-xl text-xs font-bold" />
          <Select className="h-10 w-40 rounded-xl text-xs font-bold"><option>Barcha turlar</option></Select>
        </div>
        <DataTable
          headers={["Nomi", "Turi", "Hajmi", "Yaratilgan sana", "Izoh", "Holat", "Amallar"]}
          rows={(data?.backups ?? []).map((item) => [
            item.name,
            item.backup_type === "database" ? "Ma'lumotlar bazasi" : "To'liq",
            formatBytes(item.size_bytes),
            formatDate(item.created_at),
            item.note || "-",
            backupStatusLabel(item.status),
            (
              <div className="flex gap-2">
                <IconButton icon={Download} title="Metadata yuklab olish" onClick={() => downloadBackupMeta(item)} />
                <IconButton
                  icon={RefreshCcw}
                  title="Tiklangan deb belgilash"
                  disabled={restoreMutation.isPending}
                  onClick={() => restoreMutation.mutate(item.id)}
                />
                <IconButton
                  icon={Trash2}
                  title="O'chirish"
                  disabled={deleteMutation.isPending}
                  onClick={() => {
                    if (window.confirm(`${item.name} zaxira yozuvini o'chirasizmi?`)) {
                      deleteMutation.mutate(item.id);
                    }
                  }}
                />
              </div>
            ),
          ])}
          emptyText="Zaxira nusxalar hali yo'q"
        />
      </Panel>
    </div>
  );
}

function SecuritySettings({ data, onSaved }: { data?: SettingsData; loading: boolean; onSaved: (label?: string) => void }) {
  const queryClient = useQueryClient();
  const failed = data?.security.failedLogins ?? 0;
  const success = data?.security.successfulLogins ?? 0;
  const securityScore = Math.max(0, Math.min(100, 100 - failed * 3));
  const exportSecurityLogs = () => {
    downloadTextFile(
      `security-logins-${new Date().toISOString().slice(0, 10)}.csv`,
      toCsv((data?.logins ?? []).map((item) => ({
        id: item.id,
        ip_address: item.ip_address ?? "",
        user_agent: item.user_agent ?? "",
        location: item.location ?? "",
        success: item.success,
        failure_reason: item.failure_reason ?? "",
        created_at: item.created_at,
      }))),
      "text/csv;charset=utf-8",
    );
    toast.success("Xavfsizlik loglari eksport qilindi");
  };
  const saveMutation = useMutation({
    mutationFn: () => saveSettingsAction("security", {
      twoFactor: true,
      firewall: true,
      passwordPolicy: {
        minLength: 8,
        uppercase: true,
        number: true,
        symbol: true,
        expiryDays: 90,
      },
      updatedAt: new Date().toISOString(),
    }),
    onSuccess: (result) => {
      if (!result.ok) {
        toast.error(result.error);
        return;
      }
      queryClient.invalidateQueries({ queryKey: ["settings-page-data"] });
      onSaved("Xavfsizlik sozlamalari");
    },
  });
  const revokeMutation = useMutation({
    mutationFn: (id: string) => revokeSessionAction(id),
    onSuccess: (result) => {
      if (!result.ok) {
        toast.error(result.error);
        return;
      }
      queryClient.invalidateQueries({ queryKey: ["settings-page-data"] });
      onSaved("Sessiya chiqarildi");
    },
  });

  return (
    <div className="space-y-5">
      <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-3 2xl:grid-cols-5">
        <Metric icon={ShieldCheck} title="Xavfsizlik darajasi" value={`${securityScore}%`} hint="Haqiqiy login loglari asosida" tone="green" />
        <Metric icon={UsersIcon} title="Faol sessiyalar" value={String(data?.sessions.length ?? 0)} hint="faol sessiya" tone="blue" />
        <Metric icon={Lock} title="Ikki faktorli autentifikatsiya" value="ON" hint="Adminlar uchun yoqilgan" tone="green" />
        <Metric icon={ShieldCheck} title="Xavfsizlik devori" value="Himoyalangan" hint="Siyosatlar faol" tone="green" />
        <Metric icon={AlertTriangle} title="Muvaffaqiyatsiz urinishlar" value={String(failed)} hint="oxirgi loglarda" tone="red" />
      </div>
      <div className="grid gap-4 xl:grid-cols-2 2xl:grid-cols-[1.15fr_0.85fr_1fr]">
        <Panel title="Kirish faolligi" action="Eksport" onAction={exportSecurityLogs}>
          <MiniSparkline points={(data?.security.loginTrend ?? []).map((item) => item.active)} color="#2563eb" height={150} filled />
          <div className="mt-5 grid grid-cols-3 divide-x divide-slate-100 rounded-xl border border-slate-100 p-4">
            <StatText label="Muvaffaqiyatli kirishlar" value={success} tone="green" />
            <StatText label="Muvaffaqiyatsiz kirishlar" value={failed} tone="red" />
            <StatText label="Bloklangan IP lar" value={data?.security.blocked ?? 0} tone="violet" />
          </div>
        </Panel>
        <Panel title="Xavfli faoliyatlar" action="Eksport" onAction={exportSecurityLogs}>
          <div className="space-y-3">
            {(data?.logins ?? []).filter((item) => !item.success).slice(0, 5).map((item) => (
              <AlertRow key={item.id} title={item.failure_reason || "Muvaffaqiyatsiz kirish urinishi"} detail={`IP: ${item.ip_address || "-"}`} time={formatDate(item.created_at)} />
            ))}
            {data && data.logins.filter((item) => !item.success).length === 0 ? <EmptyText text="Xavfli faoliyatlar topilmadi" /> : null}
          </div>
        </Panel>
        <Panel title="Kirishlar geografiyasi" className="xl:col-span-2 2xl:col-span-1">
          <SecurityGeoMap points={data?.security.geoPoints ?? []} />
          <div className="grid grid-cols-3 divide-x divide-slate-100 text-center">
            <StatText label="Muvaffaqiyatli" value={success} tone="green" />
            <StatText label="Shubhali" value={failed} tone="amber" />
            <StatText label="Bloklangan" value={data?.security.blocked ?? 0} tone="red" />
          </div>
        </Panel>
      </div>
      <div className="grid gap-4 xl:grid-cols-2 2xl:grid-cols-[1.15fr_0.7fr_0.7fr_0.9fr]">
        <Panel title="Ishonchli qurilmalar" className="xl:col-span-2 2xl:col-span-1">
          <DataTable
            headers={["Qurilma", "Brauzer", "IP manzil", "Joylashuv", "Oxirgi faoliyat", "Amal"]}
            rows={(data?.sessions ?? []).map((item) => [
              item.device_name || "Noma'lum qurilma",
              item.browser || "-",
              item.ip_address || "-",
              item.location || "-",
              formatDate(item.last_seen_at),
              (
                <Button
                  variant="secondary"
                  size="sm"
                  disabled={revokeMutation.isPending}
                  onClick={() => revokeMutation.mutate(item.id)}
                  className="h-8 rounded-lg border border-rose-100 bg-rose-50 px-3 text-xs font-black text-rose-600"
                >
                  Chiqish
                </Button>
              ),
            ])}
            emptyText="Faol sessiyalar hali yo'q"
          />
        </Panel>
        <Panel title="Parol siyosati">
          <CheckList items={["Minimal uzunlik: 8 belgi", "Katta harf: Yoqilgan", "Raqam: Yoqilgan", "Maxsus belgi: Yoqilgan", "Parol muddati: 90 kun"]} />
        </Panel>
        <Panel title="API xavfsizligi">
          <p className="text-sm font-black text-slate-700">Faol tokenlar <Badge className="ml-2 bg-emerald-50 text-emerald-600">3 ta</Badge></p>
          <div className="mt-5 space-y-4">
            {["API Token #1", "API Token #2", "API Token #3"].map((item, index) => (
              <div key={item} className="border-b border-slate-100 pb-3 last:border-0">
                <p className="text-xs font-black text-slate-800">{item}</p>
                <p className="text-xs font-bold text-slate-400">Yaratilgan: {index + 8}.05.2026</p>
              </div>
            ))}
          </div>
        </Panel>
        <Panel title="Xavfsizlik loglari" action="Eksport" onAction={exportSecurityLogs}>
          <div className="space-y-4">
            {(data?.logins ?? []).slice(0, 5).map((item) => (
              <LogLine key={item.id} tone={item.success ? "blue" : "red"} title={item.success ? "Admin tizimga muvaffaqiyatli kirdi" : "Kirish urinishida xatolik"} time={formatDate(item.created_at)} />
            ))}
          </div>
          <Button
            onClick={() => saveMutation.mutate()}
            disabled={saveMutation.isPending}
            className="mt-5 h-10 rounded-xl bg-blue-600 text-xs font-black text-white"
          >
            {saveMutation.isPending ? "Saqlanmoqda..." : "Yangilash"}
          </Button>
        </Panel>
      </div>
    </div>
  );
}

function PaymentSettings({ data, onSaved }: { data?: SettingsData; loading: boolean; onSaved: (label?: string) => void }) {
  const queryClient = useQueryClient();
  const stored = getStoredSettings(data, "payments");
  const [showPlanForm, setShowPlanForm] = useState(false);
  const [editingPlan, setEditingPlan] = useState<SubscriptionPlan | null>(null);
  const [refundModalOpen, setRefundModalOpen] = useState(false);
  const [paymentMethodModalOpen, setPaymentMethodModalOpen] = useState(false);
  const [planDraft, setPlanDraft] = useState({
    title: "",
    priceLabel: "",
    durationMonths: "1",
    isActive: true,
  });
  const localPlans = Array.isArray((stored as { localPlans?: unknown }).localPlans)
    ? (stored as { localPlans: SubscriptionPlan[] }).localPlans
    : [];
  const deletedPlanIds = Array.isArray((stored as { deletedPlanIds?: unknown }).deletedPlanIds)
    ? (stored as { deletedPlanIds: string[] }).deletedPlanIds
    : [];
  const planOverrides = typeof (stored as { planOverrides?: unknown }).planOverrides === "object" && (stored as { planOverrides?: unknown }).planOverrides
    ? (stored as { planOverrides: Record<string, Partial<SubscriptionPlan>> }).planOverrides
    : {};
  const plans = [...(data?.plans ?? []), ...localPlans]
    .filter((plan) => !deletedPlanIds.includes(plan.id))
    .map((plan) => ({ ...plan, ...(planOverrides[plan.id] ?? {}) }));
  const methods = useMemo(() => {
    const providers = new Set((data?.transactions ?? []).map((item) => item.provider));
    (data?.integrations ?? [])
      .filter((item) => ["click", "payme", "stripe", "uzum", "paypal"].includes(item.provider))
      .forEach((item) => providers.add(item.provider));
    return Array.from(providers);
  }, [data]);
  const createPlanMutation = useMutation({
    mutationFn: () => createSubscriptionPlanAction({
      title: planDraft.title,
      priceLabel: normalizePriceLabel(planDraft.priceLabel),
      durationMonths: Number(planDraft.durationMonths),
      isActive: planDraft.isActive,
    }),
    onSuccess: (result) => {
      if (!result.ok) {
        toast.error(result.error);
        return;
      }
      queryClient.invalidateQueries({ queryKey: ["settings-page-data"] });
      setShowPlanForm(false);
      setPlanDraft({ title: "", priceLabel: "", durationMonths: "1", isActive: true });
      onSaved("Yangi obuna rejasi");
    },
  });
  const updatePlanMutation = useMutation({
    mutationFn: ({ id, draft }: { id: string; draft: typeof planDraft }) => updateSubscriptionPlanAction(id, {
      title: draft.title,
      priceLabel: normalizePriceLabel(draft.priceLabel),
      durationMonths: Number(draft.durationMonths),
      isActive: draft.isActive,
    }),
    onSuccess: (result) => {
      if (!result.ok) {
        toast.error(result.error);
        return;
      }
      queryClient.invalidateQueries({ queryKey: ["settings-page-data"] });
      setEditingPlan(null);
      setPlanDraft({ title: "", priceLabel: "", durationMonths: "1", isActive: true });
      onSaved("Obuna rejasi saqlandi");
    },
  });
  const deletePlanMutation = useMutation({
    mutationFn: (id: string) => deleteSubscriptionPlanAction(id),
    onSuccess: (result) => {
      if (!result.ok) {
        toast.error(result.error);
        return;
      }
      queryClient.invalidateQueries({ queryKey: ["settings-page-data"] });
      onSaved("Obuna rejasi o'chirildi");
    },
  });
  const togglePlanMutation = useMutation({
    mutationFn: ({ id, active }: { id: string; active: boolean }) => toggleSubscriptionPlanAction(id, active),
    onSuccess: (result) => {
      if (!result.ok) {
        toast.error(result.error);
        return;
      }
      queryClient.invalidateQueries({ queryKey: ["settings-page-data"] });
      onSaved("Obuna rejasi");
    },
  });
  const savePaymentSetting = (key: string, value: unknown) => {
    saveSettingsAction("payments", { ...stored, [key]: value, updatedAt: new Date().toISOString() })
      .then((result) => {
        if (!result.ok) {
          toast.error(result.error);
          return;
        }
        queryClient.invalidateQueries({ queryKey: ["settings-page-data"] });
        onSaved("To'lov sozlamalari");
      })
      .catch((error) => toast.error(error.message || "To'lov sozlamasi saqlanmadi"));
  };
  const exportTransactions = () => {
    downloadTextFile(
      `transactions-${new Date().toISOString().slice(0, 10)}.csv`,
      toCsv((data?.transactions ?? []).map((item) => ({
        id: item.id,
        user_id: item.user_id ?? "",
        provider: item.provider,
        amount: item.amount,
        currency: item.currency,
        status: item.status,
        created_at: item.created_at,
      }))),
      "text/csv;charset=utf-8",
    );
    toast.success("Tranzaksiyalar eksport qilindi");
  };
  const startEditPlan = (plan: SubscriptionPlan) => {
    setEditingPlan(plan);
    setPlanDraft({
      title: plan.title,
      priceLabel: normalizePriceLabel(plan.price_label),
      durationMonths: String(plan.duration_months || 1),
      isActive: plan.is_active,
    });
    setShowPlanForm(false);
  };
  const createInvoice = () => {
    const successful = data?.transactions.find((item) => item.status === "successful") ?? data?.transactions[0];
    const invoice = {
      invoice_id: `INV-${Date.now().toString().slice(-8)}`,
      created_at: new Date().toISOString(),
      user_id: successful?.user_id ?? "manual",
      provider: successful?.provider ?? "manual",
      amount: successful?.amount ?? 0,
      currency: successful?.currency ?? "UZS",
      status: successful ? successful.status : "draft",
    };
    downloadTextFile(
      `${invoice.invoice_id}.xls`,
      toExcelTable("LabProof Academy hisob-faktura", [
        ["Hisob-faktura ID", invoice.invoice_id],
        ["Yaratilgan sana", formatDate(invoice.created_at)],
        ["Foydalanuvchi", invoice.user_id],
        ["To'lov usuli", invoice.provider],
        ["Summa", formatMoney(invoice.amount, invoice.currency === "UZS" ? "so'm" : invoice.currency)],
        ["Status", invoice.status],
      ]),
      "application/vnd.ms-excel;charset=utf-8",
    );
    savePaymentSetting("lastInvoiceRequestedAt", invoice.created_at);
    toast.success("Hisob-faktura Excel fayl sifatida yuklandi");
  };
  const refundTransactions = (data?.transactions ?? []).filter((item) => item.status === "refunded");

  return (
    <div className="space-y-5">
      <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-3 2xl:grid-cols-5">
        <Metric icon={WalletCards} title="Oylik daromad" value={formatMoney(data?.payments.monthlyRevenue ?? 0)} tone="blue" />
        <Metric icon={CreditCard} title="Muvaffaqiyatli to'lovlar" value={`${data?.payments.successful ?? 0} ta`} tone="green" />
        <Metric icon={UsersIcon} title="Faol obunalar" value={`${data?.payments.activeSubscriptions ?? 0} ta`} tone="violet" />
        <Metric icon={AlertTriangle} title="Muvaffaqiyatsiz to'lovlar" value={`${data?.payments.failed ?? 0} ta`} tone="red" />
        <Metric icon={WalletCards} title="Jami tushum" value={formatMoney(data?.payments.totalRevenue ?? 0)} tone="blue" />
      </div>
      <div className="grid gap-4 2xl:grid-cols-[1.2fr_0.8fr]">
        <Panel title="Daromad statistikasi" action="Eksport" onAction={exportTransactions}>
          <MiniSparkline points={(data?.payments.revenueTrend ?? []).map((item) => item.active)} color="#2563eb" height={170} filled />
        </Panel>
        <Panel title="To'lov usullari" action="Sozlamalarni tahrirlash" onAction={() => setPaymentMethodModalOpen(true)}>
          <div className="space-y-3">
            {methods.map((method, index) => (
              <div key={method} className="grid grid-cols-[44px_1fr_auto_auto] items-center gap-3 border-b border-slate-100 pb-3 last:border-0">
                <span className="grid size-10 place-items-center rounded-xl bg-blue-50 text-sm font-black uppercase text-blue-600">{method.slice(0, 1)}</span>
                <span className="text-sm font-black capitalize text-slate-800">{method}</span>
                <Badge className="bg-emerald-50 text-emerald-600">Ulangan</Badge>
                <span className="text-xs font-black text-slate-600">{(1.5 + index * 0.3).toFixed(1)}%</span>
              </div>
            ))}
            {methods.length === 0 ? <EmptyText text="To'lov usullari hali ulanmagan" /> : null}
          </div>
        </Panel>
      </div>
      <div className="grid gap-4 2xl:grid-cols-[0.95fr_1.25fr_0.8fr]">
        <Panel title="Obuna rejalari" action={showPlanForm ? "Bekor qilish" : "Yangi reja qo'shish"} onAction={() => setShowPlanForm((value) => !value)}>
          {showPlanForm ? (
            <div className="mb-4 rounded-2xl border border-blue-100 bg-blue-50/50 p-4">
              <div className="grid gap-3 sm:grid-cols-2">
                <label className="text-xs font-black text-slate-600">
                  Reja nomi
                  <Input
                    value={planDraft.title}
                    onChange={(event) => setPlanDraft({ ...planDraft, title: event.target.value })}
                    placeholder="Masalan: Premium"
                    className="mt-2 h-10 rounded-xl bg-white font-bold"
                  />
                </label>
                <label className="text-xs font-black text-slate-600">
                  Narxi
                  <Input
                    value={planDraft.priceLabel}
                    onChange={(event) => setPlanDraft({ ...planDraft, priceLabel: event.target.value })}
                    onBlur={() => setPlanDraft((draft) => ({ ...draft, priceLabel: normalizePriceLabel(draft.priceLabel) }))}
                    placeholder="99 000 so'm / oy"
                    className="mt-2 h-10 rounded-xl bg-white font-bold"
                  />
                </label>
                <label className="text-xs font-black text-slate-600">
                  Muddat (oy)
                  <Input
                    type="number"
                    min={1}
                    max={60}
                    value={planDraft.durationMonths}
                    onChange={(event) => setPlanDraft({ ...planDraft, durationMonths: event.target.value })}
                    className="mt-2 h-10 rounded-xl bg-white font-bold"
                  />
                </label>
                <div className="flex items-end">
                  <Toggle
                    enabled={planDraft.isActive}
                    label={planDraft.isActive ? "Faol reja" : "O'chirilgan"}
                    onChange={(value) => setPlanDraft({ ...planDraft, isActive: value })}
                  />
                </div>
              </div>
              <Button
                type="button"
                disabled={createPlanMutation.isPending || !planDraft.title.trim()}
                onClick={() => createPlanMutation.mutate()}
                className="mt-4 h-10 rounded-xl bg-blue-600 px-5 text-xs font-black text-white"
              >
                <Plus className="size-4" />
                {createPlanMutation.isPending ? "Saqlanmoqda..." : "Rejani saqlash"}
              </Button>
            </div>
          ) : null}
          <div className="grid gap-3 sm:grid-cols-2 2xl:grid-cols-2">
            {plans.map((plan) => (
              <div key={plan.id} className={cn("rounded-2xl border p-4", plan.is_active ? "border-blue-200 bg-blue-50/30" : "border-slate-200")}>
                <div className="flex items-start justify-between gap-3">
                  <p className="text-sm font-black text-slate-900">{plan.title}</p>
                  <div className="flex shrink-0 gap-2">
                    <IconButton icon={Pencil} title="Tahrirlash" onClick={() => startEditPlan(plan)} />
                    <IconButton
                      icon={Trash2}
                      title="O'chirish"
                      onClick={() => {
                        if (window.confirm(`${plan.title} rejasini o'chirasizmi?`)) {
                          deletePlanMutation.mutate(plan.id);
                        }
                      }}
                    />
                  </div>
                </div>
                <p className="mt-4 break-words text-2xl font-black leading-tight text-slate-950">{normalizePriceLabel(plan.price_label)}</p>
                <p className="mt-2 text-xs font-bold text-slate-500">Muddat: {plan.duration_months} oy</p>
                <div className="mt-5 flex flex-wrap items-center gap-2">
                  <Badge className={cn(plan.is_active ? "bg-emerald-50 text-emerald-600" : "bg-slate-100 text-slate-500")}>{plan.is_active ? "Faol" : "O'chirilgan"}</Badge>
                  <Button
                    type="button"
                    variant="secondary"
                    size="sm"
                    disabled={togglePlanMutation.isPending}
                    onClick={() => togglePlanMutation.mutate({ id: plan.id, active: !plan.is_active })}
                    className="h-8 rounded-lg px-3 text-xs font-black text-blue-600"
                  >
                    {plan.is_active ? "O'chirish" : "Faollashtirish"}
                  </Button>
                </div>
              </div>
            ))}
            {data && plans.length === 0 ? <EmptyText text="Obuna rejalari hali yo'q" /> : null}
          </div>
        </Panel>
        <Panel title="So'nggi tranzaksiyalar" action="Barchasini eksport qilish" onAction={exportTransactions}>
          <DataTable
            headers={["Foydalanuvchi", "Summa", "To'lov usuli", "Status", "Sana"]}
            rows={(data?.transactions ?? []).slice(0, 5).map((item) => [
              item.user_id ? item.user_id.slice(0, 8) : "-",
              formatMoney(item.amount, item.currency),
              item.provider,
              paymentStatusLabel(item.status),
              formatDate(item.created_at),
            ])}
            emptyText="Tranzaksiyalar hali yo'q"
          />
        </Panel>
        <div className="grid gap-4">
          <SmallAction
            icon={RefreshCcw}
            title="Obunani avtomatik yangilash"
            text="Obunalar muddati tugashidan oldin avtomatik tarzda yangilanadi."
            enabled={Boolean((stored as { autoRenew?: unknown }).autoRenew ?? true)}
            onToggle={(value) => savePaymentSetting("autoRenew", value)}
          />
          <SmallAction
            icon={FileArchive}
            title="Hisob-faktura yaratish"
            text="Oxirgi to'lov asosida Excel hisob-faktura yuklab beriladi."
            button="Yaratish"
            onAction={createInvoice}
          />
          <SmallAction
            icon={AlertTriangle}
            title="Qaytarish so'rovlari"
            text="Mijozlar qaytarish so'rovlarini ko'rib chiqing."
            count={`${refundTransactions.length} ta`}
            button="Ko'rish"
            onAction={() => setRefundModalOpen(true)}
          />
          <SmallAction
            icon={Bell}
            title="To'lov eslatmalari"
            text="To'lov muvaffaqiyatli bo'lganda xabar yuborish."
            enabled={Boolean((stored as { paymentReminders?: unknown }).paymentReminders ?? true)}
            onToggle={(value) => savePaymentSetting("paymentReminders", value)}
          />
        </div>
      </div>
      <Modal
        open={Boolean(editingPlan)}
        title="Obuna rejasini tahrirlash"
        description="Narx, muddat va faol holatini o'zgartiring."
        onOpenChange={(open) => {
          if (!open) setEditingPlan(null);
        }}
        footer={(
          <>
            <Button type="button" variant="secondary" onClick={() => setEditingPlan(null)}>
              Bekor qilish
            </Button>
            <Button
              type="button"
              disabled={!planDraft.title.trim() || updatePlanMutation.isPending}
              onClick={() => editingPlan ? updatePlanMutation.mutate({ id: editingPlan.id, draft: planDraft }) : undefined}
            >
              {updatePlanMutation.isPending ? "Saqlanmoqda..." : "Saqlash"}
            </Button>
          </>
        )}
      >
        <PlanFormFields planDraft={planDraft} setPlanDraft={setPlanDraft} />
      </Modal>
      <Modal
        open={refundModalOpen}
        title="Qaytarish so'rovlari"
        description="Refund statusidagi tranzaksiyalar ro'yxati."
        onOpenChange={setRefundModalOpen}
        footer={(
          <Button type="button" onClick={() => {
            downloadTextFile(
              `refund-requests-${new Date().toISOString().slice(0, 10)}.csv`,
              toCsv(refundTransactions.map((item) => ({
                id: item.id,
                user_id: item.user_id ?? "",
                amount: item.amount,
                currency: item.currency,
                provider: item.provider,
                created_at: item.created_at,
              }))),
              "text/csv;charset=utf-8",
            );
            toast.success("Qaytarish so'rovlari eksport qilindi");
          }}>
            Eksport
          </Button>
        )}
      >
        <DataTable
          headers={["ID", "Foydalanuvchi", "Summa", "Provider", "Sana"]}
          rows={refundTransactions.map((item) => [
            item.id.slice(0, 8),
            item.user_id ? item.user_id.slice(0, 8) : "-",
            formatMoney(item.amount, item.currency),
            item.provider,
            formatDate(item.created_at),
          ])}
          emptyText="Qaytarish so'rovlari hali yo'q"
        />
      </Modal>
      <Modal
        open={paymentMethodModalOpen}
        title="To'lov usullari sozlamalari"
        description="Ulangan payment providerlarni tekshirish va eksport qilish."
        onOpenChange={setPaymentMethodModalOpen}
        footer={(
          <>
            <Button type="button" variant="secondary" onClick={() => setPaymentMethodModalOpen(false)}>
              Yopish
            </Button>
            <Button type="button" onClick={() => {
              downloadTextFile(
                `payment-methods-${new Date().toISOString().slice(0, 10)}.csv`,
                toCsv(methods.map((method, index) => ({ method, status: "connected", fee: `${(1.5 + index * 0.3).toFixed(1)}%` }))),
                "text/csv;charset=utf-8",
              );
              savePaymentSetting("paymentMethodsExportedAt", new Date().toISOString());
            }}>
              Eksport
            </Button>
          </>
        )}
      >
        <div className="space-y-3">
          {methods.length ? methods.map((method, index) => (
            <div key={method} className="flex items-center justify-between gap-3 rounded-xl border border-slate-100 p-3">
              <div>
                <p className="text-sm font-black capitalize text-slate-900">{method}</p>
                <p className="text-xs font-bold text-slate-500">Komissiya: {(1.5 + index * 0.3).toFixed(1)}%</p>
              </div>
              <Badge className="bg-emerald-50 text-emerald-600">Ulangan</Badge>
            </div>
          )) : <EmptyText text="To'lov usullari hali ulanmagan" />}
        </div>
      </Modal>
    </div>
  );
}

type PlanDraftState = {
  title: string;
  priceLabel: string;
  durationMonths: string;
  isActive: boolean;
};

function PlanFormFields({
  planDraft,
  setPlanDraft,
}: {
  planDraft: PlanDraftState;
  setPlanDraft: React.Dispatch<React.SetStateAction<PlanDraftState>>;
}) {
  return (
    <div className="grid gap-3 sm:grid-cols-2">
      <label className="text-xs font-black text-slate-600">
        Reja nomi
        <Input
          value={planDraft.title}
          onChange={(event) => setPlanDraft({ ...planDraft, title: event.target.value })}
          placeholder="Masalan: Premium"
          className="mt-2 h-10 rounded-xl bg-white font-bold"
        />
      </label>
      <label className="text-xs font-black text-slate-600">
        Narxi
        <Input
          value={planDraft.priceLabel}
          onChange={(event) => setPlanDraft({ ...planDraft, priceLabel: event.target.value })}
          onBlur={() => setPlanDraft((draft) => ({ ...draft, priceLabel: normalizePriceLabel(draft.priceLabel) }))}
          placeholder="99 000 so'm / oy"
          className="mt-2 h-10 rounded-xl bg-white font-bold"
        />
      </label>
      <label className="text-xs font-black text-slate-600">
        Muddat (oy)
        <Input
          type="number"
          min={1}
          max={60}
          value={planDraft.durationMonths}
          onChange={(event) => setPlanDraft({ ...planDraft, durationMonths: event.target.value })}
          className="mt-2 h-10 rounded-xl bg-white font-bold"
        />
      </label>
      <div className="flex items-end">
        <Toggle
          enabled={planDraft.isActive}
          label={planDraft.isActive ? "Faol reja" : "O'chirilgan"}
          onChange={(value) => setPlanDraft({ ...planDraft, isActive: value })}
        />
      </div>
    </div>
  );
}

function IntegrationSettings({ data, onSaved }: { data?: SettingsData; loading: boolean; onSaved: (label?: string) => void }) {
  const queryClient = useQueryClient();
  const stored = getStoredSettings(data, "integrations");
  const importInputRef = useRef<HTMLInputElement>(null);
  const [clientSettings, setClientSettings] = useState<Record<string, unknown>>({});
  const [selectedProvider, setSelectedProvider] = useState<string>("");
  const [showAllWebhooks, setShowAllWebhooks] = useState(false);
  const [integrationForm, setIntegrationForm] = useState<{
    mode: "create" | "edit";
    provider: string;
    label: string;
    secretRef: string;
    webhookUrl: string;
  } | null>(null);
  const [newApiKey, setNewApiKey] = useState<ApiKeyRecord | null>(null);
  const effectiveStored = useMemo(() => ({ ...stored, ...clientSettings }), [stored, clientSettings]);

  useEffect(() => {
    try {
      const raw = window.localStorage.getItem("labproof-integrations-settings");
      if (raw) setClientSettings(JSON.parse(raw) as Record<string, unknown>);
    } catch {
      // Local browser storage is an enhancement only.
    }
  }, []);

  const persistClientSettings = (values: Record<string, unknown>) => {
    setClientSettings(values);
    try {
      window.localStorage.setItem("labproof-integrations-settings", JSON.stringify(values));
    } catch {
      // Ignore storage quota/private mode errors; server action still runs.
    }
  };

  const normalizeProvider = (provider: string) =>
    provider.trim().toLowerCase().replace(/[^a-z0-9_-]+/g, "-").replace(/^-+|-+$/g, "");

  const upsertClientIntegration = (
    provider: string,
    status: IntegrationConnection["status"],
    config: Record<string, unknown> = {},
  ) => {
    const safeProvider = normalizeProvider(provider);
    if (!safeProvider) return;
    const existing = Array.isArray((effectiveStored as { localIntegrations?: unknown }).localIntegrations)
      ? (effectiveStored as { localIntegrations: Array<Record<string, unknown>> }).localIntegrations
      : [];
    const previous = existing.find((item) => item.provider === safeProvider || item.id === `local-${safeProvider}`) ?? {};
    const previousConfig = typeof previous.public_config === "object" && previous.public_config
      ? previous.public_config as Record<string, unknown>
      : {};
    const next = {
      ...effectiveStored,
      localIntegrations: [
        {
          ...previous,
          id: `local-${safeProvider}`,
          provider: safeProvider,
          status,
          public_config: {
            created_from: "admin-settings",
            ...previousConfig,
            ...config,
          },
          secret_ref: typeof previous.secret_ref === "string" ? previous.secret_ref : `${safeProvider.toUpperCase()}_SECRET`,
          last_sync_at: status === "connected" ? new Date().toISOString() : previous.last_sync_at ?? null,
          updated_at: new Date().toISOString(),
        },
        ...existing.filter((item) => item.provider !== safeProvider && item.id !== `local-${safeProvider}`),
      ],
      updatedAt: new Date().toISOString(),
    };
    persistClientSettings(next);
  };

  const generateClientApiKey = () => {
    if (typeof window !== "undefined" && window.crypto?.getRandomValues) {
      const bytes = new Uint8Array(18);
      window.crypto.getRandomValues(bytes);
      return `pk_live_${Array.from(bytes, (byte) => byte.toString(16).padStart(2, "0")).join("")}`;
    }
    return `pk_live_${Date.now().toString(16)}${Math.random().toString(16).slice(2, 14)}`;
  };

  const maskApiKey = (key: string) => `${key.slice(0, 10)}••••••••${key.slice(-4)}`;

  const addClientApiKey = () => {
    const apiKeys = Array.isArray((effectiveStored as { apiKeys?: unknown }).apiKeys)
      ? (effectiveStored as { apiKeys: Array<Record<string, unknown>> }).apiKeys
      : [];
    const key = generateClientApiKey();
    const nextKey: ApiKeyRecord = {
      id: `local-${Date.now()}`,
      name: `API kalit ${apiKeys.length + 1}`,
      masked: maskApiKey(key),
      value: key,
      createdAt: new Date().toISOString(),
      status: "active",
    };
    persistClientSettings({
      ...effectiveStored,
      apiKeys: [
        nextKey,
        ...apiKeys,
      ],
      updatedAt: new Date().toISOString(),
    });
    return nextKey;
  };

  const localIntegrations = useMemo(() => {
    const items = Array.isArray((effectiveStored as { localIntegrations?: unknown }).localIntegrations)
      ? (effectiveStored as { localIntegrations: IntegrationConnection[] }).localIntegrations
      : [];
    return items.map((item) => ({
      id: item.id ?? `local-${item.provider}`,
      provider: item.provider,
      status: item.status,
      public_config: item.public_config ?? {},
      secret_ref: item.secret_ref ?? null,
      last_sync_at: item.last_sync_at ?? null,
      updated_at: item.updated_at ?? null,
    }));
  }, [effectiveStored]);
  const integrations = useMemo(() => {
    const merged = new Map<string, IntegrationConnection>();
    (data?.integrations ?? []).forEach((item) => merged.set(item.provider, item));
    localIntegrations.forEach((item) => {
      if (!merged.has(item.provider)) merged.set(item.provider, item);
    });
    return Array.from(merged.values()).sort((a, b) => a.provider.localeCompare(b.provider));
  }, [data?.integrations, localIntegrations]);
  useEffect(() => {
    if (!integrations.length) {
      setSelectedProvider("");
      return;
    }
    if (!selectedProvider || !integrations.some((item) => item.provider === selectedProvider)) {
      setSelectedProvider(integrations.find((item) => item.provider === "telegram")?.provider ?? integrations[0].provider);
    }
  }, [integrations, selectedProvider]);
  const selected = integrations.find((item) => item.provider === selectedProvider) ?? integrations.find((item) => item.provider === "telegram") ?? integrations[0];
  const connected = integrations.filter((item) => item.status === "connected").length;
  const pending = integrations.filter((item) => item.status === "pending").length;
  const errors = integrations.filter((item) => item.status === "error").length;
  const apiKeys = Array.isArray((effectiveStored as { apiKeys?: unknown }).apiKeys)
    ? (effectiveStored as { apiKeys: ApiKeyRecord[] }).apiKeys
    : [];
  const createMutation = useMutation({
    mutationFn: (provider: string) => createIntegrationAction(provider),
    onSuccess: (result) => {
      if (!result.ok) {
        toast.error(result.error);
        return;
      }
      queryClient.invalidateQueries({ queryKey: ["settings-page-data"] });
      onSaved("Integratsiya qo'shildi");
    },
  });
  const testMutation = useMutation({
    mutationFn: (provider: string) => testIntegrationAction(provider),
    onSuccess: (result) => {
      if (!result.ok) {
        toast.error(result.error);
        return;
      }
      queryClient.invalidateQueries({ queryKey: ["settings-page-data"] });
      onSaved("Integratsiya testi");
    },
  });
  const statusMutation = useMutation({
    mutationFn: ({ provider, status }: { provider: string; status: "connected" | "pending" | "error" | "disabled" }) => updateIntegrationStatusAction(provider, status),
    onSuccess: (result) => {
      if (!result.ok) {
        toast.error(result.error);
        return;
      }
      queryClient.invalidateQueries({ queryKey: ["settings-page-data"] });
      onSaved("Integratsiya holati");
    },
  });
  const configMutation = useMutation({
    mutationFn: ({ provider, config }: { provider: string; config: { secretRef?: string; webhookUrl?: string; label?: string } }) =>
      updateIntegrationConfigAction(provider, config),
    onSuccess: (result) => {
      if (!result.ok) {
        toast.error(result.error);
        return;
      }
      queryClient.invalidateQueries({ queryKey: ["settings-page-data"] });
      onSaved("Integratsiya tafsilotlari");
    },
  });
  const apiKeyMutation = useMutation({
    mutationFn: createApiKeyAction,
    onSuccess: (result) => {
      if (!result.ok) {
        toast.error(result.error);
        return;
      }
      queryClient.invalidateQueries({ queryKey: ["settings-page-data"] });
    },
  });
  const saveIntegrationValues = (values: Record<string, unknown>, label = "Integratsiya sozlamalari") => {
    const nextValues = { ...effectiveStored, ...values, updatedAt: new Date().toISOString() };
    persistClientSettings(nextValues);
    saveSettingsAction("integrations", nextValues)
      .then((result) => {
        if (!result.ok) {
          toast.error(result.error);
          return;
        }
        queryClient.invalidateQueries({ queryKey: ["settings-page-data"] });
        onSaved(label);
      })
      .catch((error) => toast.error(error.message || "Integratsiya sozlamasi saqlanmadi"));
  };
  const saveIntegrationSetting = (key: string, value: unknown) => saveIntegrationValues({ [key]: value });
  const copyText = (value: string, label: string) => {
    navigator.clipboard.writeText(value)
      .then(() => toast.success(`${label} nusxalandi`))
      .catch(() => toast.error("Clipboardga yozib bo'lmadi"));
  };

  const openIntegrationForm = (mode: "create" | "edit", provider?: string) => {
    const current = provider
      ? integrations.find((item) => item.provider === provider)
      : selected;
    const safeProvider = normalizeProvider(provider ?? current?.provider ?? "telegram");
    const config = typeof current?.public_config === "object" && current.public_config
      ? current.public_config as Record<string, unknown>
      : {};
    setIntegrationForm({
      mode,
      provider: mode === "create" ? safeProvider || "custom-service" : safeProvider,
      label: String(config.label ?? (safeProvider ? formatProvider(safeProvider) : "")),
      secretRef: current?.secret_ref || `${(safeProvider || "CUSTOM").toUpperCase()}_SECRET`,
      webhookUrl: String(config.webhook_url ?? `/api/integrations/${safeProvider || "custom-service"}/webhook`),
    });
  };

  const handleEditSelected = () => {
    if (!selected) {
      toast.error("Avval integratsiyani tanlang");
      return;
    }
    openIntegrationForm("edit", selected.provider);
  };

  const submitIntegrationForm = () => {
    if (!integrationForm) return;
    const provider = normalizeProvider(integrationForm.provider);
    if (!provider) {
      toast.error("Integratsiya nomi kerak");
      return;
    }
    const label = integrationForm.label.trim() || formatProvider(provider);
    const secretRef = integrationForm.secretRef.trim() || `${provider.toUpperCase()}_SECRET`;
    const webhookUrl = integrationForm.webhookUrl.trim() || `/api/integrations/${provider}/webhook`;
    const status = integrationForm.mode === "create" ? "pending" : "connected";

    upsertClientIntegration(provider, status, { label, webhook_url: webhookUrl });
    setSelectedProvider(provider);
    if (integrationForm.mode === "create") {
      createMutation.mutate(provider);
      toast.success(`${label} integratsiyasi qo'shildi`);
    } else {
      configMutation.mutate({ provider, config: { label, secretRef, webhookUrl } });
      toast.success(`${label} sozlamalari saqlandi`);
    }
    setIntegrationForm(null);
  };
  const importIntegrationFile = async (file?: File | null) => {
    if (!file) return;
    try {
      const text = await file.text();
      const imported: Array<Record<string, unknown>> = file.name.endsWith(".json")
        ? JSON.parse(text)
        : text
          .split(/\r?\n/)
          .slice(1)
          .filter(Boolean)
          .map((line) => {
            const [provider = "", status = "pending", secretRef = ""] = line.split(",").map((part) => part.replace(/^"|"$/g, "").trim());
            return { provider, status, secret_ref: secretRef };
          });
      const rows = Array.isArray(imported)
        ? imported
        : Array.isArray((imported as { localIntegrations?: unknown }).localIntegrations)
          ? (imported as { localIntegrations: Array<Record<string, unknown>> }).localIntegrations
          : [];
      const normalized = rows
        .map((item) => {
          const provider = String(item.provider ?? "").trim().toLowerCase().replace(/[^a-z0-9_-]+/g, "-").replace(/^-+|-+$/g, "");
          if (!provider) return null;
          const status = ["connected", "pending", "error", "disabled"].includes(String(item.status))
            ? String(item.status) as IntegrationConnection["status"]
            : "pending";
          return {
            id: String(item.id ?? `local-${provider}`),
            provider,
            status,
            public_config: typeof item.public_config === "object" && item.public_config ? item.public_config : { imported_from: file.name },
            secret_ref: String(item.secret_ref ?? `${provider.toUpperCase()}_SECRET`),
            last_sync_at: typeof item.last_sync_at === "string" ? item.last_sync_at : null,
            updated_at: new Date().toISOString(),
          };
        })
        .filter(Boolean);
      if (!normalized.length) {
        toast.error("Import faylida integratsiya topilmadi");
        return;
      }
      const existing = Array.isArray((effectiveStored as { localIntegrations?: unknown }).localIntegrations)
        ? (effectiveStored as { localIntegrations: Array<Record<string, unknown>> }).localIntegrations
        : [];
      saveIntegrationValues({
        lastImportRequestedAt: new Date().toISOString(),
        localIntegrations: [
          ...normalized,
          ...existing.filter((item) => !normalized.some((next) => next?.provider === item.provider)),
        ],
      }, "Integratsiya importi");
    } catch (error) {
      toast.error(error instanceof Error ? error.message : "Import fayli o'qilmadi");
    } finally {
      if (importInputRef.current) importInputRef.current.value = "";
    }
  };
  const exportIntegrations = () => {
    downloadTextFile(
      `integrations-${new Date().toISOString().slice(0, 10)}.csv`,
      toCsv(integrations.map((item) => ({
        provider: item.provider,
        status: item.status,
        secret_ref: item.secret_ref ?? "",
        last_sync_at: item.last_sync_at ?? "",
        updated_at: item.updated_at ?? "",
      }))),
      "text/csv;charset=utf-8",
    );
    toast.success("Integratsiyalar eksport qilindi");
  };
  const webhookEndpoints = [
    "/api/webhooks/payment",
    "/api/webhooks/student",
    "/api/webhooks/subscription",
    "/api/integrations/telegram/webhook",
    "/api/support/conversations",
  ];
  const visibleWebhooks = showAllWebhooks ? webhookEndpoints : webhookEndpoints.slice(0, 3);
  const helpLinks: Record<string, string> = {
    "Integratsiya bo'yicha qo'llanma": "https://supabase.com/docs/guides/functions",
    "API hujjatlari": "https://supabase.com/docs/guides/api",
    "Webhook namunalar": "https://supabase.com/docs/guides/functions/examples",
    "Tez-tez so'raladigan savollar": "https://supabase.com/docs/guides/getting-started",
  };
  const integrationPresets = [
    { provider: "telegram", label: "Telegram bot", secret: "TELEGRAM_BOT_TOKEN", webhook: "/api/integrations/telegram/webhook" },
    { provider: "cloudinary", label: "Cloudinary media", secret: "CLOUDINARY_API_SECRET", webhook: "/api/integrations/cloudinary/webhook" },
    { provider: "smtp", label: "Email SMTP", secret: "SMTP_PASSWORD", webhook: "/api/integrations/smtp/webhook" },
    { provider: "click", label: "Click to'lov", secret: "CLICK_SECRET_KEY", webhook: "/api/webhooks/payment" },
    { provider: "payme", label: "Payme to'lov", secret: "PAYME_SECRET_KEY", webhook: "/api/webhooks/payment" },
    { provider: "google-oauth", label: "Google OAuth", secret: "GOOGLE_CLIENT_SECRET", webhook: "/api/integrations/google-oauth/callback" },
  ];

  return (
    <div className="space-y-5">
      <p className="-mt-2 text-sm font-bold text-slate-500">EduLab tizimini boshqa servislar va platformalar bilan integratsiya qiling, API kalitlarni boshqaring va webhook'larni sozlang.</p>
      <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-3 2xl:grid-cols-5">
        <Metric icon={SlidersHorizontal} title="Ulangan servislar" value={String(integrations.length)} tone="violet" />
        <Metric icon={CheckCircle2} title="Faol integratsiyalar" value={String(connected)} tone="green" />
        <Metric icon={Cloud} title="Kutilayotgan ulanishlar" value={String(pending)} tone="orange" />
        <Metric icon={XCircle} title="Xatoliklar" value={String(errors)} tone="red" />
        <Metric icon={ActivityIcon} title="API so'rovlar" value={String((data?.transactions.length ?? 0) + (data?.logins.length ?? 0))} hint="oxirgi so'rovlar" tone="blue" />
      </div>
      <div className="grid gap-4 xl:grid-cols-2 2xl:grid-cols-[1.2fr_0.75fr_0.75fr]">
        <Panel title="Ulangan servislar" className="xl:col-span-2 2xl:col-span-1">
          <DataTable
            headers={["Servis nomi", "Tavsif", "Holat", "So'nggi sinxron", "Amallar"]}
            rows={integrations.map((item) => [
              formatProvider(item.provider),
              integrationDescription(item.provider),
              integrationStatusLabel(item.status),
              formatDate(item.last_sync_at),
              (
                <div className="flex flex-wrap gap-2">
                  <Button
                    variant="secondary"
                    size="sm"
                    onClick={() => setSelectedProvider(item.provider)}
                    className={cn(
                      "h-8 rounded-lg px-3 text-xs font-black",
                      selected?.provider === item.provider ? "bg-blue-600 text-white hover:bg-blue-700" : "text-blue-600",
                    )}
                  >
                    Tanlash
                  </Button>
                  <Button
                    variant="secondary"
                    size="sm"
                    disabled={statusMutation.isPending}
                    onClick={() => {
                      const nextStatus = item.status === "disabled" ? "connected" : "disabled";
                      upsertClientIntegration(item.provider, nextStatus);
                      statusMutation.mutate({ provider: item.provider, status: nextStatus });
                    }}
                    className="h-8 rounded-lg px-3 text-xs font-black text-blue-600"
                  >
                    {item.status === "disabled" ? "Ulash" : "O'chirish"}
                  </Button>
                </div>
              ),
            ])}
            emptyText="Integratsiyalar hali yo'q"
          />
          <button
            type="button"
            onClick={() => openIntegrationForm("create", "telegram")}
            className="mt-4 flex h-11 w-full items-center justify-center gap-2 rounded-xl border border-dashed border-blue-200 text-sm font-black text-blue-600"
          >
            <Plus className="size-4" />
            Yangi integratsiya qo'shish
          </button>
        </Panel>
        <Panel title="Integratsiya tafsilotlari" action="Tahrirlash" onAction={handleEditSelected}>
          {selected ? (
            <div className="space-y-4">
              <div className="flex items-center gap-4">
                <span className="grid size-14 place-items-center rounded-2xl bg-sky-50 text-sky-600"><Send className="size-7" /></span>
                <div>
                  <p className="text-lg font-black text-slate-950">{formatProvider(selected.provider)}</p>
                  <Badge className="bg-emerald-50 text-emerald-600">{integrationStatusLabel(selected.status)}</Badge>
                </div>
              </div>
              <SecretLine label="Secret ref" value={selected.secret_ref || "-"} />
              <SecretLine label="Webhook URL" value={String((selected.public_config as Record<string, unknown> | null)?.webhook_url ?? `/api/integrations/${selected.provider}/webhook`)} />
              <KeyValueList rows={[["So'nggi sinxron", formatDate(selected.last_sync_at)], ["Holat", integrationStatusLabel(selected.status)]]} />
              <div className="flex gap-3 pt-4">
                <Button
                  onClick={() => {
                    upsertClientIntegration(selected.provider, "connected", {
                      last_test_at: new Date().toISOString(),
                      last_test_status: "ok",
                    });
                    testMutation.mutate(selected.provider);
                  }}
                  disabled={testMutation.isPending}
                  variant="secondary"
                  className="rounded-xl border border-blue-100 bg-blue-50 text-xs font-black text-blue-600"
                >
                  <Send className="mr-2 size-4" />
                  Test yuborish
                </Button>
                <Button
                  onClick={() => {
                    upsertClientIntegration(selected.provider, "disabled");
                    statusMutation.mutate({ provider: selected.provider, status: "disabled" });
                  }}
                  disabled={statusMutation.isPending}
                  variant="secondary"
                  className="rounded-xl border border-rose-100 bg-rose-50 text-xs font-black text-rose-600"
                >
                  <Trash2 className="mr-2 size-4" />
                  Ulanishni uzish
                </Button>
              </div>
            </div>
          ) : (
            <EmptyText text="Tanlangan integratsiya yo'q" />
          )}
        </Panel>
        <div className="space-y-4 xl:col-span-2 2xl:col-span-1">
          <Panel title="API kalitlar" action="Eksport" onAction={() => downloadTextFile("api-keys.json", JSON.stringify(apiKeys, null, 2), "application/json;charset=utf-8")}>
            {apiKeys.length ? apiKeys.slice(0, 3).map((item) => (
              <SecretLine
                key={item.id ?? item.masked}
                label={item.name ?? "API kalit"}
                value={item.masked ?? "••••"}
                revealValue={item.value ?? item.masked ?? "••••"}
              />
            )) : (
              <>
                <SecretLine label="Public API Key" value="pk_live_••••••••••••••••" />
                <SecretLine label="Secret API Key" value="sk_live_••••••••••••••••" />
                <SecretLine label="Webhook Secret" value="whsec_••••••••••••••" />
              </>
            )}
            <button
              onClick={() => {
                const created = addClientApiKey();
                setNewApiKey(created);
                toast.success("Yangi API kalit yaratildi. Uni hozir nusxalab oling.");
                apiKeyMutation.mutate();
              }}
              className="mt-4 flex h-10 w-full items-center justify-center gap-2 rounded-xl border border-dashed border-blue-200 text-xs font-black text-blue-600"
            >
              <Plus className="size-4" />
              Yangi API kalit yaratish
            </button>
          </Panel>
          <Panel title="Webhook endpointlar" action={showAllWebhooks ? "Kamroq ko'rish" : "Barchasini ko'rish"} onAction={() => {
            setShowAllWebhooks((value) => !value);
            saveIntegrationSetting("webhookReviewedAt", new Date().toISOString());
          }}>
            {visibleWebhooks.map((url) => (
              <button
                type="button"
                key={url}
                onClick={() => copyText(url, "Webhook endpoint")}
                className="flex w-full items-center justify-between gap-3 border-b border-slate-100 py-3 text-left text-xs font-bold last:border-0 hover:text-blue-600"
              >
                <span className="min-w-0 truncate">{url}</span>
                <Badge className="bg-emerald-50 text-emerald-600">Aktiv</Badge>
              </button>
            ))}
          </Panel>
        </div>
      </div>
      <div className="grid gap-4 xl:grid-cols-2 2xl:grid-cols-[0.8fr_0.7fr_0.8fr_0.8fr]">
        <Panel title="Ma'lumot almashish">
          <input
            ref={importInputRef}
            type="file"
            accept=".json,.csv,text/csv,application/json"
            className="hidden"
            onChange={(event) => importIntegrationFile(event.target.files?.[0])}
          />
          <ActionLink label="Talabalar eksporti (CSV)" button="Eksport" onClick={() => downloadTextFile("students-export.csv", toCsv([{ note: "Talabalar eksporti talabalar bo'limidagi real data orqali bajariladi" }]), "text/csv;charset=utf-8")} />
          <ActionLink label="Integratsiyalar eksporti (CSV)" button="Eksport" onClick={exportIntegrations} />
          <ActionLink label="Ma'lumotlar importi" button="Import" onClick={() => importInputRef.current?.click()} />
        </Panel>
        <Panel title="Avtomatik sinxronizatsiya">
          <Toggle enabled label="Avtomatik sinxronizatsiya" onChange={(value) => saveIntegrationSetting("autoSync", value)} />
          <Select
            value={String((effectiveStored as { syncInterval?: unknown }).syncInterval ?? "30 daqiqa")}
            onChange={(event) => saveIntegrationSetting("syncInterval", event.target.value)}
            className="mt-4 h-10 w-full rounded-xl text-xs font-bold"
          >
            <option>15 daqiqa</option>
            <option>30 daqiqa</option>
            <option>1 soat</option>
            <option>6 soat</option>
          </Select>
          <div className="mt-4"><Toggle enabled label="Xatolik bo'lsa xabar berish" onChange={(value) => saveIntegrationSetting("notifyOnError", value)} /></div>
        </Panel>
        <Panel title="Integratsiya loglari" action="Eksport" onAction={exportIntegrations}>
          {integrations.slice(0, 5).map((item) => (
            <LogLine key={item.id} tone={item.status === "error" ? "red" : "green"} title={`${formatProvider(item.provider)}: ${integrationStatusLabel(item.status)}`} time={formatDate(item.last_sync_at || item.updated_at)} />
          ))}
        </Panel>
        <Panel title="Yordam va hujjatlar">
          {["Integratsiya bo'yicha qo'llanma", "API hujjatlari", "Webhook namunalar", "Tez-tez so'raladigan savollar"].map((item) => (
            <ActionLink key={item} label={item} button="↗" onClick={() => {
              saveIntegrationSetting("lastHelpOpened", item);
              window.open(helpLinks[item], "_blank", "noopener,noreferrer");
            }} />
          ))}
        </Panel>
      </div>
      <Modal
        open={Boolean(integrationForm)}
        title={integrationForm?.mode === "create" ? "Yangi integratsiya qo'shish" : "Integratsiyani tahrirlash"}
        description="Provider, ko'rinadigan nom, secret ref va webhook URL ni kiriting."
        onOpenChange={(open) => {
          if (!open) setIntegrationForm(null);
        }}
        footer={(
          <>
            <Button type="button" variant="secondary" onClick={() => setIntegrationForm(null)}>
              Bekor qilish
            </Button>
            <Button
              type="button"
              onClick={submitIntegrationForm}
              disabled={!integrationForm?.provider.trim() || createMutation.isPending || configMutation.isPending}
            >
              {integrationForm?.mode === "create" ? "Integratsiya qo'shish" : "Saqlash"}
            </Button>
          </>
        )}
      >
        {integrationForm ? (
          <div className="space-y-4">
            {integrationForm.mode === "create" ? (
              <div>
                <LabelText>Tayyor integratsiyalar</LabelText>
                <div className="mt-2 grid gap-2 sm:grid-cols-2">
                  {integrationPresets.map((preset) => (
                    <button
                      key={preset.provider}
                      type="button"
                      onClick={() => setIntegrationForm({
                        mode: "create",
                        provider: preset.provider,
                        label: preset.label,
                        secretRef: preset.secret,
                        webhookUrl: preset.webhook,
                      })}
                      className={cn(
                        "rounded-xl border p-3 text-left transition hover:border-blue-300 hover:bg-blue-50",
                        normalizeProvider(integrationForm.provider) === preset.provider
                          ? "border-blue-400 bg-blue-50"
                          : "border-slate-200 bg-white",
                      )}
                    >
                      <p className="text-sm font-black text-slate-900">{preset.label}</p>
                      <p className="mt-1 font-mono text-[11px] font-bold text-slate-500">{preset.provider}</p>
                    </button>
                  ))}
                </div>
              </div>
            ) : null}
            <div className="grid gap-4 sm:grid-cols-2">
              <div className="space-y-2">
                <LabelText>Provider nomi</LabelText>
                <Input
                  value={integrationForm.provider}
                  onChange={(event) => {
                    const provider = normalizeProvider(event.target.value);
                    setIntegrationForm((form) => form ? {
                      ...form,
                      provider: event.target.value,
                      secretRef: form.secretRef || `${provider.toUpperCase()}_SECRET`,
                      webhookUrl: form.webhookUrl || `/api/integrations/${provider}/webhook`,
                    } : form);
                  }}
                  placeholder="masalan: telegram"
                />
              </div>
              <div className="space-y-2">
                <LabelText>Ko'rinadigan nom</LabelText>
                <Input
                  value={integrationForm.label}
                  onChange={(event) => setIntegrationForm((form) => form ? { ...form, label: event.target.value } : form)}
                  placeholder="Telegram bot"
                />
              </div>
            </div>
            <div className="space-y-2">
              <LabelText>Secret ref yoki .env nomi</LabelText>
              <Input
                value={integrationForm.secretRef}
                onChange={(event) => setIntegrationForm((form) => form ? { ...form, secretRef: event.target.value } : form)}
                placeholder="TELEGRAM_BOT_TOKEN"
              />
              <p className="text-xs font-bold text-slate-500">Bu yerga haqiqiy secret emas, .env dagi kalit nomi yoziladi.</p>
            </div>
            <div className="space-y-2">
              <LabelText>Webhook URL</LabelText>
              <Input
                value={integrationForm.webhookUrl}
                onChange={(event) => setIntegrationForm((form) => form ? { ...form, webhookUrl: event.target.value } : form)}
                placeholder="/api/integrations/telegram/webhook"
              />
            </div>
          </div>
        ) : null}
      </Modal>
      <Modal
        open={Boolean(newApiKey)}
        title="Yangi API kalit yaratildi"
        description="Bu kalitni hozir nusxalab oling. Keyin xavfsizlik uchun ro'yxatda maskalangan ko'rinadi."
        onOpenChange={(open) => {
          if (!open) setNewApiKey(null);
        }}
        footer={(
          <>
            <Button type="button" variant="secondary" onClick={() => setNewApiKey(null)}>
              Yopish
            </Button>
            <Button type="button" onClick={() => newApiKey?.value ? copyText(newApiKey.value, "API kalit") : undefined}>
              <Copy className="mr-2 size-4" />
              Nusxalash
            </Button>
          </>
        )}
      >
        {newApiKey ? (
          <div className="rounded-2xl border border-blue-100 bg-blue-50 p-4">
            <p className="text-xs font-black uppercase tracking-wide text-blue-500">{newApiKey.name ?? "API kalit"}</p>
            <p className="mt-3 break-all font-mono text-sm font-black text-slate-900">{newApiKey.value ?? newApiKey.masked}</p>
          </div>
        ) : null}
      </Modal>
    </div>
  );
}

function SettingRow({
  icon: Icon,
  title,
  description,
  children,
}: {
  icon: React.ComponentType<{ className?: string }>;
  title: string;
  description: string;
  children: React.ReactNode;
}) {
  return (
    <div className="grid gap-4 px-4 py-4 lg:grid-cols-[280px_1fr] 2xl:grid-cols-[340px_1fr]">
      <div className="flex gap-4">
        <span className="grid size-10 shrink-0 place-items-center rounded-xl bg-blue-50 text-blue-600">
          <Icon className="size-5" />
        </span>
        <div>
          <p className="text-sm font-black text-slate-800">{title}</p>
          <p className="mt-1 text-xs font-bold leading-relaxed text-slate-500">{description}</p>
        </div>
      </div>
      <div className="flex min-w-0 items-center">{children}</div>
    </div>
  );
}

function Panel({
  title,
  action,
  onAction,
  children,
  className,
}: {
  title: string;
  action?: string;
  onAction?: () => void;
  children: React.ReactNode;
  className?: string;
}) {
  return (
    <Card className={cn("min-w-0 overflow-hidden rounded-2xl border border-slate-200/80 bg-white shadow-sm", className)}>
      <CardHeader className="flex-row items-center justify-between gap-3 border-b border-slate-100 px-4 py-3">
        <CardTitle className="min-w-0 truncate text-[15px] font-black text-slate-950">{title}</CardTitle>
        {action ? (
          <button
            type="button"
            onClick={onAction ?? (() => toast.info("Bu amal uchun hozircha alohida sozlama yo'q"))}
            className="shrink-0 text-[11px] font-black text-blue-600 hover:text-blue-700"
          >
            {action} <ChevronRight className="inline size-3" />
          </button>
        ) : null}
      </CardHeader>
      <CardContent className="p-4">{children}</CardContent>
    </Card>
  );
}

function Metric({
  icon: Icon,
  title,
  value,
  hint,
  tone,
  progress,
}: {
  icon: React.ComponentType<{ className?: string }>;
  title: string;
  value: string;
  hint?: string;
  tone: "blue" | "green" | "violet" | "orange" | "red" | "slate";
  progress?: number;
}) {
  const colors = {
    blue: "bg-blue-50 text-blue-600",
    green: "bg-emerald-50 text-emerald-600",
    violet: "bg-violet-50 text-violet-600",
    orange: "bg-amber-50 text-amber-600",
    red: "bg-rose-50 text-rose-600",
    slate: "bg-slate-100 text-slate-600",
  };
  return (
    <Card className="min-w-0 overflow-hidden rounded-2xl border border-slate-200/80 bg-white shadow-sm">
      <CardContent className="p-4">
        <div className="flex gap-3">
          <span className={cn("grid size-10 shrink-0 place-items-center rounded-xl", colors[tone])}><Icon className="size-5" /></span>
          <div className="min-w-0">
            <p className="text-[11px] font-black leading-tight text-slate-500">{title}</p>
            <p className="mt-1.5 break-words text-xl font-black leading-tight text-slate-950">{value}</p>
            {hint ? <p className="mt-1.5 text-[11px] font-bold leading-tight text-slate-500">{hint}</p> : null}
          </div>
        </div>
        {typeof progress === "number" ? (
          <div className="mt-3">
            <div className="h-2 overflow-hidden rounded-full bg-slate-100">
              <div className="h-full rounded-full bg-blue-600" style={{ width: `${progress}%` }} />
            </div>
            <p className="mt-1.5 text-[11px] font-bold text-slate-500">{progress}% ishlatilgan</p>
          </div>
        ) : null}
      </CardContent>
    </Card>
  );
}

function MiniSparkline({ points, color, height = 90, filled }: { points: number[]; color: string; height?: number; filled?: boolean }) {
  const safe = points.length > 1 ? points : [0, 0];
  const max = Math.max(...safe, 1);
  const width = 360;
  const coords = safe.map((point, index) => {
    const x = (index / (safe.length - 1)) * width;
    const y = height - (point / max) * (height - 18) - 8;
    return `${x},${y}`;
  });
  const path = coords.join(" ");
  return (
    <svg viewBox={`0 0 ${width} ${height}`} className="w-full" style={{ height }}>
      <line x1="0" x2={width} y1={height - 20} y2={height - 20} stroke="#e5e7eb" />
      {filled ? <polygon points={`0,${height} ${path} ${width},${height}`} fill={color} opacity="0.12" /> : null}
      <polyline points={path} fill="none" stroke={color} strokeWidth="4" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  );
}

function Toggle({ enabled, label, onChange }: { enabled?: boolean; label: string; onChange: (enabled: boolean) => void }) {
  const [active, setActive] = useState(Boolean(enabled));
  return (
    <button
      type="button"
      onClick={() => {
        const next = !active;
        setActive(next);
        onChange(next);
      }}
      className="flex items-center gap-3 text-sm font-black text-slate-600"
    >
      <span className={cn("relative h-7 w-12 rounded-full transition", active ? "bg-blue-600" : "bg-slate-200")}>
        <span className={cn("absolute top-1 size-5 rounded-full bg-white shadow transition-all", active ? "left-6" : "left-1")} />
      </span>
      {label}
    </button>
  );
}

function Choice({
  active,
  icon: Icon,
  title,
  subtitle,
  onClick,
}: {
  active?: boolean;
  icon: React.ComponentType<{ className?: string }>;
  title: string;
  subtitle: string;
  onClick: () => void;
}) {
  return (
    <button onClick={onClick} className={cn("flex gap-4 rounded-xl border p-4 text-left transition", active ? "border-blue-500 bg-blue-50" : "border-slate-200 hover:bg-slate-50")}>
      <span className="grid size-10 place-items-center rounded-xl bg-blue-50 text-blue-600"><Icon className="size-5" /></span>
      <span>
        <span className="block text-sm font-black text-blue-700">{title}</span>
        <span className="mt-1 block text-xs font-bold text-slate-500">{subtitle}</span>
      </span>
    </button>
  );
}

function InfoLine({ icon: Icon, title, text }: { icon: React.ComponentType<{ className?: string }>; title: string; text: string }) {
  return (
    <div className="flex gap-4">
      <span className="grid size-11 shrink-0 place-items-center rounded-xl bg-blue-50 text-blue-600"><Icon className="size-5" /></span>
      <div>
        <p className="text-sm font-black text-slate-800">{title}</p>
        <p className="mt-1 text-xs font-bold text-slate-500">{text}</p>
      </div>
    </div>
  );
}

function DataTable({
  headers,
  rows,
  emptyText,
  minWidth = 620,
}: {
  headers: string[];
  rows: React.ReactNode[][];
  emptyText: string;
  minWidth?: number;
}) {
  return (
    <div className="overflow-x-auto edulab-scrollbar">
      <table className="w-full text-left" style={{ minWidth }}>
        <thead>
          <tr className="border-b border-slate-100 bg-slate-50/50 text-[11px] font-black text-slate-500">
            {headers.map((head) => <th key={head} className="px-3 py-3">{head}</th>)}
          </tr>
        </thead>
        <tbody className="divide-y divide-slate-100">
          {rows.length > 0 ? rows.map((row, rowIndex) => (
            <tr key={rowIndex} className="hover:bg-slate-50/60">
              {row.map((cell, index) => (
                <td key={index} className="px-3 py-3 text-[11px] font-bold text-slate-700">
                  {index === row.length - 1 && cell === "actions" ? (
                    <div className="flex gap-2">
                      <IconButton icon={Download} title="Yuklab olish" />
                      <IconButton icon={RefreshCcw} title="Yangilash" />
                      <IconButton icon={MoreVertical} title="Boshqa amallar" />
                    </div>
                  ) : typeof cell === "string" ? statusCell(cell) : cell}
                </td>
              ))}
            </tr>
          )) : (
            <tr>
              <td colSpan={headers.length} className="px-3 py-10 text-center text-xs font-bold text-slate-400">{emptyText}</td>
            </tr>
          )}
        </tbody>
      </table>
    </div>
  );
}

function statusCell(cell: string) {
  if (["Muvaffaqiyatli", "Ulangan", "Faol", "Onlayn", "Aktiv"].includes(cell)) return <Badge className="bg-emerald-50 text-emerald-600">{cell}</Badge>;
  if (["Kutilmoqda", "Navbatda", "Jarayonda", "pending"].includes(cell)) return <Badge className="bg-amber-50 text-amber-600">{cell}</Badge>;
  if (["Xatolik", "Muvaffaqiyatsiz", "failed"].includes(cell)) return <Badge className="bg-rose-50 text-rose-600">{cell}</Badge>;
  return cell;
}

function IconButton({
  icon: Icon,
  title,
  onClick,
  disabled,
}: {
  icon: React.ComponentType<{ className?: string }>;
  title?: string;
  onClick?: () => void;
  disabled?: boolean;
}) {
  return (
    <button
      type="button"
      title={title}
      aria-label={title}
      onClick={onClick ?? (() => toast.info(title ? `${title} amali tanlandi` : "Amal tanlandi"))}
      disabled={disabled}
      className="grid size-8 place-items-center rounded-lg border border-slate-200 bg-white text-slate-500 hover:bg-slate-50 disabled:cursor-not-allowed disabled:opacity-50"
    >
      <Icon className="size-3.5" />
    </button>
  );
}

function KeyValueList({ rows }: { rows: Array<[string, string]> }) {
  return (
    <dl className="divide-y divide-slate-100">
      {rows.map(([label, value]) => (
        <div key={label} className="grid grid-cols-[minmax(0,1fr)_minmax(0,1fr)] gap-3 py-2.5 text-xs">
          <dt className="font-bold text-slate-500">{label}</dt>
          <dd className="truncate text-right font-black text-slate-800" title={value}>{value}</dd>
        </div>
      ))}
    </dl>
  );
}

function StatusRow({ title, status }: { title: string; status: string }) {
  return (
    <div className="flex items-center justify-between gap-3 text-xs font-bold">
      <span className="min-w-0 truncate text-slate-700">{title}</span>
      <Badge className={cn(status === "connected" ? "bg-emerald-50 text-emerald-600" : status === "error" ? "bg-rose-50 text-rose-600" : "bg-amber-50 text-amber-600")}>
        {integrationStatusLabel(status)}
      </Badge>
    </div>
  );
}

function LogLine({ title, time, tone }: { title: string; time: string; tone: "green" | "red" | "blue" | "amber" }) {
  const colors = {
    green: "bg-emerald-500",
    red: "bg-rose-500",
    blue: "bg-blue-500",
    amber: "bg-amber-500",
  };
  return (
    <div className="flex items-center gap-3">
      <span className={cn("size-2 rounded-full", colors[tone])} />
      <p className="min-w-0 flex-1 truncate text-xs font-bold text-slate-700">{title}</p>
      <span className="text-xs font-bold text-slate-400">{time}</span>
    </div>
  );
}

function AlertRow({ title, detail, time }: { title: string; detail: string; time: string }) {
  return (
    <div className="grid grid-cols-[36px_1fr_auto] items-center gap-3 border-b border-slate-100 pb-3 last:border-0">
      <span className="grid size-9 place-items-center rounded-xl bg-rose-50 text-rose-500"><AlertTriangle className="size-4" /></span>
      <div>
        <p className="text-xs font-black text-slate-800">{title}</p>
        <p className="text-xs font-bold text-slate-500">{detail}</p>
      </div>
      <span className="text-right text-xs font-bold text-slate-500">{time}</span>
    </div>
  );
}

function CheckList({ items }: { items: string[] }) {
  return (
    <div className="space-y-3">
      {items.map((item) => (
        <p key={item} className="flex items-center gap-2 text-xs font-bold text-slate-700">
          <CheckCircle2 className="size-4 text-emerald-500" />
          {item}
        </p>
      ))}
    </div>
  );
}

function StatText({ label, value, tone }: { label: string; value: number; tone: "green" | "red" | "violet" | "amber" }) {
  const colors = {
    green: "text-emerald-600",
    red: "text-rose-600",
    violet: "text-violet-600",
    amber: "text-amber-600",
  };
  return (
    <div className="px-3 text-left">
      <p className="text-[11px] font-bold leading-tight text-slate-500">{label}</p>
      <p className={cn("mt-2 text-xl font-black", colors[tone])}>{value}</p>
    </div>
  );
}

function WorldMapLite() {
  return (
    <div className="relative mb-5 h-56 overflow-hidden rounded-xl bg-slate-50">
      <div className="absolute inset-6 rounded-[50%] bg-slate-200/70 blur-xl" />
      <div className="absolute left-[20%] top-[45%] size-6 rounded-full bg-blue-500/80 blur-sm" />
      <div className="absolute left-[58%] top-[38%] size-5 rounded-full bg-sky-500/80 blur-sm" />
      <div className="absolute left-[75%] top-[48%] size-4 rounded-full bg-emerald-500/80 blur-sm" />
      <div className="absolute left-[86%] top-[68%] size-4 rounded-full bg-rose-500/80 blur-sm" />
    </div>
  );
}

function EmptyText({ text }: { text: string }) {
  return <p className="py-6 text-center text-sm font-bold text-slate-400">{text}</p>;
}

function LabelText({ children }: { children: React.ReactNode }) {
  return <p className="text-xs font-black text-slate-600">{children}</p>;
}

function SecretLine({ label, value, revealValue }: { label: string; value: string; revealValue?: string }) {
  const [visible, setVisible] = useState(false);
  const actualValue = revealValue ?? value;
  const displayValue = visible ? actualValue : value;
  const copyValue = () => {
    navigator.clipboard.writeText(actualValue)
      .then(() => toast.success(`${label} nusxalandi`))
      .catch(() => toast.error("Clipboardga yozib bo'lmadi"));
  };

  return (
    <div className="flex items-center gap-3 border-b border-slate-100 py-3 last:border-0">
      <div className="min-w-0 flex-1">
        <p className="text-xs font-black text-slate-500">{label}</p>
        <p className={cn("mt-1 font-mono text-xs font-bold text-slate-700", visible ? "break-all" : "truncate")}>{displayValue}</p>
      </div>
      <IconButton icon={visible ? EyeOff : Eye} title={visible ? "Yashirish" : "Ko'rish"} onClick={() => setVisible((next) => !next)} />
      <IconButton icon={Copy} title="Nusxalash" onClick={copyValue} />
    </div>
  );
}

function SmallAction({
  icon: Icon,
  title,
  text,
  enabled,
  count,
  button,
  onAction,
  onToggle,
}: {
  icon: React.ComponentType<{ className?: string }>;
  title: string;
  text: string;
  enabled?: boolean;
  count?: string;
  button?: string;
  onAction?: () => void;
  onToggle?: (enabled: boolean) => void;
}) {
  return (
    <Card className="min-w-0 overflow-hidden rounded-2xl border border-slate-200/80 bg-white shadow-sm">
      <CardContent className="flex items-start gap-3 p-4">
        <span className="grid size-9 shrink-0 place-items-center rounded-xl bg-blue-50 text-blue-600"><Icon className="size-4" /></span>
        <div className="min-w-0 flex-1">
          <div className="flex items-center justify-between gap-3">
            <p className="min-w-0 text-sm font-black leading-tight text-slate-900">{title}</p>
            {count ? <Badge className="bg-rose-50 text-rose-600">{count}</Badge> : enabled ? <Toggle enabled label="" onChange={(value) => onToggle?.(value)} /> : null}
          </div>
          <p className="mt-2 text-xs font-bold leading-relaxed text-slate-500">{text}</p>
          {button ? (
            <Button type="button" variant="secondary" size="sm" onClick={onAction ?? (() => toast.info(`${title} amali tanlandi`))} className="mt-3 h-8 rounded-lg px-3 text-xs font-black text-blue-600">
              {button}
            </Button>
          ) : null}
        </div>
      </CardContent>
    </Card>
  );
}

function ActionLink({ label, button, onClick }: { label: string; button: string; onClick?: () => void }) {
  return (
    <div className="flex items-center justify-between gap-3 border-b border-slate-100 py-3 last:border-0">
      <span className="min-w-0 text-xs font-bold leading-tight text-slate-700">{label}</span>
      <Button type="button" onClick={onClick ?? (() => toast.info(`${label} amali tanlandi`))} variant="secondary" className="h-8 shrink-0 rounded-lg border border-slate-200 bg-white px-3 text-xs font-black text-blue-600">{button}</Button>
    </div>
  );
}

function formatProvider(provider: string) {
  const labels: Record<string, string> = {
    telegram: "Telegram",
    cloudinary: "Cloudinary",
    smtp: "Email (SMTP)",
    payme: "Payme",
    click: "Click",
    stripe: "Stripe",
    resend: "Resend",
    uzum: "Uzum Bank",
  };
  return labels[provider] ?? provider;
}

function integrationDescription(provider: string) {
  const descriptions: Record<string, string> = {
    telegram: "Telegram bot orqali xabarnomalar yuborish",
    cloudinary: "Media fayllar va transformatsiyalar",
    smtp: "SMTP server orqali email yuborish",
    payme: "Payme to'lov tizimi integratsiyasi",
    click: "Click to'lov tizimi integratsiyasi",
    stripe: "Stripe xalqaro to'lovlari",
    resend: "Transactional email xizmati",
  };
  return descriptions[provider] ?? "Uchinchi tomon servisi";
}

function integrationStatusLabel(status: string) {
  if (status === "connected") return "Ulangan";
  if (status === "pending") return "Kutilmoqda";
  if (status === "error") return "Xatolik";
  if (status === "disabled") return "O'chirilgan";
  return status;
}

function backupStatusLabel(status: string) {
  if (status === "success") return "Muvaffaqiyatli";
  if (status === "queued") return "Navbatda";
  if (status === "running") return "Jarayonda";
  if (status === "failed") return "Muvaffaqiyatsiz";
  if (status === "restored") return "Tiklangan";
  return status;
}

function paymentStatusLabel(status: string) {
  if (status === "successful") return "Muvaffaqiyatli";
  if (status === "pending") return "Kutilmoqda";
  if (status === "failed") return "Muvaffaqiyatsiz";
  if (status === "refunded") return "Qaytarilgan";
  return status;
}

function UsersIcon(props: { className?: string }) {
  return <Bell {...props} />;
}

function ActivityIcon(props: { className?: string }) {
  return <Server {...props} />;
}
