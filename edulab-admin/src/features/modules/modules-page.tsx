"use client";

import { useRef, useState } from "react";
import { Plus, Pencil, Trash2, Loader2, BookOpen, Search, CheckCircle2, ChevronRight, UploadCloud, Image as ImageIcon, Layers, Users, Star, ArrowRight, PlayCircle } from "lucide-react";
import { ConfirmDialog } from "@/components/ui/confirm-dialog";
import { PageHeader } from "@/components/layout/page-header";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { Input, Textarea, Select } from "@/components/ui/input";
import { Skeleton } from "@/components/ui/skeleton";
import { useModules, useCreateModule, useUpdateModule, useDeleteModule } from "@/hooks/use-admin-data";
import { toast } from "sonner";

function Badge({ variant, children, className }: { variant: "success" | "slate" | "warning" | "blue" | "indigo"; children: React.ReactNode; className?: string }) {
  return (
    <span className={`inline-flex items-center rounded-full px-2.5 py-1 text-[10px] uppercase tracking-wider font-bold ${
      variant === "success" ? "bg-emerald-500/10 text-emerald-600 border border-emerald-500/20" :
      variant === "warning" ? "bg-amber-500/10 text-amber-600 border border-amber-500/20" :
      variant === "blue" ? "bg-blue-500/10 text-blue-600 border border-blue-500/20" :
      variant === "indigo" ? "bg-indigo-500/10 text-indigo-600 border border-indigo-500/20" :
      "bg-slate-500/10 text-slate-600 border border-slate-500/20"
    } ${className}`}>
      {children}
    </span>
  );
}

