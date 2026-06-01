"use client";

import { useState, useEffect, useMemo } from "react";
import {
  Plus,
  Pencil,
  Trash2,
  Loader2,
  FileText,
  BookOpen,
  Search,
  Filter,
  HelpCircle,
  Eye,
  Link as LinkIcon,
  UploadCloud,
  Globe,
  ArrowRight,
  CheckCircle2,
  FileJson,
  Clock,
  Download,
  ChevronRight,
  Layers,
} from "lucide-react";
import { PageHeader } from "@/components/layout/page-header";
import { Button } from "@/components/ui/button";
import { Input, Textarea, Select } from "@/components/ui/input";
import { Skeleton } from "@/components/ui/skeleton";
import { Card, CardContent } from "@/components/ui/card";
import { ConfirmDialog } from "@/components/ui/confirm-dialog";
import {
  useModules,
  useTopics,
  useLessons,
  useCreateLesson,
  useUpdateLesson,
  useDeleteLesson,
} from "@/hooks/use-admin-data";
import { toast } from "sonner";
import { createClient } from "@/lib/supabase/client";

function Badge({ variant, children, className }: { variant: "success" | "slate" | "warning" | "blue" | "indigo" | "fuchsia" | "purple"; children: React.ReactNode; className?: string }) {
  return (
    <span className={`inline-flex items-center rounded-full px-2.5 py-1 text-[10px] uppercase tracking-wider font-bold ${
      variant === "success" ? "bg-emerald-500/10 text-emerald-600 border border-emerald-500/20" :
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

export function LessonsPage() {
  const supabase = createClient();
  const { data: modules, isLoading: isModulesLoading } = useModules();

  const [filterModuleId, setFilterModuleId] = useState("");
  const [filterTopicId, setFilterTopicId] = useState("");
  const [typeFilter, setTypeFilter] = useState("all");
  const [searchTerm, setSearchTerm] = useState("");

  const { data: topics, isLoading: isTopicsLoading } = useTopics(
    filterModuleId || undefined,
  );
  const { data: lessons, isLoading: isLessonsLoading } = useLessons(
    filterTopicId || undefined,
  );

  const createLessonMutation = useCreateLesson();
  const updateLessonMutation = useUpdateLesson();
  const deleteLessonMutation = useDeleteLesson();

  const [modalOpen, setModalOpen] = useState(false);
  const [editingLesson, setEditingLesson] = useState<any>(null);
  const [deleteConfirm, setDeleteConfirm] = useState<{
    open: boolean;
    id: string | null;
  }>({ open: false, id: null });

  // Form states
  const [step, setStep] = useState(1);
  const [formModuleId, setFormModuleId] = useState("");
  const [formTopicId, setFormTopicId] = useState("");
  const [title, setTitle] = useState("");
  const [kind, setKind] = useState<"pdf" | "text" | "link">("pdf");
  const [body, setBody] = useState("");
  const [fileUrl, setFileUrl] = useState("");
  const [durationMinutes, setDurationMinutes] = useState(15);
  const [orderIndex, setOrderIndex] = useState(1);
  const [description, setDescription] = useState("");
  const [visibility, setVisibility] = useState("visible");

  const { data: formTopics } = useTopics(formModuleId || undefined);

  useEffect(() => {
    setFilterTopicId("");
  }, [filterModuleId]);

  const handleKindChange = (newKind: "pdf" | "text" | "link") => {
    setKind(newKind);
    if (newKind === "text") {
      setFileUrl("");
    } else if (newKind === "pdf" && !fileUrl.endsWith(".pdf")) {
      setFileUrl(fileUrl || "https://example.com/document.pdf");
    } else if (newKind === "link" && fileUrl.endsWith(".pdf")) {
      setFileUrl("https://example.com/resource");
    }
  };

  const openCreateModal = () => {
    setEditingLesson(null);
    setFormModuleId(filterModuleId || modules?.[0]?.id || "");
    setFormTopicId(filterTopicId || "");
    setTitle("");
    setKind("pdf");
    setBody("");
    setFileUrl("");
    setDurationMinutes(15);
    setDescription("");
    setVisibility("visible");
    setOrderIndex(
      (lessons?.filter((l: any) => l.kind === "pdf" || l.kind === "text")
        .length || 0) + 1,
    );
    setStep(1);
    setModalOpen(true);
  };

  const openEditModal = (lesson: any) => {
    setEditingLesson(lesson);
    const assocTopic = topics?.find((t: any) => t.id === lesson.topic_id);
    setFormModuleId(assocTopic?.module_id || "");
    setFormTopicId(lesson.topic_id || "");
    setTitle(lesson.title || "");

    let visualKind: "pdf" | "text" | "link" = "pdf";
    if (lesson.kind === "text") {
      visualKind = "text";
    } else if (lesson.kind === "pdf") {
      const isUrlPdf = (lesson.file_url || "").toLowerCase().includes(".pdf");
      visualKind = isUrlPdf ? "pdf" : "link";
    }

    setKind(visualKind);
    setBody(lesson.body || "");
    setFileUrl(lesson.file_url || "");
    setDurationMinutes(Math.round((lesson.duration_seconds || 0) / 60));
    setOrderIndex(lesson.order_index || 1);
    setDescription(lesson.body?.slice(0, 100) || "");
    setVisibility("visible");
    setStep(1);
    setModalOpen(true);
  };

  const handleSubmit = async (e?: React.FormEvent) => {
    if (e) e.preventDefault();
    if (!title.trim()) {
      toast.error("Material nomini kiriting");
      return;
    }
    if (!formTopicId) {
      toast.error("Mavzuni tanlang");
      return;
    }
    if (kind === "pdf" && !fileUrl.trim()) {
      toast.error("PDF fayl URL manzilini kiriting");
      return;
    }
    if (kind === "link" && !fileUrl.trim()) {
      toast.error("Tashqi havola URL manzilini kiriting");
      return;
    }
    if (kind === "text" && !body.trim()) {
      toast.error("Matn darsi kontentini kiriting");
      return;
    }

    const dbKind = kind === "text" ? "text" : "pdf";

    const payload = {
      topic_id: formTopicId,
      kind: dbKind,
      title,
      body: kind === "text" ? body : description || null,
      file_url: kind === "text" ? null : fileUrl,
      duration_seconds: Number(durationMinutes) * 60,
      order_index: Number(orderIndex),
    };

    try {
      if (editingLesson) {
        await updateLessonMutation.mutateAsync({
          id: editingLesson.id,
          ...payload,
        });
        toast.success("Material muvaffaqiyatli yangilandi");
      } else {
        await createLessonMutation.mutateAsync(payload);
        toast.success("Yangi material muvaffaqiyatli qo'shildi");
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
      toast.success("Material muvaffaqiyatli o'chirildi");
    } catch (err: any) {
      toast.error(err.message || "O'chirishda xatolik yuz berdi");
    } finally {
      setDeleteConfirm({ open: false, id: null });
    }
  };

  const filteredLessons = useMemo(() => {
    if (!lessons) return [];

    const pdfOrText = lessons.filter(
      (l: any) => l.kind === "pdf" || l.kind === "text",
    );

    return pdfOrText
      .filter((l: any) => {
        let visualKind: "pdf" | "text" | "link" = "pdf";
        if (l.kind === "text") {
          visualKind = "text";
        } else if (l.kind === "pdf") {
          const isUrlPdf = (l.file_url || "").toLowerCase().includes(".pdf");
          visualKind = isUrlPdf ? "pdf" : "link";
        }

        const matchesSearch = l.title
          .toLowerCase()
          .includes(searchTerm.toLowerCase());
        const matchesType = typeFilter === "all" || visualKind === typeFilter;

        return matchesSearch && matchesType;
      })
      .sort((a: any, b: any) => (a.order_index || 0) - (b.order_index || 0));
  }, [lessons, searchTerm, typeFilter]);

  const stats = useMemo(() => {
    if (!lessons) return { total: 0, pdfs: 0, texts: 0, links: 0 };
    const pdfOrText = lessons.filter(
      (l: any) => l.kind === "pdf" || l.kind === "text",
    );

    let pdfs = 0;
    let texts = 0;
    let links = 0;

    pdfOrText.forEach((l: any) => {
      if (l.kind === "text") texts++;
      else if (l.kind === "pdf") {
        if ((l.file_url || "").toLowerCase().includes(".pdf")) pdfs++;
        else links++;
      }
    });

    return { total: pdfOrText.length, pdfs, texts, links };
  }, [lessons]);

  const selectedTopic = topics?.find((t: any) => t.id === filterTopicId);
  const topicTitle = selectedTopic ? selectedTopic.title : "Barcha mavzular";

  return (
    <div className="min-h-screen bg-slate-50/50 pb-20">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 mb-8">
        <div>
          <div className="flex items-center gap-1.5 text-[10px] font-bold text-slate-400 uppercase tracking-wider mb-2">
            <span>Mavzular</span> <ChevronRight className="size-3" />
            <span className="text-blue-600 font-extrabold">
              {topicTitle}
            </span>{" "}
            <ChevronRight className="size-3" />
            <span>Materiallar</span>
          </div>
          <h1 className="text-3xl font-black text-slate-900 flex items-center gap-2">
            O'quv Materiallari
          </h1>
        </div>

        <Button
          onClick={openCreateModal}
          className="flex gap-2 bg-blue-600 hover:bg-blue-700 text-white shadow-lg shadow-blue-500/20 rounded-full px-6 h-11 transition-all hover:scale-105 active:scale-95"
        >
          <Plus className="size-5" />
          Yangi Material
        </Button>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-12 gap-6 mb-8">
        <div className="md:col-span-4 lg:col-span-4 bg-white/80 backdrop-blur-xl border border-white shadow-sm rounded-3xl p-5 flex flex-col justify-center gap-4">
          <div className="space-y-2">
            <p className="text-[10px] font-bold text-slate-400 uppercase tracking-wider">
              Modulni tanlang
            </p>
            <Select
              value={filterModuleId}
              onChange={(e) => setFilterModuleId(e.target.value)}
              className="h-11 w-full bg-slate-50/50 border-transparent focus:bg-white rounded-xl font-bold text-slate-700"
            >
              <option value="">Barcha Modullar</option>
              {modules?.map((m: any) => (
                <option key={m.id} value={m.id}>
                  {m.title}
                </option>
              ))}
            </Select>
          </div>
          <div className="space-y-2">
            <p className="text-[10px] font-bold text-slate-400 uppercase tracking-wider">
              Mavzuni tanlang
            </p>
            <Select
              value={filterTopicId}
              onChange={(e) => setFilterTopicId(e.target.value)}
              disabled={!filterModuleId || isTopicsLoading}
              className="h-11 w-full bg-slate-50/50 border-transparent focus:bg-white rounded-xl font-bold text-slate-700"
            >
              <option value="">Barcha Mavzular</option>
              {topics?.map((t: any) => (
                <option key={t.id} value={t.id}>
                  {t.title}
                </option>
              ))}
            </Select>
          </div>
        </div>

        <div className="md:col-span-8 lg:col-span-8 grid grid-cols-2 sm:grid-cols-4 gap-4">
          <div className="bg-white/60 backdrop-blur-xl border border-white shadow-sm rounded-3xl p-4 flex flex-col justify-center items-center text-center">
            <div className="size-10 rounded-full bg-slate-100 text-slate-600 flex items-center justify-center mb-2">
              <Layers className="size-5" />
            </div>
            <p className="text-2xl font-black text-slate-900">{stats.total}</p>
            <p className="text-[10px] font-bold text-slate-500 uppercase tracking-wider mt-1">
              Jami
            </p>
          </div>
          <div className="bg-white/60 backdrop-blur-xl border border-white shadow-sm rounded-3xl p-4 flex flex-col justify-center items-center text-center">
            <div className="size-10 rounded-full bg-red-50 text-red-600 flex items-center justify-center mb-2">
              <FileJson className="size-5" />
            </div>
            <p className="text-2xl font-black text-slate-900">{stats.pdfs}</p>
            <p className="text-[10px] font-bold text-slate-500 uppercase tracking-wider mt-1">
              PDF Fayllar
            </p>
          </div>
          <div className="bg-white/60 backdrop-blur-xl border border-white shadow-sm rounded-3xl p-4 flex flex-col justify-center items-center text-center">
            <div className="size-10 rounded-full bg-blue-50 text-blue-600 flex items-center justify-center mb-2">
              <FileText className="size-5" />
            </div>
            <p className="text-2xl font-black text-slate-900">{stats.texts}</p>
            <p className="text-[10px] font-bold text-slate-500 uppercase tracking-wider mt-1">
              Matn Darslar
            </p>
          </div>
          <div className="bg-white/60 backdrop-blur-xl border border-white shadow-sm rounded-3xl p-4 flex flex-col justify-center items-center text-center">
            <div className="size-10 rounded-full bg-fuchsia-50 text-fuchsia-600 flex items-center justify-center mb-2">
              <LinkIcon className="size-5" />
            </div>
            <p className="text-2xl font-black text-slate-900">{stats.links}</p>
            <p className="text-[10px] font-bold text-slate-500 uppercase tracking-wider mt-1">
              Havolalar
            </p>
          </div>
        </div>
      </div>

      <div className="bg-white/80 backdrop-blur-xl border border-white shadow-sm rounded-2xl p-3 flex flex-wrap items-center gap-3 mb-8">
        <div className="relative flex-1 min-w-[250px]">
          <Search className="absolute left-4 top-1/2 -translate-y-1/2 size-5 text-slate-400" />
          <Input
            placeholder="Materiallarni izlash..."
            className="pl-11 h-12 w-full bg-slate-50/50 border-transparent hover:border-slate-200 focus:border-blue-500 rounded-xl transition-all"
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
          />
        </div>
        <div className="h-8 w-px bg-slate-200 hidden md:block"></div>
        <Select
          value={typeFilter}
          onChange={(e: any) => setTypeFilter(e.target.value)}
          className="h-12 w-full md:w-[180px] bg-slate-50/50 border-transparent rounded-xl font-medium text-slate-700"
        >
          <option value="all">Barcha Turlar</option>
          <option value="pdf">Faqat PDF Fayllar</option>
          <option value="text">Faqat Matn Darslar</option>
          <option value="link">Faqat Havolalar</option>
        </Select>
      </div>

      {/* Premium Table View */}
      {isLessonsLoading ? (
        <Card className="rounded-3xl border border-white shadow-sm overflow-hidden">
          <div className="p-6 flex flex-col gap-4">
            {[1, 2, 3].map((i) => (
              <Skeleton key={i} className="h-16 w-full rounded-2xl" />
            ))}
          </div>
        </Card>
      ) : !filteredLessons.length ? (
        <div className="flex flex-col items-center justify-center py-20 px-4 bg-white/50 backdrop-blur-sm rounded-3xl border border-white border-dashed">
          <div className="size-24 bg-blue-50 rounded-full flex items-center justify-center mb-6">
            <BookOpen className="size-10 text-blue-500" />
          </div>
          <h3 className="text-2xl font-black text-slate-900 mb-2">
            Materiallar Topilmadi
          </h3>
          <p className="text-slate-500 text-center max-w-md mb-8">
            Bu mavzu uchun hali hech qanday PDF, matn yoki havola qo'shilmagan.
          </p>
          <Button
            onClick={openCreateModal}
            className="rounded-full px-8 h-12 bg-blue-600 hover:bg-blue-700 text-white font-bold tracking-wide"
          >
            <Plus className="size-5 mr-2" /> Birinchi Materialni Qo'shish
          </Button>
        </div>
      ) : (
        <Card className="rounded-3xl border border-white shadow-sm overflow-hidden bg-white/80 backdrop-blur-xl animate-in fade-in-50 duration-200">
          <div className="overflow-x-auto edulab-scrollbar">
            <table className="w-full text-sm">
              <thead className="bg-slate-50 text-left text-[10px] font-black uppercase text-slate-400 tracking-wider border-b border-slate-100">
                <tr>
                  <th className="px-6 py-5 w-16 text-center">#</th>
                  <th className="px-6 py-5 min-w-[280px]">Material Nomi</th>
                  <th className="px-6 py-5 text-center w-36">Turi</th>
                  <th className="px-6 py-5 text-center w-36">Davomiyligi</th>
                  <th className="px-6 py-5 text-center w-32">Holati</th>
                  <th className="px-6 py-5 text-right w-36">Amallar</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-50">
                {filteredLessons.map((lesson: any, idx: number) => {
                  let visualKind: "pdf" | "text" | "link" = "pdf";
                  if (lesson.kind === "text") {
                    visualKind = "text";
                  } else if (lesson.kind === "pdf") {
                    const isUrlPdf = (lesson.file_url || "")
                      .toLowerCase()
                      .includes(".pdf");
                    visualKind = isUrlPdf ? "pdf" : "link";
                  }

                  return (
                    <tr
                      key={lesson.id}
                      className="hover:bg-blue-50/30 transition-colors group"
                    >
                      <td className="px-6 py-4 text-center">
                        <span className="font-black text-slate-300 group-hover:text-blue-400 transition-colors">
                          {lesson.order_index}
                        </span>
                      </td>
                      <td className="px-6 py-4">
                        <div className="flex items-center gap-4">
                          <div
                            className={`size-12 rounded-2xl flex items-center justify-center shrink-0 shadow-sm border ${
                              visualKind === "pdf"
                                ? "bg-red-50 border-red-100 text-red-600"
                                : visualKind === "text"
                                  ? "bg-blue-50 border-blue-100 text-blue-600"
                                  : "bg-fuchsia-50 border-fuchsia-100 text-fuchsia-600"
                            }`}
                          >
                            {visualKind === "pdf" && (
                              <FileJson className="size-6" />
                            )}
                            {visualKind === "text" && (
                              <FileText className="size-6" />
                            )}
                            {visualKind === "link" && (
                              <Globe className="size-6" />
                            )}
                          </div>
                          <div className="min-w-0">
                            <p className="font-black text-slate-900 truncate text-base group-hover:text-blue-600 transition-colors">
                              {lesson.title}
                            </p>
                            <p className="text-xs text-slate-400 font-medium truncate mt-0.5 max-w-[200px] sm:max-w-[300px]">
                              {visualKind === "text"
                                ? "Batafsil matnli kontent"
                                : lesson.file_url || "Manzil yo'q"}
                            </p>
                          </div>
                        </div>
                      </td>
                      <td className="px-6 py-4 text-center">
                        {visualKind === "pdf" && (
                          <Badge variant="destructive" className="bg-red-50">
                            PDF Hujjat
                          </Badge>
                        )}
                        {visualKind === "text" && (
                          <Badge variant="blue" className="bg-blue-50">
                            Matnli Dars
                          </Badge>
                        )}
                        {visualKind === "link" && (
                          <Badge variant="fuchsia" className="bg-fuchsia-50">
                            Tashqi Havola
                          </Badge>
                        )}
                      </td>
                      <td className="px-6 py-4 text-center">
                        <span className="inline-flex items-center gap-1 font-bold text-slate-600">
                          <Clock className="size-3.5 text-slate-400" />
                          {Math.round((lesson.duration_seconds || 0) / 60)} daq.
                        </span>
                      </td>
                      <td className="px-6 py-4 text-center">
                        <Badge variant="success">Faol</Badge>
                      </td>
                      <td className="px-6 py-4">
                        <div className="flex items-center justify-end gap-2 opacity-100 sm:opacity-0 sm:group-hover:opacity-100 transition-opacity">
                          {visualKind !== "text" && lesson.file_url && (
                            <Button
                              variant="ghost"
                              size="icon"
                              className="size-9 rounded-xl text-slate-400 hover:text-indigo-600 hover:bg-indigo-50"
                              onClick={() =>
                                window.open(lesson.file_url, "_blank")
                              }
                            >
                              <Download className="size-4.5" />
                            </Button>
                          )}
                          <Button
                            onClick={() => openEditModal(lesson)}
                            variant="ghost"
                            size="icon"
                            className="size-9 rounded-xl text-slate-400 hover:text-blue-600 hover:bg-blue-50"
                          >
                            <Pencil className="size-4.5" />
                          </Button>
                          <Button
                            onClick={() =>
                              setDeleteConfirm({ open: true, id: lesson.id })
                            }
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

      {/* FULL SCREEN WIZARD MODAL */}
      {modalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-900/60 backdrop-blur-md p-0 sm:p-6 animate-in fade-in duration-300">
          <div className="bg-white sm:rounded-[2.5rem] shadow-2xl w-full h-full sm:h-[90vh] max-w-6xl overflow-hidden flex flex-col md:flex-row animate-in zoom-in-95 slide-in-from-bottom-8 duration-500 relative">
            <button
              onClick={() => setModalOpen(false)}
              className="md:hidden absolute top-4 right-4 z-50 p-2 bg-white rounded-full shadow-md text-slate-500 hover:text-red-500"
            >
              <Plus className="size-6 rotate-45" />
            </button>

            {/* Left Side: Form Steps */}
            <div className="w-full md:w-3/5 lg:w-1/2 h-full flex flex-col bg-white z-10 overflow-y-auto">
              <div className="px-8 sm:px-12 pt-12 pb-6">
                <h2 className="text-3xl font-black text-slate-900 mb-2">
                  {editingLesson
                    ? "Materialni Tahrirlash"
                    : "Yangi Material Qo'shish"}
                </h2>
                <p className="text-slate-500">
                  O'quv materiallari, hujjatlar yoki havolalar kiriting.
                </p>
              </div>

              <div className="px-8 sm:px-12 mb-8">
                <div className="flex justify-between relative">
                  <div className="absolute left-0 top-1/2 -translate-y-1/2 w-full h-1 bg-slate-100 rounded-full" />
                  <div
                    className="absolute left-0 top-1/2 -translate-y-1/2 h-1 bg-blue-600 rounded-full transition-all duration-500"
                    style={{ width: `${(step - 1) * 100}%` }}
                  />

                  {[1, 2].map((s) => (
                    <button
                      key={s}
                      onClick={() => s < step && setStep(s)}
                      disabled={s > step}
                      className={`relative flex flex-col items-center gap-2 z-10 ${s > step ? "cursor-not-allowed opacity-50" : "cursor-pointer"}`}
                    >
                      <div
                        className={`size-10 rounded-full flex items-center justify-center font-black text-sm transition-all duration-300 shadow-sm ${step === s ? "bg-blue-600 text-white scale-110 ring-4 ring-blue-600/20" : step > s ? "bg-emerald-500 text-white" : "bg-white text-slate-400 border-2 border-slate-200"}`}
                      >
                        {step > s ? <CheckCircle2 className="size-5" /> : s}
                      </div>
                    </button>
                  ))}
                </div>
                <div className="flex justify-between mt-3 text-[10px] font-bold uppercase tracking-wider text-slate-400">
                  <span className={step >= 1 ? "text-blue-600" : ""}>
                    Asosiy
                  </span>
                  <span className={step >= 2 ? "text-blue-600" : ""}>
                    Kontent
                  </span>
                </div>
              </div>

              <div className="flex-1 px-8 sm:px-12 overflow-y-auto pb-32">
                <div className="max-w-md mx-auto w-full">
                  {step === 1 && (
                    <div className="space-y-6 animate-in slide-in-from-right-8 fade-in duration-500">
                      <div className="grid gap-2">
                        <label className="text-sm font-bold text-slate-800">
                          Qaysi modulga tegishli?{" "}
                          <span className="text-red-500">*</span>
                        </label>
                        <Select
                          value={formModuleId}
                          onChange={(e) => {
                            setFormModuleId(e.target.value);
                            setFormTopicId("");
                          }}
                          className="h-14 rounded-2xl bg-slate-50 border-transparent focus:bg-white focus:border-blue-600 px-5 text-lg font-bold text-slate-700"
                        >
                          <option value="" disabled>
                            Modulni tanlang
                          </option>
                          {modules?.map((m: any) => (
                            <option key={m.id} value={m.id}>
                              {m.title}
                            </option>
                          ))}
                        </Select>
                      </div>

                      <div className="grid gap-2">
                        <label className="text-sm font-bold text-slate-800">
                          Mavzuni tanlang{" "}
                          <span className="text-red-500">*</span>
                        </label>
                        <Select
                          value={formTopicId}
                          onChange={(e) => setFormTopicId(e.target.value)}
                          disabled={!formModuleId}
                          className="h-14 rounded-2xl bg-slate-50 border-transparent focus:bg-white focus:border-blue-600 px-5 text-lg font-bold text-slate-700 disabled:opacity-50"
                        >
                          <option value="" disabled>
                            Avval modulni tanlang
                          </option>
                          {formTopics?.map((t: any) => (
                            <option key={t.id} value={t.id}>
                              {t.title}
                            </option>
                          ))}
                        </Select>
                      </div>

                      <div className="grid gap-2">
                        <label className="text-sm font-bold text-slate-800">
                          Material Turi <span className="text-red-500">*</span>
                        </label>
                        <div className="grid grid-cols-3 gap-3">
                          <button
                            type="button"
                            onClick={() => handleKindChange("pdf")}
                            className={`flex flex-col items-center justify-center p-4 rounded-2xl border-2 transition-all ${kind === "pdf" ? "bg-red-50 border-red-200 text-red-600 scale-[1.02]" : "bg-white border-slate-100 text-slate-400 hover:border-slate-200 hover:bg-slate-50"}`}
                          >
                            <FileJson className="size-6 mb-2" />
                            <span className="text-[10px] font-black uppercase tracking-wider">
                              PDF Fayl
                            </span>
                          </button>
                          <button
                            type="button"
                            onClick={() => handleKindChange("text")}
                            className={`flex flex-col items-center justify-center p-4 rounded-2xl border-2 transition-all ${kind === "text" ? "bg-blue-50 border-blue-200 text-blue-600 scale-[1.02]" : "bg-white border-slate-100 text-slate-400 hover:border-slate-200 hover:bg-slate-50"}`}
                          >
                            <FileText className="size-6 mb-2" />
                            <span className="text-[10px] font-black uppercase tracking-wider">
                              Matn
                            </span>
                          </button>
                          <button
                            type="button"
                            onClick={() => handleKindChange("link")}
                            className={`flex flex-col items-center justify-center p-4 rounded-2xl border-2 transition-all ${kind === "link" ? "bg-fuchsia-50 border-fuchsia-200 text-fuchsia-600 scale-[1.02]" : "bg-white border-slate-100 text-slate-400 hover:border-slate-200 hover:bg-slate-50"}`}
                          >
                            <LinkIcon className="size-6 mb-2" />
                            <span className="text-[10px] font-black uppercase tracking-wider">
                              Havola
                            </span>
                          </button>
                        </div>
                      </div>

                      <div className="grid gap-2">
                        <label className="text-sm font-bold text-slate-800">
                          Material Nomi <span className="text-red-500">*</span>
                        </label>
                        <Input
                          placeholder="Masalan: JavaScript darslik PDF"
                          value={title}
                          onChange={(e) => setTitle(e.target.value)}
                          className="h-14 rounded-2xl bg-slate-50 border-transparent focus:bg-white focus:border-blue-600 px-5 text-lg font-medium transition-all"
                        />
                      </div>
                    </div>
                  )}

                  {step === 2 && (
                    <div className="space-y-6 animate-in slide-in-from-right-8 fade-in duration-500">
                      {kind === "text" ? (
                        <div className="grid gap-2">
                          <label className="text-sm font-bold text-slate-800">
                            Matnli dars kontenti{" "}
                            <span className="text-red-500">*</span>
                          </label>
                          <Textarea
                            placeholder="Dars matnini bu yerga kiriting..."
                            value={body}
                            onChange={(e) => setBody(e.target.value)}
                            className="h-64 rounded-2xl bg-slate-50 border-transparent focus:bg-white focus:border-blue-600 px-5 py-4 text-base font-medium transition-all resize-none"
                          />
                        </div>
                      ) : (
                        <div className="grid gap-2">
                          <label className="text-sm font-bold text-slate-800">
                            {kind === "pdf"
                              ? "PDF fayl manzili (URL)"
                              : "Tashqi havola manzili (URL)"}{" "}
                            <span className="text-red-500">*</span>
                          </label>
                          <div className="relative">
                            {kind === "pdf" ? (
                              <UploadCloud className="absolute left-4 top-1/2 -translate-y-1/2 size-5 text-slate-400" />
                            ) : (
                              <Globe className="absolute left-4 top-1/2 -translate-y-1/2 size-5 text-slate-400" />
                            )}
                            <Input
                              placeholder={
                                kind === "pdf"
                                  ? "https://.../document.pdf"
                                  : "https://..."
                              }
                              value={fileUrl}
                              onChange={(e) => setFileUrl(e.target.value)}
                              className="h-14 rounded-2xl bg-slate-50 border-transparent focus:bg-white focus:border-blue-600 pl-12 text-base font-medium transition-all"
                            />
                          </div>
                        </div>
                      )}

                      <div className="grid grid-cols-2 gap-4">
                        <div className="grid gap-2">
                          <label className="text-sm font-bold text-slate-800">
                            Tartib raqami
                          </label>
                          <Input
                            type="number"
                            value={orderIndex}
                            onChange={(e) =>
                              setOrderIndex(Number(e.target.value))
                            }
                            min={1}
                            className="h-14 rounded-2xl bg-slate-50 border-transparent focus:bg-white focus:border-blue-600 px-5 text-lg font-bold"
                          />
                        </div>
                        <div className="grid gap-2">
                          <label className="text-sm font-bold text-slate-800">
                            O'qish vaqti (Daqiqa)
                          </label>
                          <Input
                            type="number"
                            value={durationMinutes}
                            onChange={(e) =>
                              setDurationMinutes(Number(e.target.value))
                            }
                            min={1}
                            className="h-14 rounded-2xl bg-slate-50 border-transparent focus:bg-white focus:border-blue-600 px-5 text-lg font-bold"
                          />
                        </div>
                      </div>

                      <Button
                        onClick={handleSubmit}
                        disabled={
                          createLessonMutation.isPending ||
                          updateLessonMutation.isPending
                        }
                        className="h-16 px-12 rounded-full text-lg font-black bg-blue-600 hover:bg-blue-700 text-white shadow-xl shadow-blue-600/20 w-full mt-4"
                      >
                        {createLessonMutation.isPending ||
                        updateLessonMutation.isPending ? (
                          <Loader2 className="size-6 animate-spin mr-3" />
                        ) : null}
                        {editingLesson
                          ? "Materialni Saqlash"
                          : "Materialni Yaratish"}
                      </Button>
                    </div>
                  )}
                </div>
              </div>

              {step === 1 && (
                <div className="absolute bottom-0 left-0 w-full md:w-3/5 lg:w-1/2 p-6 sm:p-8 bg-white border-t border-slate-100 flex justify-between items-center z-20">
                  <Button
                    variant="ghost"
                    onClick={() => setModalOpen(false)}
                    className="text-slate-500 font-bold hover:bg-slate-100 rounded-full px-6 h-12"
                  >
                    Bekor qilish
                  </Button>
                  <Button
                    onClick={() => setStep((s) => s + 1)}
                    className="rounded-full px-8 h-12 font-bold bg-blue-600 hover:bg-blue-700 text-white shadow-lg shadow-blue-500/20"
                  >
                    Keyingisi <ArrowRight className="size-4 ml-2" />
                  </Button>
                </div>
              )}
            </div>

            {/* Right Side: Preview Panel */}
            <div className="hidden md:flex w-2/5 lg:w-1/2 h-full bg-slate-900 flex-col items-center justify-center p-12 relative overflow-hidden">
              <div
                className={`absolute inset-0 z-0 transition-colors duration-700 ${kind === "pdf" ? "bg-red-950/20" : kind === "text" ? "bg-blue-950/20" : "bg-fuchsia-950/20"}`}
              ></div>

              <div className="relative z-10 w-full max-w-[400px] flex flex-col items-center">
                <p className="text-white font-black tracking-widest uppercase text-[10px] mb-8 flex items-center gap-2 opacity-50">
                  <span className="w-2 h-2 rounded-full bg-white animate-pulse"></span>{" "}
                  O'quvchi Ko'rinishi
                </p>

                <div className="w-full bg-white rounded-[2rem] shadow-2xl overflow-hidden p-8 flex flex-col items-center text-center transition-all duration-500 hover:scale-[1.02]">
                  <div
                    className={`size-24 rounded-[2rem] flex items-center justify-center shadow-inner mb-6 ${
                      kind === "pdf"
                        ? "bg-red-50 text-red-500"
                        : kind === "text"
                          ? "bg-blue-50 text-blue-500"
                          : "bg-fuchsia-50 text-fuchsia-500"
                    }`}
                  >
                    {kind === "pdf" && <FileJson className="size-10" />}
                    {kind === "text" && <FileText className="size-10" />}
                    {kind === "link" && <Globe className="size-10" />}
                  </div>

                  <Badge
                    variant={
                      kind === "pdf"
                        ? "destructive"
                        : kind === "text"
                          ? "blue"
                          : "fuchsia"
                    }
                    className="mb-4"
                  >
                    {kind === "pdf"
                      ? "PDF Hujjat"
                      : kind === "text"
                        ? "Matnli dars"
                        : "Tashqi havola"}
                  </Badge>

                  <h3 className="text-xl font-black text-slate-900 leading-snug mb-3">
                    {title || "Material nomi kiritilmagan"}
                  </h3>

                  <p className="text-sm font-bold text-slate-400 flex items-center justify-center gap-1.5 mb-8">
                    <Clock className="size-4" /> {durationMinutes} daqiqa o'qish
                    vaqti
                  </p>

                  <div className="w-full h-12 rounded-xl bg-slate-50 border-2 border-dashed border-slate-200 flex items-center justify-center text-slate-400 text-sm font-bold">
                    Material kontenti zonasi
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      )}

      <ConfirmDialog
        open={deleteConfirm.open}
        title="Materialni o'chirish"
        description="Siz haqiqatan ham ushbu materialni o'chirmoqchimisiz? Uni qayta tiklash imkonsiz."
        confirmLabel="O'chirish"
        variant="danger"
        loading={deleteLessonMutation.isPending}
        onConfirm={handleDeleteConfirm}
        onCancel={() => setDeleteConfirm({ open: false, id: null })}
      />
    </div>
  );
}
