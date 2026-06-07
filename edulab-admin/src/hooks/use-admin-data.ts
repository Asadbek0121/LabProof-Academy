"use client";

import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { createClient } from "@/lib/supabase/client";
import {
  Users,
  CheckCircle2,
  Award,
  LineChart,
  Activity,
  GalleryVerticalEnd,
  FileArchive,
  FileText,
  Trophy,
  ImageIcon,
  Video,
} from "lucide-react";
import {
  permissions,
  roles,
  studentStats,
  mediaStats,
} from "@/lib/mock-data";
import type { Conversation, MediaItem, Student } from "@/lib/types";

export function useStudents() {
  const supabase = createClient();
  return useQuery({
    queryKey: ["students"],
    queryFn: async (): Promise<Student[]> => {
      const { data: profiles, error: pError } = await supabase
        .from("profiles")
        .select("*")
        .eq("role", "student")
        .order("created_at", { ascending: false });

      if (pError || !profiles) return [];

      const { data: moduleResults } = await supabase
        .from("module_results")
        .select("*");

      const { data: topicProgress } = await supabase
        .from("topic_progress")
        .select("*");

      const { count: totalTopics } = await supabase
        .from("topics")
        .select("*", { count: "exact", head: true });

      const topicsCount = totalTopics || 1;

      return profiles.map((p) => {
        const studentResults = moduleResults?.filter((r) => r.user_id === p.id) || [];
        const studentProgress = topicProgress?.filter((tp) => tp.user_id === p.id) || [];

        const completedTopics = studentProgress.filter(
          (tp) => tp.pdf_completed || tp.video_completed || tp.quiz_completed,
        ).length;
        const progressPercent = Math.round((completedTopics / topicsCount) * 100);

        const quizScores = studentProgress
          .filter((tp) => tp.quiz_score !== null)
          .map((tp) => tp.quiz_score as number);
        const averageScore =
          quizScores.length > 0
            ? Math.round(quizScores.reduce((a, b) => a + b, 0) / quizScores.length)
            : 0;

        const joinedAtDate = new Date(p.created_at);
        const joinedAt = `${String(joinedAtDate.getDate()).padStart(2, "0")}.${String(
          joinedAtDate.getMonth() + 1,
        ).padStart(2, "0")}.${joinedAtDate.getFullYear()}`;

        const lastSeenTime = p.telegram_last_seen_at
          ? new Date(p.telegram_last_seen_at).getTime()
          : 0;
        const recentlyActive =
          lastSeenTime > 0 && Date.now() - lastSeenTime <= 15 * 60 * 1000;
        const status =
          recentlyActive || progressPercent >= 70
            ? "Faol"
            : progressPercent >= 35 || averageScore >= 50
              ? "O'rtacha"
              : "Qoniqarsiz";

        return {
          id: p.id,
          name: p.full_name || "Ismsiz Talaba",
          email: p.phone ? `${p.phone}@edulab.uz` : "talaba@edulab.uz",
          phone: p.phone || "",
          initials: (p.full_name || "T")
            .split(" ")
            .map((n: string) => n[0])
            .join("")
            .toUpperCase()
            .slice(0, 2),
          modules: studentResults.filter((r) => r.passed).length,
          progress: progressPercent,
          averageScore,
          status,
          joinedAt,
          createdAt: p.created_at,
          group: null,
        };
      });
    },
  });
}