export function ModulesPage() {
  const { data: modules, isLoading } = useModules();
  const createModuleMutation = useCreateModule();
  const updateModuleMutation = useUpdateModule();
  const deleteModuleMutation = useDeleteModule();

  const [modalOpen, setModalOpen] = useState(false);
  const [editingModule, setEditingModule] = useState<any>(null);
  const [deleteConfirm, setDeleteConfirm] = useState<{ open: boolean; id: string | null }>({ open: false, id: null });
  
  const [searchQuery, setSearchQuery] = useState("");
  const [statusFilter, setStatusFilter] = useState("all");
  const [difficultyFilter, setDifficultyFilter] = useState("all");

  const [step, setStep] = useState(1);
  const [title, setTitle] = useState("");
  const [description, setDescription] = useState("");
  const [orderIndex, setOrderIndex] = useState(1);
  const [coverUrl, setCoverUrl] = useState("");
  const coverFileInputRef = useRef<HTMLInputElement>(null);
  const [coverUploading, setCoverUploading] = useState(false);
  const [levelLabel, setLevelLabel] = useState("Boshlang‘ich");
  const [durationLabel, setDurationLabel] = useState("10 soat");
  const [passingScore, setPassingScore] = useState(70);
  const [isPublished, setIsPublished] = useState(false);
  const [isLocked, setIsLocked] = useState(true);
  const [isSequential, setIsSequential] = useState(false);

  const openCreateModal = () => {
    setEditingModule(null);
    setTitle("");
    setDescription("");
    setOrderIndex((modules?.length || 0) + 1);
    setCoverUrl("");
    setLevelLabel("Boshlang‘ich");
    setDurationLabel("10 soat");
    setPassingScore(70);
    setIsPublished(false);
    setIsLocked(true);
    setIsSequential(false);
    setStep(1);
    setModalOpen(true);
  };

  const openEditModal = (module: any) => {
    setEditingModule(module);
    setTitle(module.title || "");
    setDescription(module.description || "");
    setOrderIndex(module.order_index || 1);
    setCoverUrl(module.cover_url || "");
    setLevelLabel(module.level_label || "Boshlang‘ich");
    setDurationLabel(module.duration_label || "");
    setPassingScore(module.passing_score || 70);
    setIsPublished(module.is_published || false);
    setIsLocked(module.is_locked || false);
    setIsSequential(module.is_sequential || false);
    setStep(1);
    setModalOpen(true);
  };

  const handleCoverFileChange = async (event: React.ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    if (!file) return;

    if (!file.type.startsWith("image/")) {
      toast.error("Faqat rasm fayli yuklang");
      event.target.value = "";
      return;
    }

    if (file.size > 8 * 1024 * 1024) {
      toast.error("Rasm hajmi 8MB dan oshmasin");
      event.target.value = "";
      return;
    }

    const formData = new FormData();
    formData.append("file", file);
    formData.append("kind", "image");

    try {
      setCoverUploading(true);
      const response = await fetch("/api/media/upload", {
        method: "POST",
        body: formData,
      });
      const data = await response.json().catch(() => null);

      if (!response.ok || !data?.ok || !data?.media?.secure_url) {
        throw new Error(data?.error || "Rasm yuklanmadi");
      }

      setCoverUrl(data.media.secure_url);
      toast.success("Modul muqova rasmi yuklandi");
    } catch (error: any) {
      toast.error(error?.message || "Rasm yuklashda xatolik yuz berdi");
    } finally {
      setCoverUploading(false);
      event.target.value = "";
    }
  };

  const handleSubmit = async (e?: React.FormEvent) => {
    if (e) e.preventDefault();
    if (!title.trim()) {
      toast.error("Modul nomini kiriting");
      return;
    }

    const payload = {
      title,
      description,
      order_index: Number(orderIndex),
      cover_url: coverUrl || "https://images.unsplash.com/photo-1516321318423-f06f85e504b3?w=1600&auto=format&fit=crop",
      level_label: levelLabel,
      duration_label: durationLabel,
      passing_score: Number(passingScore),
      is_published: isPublished,
      is_locked: isLocked,
      is_sequential: isSequential,
    };

    try {
      if (editingModule) {
        await updateModuleMutation.mutateAsync({ id: editingModule.id, ...payload });
        toast.success("Modul muvaffaqiyatli yangilandi");
      } else {
        await createModuleMutation.mutateAsync(payload);
        toast.success("Yangi modul muvaffaqiyatli qo'shildi");
      }
      setModalOpen(false);
    } catch (err: any) {
      toast.error(err.message || "Xatolik yuz berdi");
    }
  };

  const handleDeleteConfirm = async () => {
    if (!deleteConfirm.id) return;
    try {
      await deleteModuleMutation.mutateAsync(deleteConfirm.id);
      toast.success("Modul muvaffaqiyatli o'chirildi");
    } catch (err: any) {
      toast.error(err.message || "O'chirishda xatolik yuz berdi");
    } finally {
      setDeleteConfirm({ open: false, id: null });
    }
  };

  const filteredModules = modules?.filter((m: any) => {
    const matchesSearch = m.title?.toLowerCase().includes(searchQuery.toLowerCase()) || m.description?.toLowerCase().includes(searchQuery.toLowerCase());
    const matchesStatus = statusFilter === "all" ? true : (statusFilter === "published" ? m.is_published : !m.is_published);
    const matchesDifficulty = difficultyFilter === "all" ? true : m.level_label === difficultyFilter;
    return matchesSearch && matchesStatus && matchesDifficulty;
  }) || [];

  const totalModules = modules?.length || 0;
  const publishedModules = modules?.filter((m: any) => m.is_published).length || 0;
  const draftModules = totalModules - publishedModules;

  return (
    <div className="min-h-screen bg-slate-50/50 pb-20">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 mb-8">
        <PageHeader title="Modullar boshqaruvi" current="Modullar" />
        <Button onClick={openCreateModal} className="flex gap-2 bg-blue-600 hover:bg-blue-700 text-white shadow-lg shadow-blue-500/20 rounded-lg px-5 h-11 transition-all ">
          <Plus className="size-5" />
          Yangi Modul
        </Button>
      </div>

      {/* Analytics Glassmorphism Cards */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
        <div className="bg-white border border-slate-200 shadow-sm rounded-lg p-6 flex items-center gap-5 hover:shadow-md transition-shadow">
          <div className="size-14 rounded-lg bg-blue-500/10 text-blue-600 flex items-center justify-center shrink-0">
            <BookOpen className="size-6" />
          </div>
          <div>
            <p className="text-sm font-bold text-slate-500 uppercase tracking-wider mb-1">Jami Modullar</p>
            <p className="text-3xl font-black text-slate-900">{totalModules}</p>
          </div>
        </div>
        <div className="bg-white border border-slate-200 shadow-sm rounded-lg p-6 flex items-center gap-5 hover:shadow-md transition-shadow">
          <div className="size-14 rounded-lg bg-emerald-500/10 text-emerald-600 flex items-center justify-center shrink-0">
            <CheckCircle2 className="size-6" />
          </div>
          <div>
            <p className="text-sm font-bold text-slate-500 uppercase tracking-wider mb-1">Nashr Qilingan</p>
            <p className="text-3xl font-black text-slate-900">{publishedModules}</p>
          </div>
        </div>
        <div className="bg-white border border-slate-200 shadow-sm rounded-lg p-6 flex items-center gap-5 hover:shadow-md transition-shadow">
          <div className="size-14 rounded-lg bg-amber-500/10 text-amber-600 flex items-center justify-center shrink-0">
            <Pencil className="size-6" />
          </div>
          <div>
            <p className="text-sm font-bold text-slate-500 uppercase tracking-wider mb-1">Qoralamalar</p>
            <p className="text-3xl font-black text-slate-900">{draftModules}</p>
          </div>
        </div>
      </div>

      {/* Modern Filter Bar */}
      <div className="bg-white border border-slate-200 shadow-sm rounded-lg p-3 flex flex-wrap items-center gap-3 mb-8">
        <div className="relative flex-1 min-w-[250px]">
          <Search className="absolute left-4 top-1/2 -translate-y-1/2 size-5 text-slate-400" />
          <Input 
            placeholder="Modullarni izlash..." 
            className="pl-11 h-12 w-full bg-slate-50/50 border-transparent hover:border-slate-200 focus:border-blue-500 focus:ring-blue-500/20 rounded-lg transition-all text-base"
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
          />
        </div>
        <div className="h-8 w-px bg-slate-200 hidden md:block"></div>
        <Select value={statusFilter} onChange={(e: any) => setStatusFilter(e.target.value)} className="h-12 w-full md:w-[160px] bg-slate-50/50 border-transparent rounded-lg font-medium text-slate-700 focus:border-blue-500">
          <option value="all">Status: Barchasi</option>
          <option value="published">Nashr qilingan</option>
          <option value="draft">Qoralama</option>
        </Select>
        <Select value={difficultyFilter} onChange={(e: any) => setDifficultyFilter(e.target.value)} className="h-12 w-full md:w-[160px] bg-slate-50/50 border-transparent rounded-lg font-medium text-slate-700 focus:border-blue-500">
          <option value="all">Daraja: Barchasi</option>
          <option value="Boshlang‘ich">Boshlang‘ich</option>
          <option value="O‘rta">O‘rta</option>
          <option value="Murakkab">Murakkab</option>
        </Select>
      </div>

      {/* Premium Table View */}
      {isLoading ? (
        <Card className="rounded-lg border border-slate-200 shadow-sm overflow-hidden">
          <div className="p-6 flex flex-col gap-4">
            {[1, 2, 3, 4].map(i => <Skeleton key={i} className="h-16 w-full rounded-lg" />)}
          </div>
        </Card>
      ) : !filteredModules.length ? (
        <div className="flex flex-col items-center justify-center py-20 px-4 bg-white rounded-lg border border-dashed border-slate-200">
          <div className="size-24 bg-blue-50 rounded-full flex items-center justify-center mb-6">
            <BookOpen className="size-10 text-blue-500" />
          </div>
          <h3 className="text-2xl font-black text-slate-900 mb-2">Modullar Topilmadi</h3>
          <p className="text-slate-500 text-center max-w-md mb-8">
            Hozircha hech qanday modul mavjud emas yoki qidiruvga mos modul topilmadi.
          </p>
          <Button onClick={openCreateModal} className="rounded-lg px-6 h-12 bg-blue-600 hover:bg-blue-700 text-white font-bold tracking-wide">
            <Plus className="size-5 mr-2" /> Yangi Modul Qo'shish
          </Button>
        </div>
      ) : (
        <Card className="rounded-lg border border-slate-200 shadow-sm overflow-hidden bg-white animate-in fade-in-50 duration-200">
          <div className="overflow-x-auto edulab-scrollbar">
            <table className="w-full text-sm">
              <thead className="bg-slate-50 text-left text-[10px] font-black uppercase text-slate-400 tracking-wider border-b border-slate-100">
                <tr>
                  <th className="px-6 py-5 w-16 text-center">#</th>
                  <th className="px-6 py-5 min-w-[280px]">Modul Nomi</th>
                  <th className="px-6 py-5 text-center w-36">Daraja</th>
                  <th className="px-6 py-5 text-center w-36">Davomiyligi</th>
                  <th className="px-6 py-5 text-center w-32">O'tish Balli</th>
                  <th className="px-6 py-5 text-center w-32">Holati</th>
                  <th className="px-6 py-5 text-right w-36">Amallar</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-50">
                {filteredModules.map((m: any, idx: number) => (
                  <tr key={m.id} className="hover:bg-blue-50/30 transition-colors group">
                    <td className="px-6 py-4 text-center">
                      <span className="font-black text-slate-300 group-hover:text-blue-400 transition-colors">{m.order_index}</span>
                    </td>
                    <td className="px-6 py-4">
                      <div className="flex items-center gap-4">
                        <div className="relative size-12 rounded-lg overflow-hidden shrink-0 shadow-sm border border-slate-100 group-hover:shadow-md transition-all">
                          <img src={m.cover_url || "https://images.unsplash.com/photo-1516321318423-f06f85e504b3?w=500&auto=format&fit=crop"} alt={m.title} className="w-full h-full object-cover group-hover:scale-110 transition-transform duration-500" />
                        </div>
                        <div className="min-w-0">
                          <p className="font-black text-slate-900 truncate text-base group-hover:text-blue-600 transition-colors">{m.title}</p>
                          <p className="text-xs text-slate-400 font-medium truncate mt-0.5 max-w-[200px] sm:max-w-[300px]">
                            {m.description || "Ta'rif kiritilmagan"}
                          </p>
                        </div>
                      </div>
                    </td>
                    <td className="px-6 py-4 text-center">
                      <Badge variant="indigo">{m.level_label || "Boshlang'ich"}</Badge>
                    </td>
                    <td className="px-6 py-4 text-center font-bold text-slate-600">
                      {m.duration_label || "10 soat"}
                    </td>
                    <td className="px-6 py-4 text-center">
                      <span className="inline-flex items-center justify-center bg-slate-50 font-black text-slate-600 px-3 py-1 rounded-lg">
                        {m.passing_score || 70}%
                      </span>
                    </td>
                    <td className="px-6 py-4 text-center">
                      <Badge variant={m.is_published ? "success" : "slate"}>
                        {m.is_published ? "Nashr qilingan" : "Qoralama"}
                      </Badge>
                    </td>
                    <td className="px-6 py-4">
                      <div className="flex items-center justify-end gap-2 opacity-100 sm:opacity-0 sm:group-hover:opacity-100 transition-opacity">
                        <Button 
                          onClick={() => openEditModal(m)} 
                          variant="ghost" 
                          size="icon" 
                          className="size-9 rounded-lg text-slate-400 hover:text-blue-600 hover:bg-blue-50"
                        >
                          <Pencil className="size-4.5" />
                        </Button>
                        <Button 
                          onClick={() => setDeleteConfirm({ open: true, id: m.id })} 
                          variant="ghost" 
                          size="icon" 
                          className="size-9 rounded-lg text-slate-400 hover:text-red-600 hover:bg-red-50"
                        >
                          <Trash2 className="size-4.5" />
                        </Button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </Card>
      )}

      {/* WIZARD MODAL */}
      {modalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-900/60 backdrop-blur-md p-0 sm:p-6 animate-in fade-in duration-300">
          <div className="bg-white sm:rounded-[2.5rem] shadow-2xl w-full h-full sm:h-[90vh] max-w-6xl overflow-hidden flex flex-col md:flex-row animate-in zoom-in-95 slide-in-from-bottom-8 duration-500 relative">
            
            <button onClick={() => setModalOpen(false)} className="md:hidden absolute top-4 right-4 z-50 p-2 bg-white rounded-full shadow-md text-slate-500 hover:text-red-500">
              <Plus className="size-6 rotate-45" />
            </button>

            {/* Left Side: Form */}
            <div className="w-full md:w-3/5 lg:w-1/2 h-full flex flex-col bg-white z-10 overflow-y-auto">
              <div className="px-8 sm:px-12 pt-12 pb-6">
                <h2 className="text-3xl font-black text-slate-900 mb-2">{editingModule ? "Modulni Tahrirlash" : "Yangi Modul Qo'shish"}</h2>
                <p className="text-slate-500">Yangi o'quv modulini tizimga joylash uchun asosiy ma'lumotlarni kiriting.</p>
              </div>

              {/* Steps Indicator */}
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
                  <span className={step >= 2 ? 'text-blue-600' : ''}>Qo'shimcha</span>
                </div>
              </div>

              <div className="flex-1 px-8 sm:px-12 overflow-y-auto pb-32">
                <div className="max-w-md mx-auto w-full">
                  
                  {step === 1 && (
                    <div className="space-y-6 animate-in slide-in-from-right-8 fade-in duration-500">
                      <div className="grid gap-2">
                        <label className="text-sm font-bold text-slate-800">Modul Nomi <span className="text-red-500">*</span></label>
                        <Input
                          placeholder="Masalan: Front-End Asoslari"
                          value={title}
                          onChange={(e) => setTitle(e.target.value)}
                          className="h-14 rounded-lg bg-slate-50 border-transparent focus:bg-white focus:border-blue-600 px-5 text-lg font-medium transition-all"
                          autoFocus
                        />
                      </div>
                      
                      <div className="grid gap-2">
                        <label className="text-sm font-bold text-slate-800">To'liq Ta'rif</label>
                        <Textarea
                          placeholder="Modul nimalarni o'z ichiga oladi va talabalar nimalarni o'rganadi?"
                          value={description}
                          onChange={(e) => setDescription(e.target.value)}
                          className="h-32 rounded-lg bg-slate-50 border-transparent focus:bg-white focus:border-blue-600 px-5 py-4 text-base font-medium transition-all resize-none"
                        />
                      </div>

                      <div className="grid gap-3">
                        <label className="text-sm font-bold text-slate-800">Modul muqova rasmi</label>
                        <input
                          ref={coverFileInputRef}
                          type="file"
                          accept="image/*"
                          onChange={handleCoverFileChange}
                          className="hidden"
                        />
                        <button
                          type="button"
                          onClick={() => coverFileInputRef.current?.click()}
                          disabled={coverUploading}
                          className="group relative overflow-hidden rounded-2xl border border-dashed border-blue-200 bg-blue-50/40 p-3 text-left transition hover:border-blue-500 hover:bg-blue-50 disabled:cursor-not-allowed disabled:opacity-70"
                        >
                          <div className="flex items-center gap-4">
                            <div className="flex h-24 w-36 shrink-0 items-center justify-center overflow-hidden rounded-xl bg-white shadow-sm ring-1 ring-slate-200">
                              {coverUrl ? (
                                <img
                                  src={coverUrl}
                                  alt="Modul muqovasi"
                                  className="h-full w-full object-cover"
                                />
                              ) : (
                                <div className="flex h-full w-full items-center justify-center text-blue-500">
                                  <ImageIcon className="size-9" />
                                </div>
                              )}
                            </div>
                            <div className="min-w-0">
                              <div className="mb-2 inline-flex items-center gap-2 rounded-full bg-white px-3 py-1 text-xs font-black text-blue-600 shadow-sm">
                                {coverUploading ? (
                                  <Loader2 className="size-4 animate-spin" />
                                ) : (
                                  <UploadCloud className="size-4" />
                                )}
                                {coverUploading ? "Yuklanmoqda..." : "Kompyuterdan rasm yuklash"}
                              </div>
                              <div className="mb-2 flex flex-wrap items-center gap-2">
                                <p className="text-sm font-bold text-slate-800">Student app uchun modul background rasmi</p>
                                <span className="rounded-full bg-blue-600 px-2.5 py-1 text-[11px] font-black text-white shadow-sm">
                                  1600 x 900 px
                                </span>
                                <span className="rounded-full bg-white px-2.5 py-1 text-[11px] font-black text-blue-600 shadow-sm">
                                  16:9
                                </span>
                              </div>
                              <p className="mt-1 text-xs font-medium text-slate-500">
                                PNG, JPG yoki WEBP. Rasm kurslar ro‘yxati, modul ichidagi katta karta va mavzu kartalarida fon sifatida ko‘rinadi.
                              </p>
                            </div>
                          </div>
                        </button>
                        <div className="relative">
                          <ImageIcon className="absolute left-4 top-1/2 -translate-y-1/2 size-5 text-slate-400" />
                          <Input
                            placeholder="Yoki rasm URL manzilini kiriting"
                            value={coverUrl}
                            onChange={(e) => setCoverUrl(e.target.value)}
                            className="h-12 rounded-lg bg-slate-50 border-transparent focus:bg-white focus:border-blue-600 pl-12 text-sm font-medium transition-all"
                          />
                        </div>
                      </div>
                      
                      <div className="grid gap-2">
                        <label className="text-sm font-bold text-slate-800">Tartib raqami</label>
                        <Input type="number" value={orderIndex} onChange={(e) => setOrderIndex(Number(e.target.value))} min={1} className="h-14 rounded-lg bg-slate-50 border-transparent focus:bg-white focus:border-blue-600 px-5 text-lg font-bold" />
                      </div>
                    </div>
                  )}

                  {step === 2 && (
                    <div className="space-y-6 animate-in slide-in-from-right-8 fade-in duration-500">
                      <div className="grid grid-cols-2 gap-4">
                        <div className="grid gap-2">
                          <label className="text-sm font-bold text-slate-800">Qiyinchilik Darajasi</label>
                          <Select value={levelLabel} onChange={(e) => setLevelLabel(e.target.value)} className="h-14 rounded-lg bg-slate-50 border-transparent focus:bg-white focus:border-blue-600 px-5 font-bold text-slate-700 text-base">
                            <option value="Boshlang‘ich">Boshlang‘ich</option>
                            <option value="O‘rta">O‘rta</option>
                            <option value="Murakkab">Murakkab</option>
                          </Select>
                        </div>
                        <div className="grid gap-2">
                          <label className="text-sm font-bold text-slate-800">Davomiyligi</label>
                          <Input value={durationLabel} onChange={(e) => setDurationLabel(e.target.value)} placeholder="Masalan: 10 soat" className="h-14 rounded-lg bg-slate-50 border-transparent focus:bg-white focus:border-blue-600 px-5 font-bold text-slate-700 text-base" />
                        </div>
                      </div>

                      <div className="grid gap-2">
                        <label className="text-sm font-bold text-slate-800">O'tish Balli (%)</label>
                        <div className="flex items-center gap-4">
                          <input type="range" min={0} max={100} step={5} value={passingScore} onChange={(e) => setPassingScore(Number(e.target.value))} className="flex-1 accent-blue-600" />
                          <div className="w-16 h-10 rounded-lg bg-blue-50 text-blue-600 font-black flex items-center justify-center text-lg">
                            {passingScore}
                          </div>
                        </div>
                      </div>

                      <div className="bg-slate-50 p-5 rounded-lg border border-slate-100 space-y-4 mt-6">
                        <label className="flex items-center justify-between cursor-pointer group">
                          <div>
                            <p className="font-bold text-slate-800 group-hover:text-blue-600 transition-colors">Modulni Nashr Qilish</p>
                            <p className="text-xs text-slate-500 mt-0.5">Talabalar uchun modul darhol ko'rinadi</p>
                          </div>
                          <div className={`w-14 h-8 rounded-full transition-colors flex items-center px-1 ${isPublished ? 'bg-emerald-500' : 'bg-slate-300'}`}>
                            <div className={`size-6 rounded-full bg-white shadow-sm transition-transform ${isPublished ? 'translate-x-6' : 'translate-x-0'}`} />
                          </div>
                          <input type="checkbox" checked={isPublished} onChange={(e) => setIsPublished(e.target.checked)} className="hidden" />
                        </label>
                        
                        <div className="h-px w-full bg-slate-200" />

                        <label className="flex items-center justify-between cursor-pointer group">
                          <div>
                            <p className="font-bold text-slate-800 group-hover:text-blue-600 transition-colors">Ketma-ketlikni Talab Qilish</p>
                            <p className="text-xs text-slate-500 mt-0.5">Avvalgi darsni tugatmasdan keyingisiga o'tolmaydi</p>
                          </div>
                          <div className={`w-14 h-8 rounded-full transition-colors flex items-center px-1 ${isSequential ? 'bg-blue-600' : 'bg-slate-300'}`}>
                            <div className={`size-6 rounded-full bg-white shadow-sm transition-transform ${isSequential ? 'translate-x-6' : 'translate-x-0'}`} />
                          </div>
                          <input type="checkbox" checked={isSequential} onChange={(e) => setIsSequential(e.target.checked)} className="hidden" />
                        </label>
                      </div>

                      <Button 
                        onClick={handleSubmit} 
                        disabled={createModuleMutation.isPending || updateModuleMutation.isPending}
                        className="h-16 px-12 rounded-full text-lg font-black bg-blue-600 hover:bg-blue-700 text-white shadow-xl shadow-blue-600/20 w-full mt-4"
                      >
                        {(createModuleMutation.isPending || updateModuleMutation.isPending) ? (
                          <Loader2 className="size-6 animate-spin mr-3" />
                        ) : null}
                        {editingModule ? "Modulni Saqlash" : "Modulni Yaratish"}
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
                  <Button onClick={() => setStep(s => s + 1)} className="rounded-lg px-6 h-12 font-bold bg-blue-600 hover:bg-blue-700 text-white shadow-lg shadow-blue-500/20">
                    Keyingisi <ArrowRight className="size-4 ml-2" />
                  </Button>
                </div>
              )}
            </div>

            {/* Right Side: Live Preview Background */}
            <div className="hidden md:flex w-2/5 lg:w-1/2 h-full bg-slate-900 flex-col items-center justify-center relative overflow-hidden">
              <div className="absolute inset-0 z-0">
                <img 
                  src={coverUrl || "https://images.unsplash.com/photo-1516321318423-f06f85e504b3?w=800&q=80"} 
                  className="w-full h-full object-cover opacity-20 filter blur-sm scale-110"
                  alt=""
                />
                <div className="absolute inset-0 bg-gradient-to-t from-slate-950 via-slate-900/80 to-transparent"></div>
              </div>
              
              <div className="relative z-10 w-full max-w-sm px-6">
                <p className="text-blue-400 font-black tracking-widest uppercase text-[10px] mb-6 flex items-center gap-2">
                  <span className="w-2 h-2 rounded-full bg-blue-400 animate-pulse"></span> Jonli Ko'rinish
                </p>

                <div className="bg-white rounded-[2rem] shadow-2xl overflow-hidden transform transition-all duration-500 hover:scale-[1.02]">
                  <div className="aspect-video relative bg-slate-100">
                    <img 
                      src={coverUrl || "https://images.unsplash.com/photo-1516321318423-f06f85e504b3?w=500&q=80"} 
                      alt="Cover" 
                      className="w-full h-full object-cover"
                      onError={(e) => { (e.target as HTMLImageElement).src = 'https://images.unsplash.com/photo-1516321318423-f06f85e504b3?w=500&q=80' }}
                    />
                    <div className="absolute top-4 right-4">
                      <Badge variant="indigo" className="shadow-lg backdrop-blur-md bg-white/90">{levelLabel}</Badge>
                    </div>
                  </div>
                  <div className="p-6">
                    <div className="flex gap-2 mb-3">
                      <Badge variant="slate" className="bg-slate-100">{durationLabel}</Badge>
                      {isSequential && <Badge variant="warning" className="bg-amber-50">Ketma-ket</Badge>}
                    </div>
                    <h3 className="font-black text-xl text-slate-900 mb-2 line-clamp-2 leading-snug">
                      {title || "Yangi o'quv moduli nomi"}
                    </h3>
                    <p className="text-slate-500 text-sm line-clamp-2 mb-6 leading-relaxed">
                      {description || "Bu yerda siz kiritayotgan modulning qisqacha ta'rifi ko'rinadi."}
                    </p>
                    
                    <div className="pt-4 border-t border-slate-100 flex items-center justify-between">
                      <div className="flex -space-x-2">
                        {[1,2,3].map(i => (
                          <div key={i} className="size-8 rounded-full border-2 border-white bg-slate-200"></div>
                        ))}
                      </div>
                      <span className="text-[10px] font-bold text-slate-400 uppercase tracking-wider">O'tish: {passingScore}%</span>
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
        title="Modulni o'chirish"
        description="Siz haqiqatan ham ushbu modulni o'chirmoqchimisiz? Undagi barcha darslar va materiallar ham o'chib ketadi."
        confirmLabel="O'chirish"
        variant="danger"
        loading={deleteModuleMutation.isPending}
        onConfirm={handleDeleteConfirm}
        onCancel={() => setDeleteConfirm({ open: false, id: null })}
      />
    </div>
  );
}
