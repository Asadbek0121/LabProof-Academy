"use client";

import { useMemo, useState } from "react";
import type * as React from "react";
import { useQuery } from "@tanstack/react-query";
import { toast } from "sonner";
import {
  AlertTriangle,
  CalendarDays,
  Clock3,
  Download,
  FileClock,
  History,
  RefreshCw,
  Search,
  ShieldCheck,
  UserRound,
} from "lucide-react";
import { PageHeader } from "@/components/layout/page-header";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Input, Select } from "@/components/ui/input";
import { createClient } from "@/lib/supabase/client";
import { cn } from "@/lib/utils";

type ActivityLog = {
  id: string;
  admin_id?: string | null;
  admin_name?: string | null;
  admin_email?: string | null;
  action?: string | null;
  details?: string | null;
  created_at?: string | null;
};

const actionLabels: Record<string, string> = {
  create: "Yaratish",
  created: "Yaratish",
  yaratdi: "Yaratish",
  update: "Tahrirlash",
  updated: "Tahrirlash",
  tahrirladi: "Tahrirlash",
  delete: "O'chirish",
  deleted: "O'chirish",
  "o'chirdi": "O'chirish",
  login: "Kirish",
  logout: "Chiqish",
  approve: "Tasdiqlash",
  tasdiqladi: "Tasdiqlash",
  send: "Yuborish",
  sent: "Yuborish",
  yubordi: "Yuborish",
};