export function useStudentStats() {
  const supabase = createClient();
  return useQuery({
    queryKey: ["student-stats"],
    queryFn: async () => {
      const { data: profiles } = await supabase
        .from("profiles")
        .select("id, telegram_last_seen_at")
        .eq("role", "student");

      const { data: progress } = await supabase
        .from("topic_progress")
        .select("quiz_score, pdf_completed, video_completed, quiz_completed");

      const { count: totalTopics } = await supabase
        .from("topics")
        .select("*", { count: "exact", head: true });

      const studentCount = profiles?.length || 0;
      const activeCount =
        profiles?.filter((p) => p.telegram_last_seen_at !== null).length || 0;

      const quizScores =
        progress?.filter((tp) => tp.quiz_score !== null).map((tp) => tp.quiz_score as number) ||
        [];
      const averageScore =
        quizScores.length > 0
          ? Math.round(quizScores.reduce((a, b) => a + b, 0) / quizScores.length)
          : 0;

      const topicsCount = totalTopics || 1;
      const totalCompletedTopics =
        progress?.filter((tp) => tp.pdf_completed || tp.video_completed || tp.quiz_completed)
          .length || 0;
      const overallProgress =
        studentCount > 0
          ? Math.round((totalCompletedTopics / (topicsCount * studentCount)) * 100)
          : 0;

      return [
        {
          title: "Jami talabalar",
          value: String(studentCount),
          hint: "Barchasini ko'rish",
          tone: "blue" as const,
          icon: Users,
        },
        {
          title: "Faol talabalar",
          value: String(activeCount),
          hint: "Telegram active",
          tone: "green" as const,
          icon: CheckCircle2,
        },
        {
          title: "O'rtacha ball",
          value: `${averageScore}%`,
          hint: "Umumiy o'rtacha",
          tone: "orange" as const,
          icon: Award,
        },
        {
          title: "Umumiy progress",
          value: `${overallProgress}%`,
          hint: "Progressni ko'rish",
          tone: "violet" as const,
          icon: LineChart,
        },
      ];
    },
  });
}

export function useAnalyticsStats() {
  const supabase = createClient();
  return useQuery({
    queryKey: ["analytics-stats"],
    queryFn: async () => {
      const { count: studentCount } = await supabase
        .from("profiles")
        .select("*", { count: "exact", head: true })
        .eq("role", "student");

      const { count: activeCount } = await supabase
        .from("profiles")
        .select("*", { count: "exact", head: true })
        .eq("role", "student")
        .not("telegram_last_seen_at", "is", null);

      const { count: moduleCount } = await supabase
        .from("modules")
        .select("*", { count: "exact", head: true });

      const { count: topicCount } = await supabase
        .from("topics")
        .select("*", { count: "exact", head: true });

      const { count: quizCount } = await supabase
        .from("quiz_questions")
        .select("*", { count: "exact", head: true });

      const { count: certCount } = await supabase
        .from("certificates")
        .select("*", { count: "exact", head: true });

      return [
        {
          title: "Jami talabalar",
          value: String(studentCount || 0),
          hint: "Haqiqiy ma'lumot",
          tone: "blue" as const,
          icon: Users,
        },
        {
          title: "Faol foydalanuvchilar",
          value: String(activeCount || 0),
          hint: "Telegram active",
          tone: "green" as const,
          icon: Activity,
        },
        {
          title: "Modullar soni",
          value: String(moduleCount || 0),
          hint: "Tizim modullari",
          tone: "violet" as const,
          icon: GalleryVerticalEnd,
        },
        {
          title: "Mavzular soni",
          value: String(topicCount || 0),
          hint: "Mavzular",
          tone: "orange" as const,
          icon: FileArchive,
        },
        {
          title: "Testlar soni",
          value: String(quizCount || 0),
          hint: "Savollar",
          tone: "red" as const,
          icon: FileText,
        },
        {
          title: "Sertifikatlar",
          value: String(certCount || 0),
          hint: "Berilgan",
          tone: "blue" as const,
          icon: Trophy,
        },
      ];
    },
  });
}

type OverviewTone = "blue" | "green" | "violet" | "amber" | "rose" | "cyan";

type OverviewMetric = {
  title: string;
  value: string;
  delta: string;
  trend: number[];
  tone: OverviewTone;
};

type OverviewActivity = {
  title: string;
  detail: string;
  time: string;
  tone: OverviewTone;
};

const ONLINE_WINDOW_MS = 15 * 60 * 1000;

function isOnline(value?: string | null) {
  if (!value) return false;
  return Date.now() - new Date(value).getTime() <= ONLINE_WINDOW_MS;
}

function toDayKey(value?: string | null) {
  if (!value) return "";
  return new Date(value).toISOString().slice(0, 10);
}

function lastDays(days: number) {
  return Array.from({ length: days }, (_, index) => {
    const date = new Date();
    date.setDate(date.getDate() - (days - 1 - index));
    return date.toISOString().slice(0, 10);
  });
}

function formatTrendLabel(dayKey: string) {
  const date = new Date(`${dayKey}T00:00:00`);
  return `${date.getDate()} ${date.toLocaleString("uz-UZ", { month: "short" })}`;
}

