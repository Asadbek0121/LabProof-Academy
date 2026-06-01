"use client";

import { useState, useMemo } from "react";
import { Plus, Pencil, Trash2, Eye, EyeOff, Loader2, BookOpen, Layers, FileText, Play, CheckSquare, Clock, Search, UploadCloud, ArrowRight, CheckCircle2, ChevronRight } from "lucide-react";
import { ConfirmDialog } from "@/components/ui/confirm-dialog";
import { PageHeader } from "@/components/layout/page-header";
import { Button } from "@/components/ui/button";
import { Input, Textarea, Select } from "@/components/ui/input";
import { Skeleton } from "@/components/ui/skeleton";
import { Card, CardContent } from "@/components/ui/card";
import { useModules, useTopics, useLessons, useCreateTopic, useUpdateTopic, useDeleteTopic } from "@/hooks/use-admin-data";
import { toast } from "sonner";
import { createClient } from "@/lib/supabase/client";
import { useQuery } from "@tanstack/react-query";

function Badge({ variant, children, className }: { variant: "success" | "slate" | "warning" | "blue" | "indigo" | "purple"; children: React.ReactNode; className?: string }) {
  return (
    <span className={`inline-flex items-center rounded-full px-2.5 py-1 text-[10px] uppercase tracking-wider font-bold ${
      variant === "success" ? "bg-emerald-500/10 text-emerald-600 border border-emerald-500/20" :
      variant === "warning" ? "bg-amber-500/10 text-amber-600 border border-amber-500/20" :
      variant === "blue" ? "bg-blue-500/10 text-blue-600 border border-blue-500/20" :
      variant === "indigo" ? "bg-indigo-500/10 text-indigo-600 border border-indigo-500/20" :
      variant === "purple" ? "bg-purple-500/10 text-purple-600 border border-purple-500/20" :
      "bg-slate-500/10 text-slate-600 border border-slate-500/20"
    } ${className}`}>
      {children}
    </span>
  );
}

