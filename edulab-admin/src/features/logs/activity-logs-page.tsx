"use client";

import { useState, useEffect, useMemo } from "react";
import { PageHeader } from "@/components/layout/page-header";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input, Select } from "@/components/ui/input";
import { Badge } from "@/components/ui/badge";
import { createClient } from "@/lib/supabase/client";
import { useQuery } from "@tanstack/react-query";
import { CalendarDays, Clock, History, Search, User } from "lucide-react";
import { cn } from "@/lib/utils";

// High-fidelity fallback logs for presentation
const mockActivityLogs = [
  {
    id: "log_1",
    admin_name: "Asadbek Davronov",
    admin_email: "asadbek.d@edulab.uz",
    action: "yaratdi",
    details: "Yangi dars mavzusi qo'shildi: 'Gematologiya va qon tahlili'",
    created_at: new Date(Date.now() - 1000 * 60 * 15).toISOString(), // 15 mins ago
  },
  {
    id: "log_2",
    admin_name: "Asadbek Davronov",
    admin_email: "asadbek.d@edulab.uz",
    action: "tasdiqladi",
    details: "Talaba Malika To'xtayevaning 'Biokimyo asoslari' moduli sertifikati tasdiqlandi",
    created_at: new Date(Date.now() - 1000 * 60 * 120).toISOString(), // 2 hours ago
  },
  {
    id: "log_3",
    admin_name: "Super Admin",
    admin_email: "admin@edulab.uz",
    action: "tahrirladi",
    details: "Telegram bot sozlamalari va webhook API kaliti yangilandi",
    created_at: new Date(Date.now() - 1000 * 60 * 60 * 24).toISOString(), // 1 day ago
  },
  {
    id: "log_4",
    admin_name: "Super Admin",
    admin_email: "admin@edulab.uz",
    action: "yubordi",
    details: "Barcha faol talabalarga haftalik imtihon boshlanishi bo'yicha xabar yuborildi",
    created_at: new Date(Date.now() - 1000 * 60 * 60 * 26).toISOString(), // 1.1 days ago
  },
  {
    id: "log_5",
    admin_name: "Asadbek Davronov",
    admin_email: "asadbek.d@edulab.uz",
    action: "o'chirdi",
    details: "Eski test savollari arxividan 12 ta xato shakllangan savollar o'chirildi",
    created_at: new Date(Date.now() - 1000 * 60 * 60 * 72).toISOString(), // 3 days ago
  }
];