function countByDay(rows: { created_at?: string | null; updated_at?: string | null; completed_at?: string | null; issued_at?: string | null }[], field: "created_at" | "updated_at" | "completed_at" | "issued_at", days = 7) {
  const keys = lastDays(days);
  return keys.map((key) => ({
    name: formatTrendLabel(key),
    value: rows.filter((row) => toDayKey(row[field]) === key).length,
  }));
}

function percentDelta(current: number, previous: number) {
  if (previous === 0) return current > 0 ? "+100%" : "0%";
  const percent = Math.round(((current - previous) / previous) * 100);
  return `${percent >= 0 ? "+" : ""}${percent}%`;
}

function lastWeekDelta(rows: { created_at?: string | null }[]) {
  const now = Date.now();
  const week = 7 * 24 * 60 * 60 * 1000;
  const current = rows.filter((row) => {
    const time = row.created_at ? new Date(row.created_at).getTime() : 0;
    return time >= now - week;
  }).length;
  const previous = rows.filter((row) => {
    const time = row.created_at ? new Date(row.created_at).getTime() : 0;
    return time >= now - week * 2 && time < now - week;
  }).length;
  return percentDelta(current, previous);
}

function relativeTime(value?: string | null) {
  if (!value) return "vaqt noma'lum";
  const diff = Math.max(0, Date.now() - new Date(value).getTime());
  const minutes = Math.round(diff / 60_000);
  if (minutes < 1) return "hozir";
  if (minutes < 60) return `${minutes} daqiqa oldin`;
  const hours = Math.round(minutes / 60);
  if (hours < 24) return `${hours} soat oldin`;
  return `${Math.round(hours / 24)} kun oldin`;
}

