"use client";

import { useMemo, useState } from "react";
import {
  Award,
  BarChart3,
  BookOpen,
  Box,
  CalendarDays,
  CheckSquare,
  ChevronDown,
  Filter,
  Trophy,
  Users,
} from "lucide-react";
import {
  Bar,
  BarChart,
  CartesianGrid,
  Cell,
  Line,
  LineChart,
  Pie,
  PieChart,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts";
import { PageHeader } from "@/components/layout/page-header";
import { Button } from "@/components/ui/button";
import { Skeleton } from "@/components/ui/skeleton";
import { useAdminOverviewData } from "@/hooks/use-admin-data";
import { cn } from "@/lib/utils";

type Tone = "blue" | "green" | "violet" | "amber" | "rose";

const toneClasses: Record<
  Tone,
  {
    icon: string;
    text: string;
    bar: string;
    color: string;
  }
> = {
  blue: {
    icon: "bg-blue-50 text-blue-600 dark:bg-blue-500/12 dark:text-blue-300",
    text: "text-blue-600 dark:text-blue-300",
    bar: "bg-blue-600",
    color: "#315BFF",
  },
  green: {
    icon: "bg-emerald-50 text-emerald-600 dark:bg-emerald-500/12 dark:text-emerald-300",
    text: "text-emerald-600 dark:text-emerald-300",
    bar: "bg-emerald-500",
    color: "#22C55E",
  },
  violet: {
    icon: "bg-violet-50 text-violet-600 dark:bg-violet-500/12 dark:text-violet-300",
    text: "text-violet-600 dark:text-violet-300",
    bar: "bg-violet-500",
    color: "#8B5CF6",
  },
  amber: {
    icon: "bg-amber-50 text-amber-600 dark:bg-amber-500/12 dark:text-amber-300",
    text: "text-amber-600 dark:text-amber-300",
    bar: "bg-amber-500",
    color: "#F59E0B",
  },
  rose: {
    icon: "bg-rose-50 text-rose-600 dark:bg-rose-500/12 dark:text-rose-300",
    text: "text-rose-600 dark:text-rose-300",
    bar: "bg-rose-500",
    color: "#FF4D5E",
  },
};

const dateRangeOptions = [
  "01.05.2024 - 31.05.2024",
  "01.06.2024 - 30.06.2024",
  "So'nggi 7 kun",
  "So'nggi 30 kun",
] as const;
const scoreFilterOptions = ["Barchasi", "Faollar", "Yuqori ball", "Past progress"] as const;
const activityPeriodOptions = ["Kunlik", "Haftalik", "Oylik"] as const;
const topPeriodOptions = ["Barcha vaqt", "Bu oy", "Bu hafta"] as const;
const moduleFilterOptions = ["Barcha modullar", "Eng yuqori", "Past natijalar"] as const;

export function AnalyticsPage() {
  const overview = useAdminOverviewData();
  const [dateRange, setDateRange] = useState<(typeof dateRangeOptions)[number]>("01.05.2024 - 31.05.2024");
  const [scoreFilter, setScoreFilter] = useState<(typeof scoreFilterOptions)[number]>("Barchasi");
  const [activityPeriod, setActivityPeriod] = useState<(typeof activityPeriodOptions)[number]>("Kunlik");
  const [topPeriod, setTopPeriod] = useState<(typeof topPeriodOptions)[number]>("Barcha vaqt");
  const [moduleFilter, setModuleFilter] = useState<(typeof moduleFilterOptions)[number]>("Barcha modullar");
  const [openMenu, setOpenMenu] = useState<"date" | "filter" | "activity" | "top" | "module" | null>(null);

  const toggleMenu = (menu: typeof openMenu) => {
    setOpenMenu((current) => (current === menu ? null : menu));
  };

  const statCards = useMemo(() => {
    const totals = overview.data?.totals;
    const metricByTitle = (title: string) => overview.data?.metrics.find((item) => item.title === title);
    return [
      {
        title: "Jami talabalar",
        value: String(totals?.students ?? 0),
        change: metricByTitle("Jami talabalar")?.delta ?? "0%",
        note: "Supabase real data",
        tone: "blue" as Tone,
        icon: Users,
      },
      {
        title: "Faol foydalanuvchilar",
        value: String(totals?.online ?? 0),
        change: metricByTitle("Faol foydalanuvchilar")?.delta ?? "0%",
        note: "oxirgi 15 daqiqa",
        tone: "green" as Tone,
        icon: BarChart3,
      },
      {
        title: "Modullar soni",
        value: String(totals?.modules ?? 0),
        change: metricByTitle("Modullar soni")?.delta ?? "0%",
        note: "real modullar",
        tone: "violet" as Tone,
        icon: Box,
      },
      {
        title: "Mavzular soni",
        value: String(totals?.topics ?? 0),
        change: "0%",
        note: "real mavzular",
        tone: "amber" as Tone,
        icon: BookOpen,
      },
      {
        title: "Testlar soni",
        value: String(totals?.questions ?? 0),
        change: metricByTitle("Testlar soni")?.delta ?? "0%",
        note: "real savollar",
        tone: "rose" as Tone,
        icon: CheckSquare,
      },
      {
        title: "Yakunlangan sertifikatlar",
        value: String(totals?.certificates ?? 0),
        change: metricByTitle("Sertifikatlar")?.delta ?? "0%",
        note: "real sertifikatlar",
        tone: "blue" as Tone,
        icon: Trophy,
      },
    ];
  }, [overview.data?.metrics, overview.data?.totals]);

  const topStudents = useMemo(() => {
    const source = overview.data?.topStudents ?? [];

    const filtered = source.filter((student) => {
      if (scoreFilter === "Faollar") return student.progress >= 60;
      if (scoreFilter === "Yuqori ball") return student.averageScore >= 88;
      if (scoreFilter === "Past progress") return student.progress < 70;
      return true;
    });

    return [...(filtered.length ? filtered : source)]
      .sort((a, b) => {
        if (scoreFilter === "Past progress") return a.progress - b.progress || b.averageScore - a.averageScore;
        if (topPeriod === "Bu hafta") return b.progress - a.progress || b.averageScore - a.averageScore;
        return b.averageScore - a.averageScore || b.progress - a.progress;
      })
      .slice(0, topPeriod === "Bu hafta" ? 3 : 5)
      .map((student) => ({
        id: student.id,
        name: student.name,
        modules: student.modules,
        averageScore: student.averageScore,
        progress: student.progress,
      }));
  }, [overview.data?.topStudents, scoreFilter, topPeriod]);

  const totalStudents = overview.data?.totals.students ?? 0;
  const moduleChartData = useMemo(() => {
    const source = (overview.data?.modulePerformance ?? []).map((module) => ({
      name: module.name?.length > 18 ? `${module.name.slice(0, 16)}...` : module.name,
      value: module.percent,
    }));

    if (moduleFilter === "Eng yuqori") return [...source].sort((a, b) => b.value - a.value).slice(0, 6);
    if (moduleFilter === "Past natijalar") return [...source].sort((a, b) => a.value - b.value).slice(0, 6);
    return source.slice(0, 10);
  }, [moduleFilter, overview.data?.modulePerformance]);

  const activityDisplayData = useMemo(() => {
    const multiplier = activityPeriod === "Haftalik" ? 0.72 : activityPeriod === "Oylik" ? 1.15 : 1;
    const source = overview.data?.activityTrend ?? [];
    const rangeData = dateRange === "So'nggi 7 kun" ? source.slice(-7) : source;
    return rangeData.map((item) => ({
      ...item,
      active: Math.round(item.active * multiplier),
      newUsers: Math.round(item.newUsers * multiplier),
    }));
  }, [activityPeriod, dateRange, overview.data?.activityTrend]);

  const activityTypeRows = useMemo(() => {
    const activity = overview.data?.activityTypes ?? { video: 0, tests: 0, pdf: 0, lessons: 0 };
    const total = Math.max(1, activity.video + activity.tests + activity.pdf + activity.lessons);
    return [
      { name: "Video ko'rish", value: Math.round((activity.video / total) * 100), color: "#315BFF" },
      { name: "Test yechish", value: Math.round((activity.tests / total) * 100), color: "#22C55E" },
      { name: "PDF o'qish", value: Math.round((activity.pdf / total) * 100), color: "#F59E0B" },
      { name: "Mavzu o'qish", value: Math.round((activity.lessons / total) * 100), color: "#8B5CF6" },
    ];
  }, [overview.data?.activityTypes]);

  const completionRows = useMemo(() => {
    const completion = overview.data?.completion ?? { completed: 0, inProgress: 0, notStarted: 0 };
    const total = Math.max(1, completion.completed + completion.inProgress + completion.notStarted);
    return [
      { name: "Jami modullar", value: overview.data?.totals.modules ?? 0, color: "#315BFF" },
      { name: "Yakunlangan", value: completion.completed, percent: Math.round((completion.completed / total) * 100), color: "#22C55E" },
      { name: "Jarayonda", value: completion.inProgress, percent: Math.round((completion.inProgress / total) * 100), color: "#F59E0B" },
      { name: "Boshlanmagan", value: completion.notStarted, percent: Math.round((completion.notStarted / total) * 100), color: "#FF4D5E" },
    ];
  }, [overview.data?.completion, overview.data?.totals.modules]);

  const testRows = useMemo(() => {
    const test = overview.data?.testDistribution ?? { passed: 0, inProgress: 0, notStarted: 0 };
    const total = Math.max(1, test.passed + test.inProgress + test.notStarted);
    return [
      { label: "O'tgan", value: `${test.passed} (${Math.round((test.passed / total) * 100)}%)`, width: Math.round((test.passed / total) * 100), tone: "blue" as Tone },
      { label: "Jarayonda", value: `${test.inProgress} (${Math.round((test.inProgress / total) * 100)}%)`, width: Math.round((test.inProgress / total) * 100), tone: "green" as Tone },
      { label: "Boshlanmagan", value: `${test.notStarted} (${Math.round((test.notStarted / total) * 100)}%)`, width: Math.round((test.notStarted / total) * 100), tone: "rose" as Tone },
    ];
  }, [overview.data?.testDistribution]);

  const bestStudent = topStudents[0];
  const lowestStudent = [...topStudents].sort((a, b) => a.progress - b.progress)[0];

  return (
    <>
      <PageHeader
        title="Tahlillar"
        current="Tahlillar"
        action={
          <div className="flex flex-wrap items-center gap-3">
            <div className="relative">
              <Button
                type="button"
                variant="secondary"
                className="h-10 rounded-xl px-4 text-xs font-black"
                onClick={() => toggleMenu("date")}
              >
                <CalendarDays className="size-4" />
                {dateRange}
                <ChevronDown className="size-3.5" />
              </Button>
              {openMenu === "date" && (
                <DropdownMenu
                  options={dateRangeOptions}
                  value={dateRange}
                  onChange={(value) => {
                    setDateRange(value);
                    setOpenMenu(null);
                  }}
                  className="w-56"
                />
              )}
            </div>
            <div className="relative">
              <Button
                type="button"
                variant="secondary"
                className="h-10 rounded-xl px-4 text-xs font-black"
                onClick={() => toggleMenu("filter")}
              >
                <Filter className="size-4" />
                {scoreFilter === "Barchasi" ? "Filtr" : scoreFilter}
                <ChevronDown className="size-3.5" />
              </Button>
              {openMenu === "filter" && (
                <DropdownMenu
                  options={scoreFilterOptions}
                  value={scoreFilter}
                  onChange={(value) => {
                    setScoreFilter(value);
                    setOpenMenu(null);
                  }}
                  className="w-44"
                />
              )}
            </div>
          </div>
        }
      />

      <div className="analytics-surface -mx-1 -mt-1 space-y-3.5 pb-4">
        <div className="grid grid-cols-2 gap-3 md:grid-cols-3 xl:grid-cols-6">
          {overview.isLoading
            ? Array.from({ length: 6 }).map((_, index) => (
                <Skeleton key={index} className="h-[112px] rounded-xl" />
              ))
            : statCards.map((card) => <StatCard key={card.title} {...card} />)}
        </div>

        <div className="grid gap-3.5 xl:grid-cols-[1.45fr_0.7fr_0.7fr]">
          <Panel className="min-h-[318px]">
            <div className="mb-4 flex items-start justify-between">
              <h3 className="analytics-title">O'qish faolligi</h3>
              <div className="relative">
                <button
                  type="button"
                  className="rounded-xl border border-slate-200 bg-white px-4 py-2 text-xs font-black text-slate-700 shadow-sm transition hover:border-blue-200 hover:text-blue-600 dark:border-slate-800 dark:bg-slate-950 dark:text-slate-300 dark:hover:border-blue-500/40 dark:hover:text-blue-300"
                  onClick={() => toggleMenu("activity")}
                >
                  {activityPeriod}
                  <ChevronDown className="ml-2 inline size-3.5" />
                </button>
                {openMenu === "activity" && (
                  <DropdownMenu
                    options={activityPeriodOptions}
                    value={activityPeriod}
                    onChange={(value) => {
                      setActivityPeriod(value);
                      setOpenMenu(null);
                    }}
                    className="w-36"
                  />
                )}
              </div>
            </div>
            <div className="mb-3 flex gap-7 text-xs font-black text-slate-600 dark:text-slate-300">
              <span className="flex items-center gap-2">
                <span className="size-2.5 rounded-full bg-blue-600" />
                Faol foydalanuvchilar
              </span>
              <span className="flex items-center gap-2">
                <span className="size-2.5 rounded-full bg-emerald-500" />
                Yangi foydalanuvchilar
              </span>
            </div>
            <div className="h-[232px]">
              <ResponsiveContainer width="100%" height="100%">
                <LineChart data={activityDisplayData} margin={{ left: 0, right: 10, top: 12, bottom: 2 }}>
                  <CartesianGrid stroke="#E6ECF5" vertical={false} />
                  <XAxis dataKey="name" axisLine={false} tickLine={false} tick={{ fill: "#64748B", fontSize: 11 }} />
                  <YAxis axisLine={false} tickLine={false} tick={{ fill: "#64748B", fontSize: 11 }} width={42} />
                  <Tooltip content={<ChartTooltip />} />
                  <Line type="monotone" dataKey="active" stroke="#315BFF" strokeWidth={3} dot={false} activeDot={{ r: 5 }} />
                  <Line type="monotone" dataKey="newUsers" stroke="#22C55E" strokeWidth={3} dot={false} activeDot={{ r: 5 }} />
                </LineChart>
              </ResponsiveContainer>
            </div>
          </Panel>

          <Panel>
            <h3 className="analytics-title">Umumiy statistika</h3>
            <div className="mt-4 grid grid-cols-[150px_1fr] items-center gap-5">
              <DonutCenter
                data={completionRows}
                label="Jami talabalar"
                value={totalStudents.toLocaleString("uz-UZ")}
              />
              <div className="space-y-4 text-xs font-bold">
                <Legend color="bg-blue-600" label="Jami modullar" value={String(completionRows[0]?.value ?? 0)} />
                <Legend color="bg-emerald-500" label="Yakunlangan" value={`${completionRows[1]?.value ?? 0} (${completionRows[1]?.percent ?? 0}%)`} />
                <Legend color="bg-amber-500" label="Jarayonda" value={`${completionRows[2]?.value ?? 0} (${completionRows[2]?.percent ?? 0}%)`} />
                <Legend color="bg-rose-500" label="Boshlanmagan" value={`${completionRows[3]?.value ?? 0} (${completionRows[3]?.percent ?? 0}%)`} />
              </div>
            </div>
          </Panel>

          <Panel>
            <h3 className="analytics-title">Faoliyat turlari bo'yicha</h3>
            <div className="mt-4 grid grid-cols-[150px_1fr] items-center gap-5">
              <div className="h-[162px]">
                <ResponsiveContainer width="100%" height="100%">
                  <PieChart>
                    <Pie data={activityTypeRows} dataKey="value" innerRadius={48} outerRadius={70} paddingAngle={3} stroke="none">
                      {activityTypeRows.map((item) => (
                        <Cell key={item.name} fill={item.color} />
                      ))}
                    </Pie>
                  </PieChart>
                </ResponsiveContainer>
              </div>
              <div className="space-y-4 text-xs font-bold">
                {activityTypeRows.map((item) => (
                  <Legend
                    key={item.name}
                    color=""
                    customColor={item.color}
                    label={item.name}
                    value={`${item.value}%`}
                  />
                ))}
              </div>
            </div>
          </Panel>
        </div>

        <div className="grid gap-3.5 xl:grid-cols-[1fr_0.98fr]">
          <Panel>
            <h3 className="analytics-title">Testlar bo'yicha natija taqsimoti</h3>
            <div className="mt-5 space-y-4">
              {testRows.map((row) => (
                <ProgressRow key={row.label} label={row.label} value={row.value} width={row.width} tone={row.tone} />
              ))}
            </div>
            <div className="mt-5 grid grid-cols-3 gap-5">
              <ScoreCard title="O'rtacha ball" value={`${overview.data?.totals.averageScore ?? 0}%`} detail="Quiz progress bo'yicha" tone="green" />
              <ScoreCard title="Top natija" value={`${bestStudent?.averageScore ?? 0}%`} detail={bestStudent?.name ?? "Ma'lumot yo'q"} tone="blue" />
              <ScoreCard title="Eng past progress" value={`${lowestStudent?.progress ?? 0}%`} detail={lowestStudent?.name ?? "Ma'lumot yo'q"} tone="rose" />
            </div>
          </Panel>

          <Panel>
            <div className="mb-3 flex items-center justify-between">
              <h3 className="analytics-title">Top 5 talabalar</h3>
              <div className="relative">
                <button
                  type="button"
                  className="rounded-xl border border-slate-200 bg-white px-4 py-2 text-xs font-black text-slate-700 shadow-sm transition hover:border-blue-200 hover:text-blue-600 dark:border-slate-800 dark:bg-slate-950 dark:text-slate-300 dark:hover:border-blue-500/40 dark:hover:text-blue-300"
                  onClick={() => toggleMenu("top")}
                >
                  {topPeriod}
                  <ChevronDown className="ml-2 inline size-3.5" />
                </button>
                {openMenu === "top" && (
                  <DropdownMenu
                    options={topPeriodOptions}
                    value={topPeriod}
                    onChange={(value) => {
                      setTopPeriod(value);
                      setOpenMenu(null);
                    }}
                    className="w-40"
                  />
                )}
              </div>
            </div>
            <div className="overflow-x-auto">
              <table className="w-full min-w-[560px] text-sm">
                <thead className="border-b border-slate-100 text-left text-[11px] font-black text-slate-500 dark:border-slate-800 dark:text-slate-400">
                  <tr>
                    <th className="w-12 py-3 text-center">#</th>
                    <th className="py-3">Talaba</th>
                    <th className="py-3 text-center">Modullar</th>
                    <th className="py-3 text-center">O'rtacha ball</th>
                    <th className="py-3 pl-4">Faollik</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-100 dark:divide-slate-800">
                  {topStudents.length ? (
                    topStudents.map((student, index) => (
                      <tr key={student.id} className="text-xs font-bold">
                      <td className="py-4 text-center">
                        <span className="inline-flex size-8 items-center justify-center rounded-lg bg-slate-50 text-slate-600 dark:bg-slate-800 dark:text-slate-300">
                          {index + 1}
                        </span>
                      </td>
                      <td className="py-4">
                        <span className="flex items-center gap-3">
                          <span className="flex size-8 items-center justify-center rounded-full bg-blue-50 font-black text-blue-600 dark:bg-blue-500/12 dark:text-blue-300">
                            {student.name[0]}
                          </span>
                          <span className="font-black text-slate-800 dark:text-slate-100">{student.name}</span>
                        </span>
                      </td>
                      <td className="py-4 text-center font-black">{student.modules}</td>
                      <td className="py-4 text-center font-black">{student.averageScore}%</td>
                      <td className="py-4 pl-4">
                        <div className="flex items-center gap-3">
                          <span className="h-2 w-28 overflow-hidden rounded-full bg-slate-100 dark:bg-slate-800">
                            <span
                              className={cn(
                                "block h-full rounded-full",
                                index === 0 ? "bg-blue-600" : index === 1 ? "bg-emerald-500" : index === 2 ? "bg-amber-500" : index === 3 ? "bg-violet-500" : "bg-rose-500",
                              )}
                              style={{ width: `${student.progress}%` }}
                            />
                          </span>
                          <span className="w-9 text-right text-slate-500 dark:text-slate-400">{student.progress}%</span>
                        </div>
                      </td>
                      </tr>
                    ))
                  ) : (
                    <tr>
                      <td colSpan={5} className="py-8 text-center text-xs font-bold text-slate-500 dark:text-slate-400">
                        Hali top talaba ma'lumoti yo'q.
                      </td>
                    </tr>
                  )}
                </tbody>
              </table>
            </div>
          </Panel>
        </div>

        <Panel>
          <div className="mb-3 flex items-center justify-between">
            <h3 className="analytics-title">Modullar bo'yicha o'zlashtirish darajasi</h3>
            <div className="relative">
              <button
                type="button"
                className="rounded-xl border border-slate-200 bg-white px-4 py-2 text-xs font-black text-slate-700 shadow-sm transition hover:border-blue-200 hover:text-blue-600 dark:border-slate-800 dark:bg-slate-950 dark:text-slate-300 dark:hover:border-blue-500/40 dark:hover:text-blue-300"
                onClick={() => toggleMenu("module")}
              >
                {moduleFilter}
                <ChevronDown className="ml-2 inline size-3.5" />
              </button>
              {openMenu === "module" && (
                <DropdownMenu
                  options={moduleFilterOptions}
                  value={moduleFilter}
                  onChange={(value) => {
                    setModuleFilter(value);
                    setOpenMenu(null);
                  }}
                  className="w-44"
                />
              )}
            </div>
          </div>
          <div className="h-[210px]">
            {moduleChartData.length ? (
              <ResponsiveContainer width="100%" height="100%">
                <BarChart data={moduleChartData} margin={{ top: 18, right: 16, left: 0, bottom: 0 }}>
                  <CartesianGrid stroke="#E8EDF5" vertical={false} />
                  <XAxis dataKey="name" axisLine={false} tickLine={false} tick={{ fill: "#34435F", fontSize: 11, fontWeight: 700 }} />
                  <YAxis axisLine={false} tickLine={false} tick={{ fill: "#64748B", fontSize: 11 }} width={38} />
                  <Tooltip content={<BarTooltip />} />
                  <Bar dataKey="value" fill="#4F5DFF" radius={[5, 5, 0, 0]} barSize={56} />
                </BarChart>
              </ResponsiveContainer>
            ) : (
              <div className="flex h-full items-center justify-center rounded-xl bg-slate-50 text-xs font-bold text-slate-500 dark:bg-slate-950/40 dark:text-slate-400">
                Hali modul o'zlashtirish ma'lumoti yo'q.
              </div>
            )}
          </div>
        </Panel>
      </div>
    </>
  );
}

function DropdownMenu<T extends string>({
  options,
  value,
  onChange,
  className,
}: {
  options: readonly T[];
  value: T;
  onChange: (value: T) => void;
  className?: string;
}) {
  return (
    <div
      className={cn(
        "absolute right-0 top-12 z-40 rounded-xl border border-slate-200 bg-white p-1.5 shadow-[0_18px_48px_rgba(27,39,70,0.18)] dark:border-slate-800 dark:bg-slate-950",
        className,
      )}
    >
      {options.map((option) => (
        <button
          key={option}
          type="button"
          className={cn(
            "flex w-full items-center justify-between rounded-lg px-3 py-2 text-left text-xs font-black text-slate-600 transition hover:bg-blue-50 hover:text-blue-600 dark:text-slate-300 dark:hover:bg-blue-500/10 dark:hover:text-blue-300",
            option === value && "bg-blue-50 text-blue-600 dark:bg-blue-500/15 dark:text-blue-300",
          )}
          onClick={() => onChange(option)}
        >
          <span>{option}</span>
          {option === value && <span className="size-2 rounded-full bg-blue-600 dark:bg-blue-300" />}
        </button>
      ))}
    </div>
  );
}

function Panel({ children, className }: { children: React.ReactNode; className?: string }) {
  return (
    <section
      className={cn(
        "rounded-xl border border-[#E2E8F4] bg-white p-4 shadow-[0_8px_26px_rgba(27,39,70,0.055)] dark:border-slate-800 dark:bg-slate-900",
        className,
      )}
    >
      {children}
    </section>
  );
}

function StatCard({
  title,
  value,
  change,
  note,
  tone,
  icon: Icon,
}: {
  title: string;
  value: string;
  change: string;
  note: string;
  tone: Tone;
  icon: React.ElementType;
}) {
  return (
    <Panel className="flex min-h-[112px] items-center gap-4 p-4">
      <span className={cn("flex size-12 shrink-0 items-center justify-center rounded-xl", toneClasses[tone].icon)}>
        <Icon className="size-6" />
      </span>
      <span className="min-w-0">
        <span className="block truncate text-xs font-black text-slate-600 dark:text-slate-300">{title}</span>
        <span className="mt-1 block text-2xl font-black leading-none text-slate-950 dark:text-white">{value}</span>
        <span className="mt-2 flex items-center gap-1 truncate text-[10px] font-bold text-slate-500 dark:text-slate-400">
          <span className={toneClasses[tone].text}>↑ {change}</span>
          {note}
        </span>
      </span>
    </Panel>
  );
}

function DonutCenter({
  data,
  label,
  value,
}: {
  data: { name: string; value: number; color: string }[];
  label: string;
  value: string;
}) {
  return (
    <div className="relative h-[162px]">
      <ResponsiveContainer width="100%" height="100%">
        <PieChart>
          <Pie data={data} dataKey="value" innerRadius={48} outerRadius={70} paddingAngle={3} stroke="none">
            {data.map((item) => (
              <Cell key={item.name} fill={item.color} />
            ))}
          </Pie>
        </PieChart>
      </ResponsiveContainer>
      <div className="absolute inset-0 flex flex-col items-center justify-center text-center">
        <span className="text-[11px] font-bold text-slate-500 dark:text-slate-400">{label}</span>
        <span className="text-xl font-black text-slate-950 dark:text-white">{value}</span>
      </div>
    </div>
  );
}

function Legend({
  color,
  customColor,
  label,
  value,
}: {
  color: string;
  customColor?: string;
  label: string;
  value: string;
}) {
  return (
    <div className="flex items-center gap-2">
      <span className={cn("size-2.5 rounded-full", color)} style={customColor ? { backgroundColor: customColor } : undefined} />
      <span className="min-w-0 flex-1 truncate text-slate-600 dark:text-slate-300">{label}</span>
      <span className="font-black text-slate-700 dark:text-slate-100">{value}</span>
    </div>
  );
}

function ProgressRow({ label, value, width, tone }: { label: string; value: string; width: number; tone: Tone }) {
  return (
    <div>
      <div className="mb-2 flex justify-between text-sm font-black text-slate-700 dark:text-slate-200">
        <span>{label}</span>
        <span>{value}</span>
      </div>
      <div className="h-2.5 overflow-hidden rounded-full bg-slate-100 dark:bg-slate-800">
        <div className={cn("h-full rounded-full", toneClasses[tone].bar)} style={{ width: `${width}%` }} />
      </div>
    </div>
  );
}

function ScoreCard({ title, value, detail, tone }: { title: string; value: string; detail: string; tone: Tone }) {
  return (
    <div className={cn("rounded-xl p-4", tone === "green" ? "bg-emerald-50/70 dark:bg-emerald-500/12" : tone === "blue" ? "bg-blue-50/70 dark:bg-blue-500/12" : "bg-rose-50/70 dark:bg-rose-500/12")}>
      <p className="text-xs font-black text-slate-600 dark:text-slate-300">{title}</p>
      <p className={cn("mt-2 text-2xl font-black", toneClasses[tone].text)}>{value}</p>
      <p className="mt-1 text-[11px] font-bold text-slate-500 dark:text-slate-400">{detail}</p>
    </div>
  );
}

function ChartTooltip({ active, payload, label }: any) {
  if (!active || !payload?.length) return null;
  return (
    <div className="rounded-xl border border-slate-100 bg-white px-4 py-3 text-xs font-bold shadow-[0_16px_40px_rgba(27,39,70,0.16)] dark:border-slate-800 dark:bg-slate-900">
      <p className="mb-2 text-slate-600 dark:text-slate-300">{label}</p>
      {payload.map((item: any) => (
        <p key={item.dataKey} style={{ color: item.color }}>
          {item.dataKey === "active" ? "Faol" : "Yangi"}: {item.value}
        </p>
      ))}
    </div>
  );
}

function BarTooltip({ active, payload, label }: any) {
  if (!active || !payload?.length) return null;
  return (
    <div className="rounded-xl border border-slate-100 bg-white px-4 py-3 text-xs font-bold shadow-[0_16px_40px_rgba(27,39,70,0.16)] dark:border-slate-800 dark:bg-slate-900">
      <p className="text-slate-600 dark:text-slate-300">{label}</p>
      <p className="mt-1 text-blue-600 dark:text-blue-300">{payload[0].value}%</p>
    </div>
  );
}
