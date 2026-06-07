"use client";

import { useState, useEffect, useMemo } from "react";
import { 
  Plus, Pencil, Trash2, Loader2, Video, BookOpen, Search, 
  HelpCircle, Play, UploadCloud, Link2, CheckCircle2, Clock, 
  Eye, ArrowRight, Upload, ChevronRight, PlayCircle
} from "lucide-react";
import { PageHeader } from "@/components/layout/page-header";
import { Button } from "@/components/ui/button";
import { Input, Textarea, Select } from "@/components/ui/input";
import { Skeleton } from "@/components/ui/skeleton";
import { Card, CardContent } from "@/components/ui/card";
import { ConfirmDialog } from "@/components/ui/confirm-dialog";
import { useModules, useTopics, useLessons, useCreateLesson, useUpdateLesson, useDeleteLesson } from "@/hooks/use-admin-data";
import { toast } from "sonner";
import { createClient } from "@/lib/supabase/client";

function Badge({ variant, children, className }: { variant: "success" | "slate" | "destructive" | "warning" | "blue" | "indigo" | "fuchsia" | "purple"; children: React.ReactNode; className?: string }) {
  return (
    <span className={`inline-flex items-center rounded-full px-2.5 py-1 text-[10px] uppercase tracking-wider font-bold ${
      variant === "success" ? "bg-emerald-500/10 text-emerald-600 border border-emerald-500/20" :
      variant === "destructive" ? "bg-red-500/10 text-red-600 border border-red-500/20" :
      variant === "warning" ? "bg-amber-500/10 text-amber-600 border border-amber-500/20" :
      variant === "blue" ? "bg-blue-500/10 text-blue-600 border border-blue-500/20" :
      variant === "indigo" ? "bg-indigo-500/10 text-indigo-600 border border-indigo-500/20" :
      variant === "fuchsia" ? "bg-fuchsia-500/10 text-fuchsia-600 border border-fuchsia-500/20" :
      variant === "purple" ? "bg-purple-500/10 text-purple-600 border border-purple-500/20" :
      "bg-slate-500/10 text-slate-600 border border-slate-500/20"
    } ${className}`}>
      {children}
    </span>
  );
}

type VideoChapterDraft = {
  id: string;
  time: string;
  title: string;
};

type VideoChapterPayload = {
  time_seconds: number;
  title: string;
};

const DEFAULT_VIDEO_CHAPTERS: Array<Omit<VideoChapterDraft, "id">> = [
  { time: "00:00", title: "Kirish" },
  { time: "00:36", title: "Klinik laboratoriya vazifalari" },
  { time: "01:12", title: "Laboratoriya bo'limlari" },
  { time: "01:48", title: "Laboratoriya xodimlari" },
  { time: "02:24", title: "Xulosa" },
];

let chapterDraftCounter = 0;

function createChapterDraft(input: Omit<VideoChapterDraft, "id">): VideoChapterDraft {
  chapterDraftCounter += 1;
  return {
    id: `chapter-${Date.now()}-${chapterDraftCounter}`,
    ...input,
  };
}

function secondsToChapterTime(value: unknown) {
  const secondsValue = typeof value === "number" && Number.isFinite(value) ? Math.max(0, Math.round(value)) : 0;
  const minutes = Math.floor(secondsValue / 60);
  const seconds = secondsValue % 60;
  return `${String(minutes).padStart(2, "0")}:${String(seconds).padStart(2, "0")}`;
}

function parseChapterTime(value: string) {
  const trimmed = value.trim();
  if (!trimmed) return 0;

  const numeric = Number(trimmed);
  if (Number.isFinite(numeric)) return Math.max(0, Math.round(numeric));

  const parts = trimmed.split(":").map((part) => Number(part.trim()));
  if (parts.some((part) => !Number.isFinite(part))) return 0;

  if (parts.length === 2) {
    return Math.max(0, Math.round(parts[0] * 60 + parts[1]));
  }

  if (parts.length === 3) {
    return Math.max(0, Math.round(parts[0] * 3600 + parts[1] * 60 + parts[2]));
  }

  return 0;
}

function normalizeChapterDrafts(value: unknown): VideoChapterDraft[] {
  if (!Array.isArray(value)) {
    return DEFAULT_VIDEO_CHAPTERS.map(createChapterDraft);
  }

  const chapters = value
    .map((item) => {
      if (!item || typeof item !== "object") return null;
      const record = item as Record<string, unknown>;
      const title = String(record.title ?? record.label ?? "").trim();
      if (!title) return null;
      const seconds =
        typeof record.time_seconds === "number"
          ? record.time_seconds
          : typeof record.seconds === "number"
            ? record.seconds
            : typeof record.start_seconds === "number"
              ? record.start_seconds
              : parseChapterTime(String(record.time ?? "0"));

      return createChapterDraft({
        time: secondsToChapterTime(seconds),
        title,
      });
    })
    .filter((chapter): chapter is VideoChapterDraft => chapter !== null);

  return chapters.length > 0 ? chapters : DEFAULT_VIDEO_CHAPTERS.map(createChapterDraft);
}

function buildChapterPayload(chapters: VideoChapterDraft[]): VideoChapterPayload[] {
  return chapters
    .map((chapter) => ({
      time_seconds: parseChapterTime(chapter.time),
      title: chapter.title.trim(),
    }))
    .filter((chapter) => chapter.title.length > 0)
    .sort((a, b) => a.time_seconds - b.time_seconds);
}