export function useAdminOverviewData() {
  const supabase = createClient();
  return useQuery({
    queryKey: ["admin-overview-data"],
    queryFn: async () => {
      const [
        profilesResult,
        modulesResult,
        topicsResult,
        lessonsResult,
        questionsResult,
        progressResult,
        resultsResult,
        certificatesResult,
        mediaResult,
      ] = await Promise.all([
        supabase
          .from("profiles")
          .select("id, full_name, phone, role, created_at, telegram_last_seen_at")
          .eq("role", "student"),
        supabase.from("modules").select("id, title, is_published, created_at").order("order_index", { ascending: true }),
        supabase.from("topics").select("id, module_id, title, is_published, created_at"),
        supabase.from("lessons").select("id, topic_id, kind, created_at"),
        supabase.from("quiz_questions").select("id, topic_id, module_id, created_at"),
        supabase.from("topic_progress").select("user_id, topic_id, pdf_completed, video_completed, quiz_completed, quiz_score, updated_at, completed_at"),
        supabase.from("module_results").select("user_id, module_id, score, passed, created_at"),
        supabase.from("certificates").select("id, user_id, module_id, issued_at"),
        supabase.from("media_library").select("kind, bytes, created_at"),
      ]);

      const profiles = profilesResult.error ? [] : profilesResult.data ?? [];
      const modules = modulesResult.error ? [] : modulesResult.data ?? [];
      const topics = topicsResult.error ? [] : topicsResult.data ?? [];
      const lessons = lessonsResult.error ? [] : lessonsResult.data ?? [];
      const questions = questionsResult.error ? [] : questionsResult.data ?? [];
      const progress = progressResult.error ? [] : progressResult.data ?? [];
      const moduleResults = resultsResult.error ? [] : resultsResult.data ?? [];
      const certificates = certificatesResult.error ? [] : certificatesResult.data ?? [];
      const media = mediaResult.error ? [] : mediaResult.data ?? [];

      const completedProgress = progress.filter((row) => row.pdf_completed || row.video_completed || row.quiz_completed);
      const quizScores = progress.filter((row) => typeof row.quiz_score === "number").map((row) => Number(row.quiz_score));
      const averageScore = quizScores.length
        ? Math.round(quizScores.reduce((sum, score) => sum + score, 0) / quizScores.length)
        : 0;
      const totalTopicSlots = Math.max(1, profiles.length * Math.max(1, topics.length));
      const completionPercent = profiles.length && topics.length ? Math.round((completedProgress.length / totalTopicSlots) * 100) : 0;
      const passedModules = moduleResults.filter((row) => row.passed).length;
      const inProgressModules = Math.max(0, moduleResults.length - passedModules);
      const notStartedModules = Math.max(0, profiles.length * modules.length - moduleResults.length);
      const onlineProfiles = profiles.filter((profile) => isOnline(profile.telegram_last_seen_at));

      const studentTrend = countByDay(profiles, "created_at", 7);
      const progressTrend = countByDay(progress, "updated_at", 7);
      const mediaTotalBytes = media.reduce((sum, item) => sum + Number(item.bytes || 0), 0);
      const mediaByKind = {
        images: media.filter((item) => item.kind === "image").length,
        videos: media.filter((item) => item.kind === "video" || item.kind === "round_video").length,
        voices: media.filter((item) => item.kind === "voice").length,
        pdfs: media.filter((item) => item.kind === "pdf" || item.kind === "document").length,
        files: media.length,
      };

      const topicByModule = topics.reduce<Record<string, number>>((acc, topic) => {
        acc[topic.module_id] = (acc[topic.module_id] || 0) + 1;
        return acc;
      }, {});
      const progressByModule = progress.reduce<Record<string, number>>((acc, item) => {
        const topic = topics.find((row) => row.id === item.topic_id);
        if (topic && (item.pdf_completed || item.video_completed || item.quiz_completed)) {
          acc[topic.module_id] = (acc[topic.module_id] || 0) + 1;
        }
        return acc;
      }, {});

      const modulePerformance = modules.map((module) => {
        const total = Math.max(1, topicByModule[module.id] || 0);
        const completed = progressByModule[module.id] || 0;
        const activeStudents = new Set(moduleResults.filter((row) => row.module_id === module.id).map((row) => row.user_id)).size;
        return {
          id: module.id,
          name: module.title,
          students: activeStudents,
          percent: profiles.length && topicByModule[module.id] ? Math.min(100, Math.round((completed / (total * profiles.length)) * 100)) : 0,
        };
      });

      const topStudents = profiles
        .map((profile) => {
          const studentProgress = progress.filter((row) => row.user_id === profile.id);
          const studentResults = moduleResults.filter((row) => row.user_id === profile.id);
          const completed = studentProgress.filter((row) => row.pdf_completed || row.video_completed || row.quiz_completed).length;
          const scores = studentProgress.map((row) => Number(row.quiz_score || 0)).filter((score) => score > 0);
          return {
            id: profile.id,
            name: profile.full_name || "Ismsiz talaba",
            modules: studentResults.filter((row) => row.passed).length,
            averageScore: scores.length ? Math.round(scores.reduce((sum, score) => sum + score, 0) / scores.length) : 0,
            progress: topics.length ? Math.round((completed / topics.length) * 100) : 0,
          };
        })
        .sort((a, b) => b.averageScore - a.averageScore || b.progress - a.progress)
        .slice(0, 5);

      const recentStudents = profiles
        .slice()
        .sort((a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime())
        .slice(0, 4)
        .map((profile) => ({
          id: profile.id,
          name: profile.full_name || "Ismsiz talaba",
          modules: moduleResults.filter((row) => row.user_id === profile.id && row.passed).length,
          progress: topics.length
            ? Math.round(
                (progress.filter((row) => row.user_id === profile.id && (row.pdf_completed || row.video_completed || row.quiz_completed)).length / topics.length) * 100,
              )
            : 0,
          status: isOnline(profile.telegram_last_seen_at) ? "Faol" : "Nofaol",
          joinedAt: new Date(profile.created_at).toLocaleString("uz-UZ", { day: "2-digit", month: "2-digit", year: "numeric", hour: "2-digit", minute: "2-digit" }),
          initials: (profile.full_name || "T")
            .split(" ")
            .map((part: string) => part[0])
            .join("")
            .toUpperCase()
            .slice(0, 2),
        }));

      const activityEvents: OverviewActivity[] = [
        ...profiles.slice(-4).map((profile) => ({
          title: "Yangi talaba qo'shildi",
          detail: `${profile.full_name || "Talaba"} tizimga qo'shildi`,
          time: relativeTime(profile.created_at),
          tone: "blue" as OverviewTone,
        })),
        ...moduleResults.slice(-4).map((result) => ({
          title: result.passed ? "Modul yakunlandi" : "Modul urinishi",
          detail: `${Math.round(Number(result.score || 0))}% natija qayd etildi`,
          time: relativeTime(result.created_at),
          tone: result.passed ? ("green" as OverviewTone) : ("amber" as OverviewTone),
        })),
        ...certificates.slice(-3).map((certificate) => ({
          title: "Sertifikat berildi",
          detail: "Talabaga sertifikat yozildi",
          time: relativeTime(certificate.issued_at),
          tone: "violet" as OverviewTone,
        })),
        ...media.slice(-3).map((item) => ({
          title: "Media yuklandi",
          detail: `${item.kind || "file"} fayl qo'shildi`,
          time: relativeTime(item.created_at),
          tone: "cyan" as OverviewTone,
        })),
      ]
        .sort((a, b) => {
          const aRank = a.time === "hozir" ? 0 : Number(a.time.match(/\d+/)?.[0] || 999);
          const bRank = b.time === "hozir" ? 0 : Number(b.time.match(/\d+/)?.[0] || 999);
          return aRank - bRank;
        })
        .slice(0, 6);

      const metrics: OverviewMetric[] = [
        { title: "Jami talabalar", value: String(profiles.length), delta: lastWeekDelta(profiles), trend: studentTrend.map((row) => row.value), tone: "blue" },
        { title: "Faol foydalanuvchilar", value: String(onlineProfiles.length), delta: percentDelta(onlineProfiles.length, Math.max(0, profiles.length - onlineProfiles.length)), trend: progressTrend.map((row) => row.value), tone: "green" },
        { title: "Modullar soni", value: String(modules.length), delta: lastWeekDelta(modules), trend: countByDay(modules, "created_at", 7).map((row) => row.value), tone: "violet" },
        { title: "Testlar soni", value: String(questions.length), delta: lastWeekDelta(questions), trend: countByDay(questions, "created_at", 7).map((row) => row.value), tone: "rose" },
        { title: "Sertifikatlar", value: String(certificates.length), delta: percentDelta(certificates.filter((row) => Date.now() - new Date(row.issued_at).getTime() <= 7 * 24 * 60 * 60 * 1000).length, certificates.filter((row) => Date.now() - new Date(row.issued_at).getTime() > 7 * 24 * 60 * 60 * 1000).length), trend: countByDay(certificates, "issued_at", 7).map((row) => row.value), tone: "amber" },
        { title: "Faol kurslar", value: String(modules.filter((module) => module.is_published).length), delta: lastWeekDelta(modules), trend: modulePerformance.map((row) => row.percent).slice(0, 7), tone: "blue" },
      ];

      return {
        totals: {
          students: profiles.length,
          online: onlineProfiles.length,
          modules: modules.length,
          publishedModules: modules.filter((module) => module.is_published).length,
          topics: topics.length,
          lessons: lessons.length,
          questions: questions.length,
          certificates: certificates.length,
          mediaFiles: media.length,
          averageScore,
          completionPercent,
          mediaTotalBytes,
        },
        metrics,
        studentTrend,
        activityTrend: lastDays(16).map((key) => ({
          name: formatTrendLabel(key),
          active: progress.filter((row) => toDayKey(row.updated_at) === key).length,
          newUsers: profiles.filter((row) => toDayKey(row.created_at) === key).length,
        })),
        completion: {
          completed: passedModules,
          inProgress: inProgressModules,
          notStarted: notStartedModules,
        },
        activityTypes: {
          video: progress.filter((row) => row.video_completed).length,
          tests: progress.filter((row) => row.quiz_completed).length,
          pdf: progress.filter((row) => row.pdf_completed).length,
          lessons: completedProgress.length,
        },
        testDistribution: {
          passed: moduleResults.filter((row) => row.passed).length,
          inProgress: moduleResults.filter((row) => !row.passed).length,
          notStarted: notStartedModules,
        },
        modulePerformance,
        topStudents,
        recentStudents,
        activityEvents,
        mediaByKind,
        errors: [
          profilesResult.error?.message,
          modulesResult.error?.message,
          topicsResult.error?.message,
          lessonsResult.error?.message,
          questionsResult.error?.message,
          progressResult.error?.message,
          resultsResult.error?.message,
          certificatesResult.error?.message,
          mediaResult.error?.message,
        ].filter(Boolean),
      };
    },
    refetchInterval: 30_000,
  });
}

export function useConversations() {
  return useQuery({
    queryKey: ["conversations"],
    queryFn: async (): Promise<Conversation[]> => {
      const response = await fetch("/api/support/conversations", {
        cache: "no-store",
      });
      if (!response.ok) return [];
      return response.json();
    },
    refetchInterval: 10_000,
  });
}

export function useCertificates() {
  const supabase = createClient();
  return useQuery({
    queryKey: ["certificates"],
    queryFn: async () => {
      const { data, error } = await supabase
        .from("certificates")
        .select(`
          id,
          certificate_url,
          issued_at,
          profiles (
            full_name,
            phone
          ),
          modules (
            title
          )
        `)
        .order("issued_at", { ascending: false });

      if (error || !data) return [];

      return data.map((cert: any) => {
        const profile = cert.profiles;
        const module = cert.modules;
        const issuedDate = new Date(cert.issued_at);
        const dateStr = `${String(issuedDate.getDate()).padStart(2, "0")}.${String(
          issuedDate.getMonth() + 1,
        ).padStart(2, "0")}.${issuedDate.getFullYear()} - ${String(
          issuedDate.getHours(),
        ).padStart(2, "0")}:${String(issuedDate.getMinutes()).padStart(2, "0")}`;

        return {
          id: cert.id,
          student: profile?.full_name || "Talaba",
          email: profile?.phone ? `${profile.phone}@edulab.uz` : "talaba@edulab.uz",
          module: module?.title || "Laboratoriya ishi",
          date: dateStr,
          status: "Berilgan" as const,
          qrCode: `/certificates/verify/${cert.id}`,
          certificateUrl: cert.certificate_url || null,
        };
      });
    },
  });
}

export function useMediaLibrary() {
  const supabase = createClient();
  return useQuery({
    queryKey: ["media-library"],
    queryFn: async () => {
      const [mediaResult, lessonsResult] = await Promise.all([
        supabase
          .from("media_library")
          .select("*")
          .order("created_at", { ascending: false }),
        supabase
          .from("lessons")
          .select(`
            id,
            title,
            kind,
            file_url,
            duration_seconds,
            created_at,
            topics (
              title,
              modules (
                title
              )
            )
          `)
          .in("kind", ["pdf", "video"])
          .not("file_url", "is", null)
          .order("created_at", { ascending: false }),
      ]);

      const mediaRows = mediaResult.error ? [] : mediaResult.data ?? [];
      const lessonRows = lessonsResult.error ? [] : lessonsResult.data ?? [];

      const mediaItems: MediaItem[] = mediaRows.map((item) => ({
        id: item.id,
        name: item.original_filename || "fayl",
        publicId: item.public_id,
        secureUrl: item.secure_url,
        resourceType: item.resource_type,
        format: item.format,
        kind: item.kind as any,
        bytes: Number(item.bytes || 0),
        duration: item.duration ? Number(item.duration) : undefined,
        width: item.width || undefined,
        height: item.height || undefined,
        createdAt: new Date(item.created_at).toLocaleString(),
        uploadedBy: "Admin",
        usedIn: Array.isArray(item.metadata?.usedIn) ? item.metadata.usedIn : [],
        previewUrl: item.kind === "image" ? item.secure_url : undefined,
      }));

      const lessonItems: MediaItem[] = lessonRows
        .filter((lesson) => Boolean(lesson.file_url))
        .map((lesson) => {
          const url = String(lesson.file_url || "");
          const topic = Array.isArray(lesson.topics) ? lesson.topics[0] : lesson.topics;
          const module = Array.isArray(topic?.modules) ? topic.modules[0] : topic?.modules;
          const format = detectFileFormat(url, lesson.kind);

          return {
            id: `lesson:${lesson.id}`,
            name: lesson.title || fileNameFromUrl(url) || (lesson.kind === "video" ? "Video dars" : "PDF dars"),
            publicId: `lesson:${lesson.id}`,
            secureUrl: url,
            resourceType: lesson.kind === "video" ? "video" : "raw",
            format,
            kind: lesson.kind as any,
            bytes: 0,
            duration: lesson.duration_seconds ? Number(lesson.duration_seconds) : undefined,
            width: undefined,
            height: undefined,
            createdAt: new Date(lesson.created_at).toLocaleString(),
            uploadedBy: "Mavzu",
            usedIn: [
              module?.title ? `Modul: ${module.title}` : null,
              topic?.title ? `Mavzu: ${topic.title}` : null,
            ].filter(Boolean) as string[],
            previewUrl: undefined,
          };
        });

      return [...mediaItems, ...lessonItems].sort(
        (a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime(),
      );
    },
  });
}

function fileNameFromUrl(value: string) {
  try {
    const url = new URL(value);
    const lastSegment = url.pathname.split("/").filter(Boolean).pop();
    return lastSegment ? decodeURIComponent(lastSegment) : "";
  } catch {
    return value.split("/").filter(Boolean).pop() || "";
  }
}

function detectFileFormat(url: string, kind: string) {
  const lower = url.toLowerCase();
  if (lower.includes("youtube.com") || lower.includes("youtu.be")) return "youtube";
  const cleanPath = lower.split("?")[0] || "";
  const extension = cleanPath.split(".").pop();
  if (extension && extension !== cleanPath && extension.length <= 8) return extension;
  return kind === "video" ? "video" : "pdf";
}

export function useMediaStats() {
  const supabase = createClient();
  return useQuery({
    queryKey: ["media-stats"],
    queryFn: async () => {
      const { data, error } = await supabase.from("media_library").select("kind");
      if (error || !data) return [
        { title: "Rasmlar", value: "0", hint: "Jami fayllar ichida 0%", tone: "blue" as const, icon: ImageIcon },
        { title: "Videolar", value: "0", hint: "Jami fayllar ichida 0%", tone: "violet" as const, icon: Video },
        { title: "PDF fayllar", value: "0", hint: "Jami fayllar ichida 0%", tone: "red" as const, icon: FileText },
        { title: "Boshqalar", value: "0", hint: "Jami fayllar ichida 0%", tone: "blue" as const, icon: FileArchive },
      ];

      const images = data.filter((d) => d.kind === "image").length;
      const videos = data.filter((d) => d.kind === "video" || d.kind === "round_video").length;
      const pdfs = data.filter((d) => d.kind === "pdf" || d.kind === "document").length;
      const others = data.length - (images + videos + pdfs);
      const total = data.length || 1;

      return [
        {
          title: "Rasmlar",
          value: String(images),
          hint: `Jami fayllar ichida ${Math.round((images / total) * 100)}%`,
          tone: "blue" as const,
          icon: ImageIcon,
        },
        {
          title: "Videolar",
          value: String(videos),
          hint: `Jami fayllar ichida ${Math.round((videos / total) * 100)}%`,
          tone: "violet" as const,
          icon: Video,
        },
        {
          title: "PDF fayllar",
          value: String(pdfs),
          hint: `Jami fayllar ichida ${Math.round((pdfs / total) * 100)}%`,
          tone: "red" as const,
          icon: FileText,
        },
        {
          title: "Boshqalar",
          value: String(others),
          hint: `Jami fayllar ichida ${Math.round((others / total) * 100)}%`,
          tone: "blue" as const,
          icon: FileArchive,
        },
      ];
    },
  });
}

export function useRoles() {
  return useQuery({
    queryKey: ["roles"],
    queryFn: async () => roles,
  });
}

export function usePermissions() {
  return useQuery({
    queryKey: ["permissions"],
    queryFn: async () => permissions,
  });
}

export function useModules() {
  const supabase = createClient();
  return useQuery({
    queryKey: ["modules"],
    queryFn: async () => {
      const { data, error } = await supabase
        .from("modules")
        .select("*")
        .order("order_index", { ascending: true });
      if (error) throw error;
      return data || [];
    },
  });
}

export function useCreateModule() {
  const supabase = createClient();
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async (payload: any) => {
      const { data, error } = await supabase
        .from("modules")
        .insert([payload])
        .select()
        .single();
      if (error) throw error;
      return data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["modules"] });
      queryClient.invalidateQueries({ queryKey: ["analytics-stats"] });
    },
  });
}