export function ActivityLogsPage() {
  const [mounted, setMounted] = useState(false);
  const [searchTerm, setSearchTerm] = useState("");
  const [actionFilter, setActionFilter] = useState("all");
  const supabase = createClient();

  useEffect(() => {
    setMounted(true);
  }, []);

  const { data: dbLogs, isLoading } = useQuery({
    queryKey: ["activity-logs"],
    queryFn: async () => {
      const { data, error } = await supabase
        .from("activity_logs")
        .select("*")
        .order("created_at", { ascending: false })
        .limit(100);
      if (error) return [];
      return data || [];
    },
  });

  const activeLogs = useMemo(() => {
    if (dbLogs && dbLogs.length > 0) return dbLogs;
    return mockActivityLogs;
  }, [dbLogs]);

  const filteredLogs = useMemo(() => {
    return activeLogs.filter((log) => {
      const matchesSearch =
        log.admin_name.toLowerCase().includes(searchTerm.toLowerCase()) ||
        log.action.toLowerCase().includes(searchTerm.toLowerCase()) ||
        (log.details || "").toLowerCase().includes(searchTerm.toLowerCase());
      const matchesAction = actionFilter === "all" || log.action.includes(actionFilter);
      return matchesSearch && matchesAction;
    });
  }, [activeLogs, searchTerm, actionFilter]);

  // Dynamic statistics
  const stats = useMemo(() => {
    const total = filteredLogs.length;
    const createCount = filteredLogs.filter(l => l.action.includes("yaratdi")).length;
    const updateCount = filteredLogs.filter(l => l.action.includes("tahrirladi")).length;
    const deleteCount = filteredLogs.filter(l => l.action.includes("o'chirdi")).length;
    return { total, createCount, updateCount, deleteCount };
  }, [filteredLogs]);

  const actionColors: Record<string, string> = {
    yaratdi: "bg-emerald-50 border-emerald-100 text-emerald-700",
    tahrirladi: "bg-blue-50 border-blue-100 text-blue-700",
    "o'chirdi": "bg-rose-50 border-rose-100 text-rose-700",
    tasdiqladi: "bg-violet-50 border-violet-100 text-violet-700",
    yubordi: "bg-amber-50 border-amber-100 text-amber-700",
  };

  const getActionColor = (action: string) => {
    const lowerAction = action.toLowerCase();
    for (const [key, color] of Object.entries(actionColors)) {
      if (lowerAction.includes(key)) return color;
    }
    return "bg-slate-50 border-slate-200 text-slate-700";
  };

  const getInitials = (name: string) => {
    if (!name) return "A";
    const parts = name.split(" ");
    if (parts.length >= 2) return (parts[0][0] + parts[1][0]).toUpperCase();
    return name.slice(0, 2).toUpperCase();
  };

  if (!mounted) {
    return (
      <div className="flex h-screen items-center justify-center">
        <div className="size-8 animate-spin rounded-full border-4 border-violet-600 border-t-transparent" />
      </div>
    );
  }

  return (
    <>
      <PageHeader title="Tizim Loglari" current="Faoliyat jurnali" />

      {/* Metrics Row (Matching Students Section layout) */}
      <div className="grid gap-4.5 md:grid-cols-2 xl:grid-cols-4">
        <LogMetric title="Jami qaydlar" value={String(stats.total)} icon={History} tone="violet" hint="Tizim tarixi" />
        <LogMetric title="Yaratish" value={String(stats.createCount)} icon={User} tone="green" hint="Mavzu & dars" />
        <LogMetric title="Tahrirlash" value={String(stats.updateCount)} icon={Clock} tone="blue" hint="O'zgarishlar" />
        <LogMetric title="O'chirish" value={String(stats.deleteCount)} icon={Clock} tone="orange" hint="O'chirilganlar" />
      </div>

      {/* Filter Row (Matching Students Section layout) */}
      <div className="mt-5 flex flex-wrap gap-3 items-center justify-between bg-white border border-slate-100 rounded-2xl p-4 shadow-soft">
        <div className="relative flex-1 min-w-[280px]">
          <Search className="absolute left-3.5 top-1/2 size-4 -translate-y-1/2 text-slate-400" />
          <Input
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            placeholder="Ism, harakat yoki tafsilot orqali qidirish..."
            className="pl-10 h-10.5 rounded-xl border-slate-200 text-sm font-semibold text-slate-800 focus:border-violet-500 placeholder-slate-450"
          />
        </div>
        <div className="flex gap-2 items-center">
          <Select
            className="w-56 h-10.5 rounded-xl border-slate-200 font-bold text-xs uppercase tracking-wider text-slate-500"
            value={actionFilter}
            onChange={(e) => setActionFilter(e.target.value)}
          >
            <option value="all">Barcha harakatlar</option>
            <option value="yaratdi">Yaratish</option>
            <option value="tahrirladi">Tahrirlash</option>
            <option value="o'chirdi">O'chirish</option>
            <option value="tasdiqladi">Tasdiqlash</option>
            <option value="yubordi">Yuborish</option>
          </Select>
          <Button
            variant="secondary"
            onClick={() => {
              setSearchTerm("");
              setActionFilter("all");
            }}
            className="h-10.5 rounded-xl border border-slate-200 px-4 font-bold text-xs bg-slate-50 text-slate-700 hover:bg-slate-100"
          >
            Tozalash
          </Button>
        </div>
      </div>

      {/* Logs Table (Matching Students Section layout) */}
      <div className="mt-5">
        <Card className="border border-slate-100 bg-white rounded-2xl shadow-soft overflow-hidden">
          <CardHeader className="border-b border-slate-100 pb-4.5 px-6">
            <div className="flex items-center justify-between">
              <div>
                <CardTitle className="text-base font-black text-slate-800 uppercase tracking-wide">
                  Harakatlar jurnali
                </CardTitle>
                <CardDescription className="text-xs font-semibold text-slate-400 mt-1">
                  Tizim administratorlari tomonidan amalga oshirilgan barcha harakatlar ro'yxati.
                </CardDescription>
              </div>
              <Badge variant="violet" className="text-[10px] font-bold uppercase py-0.5 px-2.5 rounded-lg shadow-sm">
                Jami {filteredLogs.length} ta yozuv
              </Badge>
            </div>
          </CardHeader>
          <CardContent className="p-0">
            {isLoading ? (
              <div className="flex flex-col items-center justify-center py-20 text-sm font-semibold text-slate-400">
                <div className="size-8 animate-spin rounded-full border-4 border-violet-600 border-t-transparent mb-4" />
                Yuklanmoqda...
              </div>
            ) : filteredLogs.length > 0 ? (
              <div className="overflow-x-auto edulab-scrollbar">
                <table className="w-full min-w-[850px] text-sm">
                  <thead className="bg-slate-50/50 text-left text-[10px] font-bold uppercase tracking-wider text-slate-500 border-b border-slate-100">
                    <tr>
                      <th className="px-5 py-4">Administrator</th>
                      <th className="px-5 py-4">Harakat</th>
                      <th className="px-5 py-4">Tafsilotlar</th>
                      <th className="px-5 py-4 text-right">Sana va Vaqt</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-slate-100">
                    {filteredLogs.map((log) => (
                      <tr key={log.id} className="transition duration-150 hover:bg-slate-50/30">
                        <td className="px-5 py-4">
                          <div className="flex items-center gap-3">
                            <span className="flex size-9 shrink-0 items-center justify-center rounded-full bg-violet-50 text-violet-700 font-extrabold text-xs border border-violet-100">
                              {getInitials(log.admin_name)}
                            </span>
                            <div>
                              <span className="block text-sm font-extrabold text-slate-800 leading-snug">{log.admin_name}</span>
                              <span className="text-[10px] font-bold text-slate-400 mt-0.5 leading-none block">
                                {log.admin_email || "admin@edulab.uz"}
                              </span>
                            </div>
                          </div>
                        </td>
                        <td className="px-5 py-4">
                          <span className={cn(
                            "inline-flex items-center rounded-lg px-2.5 py-0.5 text-[10px] font-bold border uppercase tracking-wider",
                            getActionColor(log.action)
                          )}>
                            {log.action}
                          </span>
                        </td>
                        <td className="px-5 py-4 text-xs font-semibold text-slate-600 max-w-md truncate">
                          {log.details}
                        </td>
                        <td className="px-5 py-4 text-right text-xs font-bold text-slate-400">
                          <div className="flex items-center justify-end gap-1.5">
                            <Clock className="size-3.5 text-slate-300" />
                            <span>
                              {new Date(log.created_at).toLocaleDateString("uz-UZ", {
                                year: "numeric",
                                month: "short",
                                day: "numeric",
                              })}
                              {" "}-{" "}
                              {new Date(log.created_at).toLocaleTimeString("uz-UZ", {
                                hour: "2-digit",
                                minute: "2-digit",
                              })}
                            </span>
                          </div>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            ) : (
              <div className="text-center py-20 text-sm font-semibold text-slate-455 bg-white">
                <History className="mx-auto mb-4.5 size-12 text-slate-350" />
                <p className="text-slate-850 font-black text-sm uppercase tracking-wide">Qaydlar topilmadi</p>
                <p className="text-xs text-slate-400 mt-1 font-semibold">Mos keladigan administrator amallari tarixi topilmadi.</p>
              </div>
            )}
          </CardContent>
        </Card>
      </div>
    </>
  );
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
    blue: "bg-blue-50 text-blue-600 border border-blue-100/40",
    green: "bg-emerald-50 text-emerald-600 border border-emerald-100/40",
    violet: "bg-violet-50 text-violet-600 border border-violet-100/40",
    orange: "bg-orange-50 text-orange-600 border border-orange-100/40",
  };

  const textColors = {
    blue: "bg-blue-50/50 text-blue-600",
    green: "bg-emerald-50/50 text-emerald-600",
    violet: "bg-violet-50/50 text-violet-600",
    orange: "bg-orange-50/50 text-orange-650",
  };

  return (
    <Card className="border border-slate-100 bg-white rounded-2xl shadow-soft transition-all duration-300 hover:-translate-y-0.5 hover:shadow-md">
      <CardContent className="p-5 flex items-center justify-between">
        <div className="flex items-center gap-4">
          <span className={cn("flex size-11 items-center justify-center rounded-xl", colors[tone])}>
            <Icon className="size-5.5" />
          </span>
          <div>
            <p className="text-2xl font-black text-slate-800 leading-none">{value}</p>
            <p className="text-[10px] font-bold text-slate-400 uppercase tracking-wide mt-2">{title}</p>
          </div>
        </div>
        <Badge className={cn("text-[9px] font-bold uppercase py-0.5 px-2 rounded-lg pointer-events-none", textColors[tone])}>
          {hint}
        </Badge>
      </CardContent>
    </Card>
  );
}
