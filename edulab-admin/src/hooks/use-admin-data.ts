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
import type { Conversation, Student } from "@/lib/types";

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
          status: p.telegram_last_seen_at ? "Faol" : "Nofaol",
          joinedAt,
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

export function useConversations() {
  const supabase = createClient();
  return useQuery({
    queryKey: ["conversations"],
    queryFn: async (): Promise<Conversation[]> => {
      const { data: messages, error } = await supabase
        .from("admin_inbox_messages")
        .select("*")
        .order("created_at", { ascending: true });

      if (error || !messages) return [];

      const conversationsMap = new Map<string, Conversation>();

      for (const msg of messages) {
        const key = msg.sender_user_id || msg.telegram_chat_id || "unknown";
        if (!conversationsMap.has(key)) {
          conversationsMap.set(key, {
            id: key,
            name: msg.sender_name || "Noma'lum foydalanuvchi",
            label: msg.source === "telegram" ? "Telegram" : "Ilova",
            lastMessage: msg.body || "",
            time: new Date(msg.created_at).toLocaleTimeString([], {
              hour: "2-digit",
              minute: "2-digit",
            }),
            unread: msg.is_read ? 0 : 0, // calculated below
            online: false,
            source: msg.source === "telegram" ? "telegram" : "student_app",
            messages: [],
          });
        }

        const conv = conversationsMap.get(key)!;
        conv.lastMessage =
          msg.body ||
          (msg.message_kind === "image"
            ? "Rasm"
            : msg.message_kind === "pdf"
              ? "PDF fayl"
              : "Fayl");
        conv.time = new Date(msg.created_at).toLocaleTimeString([], {
          hour: "2-digit",
          minute: "2-digit",
        });
        if (!msg.is_read) {
          conv.unread += 1;
        }

        conv.messages.push({
          id: msg.id,
          author: "student",
          body: msg.body || "",
          time: new Date(msg.created_at).toLocaleTimeString([], {
            hour: "2-digit",
            minute: "2-digit",
          }),
          kind: (msg.message_kind as any) || "text",
          fileName: msg.attachment_name || undefined,
          fileSize: msg.attachment_size
            ? `${(Number(msg.attachment_size) / (1024 * 1024)).toFixed(1)} MB`
            : undefined,
          previewUrl: msg.attachment_url || undefined,
          read: msg.is_read,
          createdAt: msg.created_at,
        });

        if (msg.admin_reply) {
          conv.messages.push({
            id: `${msg.id}_reply`,
            author: "admin",
            body: msg.admin_reply,
            time: msg.replied_at
              ? new Date(msg.replied_at).toLocaleTimeString([], {
                  hour: "2-digit",
                  minute: "2-digit",
                })
              : conv.time,
            kind: "text",
            read: true,
            createdAt: msg.replied_at || msg.created_at,
          });
        }
      }

      return Array.from(conversationsMap.values());
    },
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
      const { data, error } = await supabase
        .from("media_library")
        .select("*")
        .order("created_at", { ascending: false });

      if (error || !data) return [];

      return data.map((item) => ({
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
        usedIn: item.metadata?.usedIn || [],
        previewUrl: item.kind === "image" ? item.secure_url : undefined,
      }));
    },
  });
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