export function useUpdateModule() {
  const supabase = createClient();
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async ({ id, ...payload }: { id: string; [key: string]: any }) => {
      const { data, error } = await supabase
        .from("modules")
        .update(payload)
        .eq("id", id)
        .select()
        .single();
      if (error) throw error;
      return data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["modules"] });
    },
  });
}

export function useDeleteModule() {
  const supabase = createClient();
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async (id: string) => {
      const { error } = await supabase
        .from("modules")
        .delete()
        .eq("id", id);
      if (error) throw error;
      return id;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["modules"] });
      queryClient.invalidateQueries({ queryKey: ["analytics-stats"] });
    },
  });
}

export function useTopics(moduleId?: string) {
  const supabase = createClient();
  return useQuery({
    queryKey: ["topics", moduleId],
    queryFn: async () => {
      let query = supabase
        .from("topics")
        .select("*")
        .order("order_index", { ascending: true });
      if (moduleId) {
        query = query.eq("module_id", moduleId);
      }
      const { data, error } = await query;
      if (error) throw error;
      return data || [];
    },
  });
}

export function useCreateTopic() {
  const supabase = createClient();
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async (payload: any) => {
      const { data, error } = await supabase
        .from("topics")
        .insert([payload])
        .select()
        .single();
      if (error) throw error;
      return data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["topics"] });
      queryClient.invalidateQueries({ queryKey: ["analytics-stats"] });
    },
  });
}

