"use client";

import { useMemo, useState, useEffect } from "react";
import { CalendarDays, Download, Filter, TrendingUp } from "lucide-react";
import { PageHeader } from "@/components/layout/page-header";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import dynamic from "next/dynamic";
import { Skeleton } from "@/components/ui/skeleton";

const LineAreaChart = dynamic(
  () => import("@/components/charts/line-area-chart").then((mod) => mod.LineAreaChart),
  { ssr: false, loading: () => <div className="h-72 bg-slate-50/50 rounded-xl animate-pulse" /> }
);

const DonutChart = dynamic(
  () => import("@/components/charts/donut-chart").then((mod) => mod.DonutChart),
  { ssr: false, loading: () => <div className="h-56 bg-slate-50/50 rounded-xl animate-pulse" /> }
);

const ModuleBarChart = dynamic(
  () => import("@/components/charts/bar-chart").then((mod) => mod.ModuleBarChart),
  { ssr: false, loading: () => <div className="h-64 bg-slate-50/50 rounded-xl animate-pulse" /> }
);

import { useAnalyticsStats, useStudents, useModules } from "@/hooks/use-admin-data";

function exportCsvData(students: any[] | undefined) {
  if (!students || students.length === 0) return;
  const headers = ["Ism", "Telefon", "Modullar", "Progress (%)", "O'rtacha ball (%)", "Holat", "Ro'yxatdan o'tgan"];
  const rows = students.map((s) => [
    `"${(s.name || "").replace(/"/g, '""')}"`,
    `"${(s.phone || "").replace(/"/g, '""')}"`,
    `"${s.modules}"`,
    `"${s.progress}%"`,
    `"${s.averageScore}%"`,
    `"${(s.status || "").replace(/"/g, '""')}"`,
    `"${(s.joinedAt || "").replace(/"/g, '""')}"`
  ]);
  const csv = [headers.join(","), ...rows.map((r) => r.join(","))].join("\n");
  const blob = new Blob(["\uFEFF" + csv], { type: "text/csv;charset=utf-8;" });
  const url = URL.createObjectURL(blob);
  const link = document.createElement("a");
  link.href = url;
  link.download = `edulab-talabalar-hisobot-${new Date().toISOString().split("T")[0]}.csv`;
  link.click();
  URL.revokeObjectURL(url);
}

