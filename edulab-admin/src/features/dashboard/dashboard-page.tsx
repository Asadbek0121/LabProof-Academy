"use client";

import Link from "next/link";
import { useMemo } from "react";
import {
  Award,
  Bell,
  BookOpen,
  Bot,
  CheckCircle2,
  CloudUpload,
  CreditCard,
  FileText,
  GraduationCap,
  ImageIcon,
  MessageSquare,
  MoreVertical,
  Plus,
  Send,
  ShieldAlert,
  Sparkles,
  Trophy,
  UploadCloud,
  UserPlus,
  Users,
} from "lucide-react";
import {
  Area,
  AreaChart,
  Cell,
  Pie,
  PieChart,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts";
import { useQuery } from "@tanstack/react-query";
import { useAdminOverviewData, useConversations } from "@/hooks/use-admin-data";
import { createClient } from "@/lib/supabase/client";
import { cn } from "@/lib/utils";

type Tone = "blue" | "green" | "violet" | "rose" | "amber" | "cyan";

const toneMap: Record<
  Tone,
  {
    icon: string;
    line: string;
    text: string;
    bg: string;
    bar: string;
  }
> = {
  blue: {
    icon: "bg-blue-50 text-blue-600 dark:bg-blue-500/12 dark:text-blue-300",
    line: "#2F6BFF",
    text: "text-blue-600 dark:text-blue-300",
    bg: "bg-blue-50 dark:bg-blue-500/12",
    bar: "bg-blue-500",
  },
  green: {
    icon: "bg-emerald-50 text-emerald-600 dark:bg-emerald-500/12 dark:text-emerald-300",
    line: "#22C55E",
    text: "text-emerald-600 dark:text-emerald-300",
    bg: "bg-emerald-50 dark:bg-emerald-500/12",
    bar: "bg-emerald-500",
  },
  violet: {
    icon: "bg-violet-50 text-violet-600 dark:bg-violet-500/12 dark:text-violet-300",
    line: "#8B5CF6",
    text: "text-violet-600 dark:text-violet-300",
    bg: "bg-violet-50 dark:bg-violet-500/12",
    bar: "bg-violet-500",
  },
  rose: {
    icon: "bg-rose-50 text-rose-600 dark:bg-rose-500/12 dark:text-rose-300",
    line: "#FF5B68",
    text: "text-rose-600 dark:text-rose-300",
    bg: "bg-rose-50 dark:bg-rose-500/12",
    bar: "bg-rose-500",
  },
  amber: {
    icon: "bg-amber-50 text-amber-600 dark:bg-amber-500/12 dark:text-amber-300",
    line: "#F59E0B",
    text: "text-amber-600 dark:text-amber-300",
    bg: "bg-amber-50 dark:bg-amber-500/12",
    bar: "bg-amber-500",
  },
  cyan: {
    icon: "bg-cyan-50 text-cyan-600 dark:bg-cyan-500/12 dark:text-cyan-300",
    line: "#14B8A6",
    text: "text-cyan-600 dark:text-cyan-300",
    bg: "bg-cyan-50 dark:bg-cyan-500/12",
    bar: "bg-cyan-500",
  },
};

type CourseRow = {
  name: string;
  students: string;
  percent: number;
  tone: Tone;
};

const quickActions = [
  { label: "Talaba qo'shish", icon: UserPlus, href: "/students", tone: "blue" as Tone },
  { label: "Modul yaratish", icon: BookOpen, href: "/modules", tone: "green" as Tone },
  { label: "Xabar yuborish", icon: Send, href: "/notifications", tone: "violet" as Tone },
  { label: "Sertifikat yuklash", icon: Award, href: "/certificates", tone: "amber" as Tone },
  { label: "Backup yaratish", icon: CloudUpload, href: "/settings/backup", tone: "amber" as Tone },
  { label: "Hisobot yaratish", icon: FileText, href: "/analytics", tone: "cyan" as Tone },
];

const platformRows = [
  "Server holati",
  "Ma'lumotlar bazasi",
  "Storage (Cloudinary)",
  "Telegram Bot",
  "SMTP Server",
  "To'lov tizimi",
];

export function DashboardPage() {
  const overview = useAdminOverviewData();
  const conversations = useConversations();
  const supabase = createClient();

  const { data: logs } = useQuery({
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

  const metricCards = useMemo(() => {
    const iconByTitle: Record<string, React.ElementType> = {
      "Jami talabalar": Users,
      "Faol foydalanuvchilar": UserPlus,
      "Modullar soni": BookOpen,
      "Testlar soni": FileText,
      Sertifikatlar: Trophy,
      "Faol kurslar": GraduationCap,
    };
    const source = overview.data?.metrics ?? [
      { title: "Jami talabalar", value: "0", delta: "0%", trend: [0, 0, 0, 0, 0, 0, 0], tone: "blue" as Tone },
      { title: "Faol foydalanuvchilar", value: "0", delta: "0%", trend: [0, 0, 0, 0, 0, 0, 0], tone: "green" as Tone },
      { title: "Modullar soni", value: "0", delta: "0%", trend: [0, 0, 0, 0, 0, 0, 0], tone: "violet" as Tone },
      { title: "Testlar soni", value: "0", delta: "0%", trend: [0, 0, 0, 0, 0, 0, 0], tone: "rose" as Tone },
      { title: "Sertifikatlar", value: "0", delta: "0%", trend: [0, 0, 0, 0, 0, 0, 0], tone: "amber" as Tone },
      { title: "Faol kurslar", value: "0", delta: "0%", trend: [0, 0, 0, 0, 0, 0, 0], tone: "blue" as Tone },
    ];
    return source.map((item) => ({
      title: item.title,
      value: item.value,
      delta: item.delta,
      sub: "Supabase real ma'lumot",
      tone: item.tone,
      icon: iconByTitle[item.title] ?? ActivityIcon,
      points: item.trend.length ? item.trend : [0, 0, 0, 0, 0, 0, 0],
    }));
  }, [overview.data?.metrics]);

  const recentStudents = overview.data?.recentStudents ?? [];
  const recentActivity = (logs ?? []).slice(0, 3).map((log) => ({
    title: log.action || "Tizim amali",
    detail: log.details || log.admin_name || "Admin panelda amal bajarildi",
    time: log.created_at
      ? new Date(log.created_at).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })
      : "hozir",
    icon: ActivityIcon,
    tone: "blue" as Tone,
  }));
  const liveActivity = [
    ...recentActivity,
    ...(overview.data?.activityEvents ?? []).map((event) => ({
      ...event,
      icon: event.title.includes("Sertifikat") ? Award : event.title.includes("Media") ? UploadCloud : event.title.includes("Modul") ? BookOpen : Users,
    })),
  ].slice(0, 6);

  const growthData = (overview.data?.studentTrend ?? []).map((item) => ({
    name: item.name,
    students: item.value,
  }));

  const courseRows: CourseRow[] = (overview.data?.modulePerformance ?? [])
    .slice()
    .sort((a, b) => b.percent - a.percent || b.students - a.students)
    .slice(0, 5)
    .map((course, index) => ({
      name: course.name,
      students: String(course.students),
      percent: course.percent,
      tone: (["green", "blue", "amber", "violet", "rose"][index] ?? "blue") as Tone,
    }));

  const totalFiles = overview.data?.mediaByKind.files || 0;
  const percentOfFiles = (value: number) => (totalFiles ? Math.round((value / totalFiles) * 100) : 0);

  const mediaRows = [
    { label: "Rasmlar", value: String(overview.data?.mediaByKind.images ?? 0), percent: percentOfFiles(overview.data?.mediaByKind.images ?? 0), tone: "blue" as Tone, icon: ImageIcon },
    { label: "Videolar", value: String(overview.data?.mediaByKind.videos ?? 0), percent: percentOfFiles(overview.data?.mediaByKind.videos ?? 0), tone: "green" as Tone, icon: BookOpen },
    { label: "Ovozli fayllar", value: String(overview.data?.mediaByKind.voices ?? 0), percent: percentOfFiles(overview.data?.mediaByKind.voices ?? 0), tone: "violet" as Tone, icon: UploadCloud },
    { label: "PDF fayllar", value: String(overview.data?.mediaByKind.pdfs ?? 0), percent: percentOfFiles(overview.data?.mediaByKind.pdfs ?? 0), tone: "rose" as Tone, icon: FileText },
  ];

  const completion = overview.data?.completion ?? { completed: 0, inProgress: 0, notStarted: 0 };
  const completionTotal = Math.max(1, completion.completed + completion.inProgress + completion.notStarted);
  const completionRows = [
    { name: "Yakunlangan", value: Math.round((completion.completed / completionTotal) * 100), color: "#22C55E" },
    { name: "Jarayonda", value: Math.round((completion.inProgress / completionTotal) * 100), color: "#2F6BFF" },
    { name: "Boshlanmagan", value: Math.round((completion.notStarted / completionTotal) * 100), color: "#F59E0B" },
  ];
  const mediaGb = ((overview.data?.totals.mediaTotalBytes ?? 0) / 1024 / 1024 / 1024).toFixed(1);
  const mediaPercent = Math.min(100, Math.round(((overview.data?.totals.mediaTotalBytes ?? 0) / (100 * 1024 * 1024 * 1024)) * 100));
  const todayCertificates = overview.data?.metrics.find((item) => item.title === "Sertifikatlar")?.trend.at(-1) ?? 0;
  const recentMediaUploads = overview.data?.activityEvents.filter((item) => item.title === "Media yuklandi").length ?? 0;
  const unreadConversations = (conversations.data ?? []).reduce((sum, conversation) => sum + conversation.unread, 0);
  const insightRows = [
    {
      title: `${Math.max(0, (overview.data?.totals.students ?? 0) - (overview.data?.totals.online ?? 0))} ta talaba hozir offline`,
      detail: "Faollik telegram/app oxirgi ko'rinishidan hisoblandi",
      action: "Ko'rish",
      icon: Bell,
      tone: "rose" as Tone,
    },
    {
      title: `O'rtacha yakunlash ${overview.data?.totals.completionPercent ?? 0}%`,
      detail: "Topic progress va module resultlardan hisoblandi",
      action: "Ko'rish",
      icon: Sparkles,
      tone: "violet" as Tone,
    },
    {
      title: overview.data?.errors.length ? "Ayrim real querylarda xatolik bor" : "Real data oqimi ishlayapti",
      detail: overview.data?.errors[0] || "Dashboard Supabase agregatlaridan o'qiyapti",
      action: "Batafsil",
      icon: overview.data?.errors.length ? ShieldAlert : CheckCircle2,
      tone: overview.data?.errors.length ? "amber" as Tone : "green" as Tone,
    },
    {
      title: `${overview.data?.totals.mediaFiles ?? 0} ta media fayl`,
      detail: `${mediaGb} GB jami media hajmi`,
      action: "Media",
      icon: UploadCloud,
      tone: "blue" as Tone,
    },
  ];

  return (
    <div className="dashboard-surface -mx-1 -mt-1 space-y-4 pb-3 text-[#17213A] dark:text-slate-100">
      <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-6">
        {metricCards.map((item) => (
          <MetricCard key={item.title} {...item} loading={overview.isLoading} />
        ))}
      </div>

      <div className="grid gap-4 xl:grid-cols-[1.35fr_0.62fr_0.98fr]">
        <Panel className="min-h-[260px] xl:col-span-1">
          <PanelHeader title="Talabalar o'sish dinamikasi" action="So'nggi 7 kun" />
          <div className="h-[212px]">
            <ResponsiveContainer width="100%" height="100%">
              <AreaChart data={growthData} margin={{ top: 8, right: 18, left: -12, bottom: 0 }}>
                <defs>
                  <linearGradient id="dashboardGrowthFill" x1="0" x2="0" y1="0" y2="1">
                    <stop offset="0%" stopColor="#2F6BFF" stopOpacity={0.22} />
                    <stop offset="100%" stopColor="#2F6BFF" stopOpacity={0.02} />
                  </linearGradient>
                </defs>
                <YAxis axisLine={false} tickLine={false} tick={{ fill: "#7B8AA7", fontSize: 11 }} width={42} />
                <XAxis dataKey="name" axisLine={false} tickLine={false} tick={{ fill: "#667792", fontSize: 11 }} />
                <Tooltip content={<GrowthTooltip />} />
                <Area
                  type="monotone"
                  dataKey="students"
                  stroke="#2F6BFF"
                  strokeWidth={3}
                  fill="url(#dashboardGrowthFill)"
                  dot={{ r: 4, fill: "#2F6BFF", stroke: "#fff", strokeWidth: 2 }}
                  activeDot={{ r: 6, fill: "#2F6BFF", stroke: "#fff", strokeWidth: 3 }}
                />
              </AreaChart>
            </ResponsiveContainer>
          </div>
        </Panel>

        <Panel className="min-h-[260px]">
          <h3 className="dashboard-title">Yakunlash statistikasi</h3>
          <div className="mt-3 flex items-center gap-4">
            <div className="relative h-[176px] flex-1 min-w-[150px]">
              <ResponsiveContainer width="100%" height="100%">
                <PieChart>
                  <Pie
                    data={completionRows}
                    dataKey="value"
                    innerRadius={54}
                    outerRadius={74}
                    paddingAngle={4}
                    stroke="none"
                  >
                    {completionRows.map((row) => (
                      <Cell key={row.name} fill={row.color} />
                    ))}
                  </Pie>
                </PieChart>
              </ResponsiveContainer>
              <div className="absolute inset-0 flex flex-col items-center justify-center text-center">
                <p className="text-3xl font-black text-slate-950 dark:text-white">{overview.data?.totals.completionPercent ?? 0}%</p>
                <p className="text-[11px] font-bold leading-tight text-slate-500">O'rtacha<br />yakunlash</p>
              </div>
            </div>
            <div className="min-w-[128px] space-y-4 text-xs font-bold">
              <LegendRow color="bg-emerald-500" label="Yakunlangan" value={`${completionRows[0]?.value ?? 0}%`} />
              <LegendRow color="bg-blue-500" label="Jarayonda" value={`${completionRows[1]?.value ?? 0}%`} />
              <LegendRow color="bg-amber-500" label="Boshlanmagan" value={`${completionRows[2]?.value ?? 0}%`} />
            </div>
          </div>
          <Link href="/modules" className="mt-2 inline-flex text-xs font-extrabold text-blue-600 dark:text-blue-300">
            Barcha modullar bo'yicha
          </Link>
        </Panel>

        <Panel className="row-span-2 min-h-[430px]">
          <div className="mb-4 flex items-center justify-between">
            <h3 className="dashboard-title">Jonli faoliyat</h3>
            <span className="rounded-full bg-emerald-50 px-2.5 py-1 text-[10px] font-black text-emerald-600 dark:bg-emerald-500/12 dark:text-emerald-300">
              Real-time
            </span>
          </div>
          <div className="space-y-4">
            {liveActivity.map((item, index) => (
              <ActivityItem key={`${item.title}-${index}`} {...item} />
            ))}
          </div>
          <Link href="/activity-logs" className="mt-7 flex justify-center text-xs font-extrabold text-blue-600 dark:text-blue-300">
            Barcha faoliyatlarni ko'rish
          </Link>
        </Panel>
      </div>

      <div className="grid gap-4 xl:grid-cols-[0.9fr_0.74fr_0.56fr_0.98fr]">
        <Panel>
          <PanelLinkTitle title="Eng faol kurslar" href="/modules" />
          <div className="mt-4 space-y-3">
            <div className="grid grid-cols-[1fr_80px_130px] text-[10px] font-black text-slate-400">
              <span>Kurs nomi</span>
              <span>Faol talabalar</span>
              <span>Yakunlash</span>
            </div>
            {courseRows.length ? (
              courseRows.map((course) => (
                <div key={course.name} className="grid grid-cols-[1fr_80px_130px] items-center gap-2 text-xs font-bold">
                  <span className="flex items-center gap-2 truncate">
                    <span className={cn("flex size-5 items-center justify-center rounded-md text-[9px] font-black", toneMap[course.tone].bg, toneMap[course.tone].text)}>
                      {course.name.slice(0, 1)}
                    </span>
                    {course.name}
                  </span>
                  <span className="text-slate-600 dark:text-slate-300">{course.students}</span>
                  <span className="flex items-center gap-2">
                    <span className="h-1.5 flex-1 overflow-hidden rounded-full bg-slate-100 dark:bg-slate-800">
                      <span className={cn("block h-full rounded-full", toneMap[course.tone].bar)} style={{ width: `${course.percent}%` }} />
                    </span>
                    <span className="w-8 text-right text-[10px] text-slate-500">{course.percent}%</span>
                  </span>
                </div>
              ))
            ) : (
              <p className="rounded-xl bg-slate-50 px-3 py-4 text-xs font-bold text-slate-500 dark:bg-slate-950/40 dark:text-slate-400">
                Hali modul progress ma'lumoti yo'q.
              </p>
            )}
          </div>
        </Panel>

        <Panel>
          <h3 className="dashboard-title">Tezkor amallar</h3>
          <div className="mt-4 grid grid-cols-3 gap-3">
            {quickActions.map((item) => (
              <Link
                key={item.label}
                href={item.href}
                className={cn(
                  "flex min-h-[76px] flex-col items-center justify-center gap-2 rounded-xl border border-slate-100 text-center text-[11px] font-extrabold shadow-sm transition hover:-translate-y-0.5 hover:shadow-md dark:border-slate-800",
                  toneMap[item.tone].bg,
                )}
              >
                <item.icon className={cn("size-6", toneMap[item.tone].text)} />
                <span>{item.label}</span>
              </Link>
            ))}
          </div>
        </Panel>

        <Panel>
          <h3 className="dashboard-title">Platforma holati</h3>
          <div className="mt-4 space-y-2.5">
            {platformRows.map((label) => (
              <div key={label} className="flex items-center justify-between gap-3 text-xs font-bold">
                <span className="flex min-w-0 items-center gap-2 truncate text-slate-600 dark:text-slate-300">
                  <span className="size-2 rounded-full bg-emerald-500" />
                  {label}
                </span>
                <span className="rounded-full bg-emerald-50 px-2 py-1 text-[10px] font-black text-emerald-600 dark:bg-emerald-500/12 dark:text-emerald-300">
                  Ishlayapti
                </span>
              </div>
            ))}
          </div>
        </Panel>
      </div>

      <div className="grid gap-4 xl:grid-cols-[0.88fr_0.9fr_0.94fr]">
        <Panel>
          <PanelLinkTitle title="So'nggi talabalar" href="/students" />
          <div className="mt-4 overflow-hidden">
            <div className="grid grid-cols-[1.1fr_1fr_86px_76px_100px_24px] gap-2 text-[10px] font-black text-slate-400">
              <span>Talaba</span>
              <span>Modul</span>
              <span>Progress</span>
              <span>Holat</span>
              <span>Qo'shilgan sana</span>
              <span />
            </div>
            <div className="mt-3 space-y-3">
              {recentStudents.length ? (
                recentStudents.map((student) => <StudentRow key={student.id} student={student} />)
              ) : (
                <p className="rounded-xl bg-slate-50 px-3 py-4 text-xs font-bold text-slate-500 dark:bg-slate-950/40 dark:text-slate-400">
                  Hali talaba ma'lumoti yo'q.
                </p>
              )}
            </div>
          </div>
        </Panel>

        <Panel>
          <h3 className="dashboard-title">Operativ ko'rsatkichlar</h3>
          <div className="mt-4 grid grid-cols-3 gap-3">
            <IndicatorCard icon={Bell} title="O'qilmagan xabarlar" value={String(unreadConversations)} detail="Support suhbatlari" tone="violet" />
            <IndicatorCard icon={ActivityIcon} title="Faol seanslar" value={String(overview.data?.totals.online ?? 0)} detail="Oxirgi 15 daqiqa" tone="green" />
            <IndicatorCard icon={CreditCard} title="O'rtacha ball" value={`${overview.data?.totals.averageScore ?? 0}%`} detail="Quiz progress bo'yicha" tone="amber" />
            <IndicatorCard icon={UploadCloud} title="Yuklangan fayllar" value={String(recentMediaUploads)} detail="Oxirgi faollikda" tone="cyan" />
            <IndicatorCard icon={Award} title="Sertifikatlar berildi" value={String(todayCertificates)} detail="So'nggi trend kuni" tone="violet" />
            <IndicatorCard icon={ShieldAlert} title="Data xatolari" value={String(overview.data?.errors.length ?? 0)} detail="Supabase query holati" tone="rose" />
          </div>
        </Panel>

        <Panel>
          <PanelLinkTitle title="Media umumiy holati" href="/media-library" />
          <div className="mt-5 grid grid-cols-[1fr_132px] items-center gap-5">
            <div className="space-y-3.5">
              {mediaRows.map((row) => (
                <div key={row.label} className="grid grid-cols-[20px_1fr_72px] items-center gap-2 text-xs font-bold">
                  <span className={cn("flex size-5 items-center justify-center rounded-md", toneMap[row.tone].bg, toneMap[row.tone].text)}>
                    <row.icon className="size-3.5" />
                  </span>
                  <span>
                    <span className="block">{row.label}</span>
                    <span className="mt-1 block h-1.5 overflow-hidden rounded-full bg-slate-100 dark:bg-slate-800">
                      <span className={cn("block h-full rounded-full", toneMap[row.tone].bar)} style={{ width: `${row.percent}%` }} />
                    </span>
                  </span>
                  <span className="text-right text-slate-600 dark:text-slate-300">{row.value} ta</span>
                </div>
              ))}
            </div>
            <div
              className="relative mx-auto flex size-32 items-center justify-center rounded-full"
              style={{
                background: `conic-gradient(#2F6BFF 0 ${mediaPercent}%, #E8EDF7 ${mediaPercent}% 100%)`,
              }}
            >
              <div className="flex size-24 flex-col items-center justify-center rounded-full bg-white text-center dark:bg-slate-900">
                <span className="text-[10px] font-bold text-slate-500">Jami foydalanish</span>
                <span className="text-xl font-black">{mediaGb} GB</span>
                <span className="text-[10px] font-bold text-slate-400">/ 100 GB</span>
              </div>
            </div>
          </div>
          <p className="mt-3 text-center text-xs font-black text-blue-600 dark:text-blue-300">{mediaPercent}% ishlatilgan</p>
        </Panel>
      </div>

      <Panel className="overflow-visible">
        <h3 className="dashboard-title">Smart insightlar</h3>
        <div className="mt-4 grid gap-3 lg:grid-cols-[54px_1fr_1fr_1fr_1fr]">
          <div className="hidden items-end justify-center lg:flex">
            <span className="flex size-12 items-center justify-center rounded-2xl bg-blue-50 text-blue-600 dark:bg-blue-500/12 dark:text-blue-300">
              <Bot className="size-7" />
            </span>
          </div>
          {insightRows.map((item) => (
            <div key={item.title} className="flex items-center gap-3 rounded-xl border border-slate-100 bg-white px-4 py-3 shadow-sm dark:border-slate-800 dark:bg-slate-900">
              <span className={cn("flex size-10 shrink-0 items-center justify-center rounded-xl", toneMap[item.tone].bg, toneMap[item.tone].text)}>
                <item.icon className="size-5" />
              </span>
              <span className="min-w-0 flex-1">
                <span className="block truncate text-xs font-black">{item.title}</span>
                <span className="mt-0.5 block truncate text-[11px] font-semibold text-slate-500 dark:text-slate-400">{item.detail}</span>
              </span>
              <Link href="/analytics" className="shrink-0 text-[11px] font-black text-blue-600 dark:text-blue-300">
                {item.action}
              </Link>
            </div>
          ))}
        </div>
      </Panel>
    </div>
  );
}

function Panel({ className, children }: { className?: string; children: React.ReactNode }) {
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

function PanelHeader({ title, action }: { title: string; action?: string }) {
  return (
    <div className="mb-2 flex items-center justify-between">
      <h3 className="dashboard-title">{title}</h3>
      {action ? (
        <button className="rounded-lg border border-slate-200 bg-white px-3 py-1.5 text-[11px] font-black text-slate-600 shadow-sm dark:border-slate-800 dark:bg-slate-950 dark:text-slate-300">
          {action}
        </button>
      ) : null}
    </div>
  );
}

function PanelLinkTitle({ title, href }: { title: string; href: string }) {
  return (
    <div className="flex items-center justify-between">
      <h3 className="dashboard-title">{title}</h3>
      <Link href={href} className="text-[11px] font-black text-blue-600 dark:text-blue-300">
        Barchasini ko'rish
      </Link>
    </div>
  );
}

function MetricCard({
  title,
  value,
  delta,
  sub,
  tone,
  icon: Icon,
  points,
  loading,
}: {
  title: string;
  value: string;
  delta: string;
  sub: string;
  tone: Tone;
  icon: React.ElementType;
  points: number[];
  loading?: boolean;
}) {
  return (
    <Panel className="min-h-[118px] p-3.5">
      <div className="flex items-start gap-2.5">
        <span className={cn("flex size-10 shrink-0 items-center justify-center rounded-xl", toneMap[tone].icon)}>
          <Icon className="size-5" />
        </span>
        <div className="min-w-0 flex-1">
          <p className="truncate text-[11px] font-black text-slate-600 dark:text-slate-300">{title}</p>
          <div className="mt-1 flex flex-wrap items-baseline gap-x-3 gap-y-0.5">
            <p className="text-[23px] font-black leading-none text-slate-950 dark:text-white">{loading ? "..." : value}</p>
            <span className="text-[11px] font-black text-emerald-600 dark:text-emerald-300">{delta}</span>
          </div>
          <p className="mt-1 truncate text-[10px] font-bold text-slate-500 dark:text-slate-400">{sub}</p>
        </div>
      </div>
      <MiniSparkline points={points} color={toneMap[tone].line} />
    </Panel>
  );
}

function MiniSparkline({ points, color }: { points: number[]; color: string }) {
  const width = 180;
  const height = 36;
  const safePoints = points.filter((point) => Number.isFinite(point));
  const chartPoints = safePoints.length > 1 ? safePoints : [0, 0];
  const min = Math.min(...chartPoints);
  const max = Math.max(...chartPoints);
  const range = Math.max(1, max - min);
  const path = chartPoints
    .map((point, index) => {
      const x = (index / (chartPoints.length - 1)) * width;
      const y = height - ((point - min) / range) * (height - 8) - 4;
      return `${index === 0 ? "M" : "L"} ${x.toFixed(1)} ${y.toFixed(1)}`;
    })
    .join(" ");
  return (
    <svg viewBox={`0 0 ${width} ${height}`} className="mt-2 h-7 w-full overflow-visible" aria-hidden="true">
      <path d={path} fill="none" stroke={color} strokeWidth="3" strokeLinecap="round" strokeLinejoin="round" />
      {chartPoints.map((point, index) => {
        const x = (index / (chartPoints.length - 1)) * width;
        const y = height - ((point - min) / range) * (height - 8) - 4;
        return <circle key={`${point}-${index}`} cx={x} cy={y} r="1.8" fill={color} />;
      })}
    </svg>
  );
}

function GrowthTooltip({ active, payload, label }: any) {
  if (!active || !payload?.length) return null;
  return (
    <div className="rounded-xl border border-slate-100 bg-white px-4 py-3 text-xs font-bold shadow-[0_16px_40px_rgba(27,39,70,0.16)] dark:border-slate-800 dark:bg-slate-900">
      <p className="text-slate-600 dark:text-slate-300">{label}</p>
      <p className="mt-1 text-slate-950 dark:text-white">{payload[0].value.toLocaleString()} talabalar</p>
    </div>
  );
}

function LegendRow({ color, label, value }: { color: string; label: string; value: string }) {
  return (
    <div className="flex items-center gap-2">
      <span className={cn("size-2.5 rounded-full", color)} />
      <span className="min-w-0 flex-1 text-slate-500 dark:text-slate-400">{label}</span>
      <span className="text-slate-700 dark:text-slate-200">{value}</span>
    </div>
  );
}

function ActivityItem({
  title,
  detail,
  time,
  icon: Icon,
  tone,
}: {
  title: string;
  detail: string;
  time: string;
  icon: React.ElementType;
  tone: Tone;
}) {
  return (
    <div className="grid grid-cols-[38px_1fr_auto] items-start gap-3">
      <span className={cn("flex size-9 items-center justify-center rounded-xl", toneMap[tone].bg, toneMap[tone].text)}>
        <Icon className="size-4" />
      </span>
      <span className="min-w-0">
        <span className="block truncate text-xs font-black">{title}</span>
        <span className="mt-0.5 block truncate text-[11px] font-semibold text-slate-500 dark:text-slate-400">{detail}</span>
      </span>
      <span className="whitespace-nowrap text-[10px] font-bold text-slate-400">{time}</span>
    </div>
  );
}

function StudentRow({ student }: { student: any }) {
  const initials = student.initials || student.name?.slice(0, 2).toUpperCase() || "ST";
  const moduleName = `${student.modules || 0} modul yakunlangan`;
  const active = student.status === "Faol";
  return (
    <div className="grid grid-cols-[1.1fr_1fr_86px_76px_100px_24px] items-center gap-2 text-[11px] font-bold">
      <span className="flex min-w-0 items-center gap-2">
        <span className="flex size-7 shrink-0 items-center justify-center rounded-full bg-violet-100 text-[10px] font-black text-violet-600 dark:bg-violet-500/15 dark:text-violet-300">
          {initials}
        </span>
        <span className="truncate">{student.name}</span>
      </span>
      <span className="truncate text-slate-500 dark:text-slate-400">{moduleName}</span>
      <span className="flex items-center gap-1.5">
        <span className="rounded-full bg-emerald-100 px-1.5 py-0.5 text-[9px] font-black text-emerald-600 dark:bg-emerald-500/15 dark:text-emerald-300">
          +{Math.max(1, Math.round(student.progress / 15))}%
        </span>
        {student.progress}%
      </span>
      <span className={cn("rounded-full px-2 py-1 text-center text-[10px] font-black", active ? "bg-emerald-50 text-emerald-600 dark:bg-emerald-500/12 dark:text-emerald-300" : "bg-slate-100 text-slate-500 dark:bg-slate-800 dark:text-slate-300")}>
        {active ? "Onlayn" : "Offlayn"}
      </span>
      <span className="truncate text-slate-500 dark:text-slate-400">{student.joinedAt}</span>
      <MoreVertical className="size-4 text-slate-400" />
    </div>
  );
}

function IndicatorCard({
  icon: Icon,
  title,
  value,
  detail,
  tone,
}: {
  icon: React.ElementType;
  title: string;
  value: string;
  detail: string;
  tone: Tone;
}) {
  return (
    <div className="rounded-xl border border-slate-100 bg-slate-50/60 p-3 dark:border-slate-800 dark:bg-slate-950/35">
      <div className="flex items-center gap-3">
        <span className={cn("flex size-10 items-center justify-center rounded-xl", toneMap[tone].bg, toneMap[tone].text)}>
          <Icon className="size-5" />
        </span>
        <span className="min-w-0">
          <span className="block truncate text-[11px] font-black">{title}</span>
          <span className="mt-1 block text-lg font-black leading-none">{value}</span>
          <span className="mt-1 block truncate text-[10px] font-semibold text-slate-500 dark:text-slate-400">{detail}</span>
        </span>
      </div>
    </div>
  );
}

function ActivityIcon(props: React.ComponentProps<typeof MessageSquare>) {
  return <MessageSquare {...props} />;
}