export function useUpdateTopic() {
  const supabase = createClient();
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async ({ id, ...payload }: { id: string; [key: string]: any }) => {
      const { data, error } = await supabase
        .from("topics")
        .update(payload)
        .eq("id", id)
        .select()
        .single();
      if (error) throw error;
      return data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["topics"] });
    },
  });
}

export function useDeleteTopic() {
  const supabase = createClient();
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async (id: string) => {
      const { error } = await supabase
        .from("topics")
        .delete()
        .eq("id", id);
      if (error) throw error;
      return id;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["topics"] });
      queryClient.invalidateQueries({ queryKey: ["analytics-stats"] });
    },
  });
}

export function useLessons(topicId?: string, kind?: "pdf" | "text" | "video") {
  const supabase = createClient();
  return useQuery({
    queryKey: ["lessons", topicId, kind],
    queryFn: async () => {
      let query = supabase
        .from("lessons")
        .select("*")
        .order("order_index", { ascending: true });
      if (topicId) {
        query = query.eq("topic_id", topicId);
      }
      if (kind) {
        query = query.eq("kind", kind);
      }
      const { data, error } = await query;
      if (error) throw error;
      return data || [];
    },
  });
}

export function useCreateLesson() {
  const supabase = createClient();
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async (payload: any) => {
      const { data, error } = await supabase
        .from("lessons")
        .insert([payload])
        .select()
        .single();
      if (error) throw error;
      return data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["lessons"] });
    },
  });
}