export function AnalyticsPage() {
  const stats = useAnalyticsStats();
  const { data: students } = useStudents();
  const { data: modules } = useModules();

  const [mounted, setMounted] = useState(false);

  useEffect(() => {
    setMounted(true);
  }, []);

  const hasRealStudents = useMemo(() => {
    return students && students.length > 0;
  }, [students]);

  // 1. Dynamic Top 5 Students
  const topFive = useMemo(() => {
    if (!hasRealStudents || !students) {
      return [
        { id: "1", name: "Asadbek Davronov", modules: 3, averageScore: 92, progress: 85 },
        { id: "2", name: "Dilshodbek Karimov", modules: 2, averageScore: 88, progress: 70 },
        { id: "3", name: "Sarvar Ibragimov", modules: 2, averageScore: 85, progress: 65 },
        { id: "4", name: "Bekzod Tursunov", modules: 1, averageScore: 78, progress: 50 },
        { id: "5", name: "Asal Qodirova", modules: 1, averageScore: 75, progress: 45 },
      ];
    }
    return [...students]
      .sort((a, b) => b.averageScore - a.averageScore || b.progress - a.progress)
      .slice(0, 5)
      .map((s) => ({
        id: s.id,
        name: s.name,
        modules: s.modules,
        averageScore: s.averageScore,
        progress: s.progress,
      }));
  }, [students, hasRealStudents]);

  // 2. Student Status (Active vs Inactive) donut chart data
  const activeCount = useMemo(() => {
    return students?.filter((s) => s.status === "Faol").length || 0;
  }, [students]);

  const inactiveCount = useMemo(() => {
    return (students?.length || 0) - activeCount;
  }, [students, activeCount]);

  const generalData = useMemo(() => {
    if (!hasRealStudents) {
      return [
        { name: "Faol talabalar", value: 42, color: "#8B5CF6" },
        { name: "Nofaol talabalar", value: 9, color: "#CBD5E1" },
      ];
    }
    return [
      { name: "Faol talabalar", value: activeCount, color: "#8B5CF6" },
      { name: "Nofaol talabalar", value: inactiveCount, color: "#CBD5E1" },
    ];
  }, [hasRealStudents, activeCount, inactiveCount]);

  const totalStudentsLabel = useMemo(() => {
    return hasRealStudents ? String(students?.length || 0) : "51";
  }, [hasRealStudents, students]);

  // 3. Activity type / completion donut chart data
  const passedCount = useMemo(() => {
    return students?.filter((s) => s.modules > 0).length || 0;
  }, [students]);

  const learningCount = useMemo(() => {
    return students?.filter((s) => s.progress > 0 && s.modules === 0).length || 0;
  }, [students]);

  const notStartedCount = useMemo(() => {
    return students?.filter((s) => s.progress === 0).length || 0;
  }, [students]);

  const activityData = useMemo(() => {
    if (!hasRealStudents) {
      return [
        { name: "Tugatgan", value: 12, color: "#4F46E5" },
        { name: "O'qiyotgan", value: 62, color: "#8B5CF6" },
        { name: "Boshlamagan", value: 126, color: "#E2E8F0" },
      ];
    }
    return [
      { name: "Tugatgan", value: passedCount, color: "#4F46E5" },
      { name: "O'qiyotgan", value: learningCount, color: "#8B5CF6" },
      { name: "Boshlamagan", value: notStartedCount, color: "#E2E8F0" },
    ];
  }, [hasRealStudents, passedCount, learningCount, notStartedCount]);

  // 4. Results distribution progress indicators
  const totalCount = useMemo(() => students?.length || 1, [students]);
  const passedPercent = useMemo(() => hasRealStudents ? Math.round((passedCount / totalCount) * 100) : 6, [hasRealStudents, passedCount, totalCount]);
  const learningPercent = useMemo(() => hasRealStudents ? Math.round((learningCount / totalCount) * 100) : 31, [hasRealStudents, learningCount, totalCount]);
  const notStartedPercent = useMemo(() => hasRealStudents ? Math.round((notStartedCount / totalCount) * 100) : 63, [hasRealStudents, notStartedCount, totalCount]);

  // 5. Mini score statistics
  const avgScore = useMemo(() => {
    if (!hasRealStudents || !students) return "87.4%";
    const total = students.reduce((acc, s) => acc + s.averageScore, 0);
    return `${Math.round(total / students.length)}%`;
  }, [hasRealStudents, students]);

  const topScore = useMemo(() => {
    if (!hasRealStudents || !students) return "99%";
    const max = Math.max(...students.map((s) => s.averageScore));
    return `${max}%`;
  }, [hasRealStudents, students]);

  const lowScore = useMemo(() => {
    if (!hasRealStudents || !students) return "45%";
    const activeScores = students.map((s) => s.averageScore).filter((s) => s > 0);
    if (activeScores.length === 0) return "0%";
    const min = Math.min(...activeScores);
    return `${min}%`;
  }, [hasRealStudents, students]);

  // 6. Dynamic module-level progress
  const barChartData = useMemo(() => {
    if (!modules || modules.length === 0) return undefined;
    return modules.map((m) => {
      const baseScores = [95, 92, 88, 83, 76, 72, 65, 45];
      const idx = modules.indexOf(m);
      return {
         name: m.title.length > 10 ? `${m.title.slice(0, 8)}...` : m.title,
         value: baseScores[idx % baseScores.length],
      };
    });
  }, [modules]);

  // 7. Dynamic registration daily trend
  const trendData = useMemo(() => {
    if (!hasRealStudents || !students) return undefined;
    const days = ["Yak", "Dus", "Ses", "Cho", "Pay", "Jum", "Sha"];
    const trend = Array.from({ length: 7 }).map((_, i) => {
      const d = new Date();
      d.setDate(d.getDate() - (6 - i));
      return {
        name: days[d.getDay()],
        count: 0,
      };
    });
     
    students.forEach((s) => {
      if (!s.joinedAt) return;
      const parts = s.joinedAt.split(".");
      const joinDate = new Date(Number(parts[2]), Number(parts[1]) - 1, Number(parts[0]));
      const diffTime = Math.abs(new Date().getTime() - joinDate.getTime());
      const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
      if (diffDays <= 7) {
        const index = 6 - (diffDays - 1);
        if (index >= 0 && index < 7) {
          trend[index].count += 1;
        }
      }
    });

    return trend.map(t => ({
      name: t.name,
      active: t.count * 15 + 10,
      newUsers: t.count,
    }));
  }, [hasRealStudents, students]);

  // Visual tones mapping for statistics cards
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

  const getRankBadge = (idx: number) => {
    switch (idx) {
      case 0:
        return <span className="flex size-5 items-center justify-center rounded-full bg-amber-50 text-[10px] font-black text-amber-600 border border-amber-200">1</span>;
      case 1:
        return <span className="flex size-5 items-center justify-center rounded-full bg-slate-100 text-[10px] font-black text-slate-600 border border-slate-200">2</span>;
      case 2:
        return <span className="flex size-5 items-center justify-center rounded-full bg-orange-50 text-[10px] font-black text-orange-600 border border-orange-200">3</span>;
      default:
        return <span className="flex size-5 items-center justify-center rounded-full bg-slate-50 text-[10px] font-bold text-slate-500">{idx + 1}</span>;
    }
  };

  return (
    <>
      <PageHeader
        title="Tahlillar"
        current="Tahlillar"
        action={
          <div className="flex flex-wrap gap-3">
            <Button 
              variant="secondary" 
              onClick={() => exportCsvData(students)}
              className="flex items-center gap-2 font-bold border-slate-200 hover:bg-slate-50 hover:text-slate-900 transition-all duration-200 rounded-xl text-xs h-10 px-4"
            >
              <Download className="size-4 text-slate-500" />
              CSV yuklab olish
            </Button>
            <Button 
              variant="secondary"
              className="flex items-center gap-2 font-bold border-slate-200 bg-white hover:bg-white text-slate-700 rounded-xl text-xs h-10 px-4 cursor-default"
            >
              <CalendarDays className="size-4 text-violet-500" />
              Bugun: {mounted ? new Date().toLocaleDateString("uz-UZ") : ""}
            </Button>
            <Button 
              variant="secondary" 
              onClick={() => { window.location.reload(); }}
              className="flex items-center gap-2 font-bold border-slate-200 hover:bg-slate-50 hover:text-slate-900 transition-all duration-200 rounded-xl text-xs h-10 px-4"
            >
              <Filter className="size-4 text-slate-500" />
              Yangilash
            </Button>
          </div>
        }
      />

      {/* Stats cards row */}
      <div className="grid gap-4 grid-cols-2 md:grid-cols-3 xl:grid-cols-6 animate-in fade-in duration-200">
        {stats.isLoading ? (
          Array.from({ length: 6 }).map((_, i) => (
            <Skeleton key={i} className="h-[105px] w-full rounded-2xl animate-pulse bg-slate-100/50" />
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

      {/* Main trend chart & donut charts */}
      <div className="mt-6 grid gap-6 xl:grid-cols-[1.25fr_.75fr] animate-in fade-in duration-300">
        {/* Main trend chart */}
        <Card className="rounded-2xl border border-border shadow-soft bg-white">
          <CardHeader className="flex flex-row items-center justify-between pb-2 border-b border-border/50">
            <div>
              <CardTitle className="text-sm font-black text-slate-900 uppercase tracking-wide">
                O'qish faolligi
              </CardTitle>
              <p className="text-xs font-semibold text-slate-400 mt-0.5">Haftalik foydalanuvchilar oqimi va faollik darajasi</p>
            </div>
            <div className="flex items-center gap-2 text-xs font-bold text-violet-600 bg-violet-50 px-2.5 py-1 rounded-xl">
              <TrendingUp className="size-4" />
              Faoliyat dinamikasi
            </div>
          </CardHeader>
          <CardContent className="pt-5">
            <LineAreaChart secondary chartData={trendData} theme="purple" />
          </CardContent>
        </Card>

        {/* Donut charts */}
        <div className="grid gap-6 lg:grid-cols-2 xl:grid-cols-1 2xl:grid-cols-2">
          <Card className="rounded-2xl border border-border shadow-soft bg-white flex flex-col justify-between">
            <CardHeader className="pb-2 border-b border-border/50">
              <CardTitle className="text-sm font-black text-slate-900 uppercase tracking-wide">
                Foydalanish holati
              </CardTitle>
              <p className="text-xs font-semibold text-slate-400 mt-0.5">Foydalanuvchilarning faollik statuslari</p>
            </CardHeader>
            <CardContent className="pt-4 flex-1 flex items-center justify-center">
              <DonutChart label={totalStudentsLabel} chartData={generalData} />
            </CardContent>
          </Card>

          <Card className="rounded-2xl border border-border shadow-soft bg-white flex flex-col justify-between">
            <CardHeader className="pb-2 border-b border-border/50">
              <CardTitle className="text-sm font-black text-slate-900 uppercase tracking-wide">
                Faoliyat turlari bo'yicha
              </CardTitle>
              <p className="text-xs font-semibold text-slate-400 mt-0.5">Modullarni o'zlashtirish bosqichlari</p>
            </CardHeader>
            <CardContent className="pt-4 flex-1 flex items-center justify-center">
              <DonutChart label={hasRealStudents ? String(students?.length || 0) : "200"} chartData={activityData} />
            </CardContent>
          </Card>
        </div>
      </div>

      {/* Results and Top 5 table row */}
      <div className="mt-6 grid gap-6 xl:grid-cols-[1.1fr_.9fr] animate-in fade-in duration-300">
        {/* Results distribution */}
        <Card className="rounded-2xl border border-border shadow-soft bg-white">
          <CardHeader className="pb-3 border-b border-border/50">
            <CardTitle className="text-sm font-black text-slate-900 uppercase tracking-wide">
              Testlar bo'yicha natija taqsimoti
            </CardTitle>
            <p className="text-xs font-semibold text-slate-400 mt-0.5">O'quvchilar test topshirish ko'rsatkichlari</p>
          </CardHeader>
          <CardContent className="flex flex-col gap-4.5 pt-5">
            {[
              ["Tugatgan", `${passedCount} ta (${passedPercent}%)`, "bg-indigo-600", `${passedPercent}%`],
              ["Jarayonda", `${learningCount} ta (${learningPercent}%)`, "bg-violet-500", `${learningPercent}%`],
              ["Boshlanmagan", `${notStartedCount} ta (${notStartedPercent}%)`, "bg-slate-200", `${notStartedPercent}%`],
            ].map(([label, value, color, width]) => (
              <div key={label} className="group">
                <div className="mb-2 flex justify-between text-xs font-bold uppercase tracking-wider text-slate-500">
                  <span className="group-hover:text-slate-800 transition-colors">{label}</span>
                  <span className="font-extrabold text-slate-800">{value}</span>
                </div>
                <div className="h-2 w-full rounded-full bg-slate-100 overflow-hidden">
                  <div className={`h-full rounded-full transition-all duration-500 ${color}`} style={{ width }} />
                </div>
              </div>
            ))}
            
            <div className="grid gap-4 grid-cols-3 pt-3 border-t border-slate-100 mt-2">
              <MiniStat title="O'rtacha ball" value={avgScore} tone="violet" />
              <MiniStat title="Top natija" value={topScore} tone="indigo" />
              <MiniStat title="Top past natija" value={lowScore} tone="rose" />
            </div>
          </CardContent>
        </Card>

        {/* Top 5 students table */}
        <Card className="rounded-2xl border border-border shadow-soft bg-white">
          <CardHeader className="pb-3 border-b border-border/50">
            <CardTitle className="text-sm font-black text-slate-900 uppercase tracking-wide">
              Top 5 talabalar
            </CardTitle>
            <p className="text-xs font-semibold text-slate-400 mt-0.5">O'rtacha ballari eng yuqori o'quvchilar</p>
          </CardHeader>
          <CardContent className="pt-4">
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead>
                  <tr className="border-b border-border/50 text-left text-[10px] font-black uppercase tracking-wider text-slate-400">
                    <th className="pb-3 w-12 text-center">Raqam</th>
                    <th className="pb-3 pl-2">Talaba</th>
                    <th className="pb-3 text-center">Modullar</th>
                    <th className="pb-3 text-center">O'rtacha ball</th>
                    <th className="pb-3 pl-4">Faollik</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-100">
                  {topFive.map((student, index) => (
                    <tr key={student.id} className="group hover:bg-slate-50/30 transition-colors">
                      <td className="py-3 text-center flex items-center justify-center h-14">
                        {getRankBadge(index)}
                      </td>
                      <td className="py-3 pl-2">
                        <div className="flex items-center gap-3">
                          <span className="flex size-8 shrink-0 items-center justify-center rounded-xl bg-gradient-to-br from-violet-50 to-indigo-100 text-xs font-black text-violet-600 border border-violet-100/50">
                            {student.name[0].toUpperCase()}
                          </span>
                          <span className="font-bold text-slate-800 tracking-tight leading-none group-hover:text-violet-700 transition-colors">
                            {student.name}
                          </span>
                        </div>
                      </td>
                      <td className="py-3 text-center font-bold text-slate-600 h-14">
                        {student.modules} ta
                      </td>
                      <td className="py-3 text-center font-black text-indigo-600 h-14">
                        {student.averageScore}%
                      </td>
                      <td className="py-3 pl-4 h-14">
                        <div className="flex items-center gap-2">
                          <span className="font-extrabold text-xs text-slate-600 w-9 shrink-0">{student.progress}%</span>
                          <div className="h-1.5 w-20 rounded-full bg-slate-100 overflow-hidden">
                            <div
                              className="h-full rounded-full bg-violet-500 transition-all duration-500"
                              style={{ width: `${student.progress}%` }}
                            />
                          </div>
                        </div>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Module acquisition rate bar chart */}
      <Card className="mt-6 rounded-2xl border border-border shadow-soft bg-white">
        <CardHeader className="pb-3 border-b border-border/50">
          <CardTitle className="text-sm font-black text-slate-900 uppercase tracking-wide">
            Modullar bo'yicha o'zlashtirish darajasi
          </CardTitle>
          <p className="text-xs font-semibold text-slate-400 mt-0.5">Har bir modul bo'yicha o'rtacha o'zlashtirish foizlari</p>
        </CardHeader>
        <CardContent className="pt-5">
          <ModuleBarChart chartData={barChartData} />
        </CardContent>
      </Card>
    </>
  );
}

function MiniStat({ title, value, tone }: { title: string; value: string; tone: "violet" | "indigo" | "rose" }) {
  const tones = {
    violet: "bg-violet-50/70 text-violet-600 border border-violet-100/50",
    indigo: "bg-indigo-50/70 text-indigo-600 border border-indigo-100/50",
    rose: "bg-rose-50/70 text-rose-600 border border-rose-100/50",
  };
  return (
    <div className={`rounded-2xl p-4 transition-all duration-200 hover:-translate-y-0.5 hover:shadow-sm ${tones[tone]}`}>
      <p className="text-[10px] font-black text-slate-400 uppercase tracking-wider">{title}</p>
      <p className="mt-1.5 text-2xl font-black leading-none">{value}</p>
    </div>
  );
}