export function ActivityLogsPage() {
  const [searchTerm, setSearchTerm] = useState("");
  const [actionFilter, setActionFilter] = useState("all");
  const [periodFilter, setPeriodFilter] = useState("all");
  const supabase = createClient();

  const {
    data: logs = [],
    isLoading,
    refetch,
    isFetching,
  } = useQuery({
    queryKey: ["activity-logs"],
    queryFn: async () => {
      const { data, error } = await supabase
        .from("activity_logs")
        .select("*")
        .order("created_at", { ascending: false })
        .limit(250);
      if (error) {
        toast.error(error.message || "Tizim loglari yuklanmadi");
        return [];
      }
      return (data || []) as ActivityLog[];
    },
  });

  const normalizedLogs = useMemo(() => {
    return logs.map((log) => ({
      ...log,
      action: log.action || "system",
      details: log.details || "Tafsilot yozilmagan",
      admin_name: log.admin_name || "Tizim administratori",
      admin_email: log.admin_email || log.admin_id || "email yo'q",
      created_at: log.created_at || new Date(0).toISOString(),
    }));
  }, [logs]);

  const filteredLogs = useMemo(() => {
    const now = Date.now();
    return normalizedLogs.filter((log) => {
      const query = searchTerm.toLowerCase().trim();
      const action = String(log.action).toLowerCase();
      const details = String(log.details).toLowerCase();
      const adminName = String(log.admin_name).toLowerCase();
      const adminEmail = String(log.admin_email).toLowerCase();
      const logTime = new Date(log.created_at).getTime();

      const matchesSearch =
        !query ||
        adminName.includes(query) ||
        adminEmail.includes(query) ||
        action.includes(query) ||
        details.includes(query);
      const matchesAction = actionFilter === "all" || classifyAction(action) === actionFilter;
      const matchesPeriod =
        periodFilter === "all" ||
        (periodFilter === "24h" && now - logTime <= 24 * 60 * 60 * 1000) ||
        (periodFilter === "7d" && now - logTime <= 7 * 24 * 60 * 60 * 1000) ||
        (periodFilter === "30d" && now - logTime <= 30 * 24 * 60 * 60 * 1000);

      return matchesSearch && matchesAction && matchesPeriod;
    });
  }, [actionFilter, normalizedLogs, periodFilter, searchTerm]);

  const stats = useMemo(() => {
    const now = Date.now();
    const last24h = normalizedLogs.filter((log) => now - new Date(log.created_at).getTime() <= 24 * 60 * 60 * 1000).length;
    const updates = normalizedLogs.filter((log) => classifyAction(log.action) === "update").length;
    const security = normalizedLogs.filter((log) => classifyAction(log.action) === "security").length;
    return {
      total: normalizedLogs.length,
      last24h,
      updates,
      security,
    };
  }, [normalizedLogs]);

  const actionCounts = useMemo(() => {
    return normalizedLogs.reduce<Record<string, number>>((acc, log) => {
      const key = classifyAction(log.action);
      acc[key] = (acc[key] ?? 0) + 1;
      return acc;
    }, {});
  }, [normalizedLogs]);

  const handleExport = () => {
    if (filteredLogs.length === 0) {
      toast.error("Eksport qilish uchun loglar yo'q");
      return;
    }
    const rows = filteredLogs.map((log) => ({
      sana: formatDateTime(log.created_at),
      admin: log.admin_name,
      email: log.admin_email,
      harakat: getActionLabel(log.action),
      tafsilot: log.details,
    }));
    const headers = Object.keys(rows[0]);
    const csv = [
      headers.join(","),
      ...rows.map((row) => headers.map((header) => csvCell(row[header as keyof typeof row])).join(",")),
    ].join("\n");
    downloadFile(`activity-logs-${new Date().toISOString().slice(0, 10)}.csv`, csv, "text/csv;charset=utf-8");
    toast.success("Tizim loglari CSV formatida yuklandi");
  };

  return (
    <>
      <PageHeader
        title="Tizim loglari"
        current="Faoliyat jurnali"
        action={
          <Button onClick={handleExport} className="h-10 rounded-xl bg-blue-600 px-4 text-xs font-black text-white hover:bg-blue-700">
            <Download className="size-4" />
            CSV yuklash
          </Button>
        }
      />

      <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
        <LogMetric title="Jami loglar" value={String(stats.total)} icon={History} tone="blue" hint="Real baza" />
        <LogMetric title="Oxirgi 24 soat" value={String(stats.last24h)} icon={Clock3} tone="green" hint="Yangi" />
        <LogMetric title="Tahrirlar" value={String(stats.updates)} icon={FileClock} tone="violet" hint="O'zgarish" />
        <LogMetric title="Xavfsizlik" value={String(stats.security)} icon={ShieldCheck} tone="orange" hint="Nazorat" />
      </div>

      <Card className="mt-5 rounded-2xl border border-slate-100 bg-white shadow-soft">
        <CardContent className="flex flex-wrap items-center justify-between gap-3 p-4">
          <div className="relative min-w-[280px] flex-1">
            <Search className="absolute left-3.5 top-1/2 size-4 -translate-y-1/2 text-slate-400" />
            <Input
              value={searchTerm}
              onChange={(event) => setSearchTerm(event.target.value)}
              placeholder="Admin, email, harakat yoki tafsilot..."
              className="h-10.5 rounded-xl border-slate-200 pl-10 text-sm font-semibold"
            />
          </div>
          <div className="flex flex-wrap items-center gap-2">
            <Select value={actionFilter} onChange={(event) => setActionFilter(event.target.value)} className="h-10.5 w-44 rounded-xl border-slate-200 text-xs font-black">
              <option value="all">Barcha harakatlar</option>
              <option value="create">Yaratish</option>
              <option value="update">Tahrirlash</option>
              <option value="delete">O'chirish</option>
              <option value="security">Xavfsizlik</option>
              <option value="message">Xabar</option>
            </Select>
            <Select value={periodFilter} onChange={(event) => setPeriodFilter(event.target.value)} className="h-10.5 w-40 rounded-xl border-slate-200 text-xs font-black">
              <option value="all">Barcha vaqt</option>
              <option value="24h">24 soat</option>
              <option value="7d">7 kun</option>
              <option value="30d">30 kun</option>
            </Select>
            <Button
              variant="secondary"
              onClick={() => {
                setSearchTerm("");
                setActionFilter("all");
                setPeriodFilter("all");
              }}
              className="h-10.5 rounded-xl border border-slate-200 bg-white px-4 text-xs font-black text-slate-600"
            >
              Tozalash
            </Button>
            <Button
              variant="secondary"
              onClick={() => refetch()}
              className="h-10.5 rounded-xl border border-slate-200 bg-slate-50 px-4 text-xs font-black text-slate-700"
            >
              <RefreshCw className={cn("size-4", isFetching && "animate-spin")} />
              Yangilash
            </Button>
          </div>
        </CardContent>
      </Card>

      <div className="mt-5 grid gap-5 xl:grid-cols-[1fr_360px] 2xl:grid-cols-[1fr_420px]">
        <Card className="overflow-hidden rounded-2xl border border-slate-100 bg-white shadow-soft">
          <CardHeader className="border-b border-slate-100">
            <div>
              <CardTitle className="text-lg font-black text-slate-950">Faoliyat oqimi</CardTitle>
              <p className="mt-1 text-xs font-semibold text-slate-500">Admin panelda bajarilgan real amallar jurnali.</p>
            </div>
            <Badge variant="slate">{filteredLogs.length} ta yozuv</Badge>
          </CardHeader>
          <CardContent className="p-0">
            {isLoading ? (
              <div className="flex flex-col items-center justify-center py-20 text-sm font-bold text-slate-400">
                <div className="mb-4 size-8 animate-spin rounded-full border-4 border-blue-600 border-t-transparent" />
                Loglar yuklanmoqda...
              </div>
            ) : filteredLogs.length > 0 ? (
              <div className="divide-y divide-slate-100">
                {filteredLogs.map((log) => {
                  const type = classifyAction(log.action);
                  return (
                    <div key={log.id} className="grid gap-4 p-4 transition hover:bg-slate-50/70 lg:grid-cols-[220px_150px_minmax(0,1fr)_170px] lg:items-center">
                      <div className="flex min-w-0 items-center gap-3">
                        <span className={cn("grid size-11 shrink-0 place-items-center rounded-2xl", actionIconClass(type))}>
                          <UserRound className="size-5" />
                        </span>
                        <div className="min-w-0">
                          <p className="truncate text-sm font-black text-slate-900">{log.admin_name}</p>
                          <p className="mt-1 truncate text-xs font-semibold text-slate-500">{log.admin_email}</p>
                        </div>
                      </div>
                      <div>
                        <Badge className={cn("rounded-lg text-[10px] uppercase tracking-wide", actionBadgeClass(type))}>
                          {getActionLabel(log.action)}
                        </Badge>
                      </div>
                      <p className="min-w-0 text-sm font-semibold leading-6 text-slate-600">{log.details}</p>
                      <div className="flex items-center gap-2 text-xs font-bold text-slate-500 lg:justify-end">
                        <CalendarDays className="size-4 text-slate-400" />
                        <span>{formatDateTime(log.created_at)}</span>
                      </div>
                    </div>
                  );
                })}
              </div>
            ) : (
              <div className="flex flex-col items-center justify-center py-20 text-center">
                <History className="mb-4 size-12 text-slate-300" />
                <p className="text-sm font-black text-slate-900">Haqiqiy loglar hali yo'q</p>
                <p className="mt-1 max-w-sm text-xs font-semibold text-slate-500">
                  Admin amallari `activity_logs` jadvaliga yozilganda shu yerda ko'rinadi.
                </p>
              </div>
            )}
          </CardContent>
        </Card>

        <div className="space-y-5">
          <Card className="rounded-2xl border border-slate-100 bg-white shadow-soft">
            <CardHeader>
              <CardTitle className="text-base font-black">Harakatlar taqsimoti</CardTitle>
            </CardHeader>
            <CardContent className="space-y-3">
              {["create", "update", "delete", "security", "message"].map((type) => (
                <LogBreakdown key={type} label={typeLabel(type)} value={actionCounts[type] ?? 0} total={Math.max(1, normalizedLogs.length)} tone={type} />
              ))}
            </CardContent>
          </Card>

          <Card className="rounded-2xl border border-slate-100 bg-white shadow-soft">
            <CardHeader>
              <CardTitle className="text-base font-black">Audit holati</CardTitle>
            </CardHeader>
            <CardContent className="space-y-3">
              <AuditHint icon={ShieldCheck} label="Manba" value="Supabase activity_logs" />
              <AuditHint icon={FileClock} label="Limit" value="Oxirgi 250 yozuv" />
              <AuditHint icon={AlertTriangle} label="Namuna data" value="O'chirilgan" />
            </CardContent>
          </Card>
        </div>
      </div>
    </>
  );
}