export function useUpdateLesson() {
  const supabase = createClient();
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async ({ id, ...payload }: { id: string; [key: string]: any }) => {
      const { data, error } = await supabase
        .from("lessons")
        .update(payload)
        .eq("id", id)
        .select()
        .single();
      if (error) throw error;
      return data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["lessons"] });
    },
  });
}

export function useDeleteLesson() {
  const supabase = createClient();
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async (id: string) => {
      const { error } = await supabase
        .from("lessons")
        .delete()
        .eq("id", id);
      if (error) throw error;
      return id;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["lessons"] });
    },
  });
}

export function useQuizQuestions(type?: "topic" | "module", targetId?: string) {
  const supabase = createClient();
  return useQuery({
    queryKey: ["quiz-questions", type, targetId],
    queryFn: async () => {
      let query = supabase
        .from("quiz_questions")
        .select("*")
        .order("created_at", { ascending: false });
      if (type === "topic" && targetId) {
        query = query.eq("topic_id", targetId);
      } else if (type === "module" && targetId) {
        query = query.eq("module_id", targetId).is("topic_id", null);
      }
      const { data, error } = await query;
      if (error) throw error;
      return data || [];
    },
  });
}

export function useCreateQuestion() {
  const supabase = createClient();
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async (payload: any) => {
      const { data, error } = await supabase
        .from("quiz_questions")
        .insert([payload])
        .select()
        .single();
      if (error) throw error;
      return data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["quiz-questions"] });
      queryClient.invalidateQueries({ queryKey: ["analytics-stats"] });
    },
  });
}

export function useUpdateQuestion() {
  const supabase = createClient();
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async ({ id, ...payload }: { id: string; [key: string]: any }) => {
      const { data, error } = await supabase
        .from("quiz_questions")
        .update(payload)
        .eq("id", id)
        .select()
        .single();
      if (error) throw error;
      return data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["quiz-questions"] });
    },
  });
}

export function useDeleteQuestion() {
  const supabase = createClient();
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async (id: string) => {
      const { error } = await supabase
        .from("quiz_questions")
        .delete()
        .eq("id", id);
      if (error) throw error;
      return id;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["quiz-questions"] });
      queryClient.invalidateQueries({ queryKey: ["analytics-stats"] });
    },
  });
}