export function VideosPage() {
  const supabase = createClient();
  const { data: modules, isLoading: isModulesLoading } = useModules();
  
  const [filterModuleId, setFilterModuleId] = useState("");
  const [filterTopicId, setFilterTopicId] = useState("");
  const [videoTypeFilter, setVideoTypeFilter] = useState("all"); 
  const [searchTerm, setSearchTerm] = useState("");

  const { data: topics, isLoading: isTopicsLoading } = useTopics(filterModuleId || undefined);
  const { data: lessons, isLoading: isLessonsLoading } = useLessons(filterTopicId || undefined);

  const createLessonMutation = useCreateLesson();
  const updateLessonMutation = useUpdateLesson();
  const deleteLessonMutation = useDeleteLesson();

  const [modalOpen, setModalOpen] = useState(false);
  const [editingLesson, setEditingLesson] = useState<any>(null);
  const [deleteConfirm, setDeleteConfirm] = useState<{ open: boolean; id: string | null }>({ open: false, id: null });

  // Form states
  const [step, setStep] = useState(1);
  const [formModuleId, setFormModuleId] = useState("");
  const [formTopicId, setFormTopicId] = useState("");
  const [title, setTitle] = useState("");
  const [description, setDescription] = useState("");
  const [videoKind, setVideoKind] = useState<"uploaded" | "youtube" | "external">("uploaded");
  const [fileUrl, setFileUrl] = useState("");
  const [durationMinutes, setDurationMinutes] = useState(15);
  const [orderIndex, setOrderIndex] = useState(1);
  
  // Extra settings state
  const [visibility, setVisibility] = useState("Published");
  const [category, setCategory] = useState("Nazarariy");
  const [difficulty, setDifficulty] = useState("Boshlang‘ich");
  const [tags, setTags] = useState("");
  const [chapters, setChapters] = useState<VideoChapterDraft[]>(() => normalizeChapterDrafts(undefined));

  const { data: formTopics } = useTopics(formModuleId || undefined);

  useEffect(() => {
    setFilterTopicId("");
  }, [filterModuleId]);

  const openCreateModal = (forcedKind?: "uploaded" | "youtube" | "external") => {
    setEditingLesson(null);
    setFormModuleId(filterModuleId || (modules?.[0]?.id || ""));
    setFormTopicId(filterTopicId || "");
    setTitle("");
    setDescription("");
    setVideoKind(forcedKind || "uploaded");
    setFileUrl("");
    setDurationMinutes(15);
    setCategory("Nazarariy");
    setDifficulty("Boshlang‘ich");
    setTags("");
    setChapters(normalizeChapterDrafts(undefined));
    setOrderIndex((lessons?.filter((l: any) => l.kind === "video").length || 0) + 1);
    setStep(1);
    setModalOpen(true);
  };

  const openEditModal = (lesson: any) => {
    setEditingLesson(lesson);
    const assocTopic = topics?.find((t: any) => t.id === lesson.topic_id);
    setFormModuleId(assocTopic?.module_id || "");
    setFormTopicId(lesson.topic_id || "");
    setTitle(lesson.title || "");
    setDescription(lesson.body || "");
    
    const isYoutube = (lesson.file_url || "").toLowerCase().includes("youtube.com") || (lesson.file_url || "").toLowerCase().includes("youtu.be");
    const isExternal = (lesson.file_url || "").toLowerCase().includes("drive.google.com") || (lesson.file_url || "").toLowerCase().includes("dropbox.com");
    setVideoKind(isYoutube ? "youtube" : isExternal ? "external" : "uploaded");
    
    setFileUrl(lesson.file_url || "");
    setDurationMinutes(Math.round((lesson.duration_seconds || 0) / 60));
    setOrderIndex(lesson.order_index || 1);
    setChapters(normalizeChapterDrafts(lesson.chapters));
    setStep(1);
    setModalOpen(true);
  };

  const handleSubmit = async (e?: React.FormEvent) => {
    if (e) e.preventDefault();
    if (!title.trim()) {
      toast.error("Video nomini kiriting");
      return;
    }
    if (!formTopicId) {
      toast.error("Mavzuni tanlang");
      return;
    }
    if (!fileUrl.trim()) {
      toast.error("Video manzilini kiriting");
      return;
    }

    const payload = {
      topic_id: formTopicId,
      kind: "video",
      title,
      body: description || null,
      file_url: fileUrl,
      duration_seconds: Number(durationMinutes) * 60,
      chapters: buildChapterPayload(chapters),
      order_index: Number(orderIndex),
    };

    try {
      if (editingLesson) {
        await updateLessonMutation.mutateAsync({ id: editingLesson.id, ...payload });
        toast.success("Video dars muvaffaqiyatli yangilandi");
      } else {
        await createLessonMutation.mutateAsync(payload);
        toast.success("Yangi video dars muvaffaqiyatli qo'shildi");
      }
      setModalOpen(false);
    } catch (err: any) {
      toast.error(err.message || "Xatolik yuz berdi");
    }
  };

  const handleDeleteConfirm = async () => {
    if (!deleteConfirm.id) return;
    try {
      await deleteLessonMutation.mutateAsync(deleteConfirm.id);
      toast.success("Video dars muvaffaqiyatli o'chirildi");
    } catch (err: any) {
      toast.error(err.message || "O'chirishda xatolik yuz berdi");
    } finally {
      setDeleteConfirm({ open: false, id: null });
    }
  };

  const filteredVideos = useMemo(() => {
    if (!lessons) return [];
    
    const videoLessons = lessons.filter((l: any) => l.kind === "video");
    
    return videoLessons.filter((l: any) => {
      const isYoutube = (l.file_url || "").toLowerCase().includes("youtube.com") || (l.file_url || "").toLowerCase().includes("youtu.be");
      const kindMatches = videoTypeFilter === "all" || 
        (videoTypeFilter === "youtube" && isYoutube) ||
        (videoTypeFilter === "uploaded" && !isYoutube);

      const matchesSearch = l.title.toLowerCase().includes(searchTerm.toLowerCase()) || 
        (l.body || "").toLowerCase().includes(searchTerm.toLowerCase());

      return kindMatches && matchesSearch;
    }).sort((a: any, b: any) => (a.order_index || 0) - (b.order_index || 0));
  }, [lessons, videoTypeFilter, searchTerm]);

  const stats = useMemo(() => {
    if (!lessons) return { total: 0, uploaded: 0, youtube: 0, totalDuration: "0s", views: 0 };
    
    const videoLessons = lessons.filter((l: any) => l.kind === "video");
    const total = videoLessons.length;
    
    const youtube = videoLessons.filter((l: any) => (l.file_url || "").toLowerCase().includes("youtube.com") || (l.file_url || "").toLowerCase().includes("youtu.be")).length;
    const uploaded = total - youtube;
    
    const totalSeconds = videoLessons.reduce((acc: number, l: any) => acc + (l.duration_seconds || 0), 0);
    const hours = Math.floor(totalSeconds / 3600);
    const minutes = Math.floor((totalSeconds % 3600) / 60);
    const totalDuration = hours > 0 ? `${hours}s ${minutes}d` : `${minutes} daqiqa`;
    
    const views = videoLessons.reduce((acc: number, l: any) => acc + (l.title.length * 23 % 200) + 15, 0);

    return { total, uploaded, youtube, totalDuration, views };
  }, [lessons]);

  const selectedTopic = topics?.find((t: any) => t.id === filterTopicId);
  const topicTitle = selectedTopic ? selectedTopic.title : "Barcha mavzular";
  const chapterPreview = useMemo(() => buildChapterPayload(chapters), [chapters]);

  // Function to extract youtube id for thumbnail preview
  const getYoutubeVideoId = (url: string) => {
    if (!url) return null;
    const regExp = /^.*(youtu.be\/|v\/|u\/\w\/|embed\/|watch\?v=|&v=)([^#&?]*).*/;
    const match = url.match(regExp);
    return (match && match[2].length === 11) ? match[2] : null;
  };

  const addChapter = () => {
    setChapters((previous) => {
      const sorted = buildChapterPayload(previous);
      const last = sorted[sorted.length - 1];
      return [
        ...previous,
        createChapterDraft({
          time: secondsToChapterTime((last?.time_seconds ?? 0) + 60),
          title: "",
        }),
      ];
    });
  };

  const updateChapter = (id: string, key: "time" | "title", value: string) => {
    setChapters((previous) => previous.map((chapter) => (chapter.id === id ? { ...chapter, [key]: value } : chapter)));
  };

  const removeChapter = (id: string) => {
    setChapters((previous) => (previous.length <= 1 ? previous : previous.filter((chapter) => chapter.id !== id)));
  };

  return (
    <div className="min-h-screen bg-slate-50/50 pb-20">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 mb-8">
        <div>
          <div className="flex items-center gap-1.5 text-[10px] font-bold text-slate-400 uppercase tracking-wider mb-2">
            <span>Mavzular</span> <ChevronRight className="size-3" />
            <span className="text-blue-600 font-extrabold">{topicTitle}</span> <ChevronRight className="size-3" />
            <span>Videolar</span>
          </div>
          <h1 className="text-3xl font-black text-slate-900 flex items-center gap-2">
            Video Darslar
          </h1>
        </div>
        
        <Button onClick={() => openCreateModal()} className="flex gap-2 bg-blue-600 hover:bg-blue-700 text-white shadow-lg shadow-blue-500/20 rounded-lg px-5 h-11 transition-all ">
          <Plus className="size-5" />
          Yangi Video
        </Button>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-12 gap-6 mb-8">
        <div className="md:col-span-4 lg:col-span-4 bg-white border border-slate-200 shadow-sm rounded-lg p-5 flex flex-col justify-center gap-4">
          <div className="space-y-2">
            <p className="text-[10px] font-bold text-slate-400 uppercase tracking-wider">Modulni tanlang</p>
            <Select 
              value={filterModuleId} 
              onChange={(e) => setFilterModuleId(e.target.value)}
              className="h-11 w-full bg-slate-50/50 border-transparent focus:bg-white rounded-lg font-bold text-slate-700"
            >
              <option value="">Barcha Modullar</option>
              {modules?.map((m: any) => <option key={m.id} value={m.id}>{m.title}</option>)}
            </Select>
          </div>
          <div className="space-y-2">
            <p className="text-[10px] font-bold text-slate-400 uppercase tracking-wider">Mavzuni tanlang</p>
            <Select 
              value={filterTopicId} 
              onChange={(e) => setFilterTopicId(e.target.value)}
              disabled={!filterModuleId || isTopicsLoading}
              className="h-11 w-full bg-slate-50/50 border-transparent focus:bg-white rounded-lg font-bold text-slate-700 disabled:opacity-50"
            >
              <option value="">Barcha Mavzular</option>
              {topics?.map((t: any) => <option key={t.id} value={t.id}>{t.title}</option>)}
            </Select>
          </div>
        </div>

        <div className="md:col-span-8 lg:col-span-8 grid grid-cols-2 sm:grid-cols-4 gap-4">
          <div className="bg-white border border-slate-200 shadow-sm rounded-lg p-4 flex flex-col justify-center items-center text-center">
            <div className="size-10 rounded-full bg-slate-100 text-slate-600 flex items-center justify-center mb-2"><Video className="size-5" /></div>
            <p className="text-2xl font-black text-slate-900">{stats.total}</p>
            <p className="text-[10px] font-bold text-slate-500 uppercase tracking-wider mt-1">Jami Videolar</p>
          </div>
          <div className="bg-white border border-slate-200 shadow-sm rounded-lg p-4 flex flex-col justify-center items-center text-center">
            <div className="size-10 rounded-full bg-red-50 text-red-600 flex items-center justify-center mb-2"><Play className="size-5 ml-1" /></div>
            <p className="text-2xl font-black text-slate-900">{stats.youtube}</p>
            <p className="text-[10px] font-bold text-slate-500 uppercase tracking-wider mt-1">YouTube</p>
          </div>
          <div className="bg-white border border-slate-200 shadow-sm rounded-lg p-4 flex flex-col justify-center items-center text-center">
            <div className="size-10 rounded-full bg-blue-50 text-blue-600 flex items-center justify-center mb-2"><UploadCloud className="size-5" /></div>
            <p className="text-2xl font-black text-slate-900">{stats.uploaded}</p>
            <p className="text-[10px] font-bold text-slate-500 uppercase tracking-wider mt-1">Yuklangan</p>
          </div>
          <div className="bg-white border border-slate-200 shadow-sm rounded-lg p-4 flex flex-col justify-center items-center text-center">
            <div className="size-10 rounded-full bg-emerald-50 text-emerald-600 flex items-center justify-center mb-2"><Clock className="size-5" /></div>
            <p className="text-2xl font-black text-slate-900">{stats.totalDuration}</p>
            <p className="text-[10px] font-bold text-slate-500 uppercase tracking-wider mt-1">Umumiy Vaqt</p>
          </div>
        </div>
      </div>

      <div className="bg-white border border-slate-200 shadow-sm rounded-lg p-3 flex flex-wrap items-center gap-3 mb-8">
        <div className="relative flex-1 min-w-[250px]">
          <Search className="absolute left-4 top-1/2 -translate-y-1/2 size-5 text-slate-400" />
          <Input 
            placeholder="Videolarni izlash..." 
            className="pl-11 h-12 w-full bg-slate-50/50 border-transparent hover:border-slate-200 focus:border-blue-500 rounded-lg transition-all"
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
          />
        </div>
        <div className="h-8 w-px bg-slate-200 hidden md:block"></div>
        <Select value={videoTypeFilter} onChange={(e: any) => setVideoTypeFilter(e.target.value)} className="h-12 w-full md:w-[180px] bg-slate-50/50 border-transparent rounded-lg font-medium text-slate-700">
          <option value="all">Barcha Turlar</option>
          <option value="youtube">Faqat YouTube</option>
          <option value="uploaded">Faqat Yuklangan</option>
        </Select>
      </div>

      {/* Premium Table View */}
      {isLessonsLoading ? (
        <Card className="rounded-lg border border-slate-200 shadow-sm overflow-hidden">
          <div className="p-6 flex flex-col gap-4">
            {[1, 2, 3].map(i => <Skeleton key={i} className="h-16 w-full rounded-lg" />)}
          </div>
        </Card>
      ) : !filteredVideos.length ? (
        <div className="flex flex-col items-center justify-center py-20 px-4 bg-white rounded-lg border border-dashed border-slate-200">
          <div className="size-24 bg-blue-50 rounded-full flex items-center justify-center mb-6">
            <Video className="size-10 text-blue-500" />
          </div>
          <h3 className="text-2xl font-black text-slate-900 mb-2">Videolar Topilmadi</h3>
          <p className="text-slate-500 text-center max-w-md mb-8">
            Bu mavzu uchun hali hech qanday video dars qo'shilmagan.
          </p>
          <Button onClick={() => openCreateModal()} className="rounded-lg px-6 h-12 bg-blue-600 hover:bg-blue-700 text-white font-bold tracking-wide">
            <Plus className="size-5 mr-2" /> Birinchi Videoni Qo'shish
          </Button>
        </div>
      ) : (
        <Card className="rounded-lg border border-slate-200 shadow-sm overflow-hidden bg-white animate-in fade-in-50 duration-200">
          <div className="overflow-x-auto edulab-scrollbar">
            <table className="w-full text-sm">
              <thead className="bg-slate-50 text-left text-[10px] font-black uppercase text-slate-400 tracking-wider border-b border-slate-100">
                <tr>
                  <th className="px-6 py-5 w-16 text-center">#</th>
                  <th className="px-6 py-5 min-w-[280px]">Video Nomi</th>
                  <th className="px-6 py-5 text-center w-36">Turi</th>
                  <th className="px-6 py-5 text-center w-36">Davomiyligi</th>
                  <th className="px-6 py-5 text-center w-32">Holati</th>
                  <th className="px-6 py-5 text-right w-36">Amallar</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-50">
                {filteredVideos.map((video: any, idx: number) => {
                  const isYoutube = (video.file_url || "").toLowerCase().includes("youtube.com") || (video.file_url || "").toLowerCase().includes("youtu.be");
                  const ytId = isYoutube ? getYoutubeVideoId(video.file_url) : null;
                  const thumbUrl = ytId ? `https://img.youtube.com/vi/${ytId}/mqdefault.jpg` : null;

                  return (
                    <tr key={video.id} className="hover:bg-blue-50/30 transition-colors group">
                      <td className="px-6 py-4 text-center">
                        <span className="font-black text-slate-300 group-hover:text-blue-400 transition-colors">{video.order_index}</span>
                      </td>
                      <td className="px-6 py-4">
                        <div className="flex items-center gap-4">
                          <div className="relative w-20 h-12 rounded-lg overflow-hidden shrink-0 shadow-sm border border-slate-100 bg-slate-900 flex items-center justify-center group-hover:shadow-md transition-all">
                            {thumbUrl ? (
                              <img src={thumbUrl} alt={video.title} className="w-full h-full object-cover opacity-80 group-hover:opacity-100 transition-opacity" />
                            ) : (
                              <Video className="size-5 text-slate-400" />
                            )}
                            <div className="absolute inset-0 flex items-center justify-center">
                              <PlayCircle className="size-6 text-white drop-shadow-md opacity-70 group-hover:scale-110 group-hover:opacity-100 transition-all" />
                            </div>
                          </div>
                          <div className="min-w-0">
                            <p className="font-black text-slate-900 truncate text-base group-hover:text-blue-600 transition-colors">{video.title}</p>
                            <p className="text-xs text-slate-400 font-medium truncate mt-0.5 max-w-[200px] sm:max-w-[300px]">
                              {video.body || "Ta'rif kiritilmagan"}
                            </p>
                          </div>
                        </div>
                      </td>
                      <td className="px-6 py-4 text-center">
                        {isYoutube ? (
                          <Badge variant="destructive" className="bg-red-50 text-red-600 border border-red-100"><Play className="size-3 mr-1" /> YouTube</Badge>
                        ) : (
                          <Badge variant="blue" className="bg-blue-50 text-blue-600 border border-blue-100"><UploadCloud className="size-3 mr-1" /> Platforma</Badge>
                        )}
                      </td>
                      <td className="px-6 py-4 text-center">
                        <span className="inline-flex items-center gap-1 font-bold text-slate-600">
                          <Clock className="size-3.5 text-slate-400" />
                          {Math.round((video.duration_seconds || 0) / 60)} daq.
                        </span>
                      </td>
                      <td className="px-6 py-4 text-center">
                        <Badge variant="success">Nashr</Badge>
                      </td>
                      <td className="px-6 py-4">
                        <div className="flex items-center justify-end gap-2 opacity-100 sm:opacity-0 sm:group-hover:opacity-100 transition-opacity">
                          <Button 
                            variant="ghost" 
                            size="icon" 
                            className="size-9 rounded-lg text-slate-400 hover:text-indigo-600 hover:bg-indigo-50"
                            onClick={() => window.open(video.file_url, '_blank')}
                          >
                            <Eye className="size-4.5" />
                          </Button>
                          <Button 
                            onClick={() => openEditModal(video)} 
                            variant="ghost" 
                            size="icon" 
                            className="size-9 rounded-lg text-slate-400 hover:text-blue-600 hover:bg-blue-50"
                          >
                            <Pencil className="size-4.5" />
                          </Button>
                          <Button 
                            onClick={() => setDeleteConfirm({ open: true, id: video.id })} 
                            variant="ghost" 
                            size="icon" 
                            className="size-9 rounded-lg text-slate-400 hover:text-red-600 hover:bg-red-50"
                          >
                            <Trash2 className="size-4.5" />
                          </Button>
                        </div>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        </Card>
      )}

      {/* FULL SCREEN WIZARD MODAL FOR VIDEOS */}
      {modalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-900/60 backdrop-blur-md p-0 sm:p-6 animate-in fade-in duration-300">
          <div className="bg-white sm:rounded-[2.5rem] shadow-2xl w-full h-full sm:h-[90vh] max-w-6xl overflow-hidden flex flex-col md:flex-row animate-in zoom-in-95 slide-in-from-bottom-8 duration-500 relative">
            
            <button onClick={() => setModalOpen(false)} className="md:hidden absolute top-4 right-4 z-50 p-2 bg-white rounded-full shadow-md text-slate-500 hover:text-red-500">
              <Plus className="size-6 rotate-45" />
            </button>

            {/* Left Side: Form Steps */}
            <div className="w-full md:w-3/5 lg:w-1/2 h-full flex flex-col bg-white z-10 overflow-y-auto">
              <div className="px-8 sm:px-12 pt-12 pb-6">
                <h2 className="text-3xl font-black text-slate-900 mb-2">{editingLesson ? "Videoni Tahrirlash" : "Yangi Video Qo'shish"}</h2>
                <p className="text-slate-500">Talabalar uchun yangi video dars joylashtiring.</p>
              </div>

              {/* Step Indicators */}
              <div className="px-8 sm:px-12 mb-8">
                <div className="flex justify-between relative">
                  <div className="absolute left-0 top-1/2 -translate-y-1/2 w-full h-1 bg-slate-100 rounded-full" />
                  <div className="absolute left-0 top-1/2 -translate-y-1/2 h-1 bg-blue-600 rounded-full transition-all duration-500" style={{ width: `${(step - 1) * 100}%` }} />
                  
                  {[1,2,3].map(s => (
                    <button key={s} onClick={() => s < step && setStep(s)} disabled={s > step} className={`relative flex flex-col items-center gap-2 z-10 ${s > step ? 'cursor-not-allowed opacity-50' : 'cursor-pointer'}`}>
                      <div className={`size-10 rounded-full flex items-center justify-center font-black text-sm transition-all duration-300 shadow-sm ${step === s ? 'bg-blue-600 text-white scale-110 ring-4 ring-blue-600/20' : step > s ? 'bg-emerald-500 text-white' : 'bg-white text-slate-400 border-2 border-slate-200'}`}>
                        {step > s ? <CheckCircle2 className="size-5" /> : s}
                      </div>
                    </button>
                  ))}
                </div>
                <div className="flex justify-between mt-3 text-[10px] font-bold uppercase tracking-wider text-slate-400 px-1">
                  <span className={step >= 1 ? 'text-blue-600' : ''}>Asosiy</span>
                  <span className={step >= 2 ? 'text-blue-600' : ''}>Video fayl</span>
                  <span className={step >= 3 ? 'text-blue-600' : ''}>Sozlamalar</span>
                </div>
              </div>

              <div className="flex-1 px-8 sm:px-12 overflow-y-auto pb-32">
                <div className="max-w-md mx-auto w-full">
                  
                  {/* STEP 1 */}
                  {step === 1 && (
                    <div className="space-y-6 animate-in slide-in-from-right-8 fade-in duration-500">
                      <div className="grid gap-2">
                        <label className="text-sm font-bold text-slate-800">Qaysi modulga tegishli? <span className="text-red-500">*</span></label>
                        <Select 
                          value={formModuleId} 
                          onChange={(e) => {
                            setFormModuleId(e.target.value);
                            setFormTopicId("");
                          }}
                          className="h-14 rounded-lg bg-slate-50 border-transparent focus:bg-white focus:border-blue-600 px-5 text-lg font-bold text-slate-700"
                        >
                          <option value="" disabled>Modulni tanlang</option>
                          {modules?.map((m: any) => (
                            <option key={m.id} value={m.id}>{m.title}</option>
                          ))}
                        </Select>
                      </div>

                      <div className="grid gap-2">
                        <label className="text-sm font-bold text-slate-800">Mavzuni tanlang <span className="text-red-500">*</span></label>
                        <Select 
                          value={formTopicId} 
                          onChange={(e) => setFormTopicId(e.target.value)}
                          disabled={!formModuleId}
                          className="h-14 rounded-lg bg-slate-50 border-transparent focus:bg-white focus:border-blue-600 px-5 text-lg font-bold text-slate-700 disabled:opacity-50"
                        >
                          <option value="" disabled>Avval modulni tanlang</option>
                          {formTopics?.map((t: any) => (
                            <option key={t.id} value={t.id}>{t.title}</option>
                          ))}
                        </Select>
                      </div>

                      <div className="grid gap-2">
                        <label className="text-sm font-bold text-slate-800">Video Dars Nomi <span className="text-red-500">*</span></label>
                        <Input
                          placeholder="Masalan: Flexbox bilan ishlash asoslari"
                          value={title}
                          onChange={(e) => setTitle(e.target.value)}
                          className="h-14 rounded-lg bg-slate-50 border-transparent focus:bg-white focus:border-blue-600 px-5 text-lg font-medium transition-all"
                          autoFocus
                        />
                      </div>

                      <div className="grid gap-2">
                        <label className="text-sm font-bold text-slate-800">Qisqacha Ta'rif</label>
                        <Textarea
                          placeholder="Ushbu videoda nimalar o'rgatiladi?"
                          value={description}
                          onChange={(e) => setDescription(e.target.value)}
                          className="h-24 rounded-lg bg-slate-50 border-transparent focus:bg-white focus:border-blue-600 px-5 py-4 text-base font-medium transition-all resize-none"
                        />
                      </div>
                    </div>
                  )}

                  {/* STEP 2 */}
                  {step === 2 && (
                    <div className="space-y-6 animate-in slide-in-from-right-8 fade-in duration-500">
                      <div className="grid gap-2">
                        <label className="text-sm font-bold text-slate-800">Video Manbasi <span className="text-red-500">*</span></label>
                        <div className="grid grid-cols-2 gap-3">
                          <button
                            type="button"
                            onClick={() => setVideoKind("youtube")}
                            className={`flex flex-col items-center justify-center p-5 rounded-lg border-2 transition-all ${videoKind === "youtube" ? 'bg-red-50 border-red-200 text-red-600 scale-[1.02] shadow-sm' : 'bg-white border-slate-100 text-slate-400 hover:border-slate-200 hover:bg-slate-50'}`}
                          >
                            <Play className="size-8 mb-3" />
                            <span className="text-xs font-black uppercase tracking-wider">YouTube</span>
                          </button>
                          <button
                            type="button"
                            onClick={() => setVideoKind("uploaded")}
                            className={`flex flex-col items-center justify-center p-5 rounded-lg border-2 transition-all ${videoKind === "uploaded" ? 'bg-blue-50 border-blue-200 text-blue-600 scale-[1.02] shadow-sm' : 'bg-white border-slate-100 text-slate-400 hover:border-slate-200 hover:bg-slate-50'}`}
                          >
                            <UploadCloud className="size-8 mb-3" />
                            <span className="text-xs font-black uppercase tracking-wider">Boshqa URL</span>
                          </button>
                        </div>
                      </div>

                      <div className="grid gap-2 mt-4">
                        <label className="text-sm font-bold text-slate-800">
                          {videoKind === "youtube" ? "YouTube Video Havolasi" : "Fayl URL Manzili"} <span className="text-red-500">*</span>
                        </label>
                        <div className="relative">
                          {videoKind === "youtube" ? <Play className="absolute left-4 top-1/2 -translate-y-1/2 size-5 text-red-400" /> : <Link2 className="absolute left-4 top-1/2 -translate-y-1/2 size-5 text-blue-400" />}
                          <Input
                            placeholder={videoKind === "youtube" ? "https://youtube.com/watch?v=..." : "https://.../video.mp4"}
                            value={fileUrl}
                            onChange={(e) => setFileUrl(e.target.value)}
                            className="h-14 rounded-lg bg-slate-50 border-transparent focus:bg-white focus:border-blue-600 pl-12 text-base font-medium transition-all"
                          />
                        </div>
                        {videoKind === "youtube" && fileUrl && getYoutubeVideoId(fileUrl) && (
                           <div className="mt-4 p-2 bg-slate-50 rounded-lg border border-slate-100 flex items-center gap-4">
                             <img src={`https://img.youtube.com/vi/${getYoutubeVideoId(fileUrl)}/default.jpg`} className="w-24 h-16 rounded-lg object-cover" alt="Thumb" />
                             <p className="text-xs font-bold text-emerald-600 flex items-center gap-1"><CheckCircle2 className="size-4" /> Video topildi</p>
                           </div>
                        )}
                      </div>
                    </div>
                  )}

                  {/* STEP 3 */}
                  {step === 3 && (
                    <div className="space-y-6 animate-in slide-in-from-right-8 fade-in duration-500">
                      
                      <div className="grid grid-cols-2 gap-4">
                        <div className="grid gap-2">
                          <label className="text-sm font-bold text-slate-800">Tartib raqami</label>
                          <Input type="number" value={orderIndex} onChange={(e) => setOrderIndex(Number(e.target.value))} min={1} className="h-14 rounded-lg bg-slate-50 border-transparent focus:bg-white focus:border-blue-600 px-5 text-lg font-bold" />
                        </div>
                        <div className="grid gap-2">
                          <label className="text-sm font-bold text-slate-800">Video davomiyligi (Daqiqada)</label>
                          <Input type="number" value={durationMinutes} onChange={(e) => setDurationMinutes(Number(e.target.value))} min={1} className="h-14 rounded-lg bg-slate-50 border-transparent focus:bg-white focus:border-blue-600 px-5 text-lg font-bold" />
                        </div>
                      </div>

                      <div className="rounded-2xl border border-blue-100 bg-blue-50/50 p-4">
                        <div className="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
                          <div>
                            <label className="text-sm font-black text-slate-900">Video bo'limlari</label>
                            <p className="mt-1 text-xs font-semibold leading-relaxed text-slate-500">
                              Student appda video ostida chiqadigan vaqtlar. Masalan: 00:36 - Klinik laboratoriya vazifalari.
                            </p>
                          </div>
                          <Button
                            type="button"
                            variant="secondary"
                            onClick={addChapter}
                            className="h-9 rounded-lg border-blue-200 bg-white text-blue-600 hover:bg-blue-50"
                          >
                            <Plus className="mr-1 size-4" />
                            Qo'shish
                          </Button>
                        </div>
                        <div className="mt-4 space-y-2">
                          {chapters.map((chapter, index) => (
                            <div key={chapter.id} className="grid grid-cols-1 gap-2 sm:grid-cols-[92px_1fr_40px]">
                              <Input
                                value={chapter.time}
                                onChange={(e) => updateChapter(chapter.id, "time", e.target.value)}
                                placeholder="00:00"
                                className="h-11 rounded-lg border-blue-100 bg-white font-black text-blue-600"
                              />
                              <Input
                                value={chapter.title}
                                onChange={(e) => updateChapter(chapter.id, "title", e.target.value)}
                                placeholder={index === 0 ? "Kirish" : "Bo'lim nomi"}
                                className="h-11 rounded-lg border-blue-100 bg-white font-semibold"
                              />
                              <Button
                                type="button"
                                variant="ghost"
                                size="icon"
                                onClick={() => removeChapter(chapter.id)}
                                disabled={chapters.length === 1}
                                className="h-11 w-11 rounded-lg text-slate-400 hover:bg-red-50 hover:text-red-600 disabled:opacity-40"
                              >
                                <Trash2 className="size-4" />
                              </Button>
                            </div>
                          ))}
                        </div>
                      </div>

                      <div className="grid gap-2">
                        <label className="text-sm font-bold text-slate-800">Dars Turini Tanlang</label>
                        <Select value={category} onChange={(e) => setCategory(e.target.value)} className="h-14 rounded-lg bg-slate-50 border-transparent focus:bg-white focus:border-blue-600 px-5 font-bold text-slate-700">
                          <option value="Nazarariy">Nazarariy Dars</option>
                          <option value="Amaliy">Amaliy Mashg'ulot</option>
                          <option value="Mustaqil">Mustaqil Ish</option>
                        </Select>
                      </div>

                      <div className="grid gap-2">
                        <label className="text-sm font-bold text-slate-800">Daraja</label>
                        <Select value={difficulty} onChange={(e) => setDifficulty(e.target.value)} className="h-14 rounded-lg bg-slate-50 border-transparent focus:bg-white focus:border-blue-600 px-5 font-bold text-slate-700">
                          <option value="Boshlang‘ich">Boshlang‘ich</option>
                          <option value="O‘rta">O‘rta</option>
                          <option value="Murakkab">Murakkab</option>
                        </Select>
                      </div>

                      <Button 
                        onClick={handleSubmit} 
                        disabled={createLessonMutation.isPending || updateLessonMutation.isPending}
                        className="h-16 px-12 rounded-full text-lg font-black bg-blue-600 hover:bg-blue-700 text-white shadow-xl shadow-blue-600/20 w-full mt-4"
                      >
                        {(createLessonMutation.isPending || updateLessonMutation.isPending) ? (
                          <Loader2 className="size-6 animate-spin mr-3" />
                        ) : null}
                        {editingLesson ? "Videoni Saqlash" : "Videoni Joylash"}
                      </Button>
                    </div>
                  )}

                </div>
              </div>

              {step < 3 && (
                <div className="absolute bottom-0 left-0 w-full md:w-3/5 lg:w-1/2 p-6 sm:p-8 bg-white border-t border-slate-100 flex justify-between items-center z-20">
                  <Button variant="ghost" onClick={() => {
                    if (step > 1) setStep(s => s - 1);
                    else setModalOpen(false);
                  }} className="text-slate-500 font-bold hover:bg-slate-100 rounded-full px-6 h-12">
                    {step > 1 ? "Ortga" : "Bekor qilish"}
                  </Button>
                  <Button onClick={() => setStep(s => s + 1)} className="rounded-lg px-6 h-12 font-bold bg-blue-600 hover:bg-blue-700 text-white shadow-lg shadow-blue-500/20">
                    Keyingisi <ArrowRight className="size-4 ml-2" />
                  </Button>
                </div>
              )}
            </div>

            {/* Right Side: Visual Preview Area */}
            <div className="hidden md:flex w-2/5 lg:w-1/2 h-full bg-slate-900 flex-col items-center justify-center relative overflow-hidden">
              <div className="absolute inset-0 bg-gradient-to-br from-blue-900/30 via-slate-900 to-black z-0"></div>
              
              <div className="relative z-10 w-full px-12 flex flex-col items-center">
                <div className="w-full bg-black/40 border border-white/10 rounded-lg shadow-xl overflow-hidden ">
                  {/* Fake Video Player */}
                  <div className="aspect-video bg-black relative flex items-center justify-center group cursor-pointer">
                    {videoKind === "youtube" && getYoutubeVideoId(fileUrl) ? (
                      <img src={`https://img.youtube.com/vi/${getYoutubeVideoId(fileUrl)}/maxresdefault.jpg`} className="absolute inset-0 w-full h-full object-cover opacity-80 group-hover:opacity-100 transition-opacity" alt="Preview" />
                    ) : (
                      <div className="absolute inset-0 bg-gradient-to-tr from-slate-900 to-slate-800"></div>
                    )}
                    <div className="size-16 rounded-full bg-blue-600/90 text-white flex items-center justify-center backdrop-blur-md shadow-xl group-hover:scale-110 transition-transform relative z-10">
                      <Play className="size-8 ml-1" />
                    </div>
                    {/* Fake progress bar */}
                    <div className="absolute bottom-0 left-0 w-full h-1.5 bg-white/20">
                      <div className="h-full bg-blue-500 w-1/3"></div>
                    </div>
                  </div>
                  
                  {/* Player Controls & Info */}
                  <div className="p-6">
                    <div className="flex items-center gap-3 mb-4">
                      <Badge variant="blue" className="bg-blue-500/20 text-blue-300 border-transparent">{category}</Badge>
                      <Badge variant="slate" className="bg-white/10 text-slate-300 border-transparent">{difficulty}</Badge>
                    </div>
                    
                    <h3 className="text-xl font-black text-white leading-snug mb-2">
                      {title || "Yangi Video Nomi"}
                    </h3>
                    <p className="text-sm text-slate-400 line-clamp-2 leading-relaxed">
                      {description || "Talabalarga bu video dars nima haqida ekanligini ko'rsatish uchun ta'rif yozing."}
                    </p>
                    
                      <div className="mt-6 flex items-center justify-between text-xs font-bold text-slate-500">
                        <div className="flex items-center gap-2">
                          <Clock className="size-4" />
                          <span>{durationMinutes} daqiqa</span>
                        </div>
                      <div className="flex items-center gap-2">
                        <div className="size-6 rounded-full bg-white/10 flex items-center justify-center"><BookOpen className="size-3" /></div>
                        Mavzu #{orderIndex}
                      </div>
                    </div>

                    {chapterPreview.length > 0 && (
                      <div className="border-t border-white/10 bg-white/[0.03] p-5">
                        <p className="mb-3 text-[10px] font-black uppercase tracking-wider text-blue-200">Video bo'limlari</p>
                        <div className="space-y-2">
                          {chapterPreview.slice(0, 5).map((chapter) => (
                            <div key={`${chapter.time_seconds}-${chapter.title}`} className="flex items-start gap-3 text-xs">
                              <span className="w-12 shrink-0 font-black text-blue-300">{secondsToChapterTime(chapter.time_seconds)}</span>
                              <span className="line-clamp-1 font-semibold text-slate-300">{chapter.title}</span>
                            </div>
                          ))}
                        </div>
                      </div>
                    )}
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      )}

      <ConfirmDialog
        open={deleteConfirm.open}
        title="Videoni o'chirish"
        description="Siz haqiqatan ham ushbu video darsni o'chirmoqchimisiz? Uni qayta tiklash imkonsiz."
        confirmLabel="O'chirish"
        variant="danger"
        loading={deleteLessonMutation.isPending}
        onConfirm={handleDeleteConfirm}
        onCancel={() => setDeleteConfirm({ open: false, id: null })}
      />
    </div>
  );
}
