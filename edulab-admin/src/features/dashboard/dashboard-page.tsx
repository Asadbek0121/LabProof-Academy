"use client";

import { useState, useEffect } from "react";
import { 
  Activity, 
  Bot, 
  CalendarDays, 
  History, 
  MessageSquare, 
  TrendingUp, 
  Users, 
  ChevronRight,
  HelpCircle,
  Sparkles,
  TrendingDown,
  UserCheck
} from "lucide-react";
import Link from "next/link";
import { PageHeader } from "@/components/layout/page-header";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import dynamic from "next/dynamic";

const LineAreaChart = dynamic(
  () => import("@/components/charts/line-area-chart").then((mod) => mod.LineAreaChart),
  { ssr: false, loading: () => <div className="h-72 bg-slate-50/50 rounded-xl animate-pulse" /> }
);

import { useAnalyticsStats, useConversations } from "@/hooks/use-admin-data";
import { createClient } from "@/lib/supabase/client";
import { useQuery } from "@tanstack/react-query";
import { Skeleton } from "@/components/ui/skeleton";

export function DashboardPage() {
  const stats = useAnalyticsStats();
  const conversations = useConversations();
  const supabase = createClient();

  const [mounted, setMounted] = useState(false);
  useEffect(() => {
    setMounted(true);
  }, []);

  // Activity logs fetch
  const { data: logs, isLoading: isLogsLoading } = useQuery({
    queryKey: ["dashboard-activity-logs"],
    queryFn: async () => {
      const { data, error } = await supabase
        .from("activity_logs")
        .select("*")
        .order("created_at", { ascending: false })
        .limit(5);
      if (error) return [];
      return data || [];
    },
  });

  const recentSupport = conversations.data?.slice(0, 3) || [];

  // Telegram bot verifications query
  const { data: verifications } = useQuery({
    queryKey: ["telegram-verifications-summary"],
    queryFn: async () => {
      const { data, error } = await supabase
        .from("telegram_verifications")
        .select("confirmed");
      if (error) return [];
      return data || [];
    },
  });

  const pendingVerificationsCount = verifications?.filter((v) => !v.confirmed).length || 0;
  const confirmedVerificationsCount = verifications?.filter((v) => v.confirmed).length || 0;

  // Visual tones mapping for dashboard statistics cards
  const getIconColorClasses = (tone: string) => {
    switch (tone) {
      case "blue":
        return "bg-indigo-50 text-indigo-600";
      case "green":
        return "bg-emerald-50 text-emerald-600";
      case "violet":
        return "bg-violet-50 text-violet-600";
      case "orange":
        return "bg-amber-50 text-amber-600";
      case "red":
        return "bg-rose-50 text-rose-600";
      default:
        return "bg-slate-50 text-slate-600";
    }
  };

  return (
    <>
      {/* Page Header */}
      <PageHeader
        title="Dashboard"
        current="Boshqaruv paneli"
        action={
          <Button variant="secondary" className="flex gap-2 font-bold border-slate-200">
            <CalendarDays className="size-4" />
            Bugun: {mounted ? new Date().toLocaleDateString("uz-UZ") : ""}
          </Button>
        }
      />

      {/* Stats row with premium medical/enterprise theme */}
      <div className="grid gap-4 grid-cols-2 md:grid-cols-3 xl:grid-cols-6 animate-in fade-in duration-200">
        {stats.isLoading ? (
          Array.from({ length: 6 }).map((_, i) => (
            <Skeleton key={i} className="h-[105px] w-full rounded-2xl" />
          ))
        ) : (
          stats.data?.map((item) => {
            const Icon = item.icon;
            const bgAndColor = getIconColorClasses(item.tone);
            return (
              <Card 
                key={item.title} 
                className="p-4.5 transition-all duration-300 hover:-translate-y-0.5 hover:shadow-soft bg-white border border-border rounded-2xl flex items-center gap-4.5"
              >
                <span className={`flex size-12 shrink-0 items-center justify-center rounded-xl ${bgAndColor}`}>
                  <Icon className="size-6" />
                </span>
                <div className="min-w-0">
                  <p className="text-[10px] font-bold text-slate-400 uppercase tracking-wider truncate">
                    {item.title}
                  </p>
                  <p className="text-2xl font-black text-slate-900 mt-0.5 leading-none">
                    {item.value}
                  </p>
                  <p className="text-[9px] font-semibold text-slate-400 mt-1 truncate">
                    {item.hint}
                  </p>
                </div>
              </Card>
            );
          })
        )}
      </div>

      {/* Main Charts & Support Queue grid */}
      <div className="mt-6 grid gap-6 xl:grid-cols-[1.25fr_.75fr] animate-in fade-in duration-300">
        {/* Activity chart card */}
        <Card className="rounded-2xl border border-border shadow-soft bg-white">
          <CardHeader className="flex flex-row items-center justify-between pb-2 border-b border-border/50">
            <div>
              <CardTitle className="text-sm font-black text-slate-900 uppercase tracking-wide flex items-center gap-2">
                Tizim Faolligi
                <HelpCircle className="size-4 text-slate-400 hover:text-slate-600 cursor-pointer" />
              </CardTitle>
              <p className="text-xs font-semibold text-slate-400 mt-0.5">O'quvchilar va bot bilan ishlash dinamikasi</p>
            </div>
            <div className="flex items-center gap-2 text-xs font-bold text-emerald-600 bg-emerald-50 px-2.5 py-1 rounded-xl">
              <TrendingUp className="size-4" />
              +14.2% faol
            </div>
          </CardHeader>
          <CardContent className="pt-5">
            <LineAreaChart />
          </CardContent>
        </Card>

        {/* Live Support Requests queue */}
        <Card className="rounded-2xl border border-border shadow-soft bg-white flex flex-col">
          <CardHeader className="flex flex-row items-center justify-between pb-3 border-b border-border/50">
            <div>
              <CardTitle className="text-sm font-black text-slate-900 uppercase tracking-wide">
                Yordam So'rovlari
              </CardTitle>
              <p className="text-xs font-semibold text-slate-400 mt-0.5">Talabalardan kelgan so'nggi xabarlar</p>
            </div>
            <Link href="/support-requests">
              <Button variant="ghost" size="sm" className="font-bold text-blue-600 hover:bg-blue-50 px-3 h-8 text-xs">
                Barchasi
              </Button>
            </Link>
          </CardHeader>
          <CardContent className="flex flex-col gap-3.5 pt-4 flex-1 overflow-y-auto">
            {recentSupport.length > 0 ? (
              recentSupport.map((chat) => (
                <div
                  key={chat.id}
                  className="flex items-center justify-between rounded-xl border border-border p-3.5 transition hover:border-slate-300 hover:bg-slate-50/50"
                >
                  <div className="flex items-center gap-3.5 min-w-0">
                    <span className="flex size-9.5 shrink-0 items-center justify-center rounded-xl bg-violet-50 text-sm font-black text-violet-600">
                      {chat.name[0].toUpperCase()}
                    </span>
                    <div className="min-w-0">
                      <p className="text-xs font-extrabold text-slate-800 truncate">{chat.name}</p>
                      <p className="text-[11px] font-semibold text-slate-400 truncate max-w-[160px] sm:max-w-[200px] mt-0.5">
                        {chat.lastMessage}
                      </p>
                    </div>
                  </div>
                  <div className="flex flex-col items-end gap-1.5 shrink-0">
                    <span className="text-[10px] font-bold text-slate-400">{chat.time}</span>
                    {chat.unread > 0 ? (
                      <span className="flex size-4.5 items-center justify-center rounded-full bg-blue-600 text-[8px] font-black text-white">
                        {chat.unread}
                      </span>
                    ) : (
                      <span className="flex size-2 rounded-full bg-emerald-500" title="Online" />
                    )}
                  </div>
                </div>
              ))
            ) : (
              <div className="py-12 text-center text-xs font-semibold text-slate-400 flex flex-col items-center justify-center gap-2">
                <MessageSquare className="size-8 text-slate-300" />
                Hozircha yordam so'rovlari yo'q
              </div>
            )}
          </CardContent>
        </Card>
      </div>

      {/* Bottom widgets grid: Activity Logs & Telegram Bot Monitor */}
      <div className="mt-6 grid gap-6 md:grid-cols-2 animate-in fade-in duration-300">
        {/* Activity Logs card */}
        <Card className="rounded-2xl border border-border shadow-soft bg-white">
          <CardHeader className="flex flex-row items-center justify-between pb-3 border-b border-border/50">
            <div>
              <CardTitle className="text-sm font-black text-slate-900 uppercase tracking-wide">
                Oxirgi Tizim Loglari
              </CardTitle>
              <p className="text-xs font-semibold text-slate-400 mt-0.5">Tizimda bajarilgan oxirgi amallar</p>
            </div>
            <Link href="/activity-logs">
              <Button variant="ghost" size="sm" className="font-bold text-blue-600 hover:bg-blue-50 px-3 h-8 text-xs">
                Barchasi
              </Button>
            </Link>
          </CardHeader>
          <CardContent className="flex flex-col gap-4 pt-4">
            {isLogsLoading ? (
              Array.from({ length: 4 }).map((_, i) => (
                <Skeleton key={i} className="h-12 w-full rounded-xl" />
              ))
            ) : logs && logs.length > 0 ? (
              logs.map((log) => {
                // Classify action types visually
                const isCreate = (log.action || "").toLowerCase().includes("qo'sh") || (log.action || "").toLowerCase().includes("yarat") || (log.action || "").toLowerCase().includes("create");
                const isDelete = (log.action || "").toLowerCase().includes("o'chir") || (log.action || "").toLowerCase().includes("delete");
                
                const actionBadgeClass = isCreate 
                  ? "bg-emerald-50 text-emerald-600 border border-emerald-100" 
                  : isDelete 
                    ? "bg-rose-50 text-rose-600 border border-rose-100" 
                    : "bg-amber-50 text-amber-600 border border-amber-100";

                return (
                  <div key={log.id} className="flex items-start gap-3.5 pb-3.5 border-b border-slate-100 last:border-0 last:pb-0">
                    <span className={`text-[9px] font-black uppercase tracking-wider py-0.5 px-2 rounded-lg shrink-0 mt-0.5 ${actionBadgeClass}`}>
                      {isCreate ? "CREATE" : isDelete ? "DELETE" : "UPDATE"}
                    </span>
                    <div className="flex-1 min-w-0 text-xs">
                      <p className="font-bold text-slate-800 leading-snug">
                        {log.admin_name} <span className="font-semibold text-slate-500">{log.action}</span>
                      </p>
                      <p className="text-[11px] font-semibold text-slate-400 mt-0.5 leading-snug truncate">
                        {log.details}
                      </p>
                    </div>
                    <span className="text-[10px] font-bold text-slate-400 shrink-0">
                      {new Date(log.created_at).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })}
                    </span>
                  </div>
                );
              })
            ) : (
              <div className="py-12 text-center text-xs font-semibold text-slate-400 flex flex-col items-center justify-center gap-2">
                <History className="size-8 text-slate-300" />
                Hozircha tizim amallari qayd etilmagan
              </div>
            )}
          </CardContent>
        </Card>

        {/* Telegram bot status card */}
        <Card className="rounded-2xl border border-border shadow-soft bg-white flex flex-col">
          <CardHeader className="border-b border-border/50 pb-3">
            <CardTitle className="text-sm font-black text-slate-900 uppercase tracking-wide">
              Telegram Bot Monitoring
            </CardTitle>
            <p className="text-xs font-semibold text-slate-400 mt-0.5">Bot holati va verifikatsiyalar</p>
          </CardHeader>
          <CardContent className="flex flex-col gap-5 pt-4 flex-1">
            <div className="flex items-center justify-between rounded-2xl border border-border p-4 bg-slate-50/50">
              <div className="flex items-center gap-3">
                <span className="flex size-11 items-center justify-center rounded-xl bg-emerald-50 text-emerald-600 shrink-0">
                  <Bot className="size-5.5 animate-pulse" />
                </span>
                <div>
                  <p className="text-xs font-extrabold text-slate-800">EduLab Academy Bot</p>
                  <p className="text-[10px] font-bold text-slate-400 mt-0.5">Webhook Active (0.0.0.0)</p>
                </div>
              </div>
              
              {/* Pulsating status dot */}
              <span className="relative flex h-3.5 w-3.5">
                <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75"></span>
                <span className="relative inline-flex rounded-full h-3.5 w-3.5 bg-emerald-500"></span>
              </span>
            </div>

            <div className="grid grid-cols-2 gap-4">
              <div className="rounded-2xl bg-blue-50/20 border border-blue-100/60 p-4">
                <p className="text-[10px] font-black text-blue-600 uppercase tracking-wide">Verification Requests</p>
                <p className="mt-1 text-2xl font-black text-blue-950">{pendingVerificationsCount} ta</p>
              </div>
              <div className="rounded-2xl bg-violet-50/20 border border-violet-100/60 p-4">
                <p className="text-[10px] font-black text-violet-600 uppercase tracking-wide">Confirmed Members</p>
                <p className="mt-1 text-2xl font-black text-violet-950">{confirmedVerificationsCount} ta</p>
              </div>
            </div>

            <div className="flex justify-end gap-3 mt-auto pt-4">
              <Link href="/bot-management" className="w-full">
                <Button className="w-full font-bold h-10 bg-blue-600 text-white hover:bg-blue-700 flex gap-2">
                  <UserCheck className="size-4" />
                  Bot sozlamalariga o'tish
                </Button>
              </Link>
            </div>
          </CardContent>
        </Card>
      </div>
    </>
  );
}