function classifyAction(action: string | null | undefined) {
  const value = String(action || "").toLowerCase();
  if (/(create|created|insert|yarat|qo'sh)/.test(value)) return "create";
  if (/(update|updated|edit|tahrir|change|save|saqla)/.test(value)) return "update";
  if (/(delete|deleted|remove|o'chir)/.test(value)) return "delete";
  if (/(login|logout|auth|security|xavfsiz|role|permission)/.test(value)) return "security";
  if (/(send|sent|message|telegram|xabar|yubor)/.test(value)) return "message";
  return "system";
}

function getActionLabel(action: string | null | undefined) {
  const value = String(action || "system").toLowerCase();
  return actionLabels[value] || typeLabel(classifyAction(value));
}

function typeLabel(type: string) {
  const labels: Record<string, string> = {
    create: "Yaratish",
    update: "Tahrirlash",
    delete: "O'chirish",
    security: "Xavfsizlik",
    message: "Xabarlar",
    system: "Tizim",
  };
  return labels[type] || "Tizim";
}

function actionIconClass(type: string) {
  const classes: Record<string, string> = {
    create: "bg-emerald-50 text-emerald-600",
    update: "bg-blue-50 text-blue-600",
    delete: "bg-rose-50 text-rose-600",
    security: "bg-amber-50 text-amber-600",
    message: "bg-violet-50 text-violet-600",
    system: "bg-slate-100 text-slate-600",
  };
  return classes[type] || classes.system;
}

function actionBadgeClass(type: string) {
  const classes: Record<string, string> = {
    create: "bg-emerald-50 text-emerald-600",
    update: "bg-blue-50 text-blue-600",
    delete: "bg-rose-50 text-rose-600",
    security: "bg-amber-50 text-amber-600",
    message: "bg-violet-50 text-violet-600",
    system: "bg-slate-100 text-slate-600",
  };
  return classes[type] || classes.system;
}

function formatDateTime(value: string | null | undefined) {
  if (!value) return "-";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return "-";
  return date.toLocaleString("uz-UZ", {
    day: "2-digit",
    month: "2-digit",
    year: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  });
}

function csvCell(value: unknown) {
  const text = String(value ?? "").replaceAll('"', '""');
  return `"${text}"`;
}

function downloadFile(filename: string, content: string, type: string) {
  const blob = new Blob([content], { type });
  const url = URL.createObjectURL(blob);
  const link = document.createElement("a");
  link.href = url;
  link.download = filename;
  document.body.appendChild(link);
  link.click();
  link.remove();
  URL.revokeObjectURL(url);
}

function LogMetric({
  title,
  value,
  icon: Icon,
  tone,
  hint,
}: {
  title: string;
  value: string;
  icon: React.ComponentType<{ className?: string }>;
  tone: "blue" | "green" | "violet" | "orange";
  hint: string;
}) {
  const colors = {
    blue: "bg-blue-50 text-blue-600",
    green: "bg-emerald-50 text-emerald-600",
    violet: "bg-violet-50 text-violet-600",
    orange: "bg-orange-50 text-orange-600",
  };

  return (
    <Card className="rounded-2xl border border-slate-100 bg-white shadow-soft transition duration-200 hover:-translate-y-0.5">
      <CardContent className="flex items-center justify-between p-5">
        <div className="flex items-center gap-4">
          <span className={cn("grid size-12 place-items-center rounded-2xl", colors[tone])}>
            <Icon className="size-5" />
          </span>
          <div>
            <p className="text-2xl font-black leading-none text-slate-950">{value}</p>
            <p className="mt-2 text-[10px] font-black uppercase tracking-wide text-slate-400">{title}</p>
          </div>
        </div>
        <Badge className={cn("rounded-lg text-[10px] uppercase tracking-wide", colors[tone])}>{hint}</Badge>
      </CardContent>
    </Card>
  );
}

function LogBreakdown({ label, value, total, tone }: { label: string; value: number; total: number; tone: string }) {
  const percent = Math.round((value / total) * 100);
  const barClass = actionBadgeClass(tone).split(" ")[0].replace("bg-", "bg-");
  return (
    <div>
      <div className="mb-2 flex items-center justify-between text-xs font-black text-slate-600">
        <span>{label}</span>
        <span>{value} ta</span>
      </div>
      <div className="h-2 overflow-hidden rounded-full bg-slate-100">
        <div className={cn("h-full rounded-full", barClass)} style={{ width: `${percent}%` }} />
      </div>
    </div>
  );
}

function AuditHint({
  icon: Icon,
  label,
  value,
}: {
  icon: React.ComponentType<{ className?: string }>;
  label: string;
  value: string;
}) {
  return (
    <div className="flex items-center justify-between rounded-2xl border border-slate-100 bg-slate-50/60 p-3">
      <div className="flex items-center gap-3">
        <span className="grid size-10 place-items-center rounded-xl bg-blue-50 text-blue-600">
          <Icon className="size-5" />
        </span>
        <span className="text-xs font-black text-slate-600">{label}</span>
      </div>
      <span className="text-xs font-black text-slate-900">{value}</span>
    </div>
  );
}