export function TopicsPage() {
  const supabase = createClient();
  const { data: modules, isLoading: isModulesLoading } = useModules();
  const [selectedModuleId, setSelectedModuleId] = useState<string>("");

  const { data: topics, isLoading: isTopicsLoading } = useTopics(selectedModuleId || undefined);
  const createTopicMutation = useCreateTopic();
  const updateTopicMutation = useUpdateTopic();
  const deleteTopicMutation = useDeleteTopic();

  const [modalOpen, setModalOpen] = useState(false);
  const [editingTopic, setEditingTopic] = useState<any>(null);
  const [deleteConfirm, setDeleteConfirm] = useState<{ open: boolean; id: string | null }>({ open: false, id: null });

  // Filter States
  const [searchTerm, setSearchTerm] = useState("");
  const [statusFilter, setStatusFilter] = useState("all");

  // Form states
  const [step, setStep] = useState(1);
  const [moduleId, setModuleId] = useState("");
  const [title, setTitle] = useState("");
  const [description, setDescription] = useState("");
  const [orderIndex, setOrderIndex] = useState(1);
  const [coverUrl, setCoverUrl] = useState("");
  const [durationMinutes, setDurationMinutes] = useState(20);
  const [isPublished, setIsPublished] = useState(true);

  // Fetch all lessons & quizzes for count calculations
  const { data: allLessons } = useLessons(undefined);
  const { data: allQuizzes } = useQuery({
    queryKey: ["all-quiz-questions-summary"],
    queryFn: async () => {
      const { data } = await supabase.from("quiz_questions").select("id, topic_id");
      return data || [];
    }
  });

  const selectedModule = modules?.find((m: any) => m.id === selectedModuleId);
  const moduleTitle = selectedModule ? selectedModule.title : "Barcha modullar";

  const stats = useMemo(() => {
    if (!topics) return { total: 0, pdfs: 0, videos: 0, tests: 0, avgMinutes: 0 };
    
    const activeTopicIds = new Set(topics.map((t: any) => t.id));
    const total = topics.length;
    
    const pdfs = allLessons?.filter((l: any) => activeTopicIds.has(l.topic_id) && (l.kind === "pdf" || l.kind === "text")).length || 0;
    const videos = allLessons?.filter((l: any) => activeTopicIds.has(l.topic_id) && l.kind === "video").length || 0;
    const tests = allQuizzes?.filter((q: any) => activeTopicIds.has(q.topic_id)).length || 0;
    
    const totalDurationSeconds = topics.reduce((acc: number, t: any) => acc + (t.duration_seconds || 0), 0);
    const avgMinutes = total ? Math.round((totalDurationSeconds / total) / 60) : 0;
    
    return { total, pdfs, videos, tests, avgMinutes };
  }, [topics, allLessons, allQuizzes]);

  const filteredTopics = useMemo(() => {
    if (!topics) return [];
    return topics.filter((t: any) => {
      const matchesSearch = t.title.toLowerCase().includes(searchTerm.toLowerCase()) || 
        (t.description || "").toLowerCase().includes(searchTerm.toLowerCase());
      
      const matchesStatus = statusFilter === "all" || 
        (statusFilter === "published" && t.is_published) ||
        (statusFilter === "draft" && !t.is_published);
        
      return matchesSearch && matchesStatus;
    });
  }, [topics, searchTerm, statusFilter]);

  const openCreateModal = () => {
    setEditingTopic(null);
    setModuleId(selectedModuleId || (modules?.[0]?.id || ""));
    setTitle("");
    setDescription("");
    setOrderIndex((topics?.length || 0) + 1);
    setCoverUrl("");
    setDurationMinutes(20);
    setIsPublished(true);
    setStep(1);
    setModalOpen(true);
  };

  const openEditModal = (topic: any) => {
    setEditingTopic(topic);
    setModuleId(topic.module_id || "");
    setTitle(topic.title || "");
    setDescription(topic.description || "");
    setOrderIndex(topic.order_index || 1);
    setCoverUrl(topic.cover_url || "");
    setDurationMinutes(Math.round((topic.duration_seconds || 0) / 60));
    setIsPublished(topic.is_published || false);
    setStep(1);
    setModalOpen(true);
  };

  const handleSubmit = async (e?: React.FormEvent) => {
    if (e) e.preventDefault();
    if (!title.trim()) {
      toast.error("Mavzu nomini kiriting");
      return;
    }
    if (!moduleId) {
      toast.error("Modulni tanlang");
      return;
    }

    const payload = {
      module_id: moduleId,
      title,
      description,
      order_index: Number(orderIndex),
      cover_url: coverUrl || "https://images.unsplash.com/photo-1434030216411-0b793f4b4173?w=500&auto=format&fit=crop",
      duration_seconds: Number(durationMinutes) * 60,
      is_published: isPublished,
    };

    try {
      if (editingTopic) {
        await updateTopicMutation.mutateAsync({ id: editingTopic.id, ...payload });
        toast.success("Mavzu muvaffaqiyatli yangilandi");
      } else {
        await createTopicMutation.mutateAsync(payload);
        toast.success("Yangi mavzu muvaffaqiyatli qo'shildi");
      }
      setModalOpen(false);
    } catch (err: any) {
      toast.error(err.message || "Xatolik yuz berdi");
    }
  };

  const handleDeleteConfirm = async () => {
    if (!deleteConfirm.id) return;
    try {
      await deleteTopicMutation.mutateAsync(deleteConfirm.id);
      toast.success("Mavzu muvaffaqiyatli o'chirildi");
    } catch (err: any) {
      toast.error(err.message || "O'chirishda xatolik yuz berdi");
    } finally {
      setDeleteConfirm({ open: false, id: null });
    }
  };

  return (
    <div className="min-h-screen bg-slate-50/50 pb-20">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 mb-8">
        <div>
          <div className="flex items-center gap-1.5 text-[10px] font-bold text-slate-400 uppercase tracking-wider mb-2">
            <span>Modullar</span> <ChevronRight className="size-3" />
            <span className="text-blue-600 font-extrabold">{moduleTitle}</span> <ChevronRight className="size-3" />
            <span>Mavzular</span>
          </div>
          <h1 className="text-3xl font-black text-slate-900 flex items-center gap-2">
            Mavzular (Topics)
          </h1>
        </div>
        
        <Button onClick={openCreateModal} className="flex gap-2 bg-blue-600 hover:bg-blue-700 text-white shadow-lg shadow-blue-500/20 rounded-full px-6 h-11 transition-all hover:scale-105 active:scale-95">
          <Plus className="size-5" />
          Yangi Mavzu
        </Button>
      </div>

      {/* Modern Filter & Stats Bar */}
      <div className="grid grid-cols-1 md:grid-cols-12 gap-6 mb-8">
        <div className="md:col-span-4 lg:col-span-3 bg-white/80 backdrop-blur-xl border border-white shadow-sm rounded-3xl p-5 flex flex-col justify-center">
          <p className="text-[10px] font-bold text-slate-400 uppercase tracking-wider mb-2">Qaysi modul mavzulari?</p>
          {isModulesLoading ? (
            <Skeleton className="h-12 w-full rounded-xl" />
          ) : (
            <Select 
              value={selectedModuleId} 
              onChange={(e) => setSelectedModuleId(e.target.value)}
              className="h-12 w-full bg-slate-50/50 border-transparent hover:border-slate-200 focus:border-blue-500 focus:ring-blue-500/20 rounded-xl font-bold text-slate-700 transition-all text-base"
            >
              <option value="">Barcha Modullar</option>
              {modules?.map((m: any) => (
                <option key={m.id} value={m.id}>{m.title}</option>
              ))}
            </Select>
          )}
        </div>

        <div className="md:col-span-8 lg:col-span-9 grid grid-cols-2 sm:grid-cols-4 gap-4">
          <div className="bg-white/60 backdrop-blur-xl border border-white shadow-sm rounded-3xl p-4 flex flex-col justify-center items-center text-center hover:shadow-md transition-shadow">
            <div className="size-10 rounded-full bg-blue-50 text-blue-600 flex items-center justify-center mb-2"><Layers className="size-5" /></div>
            <p className="text-2xl font-black text-slate-900 leading-none">{stats.total}</p>
            <p className="text-[10px] font-bold text-slate-500 uppercase tracking-wider mt-1">Jami Mavzular</p>
          </div>
          <div className="bg-white/60 backdrop-blur-xl border border-white shadow-sm rounded-3xl p-4 flex flex-col justify-center items-center text-center hover:shadow-md transition-shadow">
            <div className="size-10 rounded-full bg-violet-50 text-violet-600 flex items-center justify-center mb-2"><Play className="size-5" /></div>
            <p className="text-2xl font-black text-slate-900 leading-none">{stats.videos}</p>
            <p className="text-[10px] font-bold text-slate-500 uppercase tracking-wider mt-1">Video Darslar</p>
          </div>
          <div className="bg-white/60 backdrop-blur-xl border border-white shadow-sm rounded-3xl p-4 flex flex-col justify-center items-center text-center hover:shadow-md transition-shadow">
            <div className="size-10 rounded-full bg-emerald-50 text-emerald-600 flex items-center justify-center mb-2"><FileText className="size-5" /></div>
            <p className="text-2xl font-black text-slate-900 leading-none">{stats.pdfs}</p>
            <p className="text-[10px] font-bold text-slate-500 uppercase tracking-wider mt-1">Materiallar</p>
          </div>
          <div className="bg-white/60 backdrop-blur-xl border border-white shadow-sm rounded-3xl p-4 flex flex-col justify-center items-center text-center hover:shadow-md transition-shadow">
            <div className="size-10 rounded-full bg-orange-50 text-orange-600 flex items-center justify-center mb-2"><CheckSquare className="size-5" /></div>
            <p className="text-2xl font-black text-slate-900 leading-none">{stats.tests}</p>
            <p className="text-[10px] font-bold text-slate-500 uppercase tracking-wider mt-1">Test Savollari</p>
          </div>
        </div>
      </div>

      <div className="bg-white/80 backdrop-blur-xl border border-white shadow-sm rounded-2xl p-3 flex flex-wrap items-center gap-3 mb-8">
        <div className="relative flex-1 min-w-[250px]">
          <Search className="absolute left-4 top-1/2 -translate-y-1/2 size-5 text-slate-400" />
          <Input 
            placeholder="Mavzularni izlash..." 
            className="pl-11 h-12 w-full bg-slate-50/50 border-transparent hover:border-slate-200 focus:border-blue-500 focus:ring-blue-500/20 rounded-xl transition-all text-base"
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
          />
        </div>
        <div className="h-8 w-px bg-slate-200 hidden md:block"></div>
        <Select value={statusFilter} onChange={(e: any) => setStatusFilter(e.target.value)} className="h-12 w-full md:w-[160px] bg-slate-50/50 border-transparent rounded-xl font-medium text-slate-700 focus:border-blue-500">
          <option value="all">Status: Barchasi</option>
          <option value="published">Nashr qilingan</option>
          <option value="draft">Qoralama</option>
        </Select>
      </div>

      {/* Premium Table View */}
      {isTopicsLoading ? (
        <Card className="rounded-3xl border border-white shadow-sm overflow-hidden">
          <div className="p-6 flex flex-col gap-4">
            {[1, 2, 3, 4].map(i => <Skeleton key={i} className="h-16 w-full rounded-2xl" />)}
          </div>
        </Card>
      ) : !filteredTopics.length ? (
        <div className="flex flex-col items-center justify-center py-20 px-4 bg-white/50 backdrop-blur-sm rounded-3xl border border-white border-dashed">
          <div className="size-24 bg-blue-50 rounded-full flex items-center justify-center mb-6">
            <Layers className="size-10 text-blue-500" />
          </div>
          <h3 className="text-2xl font-black text-slate-900 mb-2">Mavzular Topilmadi</h3>
          <p className="text-slate-500 text-center max-w-md mb-8">
            Ushbu modulda hozircha hech qanday mavzu yo'q. Birinchi mavzuni qo'shing.
          </p>
          <Button onClick={openCreateModal} className="rounded-full px-8 h-12 bg-blue-600 hover:bg-blue-700 text-white font-bold tracking-wide">
            <Plus className="size-5 mr-2" /> Yangi Mavzu Qo'shish
          </Button>
        </div>
      ) : (
        <Card className="rounded-3xl border border-white shadow-sm overflow-hidden bg-white/80 backdrop-blur-xl animate-in fade-in-50 duration-200">
          <div className="overflow-x-auto edulab-scrollbar">
            <table className="w-full text-sm">
              <thead className="bg-slate-50 text-left text-[10px] font-black uppercase text-slate-400 tracking-wider border-b border-slate-100">
                <tr>
                  <th className="px-6 py-5 w-16 text-center">#</th>
                  <th className="px-6 py-5 min-w-[280px]">Mavzu Nomi</th>
                  <th className="px-6 py-5 text-center w-32">Davomiylik</th>
                  <th className="px-6 py-5 text-center w-28">Text/PDF</th>
                  <th className="px-6 py-5 text-center w-28">Videolar</th>
                  <th className="px-6 py-5 text-center w-28">Testlar</th>
                  <th className="px-6 py-5 text-center w-32">Holati</th>
                  <th className="px-6 py-5 text-right w-36">Amallar</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-50">
                {filteredTopics.map((topic: any, idx: number) => {
                  const topicPdfs = allLessons?.filter((l: any) => l.topic_id === topic.id && (l.kind === "pdf" || l.kind === "text")).length || 0;
                  const topicVideos = allLessons?.filter((l: any) => l.topic_id === topic.id && l.kind === "video").length || 0;
                  const topicTests = allQuizzes?.filter((q: any) => q.topic_id === topic.id).length || 0;

                  return (
                    <tr key={topic.id} className="hover:bg-blue-50/30 transition-colors group">
                      <td className="px-6 py-4 text-center">
                        <span className="font-black text-slate-300 group-hover:text-blue-400 transition-colors">{topic.order_index}</span>
                      </td>
                      <td className="px-6 py-4">
                        <div className="flex items-center gap-4">
                          <div className="relative size-12 rounded-2xl overflow-hidden shrink-0 shadow-sm border border-slate-100 group-hover:shadow-md transition-all">
                            <img src={topic.cover_url || "https://images.unsplash.com/photo-1434030216411-0b793f4b4173?w=500&auto=format&fit=crop"} alt={topic.title} className="w-full h-full object-cover group-hover:scale-110 transition-transform duration-500" />
                          </div>
                          <div className="min-w-0">
                            <p className="font-black text-slate-900 truncate text-base group-hover:text-blue-600 transition-colors">{topic.title}</p>
                            <p className="text-xs text-slate-400 font-medium truncate mt-0.5 max-w-[200px] sm:max-w-[300px]">
                              {topic.description || "Ta'rif kiritilmagan"}
                            </p>
                          </div>
                        </div>
                      </td>
                      <td className="px-6 py-4 text-center">
                        <span className="inline-flex items-center gap-1 font-bold text-slate-600">
                          <Clock className="size-3.5 text-slate-400" />
                          {Math.round((topic.duration_seconds || 0) / 60)} daq.
                        </span>
                      </td>
                      <td className="px-6 py-4 text-center">
                        <Badge variant="indigo" className="bg-indigo-50"><FileText className="size-3 mr-1" /> {topicPdfs}</Badge>
                      </td>
                      <td className="px-6 py-4 text-center">
                        <Badge variant="blue" className="bg-blue-50"><Play className="size-3 mr-1" /> {topicVideos}</Badge>
                      </td>
                      <td className="px-6 py-4 text-center">
                        <Badge variant="warning" className="bg-orange-50"><CheckSquare className="size-3 mr-1" /> {topicTests}</Badge>
                      </td>
                      <td className="px-6 py-4 text-center">
                        <Badge variant={topic.is_published ? "success" : "slate"}>
                          {topic.is_published ? "Nashr" : "Qoralama"}
                        </Badge>
                      </td>
                      <td className="px-6 py-4">
                        <div className="flex items-center justify-end gap-2 opacity-100 sm:opacity-0 sm:group-hover:opacity-100 transition-opacity">
                          <Button 
                            onClick={() => openEditModal(topic)} 
                            variant="ghost" 
                            size="icon" 
                            className="size-9 rounded-xl text-slate-400 hover:text-blue-600 hover:bg-blue-50"
                          >
                            <Pencil className="size-4.5" />
                          </Button>
                          <Button 
                            onClick={() => setDeleteConfirm({ open: true, id: topic.id })} 
                            variant="ghost" 
                            size="icon" 
                            className="size-9 rounded-xl text-slate-400 hover:text-red-600 hover:bg-red-50"
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

      {/* FULL SCREEN WIZARD MODAL FOR TOPICS */}
      {modalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-900/60 backdrop-blur-md p-0 sm:p-6 animate-in fade-in duration-300">
          <div className="bg-white sm:rounded-[2.5rem] shadow-2xl w-full h-full sm:h-[90vh] max-w-6xl overflow-hidden flex flex-col md:flex-row animate-in zoom-in-95 slide-in-from-bottom-8 duration-500 relative">
            
            <button onClick={() => setModalOpen(false)} className="md:hidden absolute top-4 right-4 z-50 p-2 bg-white rounded-full shadow-md text-slate-500 hover:text-red-500">
              <Plus className="size-6 rotate-45" />
            </button>

            {/* Left Side: Form Steps */}
            <div className="w-full md:w-3/5 lg:w-1/2 h-full flex flex-col bg-white z-10 overflow-y-auto">
              <div className="px-8 sm:px-12 pt-12 pb-6">
                <h2 className="text-3xl font-black text-slate-900 mb-2">{editingTopic ? "Mavzuni Tahrirlash" : "Yangi Mavzu Qo'shish"}</h2>
                <p className="text-slate-500">O'quv rejasini tartiblash uchun mavzu ma'lumotlarini kiriting.</p>
              </div>

              {/* Step Indicators */}
              <div className="px-8 sm:px-12 mb-8">
                <div className="flex justify-between relative">
                  <div className="absolute left-0 top-1/2 -translate-y-1/2 w-full h-1 bg-slate-100 rounded-full" />
                  <div className="absolute left-0 top-1/2 -translate-y-1/2 h-1 bg-blue-600 rounded-full transition-all duration-500" style={{ width: `${(step - 1) * 100}%` }} />
                  
                  {[1,2].map(s => (
                    <button key={s} onClick={() => s < step && setStep(s)} disabled={s > step} className={`relative flex flex-col items-center gap-2 z-10 ${s > step ? 'cursor-not-allowed opacity-50' : 'cursor-pointer'}`}>
                      <div className={`size-10 rounded-full flex items-center justify-center font-black text-sm transition-all duration-300 shadow-sm ${step === s ? 'bg-blue-600 text-white scale-110 ring-4 ring-blue-600/20' : step > s ? 'bg-emerald-500 text-white' : 'bg-white text-slate-400 border-2 border-slate-200'}`}>
                        {step > s ? <CheckCircle2 className="size-5" /> : s}
                      </div>
                    </button>
                  ))}
                </div>
                <div className="flex justify-between mt-3 text-[10px] font-bold uppercase tracking-wider text-slate-400">
                  <span className={step >= 1 ? 'text-blue-600' : ''}>Asosiy</span>
                  <span className={step >= 2 ? 'text-blue-600' : ''}>Sozlamalar</span>
                </div>
              </div>

              <div className="flex-1 px-8 sm:px-12 overflow-y-auto pb-32">
                <div className="max-w-md mx-auto w-full">
                  
                  {step === 1 && (
                    <div className="space-y-6 animate-in slide-in-from-right-8 fade-in duration-500">
                      <div className="grid gap-2">
                        <label className="text-sm font-bold text-slate-800">Qaysi modulga tegishli? <span className="text-red-500">*</span></label>
                        <Select 
                          value={moduleId} 
                          onChange={(e) => setModuleId(e.target.value)}
                          className="h-14 rounded-2xl bg-slate-50 border-transparent focus:bg-white focus:border-blue-600 focus:ring-blue-600/20 px-5 text-lg font-bold text-slate-700"
                        >
                          <option value="" disabled>Modulni tanlang</option>
                          {modules?.map((m: any) => (
                            <option key={m.id} value={m.id}>{m.title}</option>
                          ))}
                        </Select>
                      </div>

                      <div className="grid gap-2">
                        <label className="text-sm font-bold text-slate-800">Mavzu Nomi <span className="text-red-500">*</span></label>
                        <Input
                          placeholder="Masalan: HTML asoslari"
                          value={title}
                          onChange={(e) => setTitle(e.target.value)}
                          className="h-14 rounded-2xl bg-slate-50 border-transparent focus:bg-white focus:border-blue-600 px-5 text-lg font-medium transition-all"
                          autoFocus
                        />
                      </div>
                      
                      <div className="grid gap-2">
                        <label className="text-sm font-bold text-slate-800">Qisqacha Tavsif</label>
                        <Textarea
                          placeholder="Ushbu mavzuda nimalar o'tiladi?"
                          value={description}
                          onChange={(e) => setDescription(e.target.value)}
                          className="h-24 rounded-2xl bg-slate-50 border-transparent focus:bg-white focus:border-blue-600 px-5 py-4 text-base font-medium transition-all resize-none"
                        />
                      </div>

                      <div className="grid grid-cols-2 gap-4">
                        <div className="grid gap-2">
                          <label className="text-sm font-bold text-slate-800">Tartib raqami</label>
                          <Input type="number" value={orderIndex} onChange={(e) => setOrderIndex(Number(e.target.value))} min={1} className="h-14 rounded-2xl bg-slate-50 border-transparent focus:bg-white focus:border-blue-600 px-5 text-lg font-bold" />
                        </div>
                        <div className="grid gap-2">
                          <label className="text-sm font-bold text-slate-800">Davomiyligi (Daqiqada)</label>
                          <Input type="number" value={durationMinutes} onChange={(e) => setDurationMinutes(Number(e.target.value))} min={1} className="h-14 rounded-2xl bg-slate-50 border-transparent focus:bg-white focus:border-blue-600 px-5 text-lg font-bold" />
                        </div>
                      </div>
                    </div>
                  )}

                  {step === 2 && (
                    <div className="space-y-6 animate-in slide-in-from-right-8 fade-in duration-500">
                      <div className="grid gap-2">
                        <label className="text-sm font-bold text-slate-800">Muqova Rasmi (URL)</label>
                        <div className="relative">
                          <UploadCloud className="absolute left-4 top-1/2 -translate-y-1/2 size-5 text-slate-400" />
                          <Input
                            placeholder="https://images.unsplash.com/..."
                            value={coverUrl}
                            onChange={(e) => setCoverUrl(e.target.value)}
                            className="h-14 rounded-2xl bg-slate-50 border-transparent focus:bg-white focus:border-blue-600 pl-12 text-base font-medium transition-all"
                          />
                        </div>
                      </div>

                      <div className="bg-slate-50 p-5 rounded-3xl border border-slate-100 space-y-4 mt-6">
                        <label className="flex items-center justify-between cursor-pointer group">
                          <div>
                            <p className="font-bold text-slate-800 group-hover:text-blue-600 transition-colors">Mavzuni Nashr Qilish</p>
                            <p className="text-xs text-slate-500 mt-0.5">Mavzu o'quvchilarga ko'rinadi</p>
                          </div>
                          <div className={`w-14 h-8 rounded-full transition-colors flex items-center px-1 ${isPublished ? 'bg-emerald-500' : 'bg-slate-300'}`}>
                            <div className={`size-6 rounded-full bg-white shadow-sm transition-transform ${isPublished ? 'translate-x-6' : 'translate-x-0'}`} />
                          </div>
                          <input type="checkbox" checked={isPublished} onChange={(e) => setIsPublished(e.target.checked)} className="hidden" />
                        </label>
                      </div>

                      <Button 
                        onClick={handleSubmit} 
                        disabled={createTopicMutation.isPending || updateTopicMutation.isPending}
                        className="h-16 px-12 rounded-full text-lg font-black bg-blue-600 hover:bg-blue-700 text-white shadow-xl shadow-blue-600/20 w-full mt-4"
                      >
                        {(createTopicMutation.isPending || updateTopicMutation.isPending) ? (
                          <Loader2 className="size-6 animate-spin mr-3" />
                        ) : null}
                        {editingTopic ? "Mavzuni Saqlash" : "Mavzuni Yaratish"}
                      </Button>
                    </div>
                  )}

                </div>
              </div>

              {step === 1 && (
                <div className="absolute bottom-0 left-0 w-full md:w-3/5 lg:w-1/2 p-6 sm:p-8 bg-white border-t border-slate-100 flex justify-between items-center z-20">
                  <Button variant="ghost" onClick={() => setModalOpen(false)} className="text-slate-500 font-bold hover:bg-slate-100 rounded-full px-6 h-12">
                    Bekor qilish
                  </Button>
                  <Button onClick={() => setStep(s => s + 1)} className="rounded-full px-8 h-12 font-bold bg-blue-600 hover:bg-blue-700 text-white shadow-lg shadow-blue-500/20">
                    Keyingisi <ArrowRight className="size-4 ml-2" />
                  </Button>
                </div>
              )}
            </div>

            {/* Right Side: Live Interactive Topic Card Preview */}
            <div className="hidden md:flex w-2/5 lg:w-1/2 h-full bg-slate-900 flex-col items-center justify-center p-12 relative overflow-hidden">
              <div className="absolute inset-0 bg-gradient-to-br from-blue-950/80 via-slate-900 to-black z-0"></div>
              <div className="absolute inset-0 bg-[url('https://images.unsplash.com/photo-1456406644174-8ddd4cd52a06?q=80&w=2000&auto=format&fit=crop')] bg-cover bg-center opacity-10 mix-blend-overlay filter grayscale"></div>
              
              <div className="relative z-10 w-full max-w-[400px] flex flex-col items-center">
                <p className="text-blue-400 font-black tracking-widest uppercase text-[10px] mb-8 flex items-center gap-2">
                  <span className="w-2 h-2 rounded-full bg-blue-400 animate-pulse"></span> Talaba Ko'rinishi
                </p>

                <div className="w-full bg-white rounded-[2rem] shadow-2xl overflow-hidden transition-all duration-500 hover:scale-[1.02]">
                  <div className="h-40 relative overflow-hidden">
                    <img 
                      src={coverUrl || "https://images.unsplash.com/photo-1434030216411-0b793f4b4173?w=500&q=80"} 
                      alt="Cover" 
                      className="w-full h-full object-cover"
                      onError={(e) => { (e.target as HTMLImageElement).src = 'https://images.unsplash.com/photo-1434030216411-0b793f4b4173?w=500&q=80' }}
                    />
                    <div className="absolute inset-0 bg-gradient-to-t from-slate-900/80 to-transparent"></div>
                    <div className="absolute bottom-4 left-4 flex gap-2">
                      <Badge variant="indigo" className="bg-indigo-500 text-white border-transparent backdrop-blur-md">
                        {modules?.find((m: any) => m.id === moduleId)?.title || "Modul Nomi"}
                      </Badge>
                    </div>
                  </div>
                  
                  <div className="p-6">
                    <div className="flex items-center justify-between mb-3">
                      <div className="flex items-center gap-2 text-slate-400 text-[10px] font-bold uppercase tracking-wider">
                        <span>Qism #{orderIndex}</span>
                        <span className="w-1 h-1 rounded-full bg-slate-300"></span>
                        <span className="flex items-center gap-1"><Clock className="size-3"/> {durationMinutes} daq</span>
                      </div>
                      {isPublished ? (
                        <div className="size-8 rounded-full bg-blue-50 text-blue-600 flex items-center justify-center">
                          <Play className="size-4 ml-0.5" />
                        </div>
                      ) : (
                        <div className="size-8 rounded-full bg-slate-50 text-slate-400 flex items-center justify-center">
                          <EyeOff className="size-4" />
                        </div>
                      )}
                    </div>

                    <h3 className="text-xl font-black text-slate-900 leading-snug line-clamp-2 mb-2">
                      {title || "Mavzu nomi kiritilmagan"}
                    </h3>
                    
                    <p className="text-sm text-slate-500 line-clamp-2 mb-5 leading-relaxed">
                      {description || "Tavsif bu yerda paydo bo'ladi. U mavzu mohiyatini yoritadi."}
                    </p>

                    <div className="flex gap-4 pt-4 border-t border-slate-100 text-xs font-bold text-slate-500">
                      <span className="flex items-center gap-1.5"><FileText className="size-4 text-indigo-500"/> Materiallar</span>
                      <span className="flex items-center gap-1.5"><Play className="size-4 text-emerald-500"/> Videolar</span>
                      <span className="flex items-center gap-1.5"><CheckSquare className="size-4 text-orange-500"/> Testlar</span>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      )}

      <ConfirmDialog
        open={deleteConfirm.open}
        title="Mavzuni o'chirish"
        description="Siz haqiqatan ham ushbu mavzuni o'chirmoqchimisiz? Barcha biriktirilgan darslar, videolar va testlar ham o'chib ketadi."
        confirmLabel="O'chirish"
        variant="danger"
        loading={deleteTopicMutation.isPending}
        onConfirm={handleDeleteConfirm}
        onCancel={() => setDeleteConfirm({ open: false, id: null })}
      />
    </div>
  );
}
