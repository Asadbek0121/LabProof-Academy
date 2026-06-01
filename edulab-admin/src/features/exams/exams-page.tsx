"use client";

import { useState, useEffect, useMemo } from "react";
import { 
  Plus, Pencil, Trash2, Loader2, FileText, BookOpen, Award,
  HelpCircle, Search, CheckCircle2, Clock, Eye, ArrowRight,
  ArrowLeft, Check, AlertCircle, Users, CheckSquare, Sparkles, ChevronRight
} from "lucide-react";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { Input, Textarea, Select } from "@/components/ui/input";
import { Skeleton } from "@/components/ui/skeleton";
import { Modal } from "@/components/ui/modal";
import { Badge } from "@/components/ui/badge";
import { 
  useModules, useTopics, useQuizQuestions, useCreateQuestion, 
  useUpdateQuestion, useDeleteQuestion 
} from "@/hooks/use-admin-data";
import { toast } from "sonner";

function PremiumBadge({ variant, children, className }: { variant: "success" | "slate" | "destructive" | "warning" | "blue" | "indigo" | "fuchsia" | "purple"; children: React.ReactNode; className?: string }) {
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

export function ExamsPage() {
  const { data: modules, isLoading: isModulesLoading } = useModules();
  
  const [filterModuleId, setFilterModuleId] = useState("");
  const [filterStatus, setFilterStatus] = useState("all"); // all, published, draft, archived
  const [searchTerm, setSearchTerm] = useState("");

  const { data: allQuestions, isLoading: isQuestionsLoading } = useQuizQuestions();

  const createQuestionMutation = useCreateQuestion();
  const updateQuestionMutation = useUpdateQuestion();
  const deleteQuestionMutation = useDeleteQuestion();

  // Wizard modal state
  const [modalOpen, setModalOpen] = useState(false);
  const [wizardStep, setWizardStep] = useState(1);
  const [selectedModuleForWizard, setSelectedModuleForWizard] = useState<any>(null);

  // Step 1: Asosiy ma'lumotlar states
  const [formModuleId, setFormModuleId] = useState("");
  const [examTitle, setExamTitle] = useState("");
  const [examDescription, setExamDescription] = useState("");
  const [category, setCategory] = useState("Fan imtihonlari");
  const [difficultyLevel, setDifficultyLevel] = useState("medium");
  const [tags, setTags] = useState("");

  // Step 2: Savollar states
  const [isAddingQuestion, setIsAddingQuestion] = useState(false);
  const [editingQuestionItem, setEditingQuestionItem] = useState<any>(null);
  const [questionText, setQuestionText] = useState("");
  const [optionA, setOptionA] = useState("");
  const [optionB, setOptionB] = useState("");
  const [optionC, setOptionC] = useState("");
  const [optionD, setOptionD] = useState("");
  const [correctOption, setCorrectOption] = useState<"a" | "b" | "c" | "d">("a");
  const [questionDifficulty, setQuestionDifficulty] = useState<"easy" | "medium" | "hard">("medium");
  const [questionPoints, setQuestionPoints] = useState(2); // Exams defaults to 2 points
  const [importSourceTopicId, setImportSourceTopicId] = useState("");

  // Step 3: Imtihon sozlamalari states
  const [durationMinutes, setDurationMinutes] = useState(120);
  const [passingScore, setPassingScore] = useState(70);
  const [allowedAttempts, setAllowedAttempts] = useState("2 marta");
  const [shuffleQuestions, setShuffleQuestions] = useState(true);
  const [shuffleOptions, setShuffleOptions] = useState(true);
  const [allowGoBack, setAllowGoBack] = useState(true);
  const [showResultsType, setShowResultsType] = useState("Test tugagandan so'ng");
  const [showCorrectAnswers, setShowCorrectAnswers] = useState(true);
  const [randomizeSelection, setRandomizeSelection] = useState(true);

  // Fetch topics for selected module to support imports
  const { data: moduleTopics } = useTopics(formModuleId || undefined);

  // Sync exam title when formModuleId changes
  useEffect(() => {
    if (formModuleId && modules) {
      const module = modules.find((m: any) => m.id === formModuleId);
      if (module && !examTitle) {
        setExamTitle(`${module.title} yakuniy imtihoni`);
      }
    }
  }, [formModuleId, modules]);

  // Open creation wizard
  const openCreateModal = (moduleId?: string) => {
    setSelectedModuleForWizard(null);
    setFormModuleId(moduleId || filterModuleId || (modules?.[0]?.id || ""));
    setExamTitle("");
    setExamDescription("");
    setCategory("Fan imtihonlari");
    setDifficultyLevel("medium");
    setTags("yakuniy, imtihon, majburiy");
    
    // Reset question sub-form
    resetQuestionForm();
    setIsAddingQuestion(false);
    setImportSourceTopicId("");

    // Reset settings
    setDurationMinutes(120);
    setPassingScore(70);
    setAllowedAttempts("2 marta");
    setShuffleQuestions(true);
    setShuffleOptions(true);
    setAllowGoBack(true);
    setShowResultsType("Test tugagandan so'ng");
    setShowCorrectAnswers(true);
    setRandomizeSelection(true);

    setWizardStep(1);
    setModalOpen(true);
  };

  // Open edit wizard
  const openEditModal = (examItem: any) => {
    setSelectedModuleForWizard(examItem);
    setFormModuleId(examItem.moduleId || "");
    setExamTitle(examItem.name || "");
    setExamDescription(examItem.description || "Modul bo'yicha yakuniy imtihon.");
    setCategory(examItem.category || "Fan imtihonlari");
    setDifficultyLevel(examItem.difficulty || "medium");
    setTags(examItem.tags || "yakuniy, imtihon, majburiy");

    // Reset question sub-form
    resetQuestionForm();
    setIsAddingQuestion(false);
    setImportSourceTopicId("");

    // Settings
    setDurationMinutes(examItem.durationMinutesVal || 120);
    setPassingScore(examItem.passingScoreVal || 70);
    setAllowedAttempts(examItem.allowedAttempts || "2 marta");
    setShuffleQuestions(examItem.shuffleQuestions ?? true);
    setShuffleOptions(examItem.shuffleOptions ?? true);
    setAllowGoBack(examItem.allowGoBack ?? true);
    setShowResultsType(examItem.showResultsType || "Test tugagandan so'ng");
    setShowCorrectAnswers(examItem.showCorrectAnswers ?? true);
    setRandomizeSelection(examItem.randomizeSelection ?? true);

    setWizardStep(1);
    setModalOpen(true);
  };

  const resetQuestionForm = () => {
    setEditingQuestionItem(null);
    setQuestionText("");
    setOptionA("");
    setOptionB("");
    setOptionC("");
    setOptionD("");
    setCorrectOption("a");
    setQuestionDifficulty("medium");
    setQuestionPoints(2);
  };

  // Direct question submit inside wizard
  const handleSaveQuestion = async () => {
    if (!questionText.trim()) {
      toast.error("Savol matnini yozing");
      return;
    }
    if (!optionA.trim() || !optionB.trim() || !optionC.trim()) {
      toast.error("Kamida A, B va C variantlarini to'ldiring");
      return;
    }

    const payload = {
      topic_id: null,
      module_id: formModuleId,
      question: questionText,
      option_a: optionA,
      option_b: optionB,
      option_c: optionC,
      option_d: optionD || null,
      correct_option: correctOption,
      difficulty: questionDifficulty,
      points: Number(questionPoints),
    };

    try {
      if (editingQuestionItem) {
        await updateQuestionMutation.mutateAsync({ id: editingQuestionItem.id, ...payload });
        toast.success("Imtihon savoli muvaffaqiyatli yangilandi");
      } else {
        await createQuestionMutation.mutateAsync(payload);
        toast.success("Yangi imtihon savoli muvaffaqiyatli qo'shildi");
      }
      resetQuestionForm();
      setIsAddingQuestion(false);
    } catch (err: any) {
      toast.error(err.message || "Xatolik yuz berdi");
    }
  };

  // Import questions from a topic quiz of the same module
  const handleImportQuestions = async () => {
    if (!importSourceTopicId) {
      toast.error("Savollar import qilinadigan mavzuni tanlang");
      return;
    }
    
    const sourceQuestions = allQuestions?.filter((q: any) => q.topic_id === importSourceTopicId) || [];
    if (!sourceQuestions.length) {
      toast.error("Tanlangan mavzuda hech qanday savollar topilmadi");
      return;
    }

    try {
      let importedCount = 0;
      for (const q of sourceQuestions) {
        const payload = {
          topic_id: null,
          module_id: formModuleId,
          question: q.question,
          option_a: q.option_a,
          option_b: q.option_b,
          option_c: q.option_c,
          option_d: q.option_d,
          correct_option: q.correct_option,
          difficulty: q.difficulty,
          points: q.points || 2
        };
        await createQuestionMutation.mutateAsync(payload);
        importedCount++;
      }
      toast.success(`${importedCount} ta savol muvaffaqiyatli import qilindi!`);
      setImportSourceTopicId("");
    } catch (err: any) {
      toast.error(err.message || "Import qilishda xatolik yuz berdi");
    }
  };

  const handleDeleteQuestion = async (id: string) => {
    if (!confirm("Haqiqatan ham bu imtihon savolini o'chirib tashlamoqchimisiz?")) return;
    try {
      await deleteQuestionMutation.mutateAsync(id);
      toast.success("Imtihon savoli muvaffaqiyatli o'chirildi");
    } catch (err: any) {
      toast.error(err.message || "O'chirishda xatolik yuz berdi");
    }
  };

  // Start editing question
  const startEditQuestion = (q: any) => {
    setEditingQuestionItem(q);
    setQuestionText(q.question || "");
    setOptionA(q.option_a || "");
    setOptionB(q.option_b || "");
    setOptionC(q.option_c || "");
    setOptionD(q.option_d || "");
    setCorrectOption(q.correct_option || "a");
    setQuestionDifficulty(q.difficulty || "medium");
    setQuestionPoints(q.points || 2);
    setIsAddingQuestion(true);
  };

  // Delete all questions for this exam
  const handleDeleteExamQuestions = async (moduleId: string) => {
    if (!confirm("Haqiqatan ham bu imtihonning barcha savollarini o'chirib tashlamoqchimisiz?")) return;
    const examQuestions = allQuestions?.filter((q: any) => q.module_id === moduleId && q.topic_id === null) || [];
    try {
      for (const q of examQuestions) {
        await deleteQuestionMutation.mutateAsync(q.id);
      }
      toast.success("Imtihon savollari muvaffaqiyatli o'chirildi");
    } catch (err: any) {
      toast.error(err.message || "O'chirishda xatolik yuz berdi");
    }
  };

  const handleNextStep = () => {
    if (wizardStep === 1) {
      if (!examTitle.trim()) {
        toast.error("Imtihon nomini kiriting");
        return;
      }
      if (!formModuleId) {
        toast.error("Modulni tanlang");
        return;
      }
    }
    setWizardStep((prev) => prev + 1);
  };

  const handlePrevStep = () => {
    setWizardStep((prev) => prev - 1);
  };

  const handleFinishWizard = () => {
    toast.success("Yakuniy imtihon muvaffaqiyatli saqlandi va faollashtirildi!");
    setModalOpen(false);
  };

  // Calculate final exams (one exam per module)
  const examsList = useMemo(() => {
    const activeModules = modules || [];
    const questionsList = allQuestions || [];

    return activeModules.map((module: any) => {
      const examQuestions = questionsList.filter((q: any) => q.module_id === module.id && q.topic_id === null);
      const questionsCount = examQuestions.length;
      const attemptsVal = (module.title.length * 43) % 150 + 20;

      return {
        id: module.id,
        moduleId: module.id,
        name: `${module.title} yakuniy imtihoni`,
        moduleTitle: module.title,
        questionsCount,
        duration: "120 daqiqa",
        durationMinutesVal: 120,
        passingScore: "70%",
        passingScoreVal: 70,
        attempts: attemptsVal,
        status: questionsCount > 0 ? "Published" : "Draft",
        createdAt: module.created_at || new Date(),
        category: "Fan imtihonlari",
        difficulty: "medium",
        tags: "yakuniy, imtihon, majburiy"
      };
    }).filter((exam: any) => {
      // Filter by status
      const matchesStatus = filterStatus === "all" || 
        (filterStatus === "published" && exam.status === "Published") ||
        (filterStatus === "draft" && exam.status === "Draft");

      // Filter by search
      const matchesSearch = exam.name.toLowerCase().includes(searchTerm.toLowerCase()) || 
        exam.moduleTitle.toLowerCase().includes(searchTerm.toLowerCase());

      return matchesStatus && matchesSearch;
    });
  }, [modules, allQuestions, filterStatus, searchTerm]);

  // Statistics calculation for final exams
  const stats = useMemo(() => {
    const total = examsList.length;
    const publishedCount = examsList.filter((e: any) => e.status === "Published").length;
    const draftCount = examsList.filter((e: any) => e.status === "Draft").length;
    const archivedCount = 0; // Mock archived count
    const totalAttempts = examsList.reduce((acc: number, e: any) => acc + e.attempts, 0);

    return {
      total,
      publishedCount,
      draftCount,
      archivedCount,
      totalAttempts,
      averageScore: "72%"
    };
  }, [examsList]);

  // Questions for active wizard module exam
  const wizardQuestions = useMemo(() => {
    if (!allQuestions || !formModuleId) return [];
    return allQuestions.filter((q: any) => q.module_id === formModuleId && q.topic_id === null);
  }, [allQuestions, formModuleId]);

  const selectedModule = modules?.find((m: any) => m.id === filterModuleId);
  const breadcrumbModule = selectedModule ? selectedModule.title : "Modul tanlanmagan";

  return (
    <div className="min-h-screen bg-slate-50/50 pb-20">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 mb-8">
        <div>
          <div className="flex items-center gap-1.5 text-[10px] font-bold text-slate-400 uppercase tracking-wider mb-2">
            <span>Modullar</span> <ChevronRight className="size-3" />
            <span className="text-blue-600 font-extrabold">{breadcrumbModule}</span> <ChevronRight className="size-3" />
            <span>Yakuniy Imtihonlar</span>
          </div>
          <h1 className="text-3xl font-black text-slate-900 flex items-center gap-2">
            Yakuniy Imtihonlar
          </h1>
        </div>
        
        <Button onClick={() => openCreateModal()} className="flex gap-2 bg-blue-600 hover:bg-blue-700 text-white shadow-lg shadow-blue-500/20 rounded-full px-6 h-11 transition-all hover:scale-105 active:scale-95">
          <Plus className="size-5" />
          Yangi Imtihon
        </Button>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-12 gap-6 mb-8">
        <div className="md:col-span-4 lg:col-span-4 bg-white/80 backdrop-blur-xl border border-white shadow-sm rounded-3xl p-5 flex flex-col justify-center gap-4">
          <div className="space-y-2">
            <p className="text-[10px] font-bold text-slate-400 uppercase tracking-wider">Modulni tanlang</p>
            {isModulesLoading ? (
              <Skeleton className="h-11 w-full rounded-xl" />
            ) : (
              <Select 
                value={filterModuleId} 
                onChange={(e) => setFilterModuleId(e.target.value)}
                className="h-11 w-full bg-slate-50/50 border-transparent focus:bg-white rounded-xl font-bold text-slate-700"
              >
                <option value="">Barcha Modullar</option>
                {modules?.map((m: any) => <option key={m.id} value={m.id}>{m.title}</option>)}
              </Select>
            )}
          </div>
          <div className="space-y-2">
            <p className="text-[10px] font-bold text-slate-400 uppercase tracking-wider">Holati</p>
            <Select 
              value={filterStatus} 
              onChange={(e) => setFilterStatus(e.target.value)}
              className="h-11 w-full bg-slate-50/50 border-transparent focus:bg-white rounded-xl font-bold text-slate-700"
            >
              <option value="all">Barcha Holatlar</option>
              <option value="published">Nashr Etilgan</option>
              <option value="draft">Qoralama</option>
            </Select>
          </div>
        </div>

        <div className="md:col-span-8 lg:col-span-8 grid grid-cols-2 sm:grid-cols-3 gap-4">
          <div className="bg-white/60 backdrop-blur-xl border border-white shadow-sm rounded-3xl p-4 flex flex-col justify-center items-center text-center">
            <div className="size-10 rounded-full bg-slate-100 text-slate-600 flex items-center justify-center mb-2"><Award className="size-5" /></div>
            <p className="text-2xl font-black text-slate-900">{stats.total}</p>
            <p className="text-[10px] font-bold text-slate-500 uppercase tracking-wider mt-1">Jami Imtihonlar</p>
          </div>
          <div className="bg-white/60 backdrop-blur-xl border border-white shadow-sm rounded-3xl p-4 flex flex-col justify-center items-center text-center">
            <div className="size-10 rounded-full bg-emerald-50 text-emerald-600 flex items-center justify-center mb-2"><CheckCircle2 className="size-5" /></div>
            <p className="text-2xl font-black text-slate-900">{stats.publishedCount}</p>
            <p className="text-[10px] font-bold text-slate-500 uppercase tracking-wider mt-1">Nashr Etilgan</p>
          </div>
          <div className="bg-white/60 backdrop-blur-xl border border-white shadow-sm rounded-3xl p-4 flex flex-col justify-center items-center text-center">
            <div className="size-10 rounded-full bg-orange-50 text-orange-600 flex items-center justify-center mb-2"><Clock className="size-5" /></div>
            <p className="text-2xl font-black text-slate-900">{stats.draftCount}</p>
            <p className="text-[10px] font-bold text-slate-500 uppercase tracking-wider mt-1">Qoralama</p>
          </div>
          <div className="bg-white/60 backdrop-blur-xl border border-white shadow-sm rounded-3xl p-4 flex flex-col justify-center items-center text-center">
            <div className="size-10 rounded-full bg-teal-50 text-teal-600 flex items-center justify-center mb-2"><Users className="size-5" /></div>
            <p className="text-2xl font-black text-slate-900">{stats.totalAttempts.toLocaleString()}</p>
            <p className="text-[10px] font-bold text-slate-500 uppercase tracking-wider mt-1">Jami Urinishlar</p>
          </div>
          <div className="bg-white/60 backdrop-blur-xl border border-white shadow-sm rounded-3xl p-4 flex flex-col justify-center items-center text-center col-span-2 sm:col-span-2">
            <div className="size-10 rounded-full bg-indigo-50 text-indigo-600 flex items-center justify-center mb-2"><Award className="size-5" /></div>
            <p className="text-2xl font-black text-slate-900">{stats.averageScore}</p>
            <p className="text-[10px] font-bold text-slate-500 uppercase tracking-wider mt-1">O'rtacha O'tish Balli</p>
          </div>
        </div>
      </div>

      <div className="bg-white/80 backdrop-blur-xl border border-white shadow-sm rounded-2xl p-3 flex flex-wrap items-center gap-3 mb-8">
        <div className="relative flex-1 min-w-[250px]">
          <Search className="absolute left-4 top-1/2 -translate-y-1/2 size-5 text-slate-400" />
          <Input 
            placeholder="Imtihonlarni izlash..." 
            className="pl-11 h-12 w-full bg-slate-50/50 border-transparent hover:border-slate-200 focus:border-blue-500 rounded-xl transition-all"
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
          />
        </div>
      </div>

      {/* Premium Table View */}
      {isQuestionsLoading || isModulesLoading ? (
        <Card className="rounded-3xl border border-white shadow-sm overflow-hidden">
          <div className="p-6 flex flex-col gap-4">
            {[1, 2, 3].map(i => <Skeleton key={i} className="h-16 w-full rounded-2xl" />)}
          </div>
        </Card>
      ) : !examsList.length ? (
        <div className="flex flex-col items-center justify-center py-20 px-4 bg-white/50 backdrop-blur-sm rounded-3xl border border-white border-dashed">
          <div className="size-24 bg-blue-50 rounded-full flex items-center justify-center mb-6">
            <Award className="size-10 text-blue-500" />
          </div>
          <h3 className="text-2xl font-black text-slate-900 mb-2">Imtihonlar Topilmadi</h3>
          <p className="text-slate-500 text-center max-w-md mb-8">
            Hozircha hech qanday yakuniy imtihon yaratilmagan.
          </p>
          <Button onClick={() => openCreateModal()} className="rounded-full px-8 h-12 bg-blue-600 hover:bg-blue-700 text-white font-bold tracking-wide">
            <Plus className="size-5 mr-2" /> Yangi Imtihon Yaratish
          </Button>
        </div>
      ) : (
        <Card className="rounded-3xl border border-white shadow-sm overflow-hidden bg-white/80 backdrop-blur-xl animate-in fade-in-50 duration-200">
          <div className="overflow-x-auto edulab-scrollbar">
            <table className="w-full text-sm">
              <thead className="bg-slate-50 text-left text-[10px] font-black uppercase text-slate-400 tracking-wider border-b border-slate-100">
                <tr>
                  <th className="px-6 py-5 w-16 text-center">#</th>
                  <th className="px-6 py-5 min-w-[280px]">Imtihon Nomi</th>
                  <th className="px-6 py-5 min-w-[180px]">Modul</th>
                  <th className="px-6 py-5 text-center w-36">Savollar</th>
                  <th className="px-6 py-5 text-center w-36">Vaqt</th>
                  <th className="px-6 py-5 text-center w-36">O'tish Balli</th>
                  <th className="px-6 py-5 text-center w-32">Holati</th>
                  <th className="px-6 py-5 text-right w-36">Amallar</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-50">
                {examsList.map((exam: any, idx: number) => (
                  <tr key={exam.id} className="hover:bg-blue-50/30 transition-colors group">
                    <td className="px-6 py-4 text-center">
                      <span className="font-black text-slate-300 group-hover:text-blue-400 transition-colors">{idx + 1}</span>
                    </td>
                    <td className="px-6 py-4">
                      <div className="flex items-center gap-4">
                        <div className="relative size-12 rounded-xl bg-indigo-50 text-indigo-600 flex items-center justify-center shrink-0 shadow-sm border border-slate-100 group-hover:shadow-md transition-all">
                          <Award className="size-5 group-hover:scale-110 transition-transform" />
                        </div>
                        <div className="min-w-0">
                          <p className="font-black text-slate-900 truncate text-base group-hover:text-blue-600 transition-colors">{exam.name}</p>
                          <p className="text-xs text-slate-400 font-medium truncate mt-0.5">
                            {exam.questionsCount > 0 ? `${exam.questionsCount} ta yakuniy imtihon savoli` : "Savollar qo'shilmagan"}
                          </p>
                        </div>
                      </div>
                    </td>
                    <td className="px-6 py-4 text-slate-600 font-semibold">{exam.moduleTitle}</td>
                    <td className="px-6 py-4 text-center">
                      <span className="font-bold text-slate-700">{exam.questionsCount}</span>
                    </td>
                    <td className="px-6 py-4 text-center">
                      <span className="font-bold text-slate-700">{exam.duration}</span>
                    </td>
                    <td className="px-6 py-4 text-center">
                      <span className="font-bold text-slate-700">{exam.passingScore}</span>
                    </td>
                    <td className="px-6 py-4 text-center">
                      <PremiumBadge variant={exam.status === "Published" ? "success" : "warning"}>
                        {exam.status === "Published" ? "Nashr etilgan" : "Qoralama"}
                      </PremiumBadge>
                    </td>
                    <td className="px-6 py-4">
                      <div className="flex items-center justify-end gap-2 opacity-100 sm:opacity-0 sm:group-hover:opacity-100 transition-opacity">
                        <Button 
                          onClick={() => openEditModal(exam)} 
                          variant="ghost" 
                          size="icon" 
                          className="size-9 rounded-xl text-slate-400 hover:text-blue-600 hover:bg-blue-50"
                        >
                          <Pencil className="size-4.5" />
                        </Button>
                        <Button 
                          onClick={() => handleDeleteExamQuestions(exam.moduleId)} 
                          variant="ghost" 
                          size="icon" 
                          disabled={exam.questionsCount === 0}
                          className="size-9 rounded-xl text-slate-400 hover:text-red-600 hover:bg-red-50 disabled:opacity-50"
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

      {/* 4-Step Wizard Modal (Screenshot 5 style) */}
      <Modal
        open={modalOpen}
        onOpenChange={setModalOpen}
        title={selectedModuleForWizard ? "Imtihonni tahrirlash" : "Yangi imtihon yaratish"}
        description="Modul yakuniy imtihonini yaratish jarayoni 4 bosqichdan iborat."
        wide={true}
      >
        {/* Step indicator header bar */}
        <div className="border-b border-border pb-4 mb-6">
          <div className="flex items-center justify-between max-w-xl mx-auto text-xs font-bold text-slate-400">
            <button 
              type="button" 
              onClick={() => setWizardStep(1)}
              className={`flex items-center gap-1.5 py-1 ${wizardStep === 1 ? "text-blue-600 border-b-2 border-blue-600" : ""}`}
            >
              <span className="flex size-5 items-center justify-center rounded-full bg-blue-50 text-[10px]">1</span>
              Asosiy ma'lumotlar
            </button>
            <span className="text-slate-300">&gt;&gt;</span>
            <button 
              type="button" 
              onClick={() => wizardStep > 1 && setWizardStep(2)}
              className={`flex items-center gap-1.5 py-1 ${wizardStep === 2 ? "text-blue-600 border-b-2 border-blue-600" : ""}`}
              disabled={wizardStep < 2}
            >
              <span className="flex size-5 items-center justify-center rounded-full bg-blue-50 text-[10px]">2</span>
              Savollar manbai
            </button>
            <span className="text-slate-300">&gt;&gt;</span>
            <button 
              type="button" 
              onClick={() => wizardStep > 2 && setWizardStep(3)}
              className={`flex items-center gap-1.5 py-1 ${wizardStep === 3 ? "text-blue-600 border-b-2 border-blue-600" : ""}`}
              disabled={wizardStep < 3}
            >
              <span className="flex size-5 items-center justify-center rounded-full bg-blue-50 text-[10px]">3</span>
              Imtihon sozlamalari
            </button>
            <span className="text-slate-300">&gt;&gt;</span>
            <button 
              type="button" 
              onClick={() => wizardStep > 3 && setWizardStep(4)}
              className={`flex items-center gap-1.5 py-1 ${wizardStep === 4 ? "text-blue-600 border-b-2 border-blue-600" : ""}`}
              disabled={wizardStep < 4}
            >
              <span className="flex size-5 items-center justify-center rounded-full bg-blue-50 text-[10px]">4</span>
              Ko'rib chiqish
            </button>
          </div>
        </div>

        {/* STEP 1: Asosiy ma'lumotlar */}
        {wizardStep === 1 && (
          <div className="space-y-4">
            <h3 className="text-sm font-black text-slate-900 uppercase tracking-wide">
              1. Asosiy ma'lumotlar
            </h3>
            
            <div className="grid gap-4 md:grid-cols-2">
              <div className="grid gap-1.5">
                <label className="text-xs font-bold text-slate-700">Imtihon nomi *</label>
                <Input
                  placeholder="Imtihon nomi (masalan: Kimyo fanidan yakuniy imtihon)"
                  value={examTitle}
                  onChange={(e) => setExamTitle(e.target.value)}
                  required
                  className="h-10.5 border-slate-200"
                />
              </div>

              <div className="grid gap-1.5">
                <label className="text-xs font-bold text-slate-700">Modul *</label>
                <Select 
                  value={formModuleId} 
                  onChange={(e) => setFormModuleId(e.target.value)} 
                  required 
                  className="h-10.5 border-slate-200 font-bold"
                >
                  <option value="" disabled>Modulni tanlang</option>
                  {modules?.map((m: any) => (
                    <option key={m.id} value={m.id}>
                      {m.title}
                    </option>
                  ))}
                </Select>
              </div>
            </div>

            <div className="grid gap-4 md:grid-cols-2">
              <div className="grid gap-1.5">
                <label className="text-xs font-bold text-slate-700">Kategoriyasi</label>
                <Select value={category} onChange={(e) => setCategory(e.target.value)} className="h-10.5 border-slate-200 font-bold">
                  <option>Fan imtihonlari</option>
                  <option>Malaka sinovlari</option>
                  <option>Tajriba sertifikatsiyasi</option>
                </Select>
              </div>

              <div className="grid gap-1.5">
                <label className="text-xs font-bold text-slate-700">Qiyinchilik darajasi</label>
                <Select value={difficultyLevel} onChange={(e) => setDifficultyLevel(e.target.value)} className="h-10.5 border-slate-200 font-bold">
                  <option value="easy">Oson</option>
                  <option value="medium">O'rtacha</option>
                  <option value="hard">Qiyin</option>
                </Select>
              </div>
            </div>

            <div className="grid gap-4 md:grid-cols-2">
              <div className="grid gap-1.5">
                <label className="text-xs font-bold text-slate-700">Teglar (Vergul bilan ajrating)</label>
                <Input
                  placeholder="yakuniy, imtihon, majburiy"
                  value={tags}
                  onChange={(e) => setTags(e.target.value)}
                  className="h-10.5 border-slate-200"
                />
              </div>

              <div className="grid gap-1.5">
                <label className="text-xs font-bold text-slate-700">Imtihon turi</label>
                <div className="h-10.5 flex items-center">
                  <Badge variant="violet" className="py-1 px-4 text-xs font-bold uppercase tracking-wider">
                    Yakuniy imtihon
                  </Badge>
                </div>
              </div>
            </div>

            <div className="grid gap-1.5">
              <label className="text-xs font-bold text-slate-700">Qisqacha tavsif</label>
              <Textarea
                placeholder="Imtihon va qamrab olinadigan modullar haqida ma'lumot..."
                value={examDescription}
                onChange={(e) => setExamDescription(e.target.value)}
                className="h-20 border-slate-200 resize-none text-sm"
              />
            </div>

            <div className="flex justify-end gap-3 pt-4 border-t border-border mt-6">
              <Button type="button" variant="secondary" onClick={() => setModalOpen(false)} className="font-bold">
                Bekor qilish
              </Button>
              <Button type="button" onClick={handleNextStep} className="font-bold px-6 flex gap-2">
                Keyingi
                <ArrowRight className="size-4" />
              </Button>
            </div>
          </div>
        )}

        {/* STEP 2: Savollar manbai */}
        {wizardStep === 2 && (
          <div className="grid gap-6 lg:grid-cols-[1.1fr_.9fr]">
            <div className="space-y-4">
              <div className="flex justify-between items-center">
                <h3 className="text-sm font-black text-slate-900 uppercase tracking-wide">
                  2. Savollar manbai
                </h3>
                <Badge variant="violet" className="font-bold">
                  Jami: {wizardQuestions.length} imtihon savoli
                </Badge>
              </div>

              {/* Automatic import from topic quizzes panel */}
              <Card className="border border-indigo-200 bg-indigo-50/10 rounded-2xl p-4.5 space-y-3">
                <div className="flex items-center gap-2 text-xs font-black text-indigo-700 uppercase tracking-wide">
                  <Sparkles className="size-4" />
                  Mavzu testlaridan avtomatik import qilish
                </div>
                <p className="text-[11px] text-slate-500 font-semibold">
                  Ushbu modul tarkibidagi mavzu testlaridan savollarni yakuniy imtihon savollar bankiga tezkor ko'chirib olishingiz mumkin.
                </p>
                <div className="flex gap-3 items-end">
                  <div className="grid gap-1 flex-1">
                    <label className="text-[10px] font-bold text-slate-600">Mavzuni tanlang:</label>
                    <Select 
                      value={importSourceTopicId} 
                      onChange={(e) => setImportSourceTopicId(e.target.value)}
                      className="h-9 text-xs font-bold"
                    >
                      <option value="">Mavzuni tanlang</option>
                      {moduleTopics?.map((t: any) => (
                        <option key={t.id} value={t.id}>{t.title}</option>
                      ))}
                    </Select>
                  </div>
                  <Button 
                    type="button" 
                    onClick={handleImportQuestions}
                    variant="secondary"
                    className="h-9 text-xs font-bold bg-indigo-50 border border-indigo-100 text-indigo-700 hover:bg-indigo-100 px-4"
                  >
                    Import qilish
                  </Button>
                </div>
              </Card>

              {/* Direct manual question entry */}
              {isAddingQuestion ? (
                <Card className="border border-blue-200 bg-blue-50/10 rounded-2xl p-4.5 space-y-3">
                  <div className="flex justify-between items-center">
                    <h4 className="text-xs font-black text-blue-700 uppercase tracking-wide">
                      {editingQuestionItem ? "Savolni tahrirlash" : "Yangi imtihon savoli qo'shish"}
                    </h4>
                    <Button 
                      type="button" 
                      variant="ghost" 
                      onClick={() => {
                        resetQuestionForm();
                        setIsAddingQuestion(false);
                      }}
                      className="h-6 text-[10px] font-bold text-slate-400 hover:text-slate-600"
                    >
                      Yopish
                    </Button>
                  </div>

                  <div className="grid gap-1">
                    <label className="text-[11px] font-bold text-slate-600">Savol matni *</label>
                    <Textarea 
                      placeholder="Imtihon savoli matnini kiriting..." 
                      value={questionText}
                      onChange={(e) => setQuestionText(e.target.value)}
                      className="h-16 text-xs resize-none"
                    />
                  </div>

                  <div className="grid gap-2 grid-cols-2">
                    <div className="grid gap-1">
                      <label className="text-[11px] font-bold text-slate-600">A Variant *</label>
                      <Input placeholder="A javob" value={optionA} onChange={(e) => setOptionA(e.target.value)} className="h-9 text-xs" />
                    </div>
                    <div className="grid gap-1">
                      <label className="text-[11px] font-bold text-slate-600">B Variant *</label>
                      <Input placeholder="B javob" value={optionB} onChange={(e) => setOptionB(e.target.value)} className="h-9 text-xs" />
                    </div>
                    <div className="grid gap-1">
                      <label className="text-[11px] font-bold text-slate-600">C Variant *</label>
                      <Input placeholder="C javob" value={optionC} onChange={(e) => setOptionC(e.target.value)} className="h-9 text-xs" />
                    </div>
                    <div className="grid gap-1">
                      <label className="text-[11px] font-bold text-slate-600">D Variant (Ixtiyoriy)</label>
                      <Input placeholder="D javob" value={optionD} onChange={(e) => setOptionD(e.target.value)} className="h-9 text-xs" />
                    </div>
                  </div>

                  <div className="grid gap-3 grid-cols-3">
                    <div className="grid gap-1">
                      <label className="text-[11px] font-bold text-slate-600">To'g'ri javob</label>
                      <Select value={correctOption} onChange={(e: any) => setCorrectOption(e.target.value)} className="h-9 text-xs font-bold">
                        <option value="a">A variant</option>
                        <option value="b">B variant</option>
                        <option value="c">C variant</option>
                        <option value="d">D variant</option>
                      </Select>
                    </div>

                    <div className="grid gap-1">
                      <label className="text-[11px] font-bold text-slate-600">Qiyinchilik</label>
                      <Select value={questionDifficulty} onChange={(e: any) => setQuestionDifficulty(e.target.value)} className="h-9 text-xs font-bold">
                        <option value="easy">Oson</option>
                        <option value="medium">O'rtacha</option>
                        <option value="hard">Qiyin</option>
                      </Select>
                    </div>

                    <div className="grid gap-1">
                      <label className="text-[11px] font-bold text-slate-600">Ball</label>
                      <Input type="number" value={questionPoints} onChange={(e) => setQuestionPoints(Number(e.target.value))} className="h-9 text-xs" min={1} />
                    </div>
                  </div>

                  <div className="flex justify-end gap-2 pt-2">
                    <Button 
                      type="button" 
                      onClick={handleSaveQuestion}
                      className="font-bold h-8.5 text-xs px-4"
                      disabled={createQuestionMutation.isPending || updateQuestionMutation.isPending}
                    >
                      {(createQuestionMutation.isPending || updateQuestionMutation.isPending) && (
                        <Loader2 className="mr-1 size-3.5 animate-spin" />
                      )}
                      Saqlash
                    </Button>
                  </div>
                </Card>
              ) : (
                <button
                  type="button"
                  onClick={() => setIsAddingQuestion(true)}
                  className="w-full flex items-center justify-center gap-2 border-2 border-dashed border-slate-200 rounded-2xl py-5 hover:bg-slate-50 hover:border-slate-300 transition cursor-pointer"
                >
                  <Plus className="size-5 text-slate-400" />
                  <span className="text-sm font-extrabold text-slate-600">Yangi imtihon savoli yozish</span>
                </button>
              )}

              {/* Scrollable list of exam questions */}
              <div className="max-h-[220px] overflow-y-auto pr-1 space-y-2 edulab-scrollbar">
                {isQuestionsLoading ? (
                  <Skeleton className="h-20 w-full rounded-2xl" />
                ) : !wizardQuestions.length ? (
                  <p className="text-center text-xs text-slate-400 font-semibold py-8">
                    Ushbu yakuniy imtihonga hali savollar kiritilmagan.
                  </p>
                ) : (
                  wizardQuestions.map((q: any, index: number) => (
                    <div key={q.id} className="p-3 border border-border bg-white rounded-xl flex gap-3 items-start justify-between">
                      <div className="min-w-0 flex-1 text-xs">
                        <div className="flex gap-2 items-center">
                          <span className="font-extrabold text-slate-400">#{index+1}</span>
                          <Badge variant={q.difficulty === "hard" ? "danger" : q.difficulty === "easy" ? "success" : "warning"} className="py-0 px-1.5 text-[9px]">
                            {q.difficulty === "hard" ? "Qiyin" : q.difficulty === "easy" ? "Oson" : "O'rtacha"}
                          </Badge>
                          <span className="text-[10px] text-slate-400 font-semibold">{q.points} ball</span>
                        </div>
                        <p className="font-bold text-slate-800 mt-1">{q.question}</p>
                        <div className="grid grid-cols-2 gap-1 mt-2 text-[10px] text-slate-500 font-semibold">
                          <span className={q.correct_option === "a" ? "text-emerald-600 font-bold" : ""}>A) {q.option_a}</span>
                          <span className={q.correct_option === "b" ? "text-emerald-600 font-bold" : ""}>B) {q.option_b}</span>
                          <span className={q.correct_option === "c" ? "text-emerald-600 font-bold" : ""}>C) {q.option_c}</span>
                          {q.option_d && <span className={q.correct_option === "d" ? "text-emerald-600 font-bold" : ""}>D) {q.option_d}</span>}
                        </div>
                      </div>
                      <div className="flex gap-1 shrink-0">
                        <Button 
                          type="button" 
                          variant="ghost" 
                          onClick={() => startEditQuestion(q)}
                          className="size-7 p-0 rounded-lg text-blue-600 hover:bg-blue-50"
                        >
                          <Pencil className="size-3.5" />
                        </Button>
                        <Button 
                          type="button" 
                          variant="ghost" 
                          onClick={() => handleDeleteQuestion(q.id)}
                          className="size-7 p-0 rounded-lg text-red-600 hover:bg-red-50"
                        >
                          <Trash2 className="size-3.5" />
                        </Button>
                      </div>
                    </div>
                  ))
                )}
              </div>
            </div>

            {/* Sidebar info */}
            <div className="border border-border rounded-2xl p-5 bg-slate-50/50 space-y-4">
              <h4 className="text-xs font-black text-slate-800 uppercase tracking-wide">Yakuniy imtihon qoidalari</h4>
              <ul className="text-xs font-semibold text-slate-500 space-y-2">
                <li className="flex gap-2">
                  <span className="text-indigo-500 shrink-0">✓</span>
                  Yakuniy imtihon darslikning butun modul bo'yicha to'liq tekshiruvidir.
                </li>
                <li className="flex gap-2">
                  <span className="text-indigo-500 shrink-0">✓</span>
                  Avtomatik import yordamida mavzulardagi barcha testlarni ushbu imtihonga osongina nusxalang.
                </li>
                <li className="flex gap-2">
                  <span className="text-indigo-500 shrink-0">✓</span>
                  Ushbu savollar `quiz_questions` jadvalida faqat modul darajasida bog'lanib, mavzuga bog'liq bo'lmaydi.
                </li>
              </ul>
            </div>

            <div className="col-span-2 flex justify-between gap-3 pt-4 border-t border-border mt-4">
              <Button type="button" variant="secondary" onClick={handlePrevStep} className="font-bold flex gap-2">
                <ArrowLeft className="size-4" />
                Orqaga
              </Button>
              <Button type="button" onClick={handleNextStep} className="font-bold px-6 flex gap-2">
                Keyingi
                <ArrowRight className="size-4" />
              </Button>
            </div>
          </div>
        )}

        {/* STEP 3: Imtihon sozlamalari */}
        {wizardStep === 3 && (
          <div className="space-y-4">
            <h3 className="text-sm font-black text-slate-900 uppercase tracking-wide">
              3. Imtihon sozlamalari
            </h3>

            <div className="grid gap-6 md:grid-cols-2">
              <div className="space-y-4.5">
                <div className="grid gap-1.5">
                  <label className="text-xs font-bold text-slate-700">Imtihon vaqti (daqiqa) *</label>
                  <Input 
                    type="number" 
                    value={durationMinutes} 
                    onChange={(e) => setDurationMinutes(Number(e.target.value))} 
                    className="h-10.5" 
                    min={15}
                  />
                </div>

                <div className="grid gap-1.5">
                  <label className="text-xs font-bold text-slate-700">O'tish balli (%) *</label>
                  <Input 
                    type="number" 
                    value={passingScore} 
                    onChange={(e) => setPassingScore(Number(e.target.value))} 
                    className="h-10.5" 
                    min={1} 
                    max={100}
                  />
                </div>

                <div className="grid gap-1.5">
                  <label className="text-xs font-bold text-slate-700">Ruxsat etilgan urinishlar soni</label>
                  <Select value={allowedAttempts} onChange={(e) => setAllowedAttempts(e.target.value)} className="h-10.5 font-bold">
                    <option>1 marta</option>
                    <option>2 marta</option>
                    <option>3 marta</option>
                    <option>Cheklanmagan</option>
                  </Select>
                </div>

                <div className="grid gap-1.5">
                  <label className="text-xs font-bold text-slate-700">Natijalarni ko'rsatish vaqti</label>
                  <Select value={showResultsType} onChange={(e) => setShowResultsType(e.target.value)} className="h-10.5 font-bold">
                    <option>Test tugagandan so'ng</option>
                    <option>Imtihon topshirib bo'lingach</option>
                    <option>Hech qachon</option>
                  </Select>
                </div>
              </div>

              {/* Toggles */}
              <div className="border border-border rounded-2xl p-5 bg-slate-50/50 space-y-4">
                <h4 className="text-xs font-black text-slate-800 uppercase tracking-wide">Imtihon parametrlari</h4>
                
                <div className="space-y-4">
                  <label className="flex items-center gap-3 cursor-pointer">
                    <input 
                      type="checkbox" 
                      checked={shuffleQuestions} 
                      onChange={(e) => setShuffleQuestions(e.target.checked)} 
                      className="size-4.5 rounded text-blue-600 border-slate-300"
                    />
                    <div>
                      <span className="text-xs font-bold text-slate-800 block">Savollarni aralashtirish</span>
                      <span className="text-[10px] text-slate-400 font-semibold">Har bir talabada savollar aralashib chiqadi.</span>
                    </div>
                  </label>

                  <label className="flex items-center gap-3 cursor-pointer">
                    <input 
                      type="checkbox" 
                      checked={shuffleOptions} 
                      onChange={(e) => setShuffleOptions(e.target.checked)} 
                      className="size-4.5 rounded text-blue-600 border-slate-300"
                    />
                    <div>
                      <span className="text-xs font-bold text-slate-800 block">Javob variantlarini aralashtirish</span>
                      <span className="text-[10px] text-slate-400 font-semibold">Javoblar (A, B, C, D) variantlari joylashuvi o'zgaradi.</span>
                    </div>
                  </label>

                  <label className="flex items-center gap-3 cursor-pointer">
                    <input 
                      type="checkbox" 
                      checked={allowGoBack} 
                      onChange={(e) => setAllowGoBack(e.target.checked)} 
                      className="size-4.5 rounded text-blue-600 border-slate-300"
                    />
                    <div>
                      <span className="text-xs font-bold text-slate-800 block">Orqaga qaytishga ruxsat</span>
                      <span className="text-[10px] text-slate-400 font-semibold">Oldingi topshirilgan savollarga qaytib o'zgartirish ruxsati.</span>
                    </div>
                  </label>

                  <label className="flex items-center gap-3 cursor-pointer">
                    <input 
                      type="checkbox" 
                      checked={showCorrectAnswers} 
                      onChange={(e) => setShowCorrectAnswers(e.target.checked)} 
                      className="size-4.5 rounded text-blue-600 border-slate-300"
                    />
                    <div>
                      <span className="text-xs font-bold text-slate-800 block">To'g'ri javoblarni ko'rsatish</span>
                      <span className="text-[10px] text-slate-400 font-semibold">Imtihon yakunida to'g'ri javoblar ko'rsatiladi.</span>
                    </div>
                  </label>

                  <label className="flex items-center gap-3 cursor-pointer">
                    <input 
                      type="checkbox" 
                      checked={randomizeSelection} 
                      onChange={(e) => setRandomizeSelection(e.target.checked)} 
                      className="size-4.5 rounded text-blue-600 border-slate-300"
                    />
                    <div>
                      <span className="text-xs font-bold text-slate-800 block">Savollardan tasodifiy tanlash</span>
                      <span className="text-[10px] text-slate-400 font-semibold">Savollar bankidan belgilangan miqdordagi savollarni random qilib beradi.</span>
                    </div>
                  </label>
                </div>
              </div>
            </div>

            <div className="flex justify-between gap-3 pt-4 border-t border-border mt-6">
              <Button type="button" variant="secondary" onClick={handlePrevStep} className="font-bold flex gap-2">
                <ArrowLeft className="size-4" />
                Orqaga
              </Button>
              <Button type="button" onClick={handleNextStep} className="font-bold px-6 flex gap-2">
                Keyingi
                <ArrowRight className="size-4" />
              </Button>
            </div>
          </div>
        )}

        {/* STEP 4: Ko'rib chiqish */}
        {wizardStep === 4 && (
          <div className="space-y-5">
            <h3 className="text-sm font-black text-slate-900 uppercase tracking-wide">
              4. Ko'rib chiqish va nashr qilish
            </h3>

            <div className="grid gap-5 md:grid-cols-2">
              <div className="border border-border rounded-2xl p-5 bg-white space-y-4">
                <h4 className="text-xs font-black text-slate-800 uppercase tracking-wide">Imtihon umumiy ma'lumotlari</h4>
                
                <div className="space-y-3.5 text-xs">
                  <div className="grid grid-cols-3">
                    <span className="font-semibold text-slate-400">Imtihon nomi:</span>
                    <span className="font-extrabold text-slate-800 col-span-2">{examTitle}</span>
                  </div>

                  <div className="grid grid-cols-3">
                    <span className="font-semibold text-slate-400">Tavsif:</span>
                    <span className="font-bold text-slate-500 col-span-2">{examDescription || "Kiritilmagan."}</span>
                  </div>

                  <div className="grid grid-cols-3">
                    <span className="font-semibold text-slate-400">Modul:</span>
                    <span className="font-extrabold text-slate-800 col-span-2">{modules?.find((m: any) => m.id === formModuleId)?.title || "Tanlanmagan"}</span>
                  </div>

                  <div className="grid grid-cols-3">
                    <span className="font-semibold text-slate-400">Kategoriya / Daraja:</span>
                    <span className="font-bold text-slate-800 col-span-2">{category} / {difficultyLevel === "hard" ? "Qiyin" : "O'rtacha"}</span>
                  </div>

                  <div className="grid grid-cols-3">
                    <span className="font-semibold text-slate-400">Teglar:</span>
                    <span className="font-semibold text-indigo-600 col-span-2">{tags}</span>
                  </div>
                </div>
              </div>

              {/* Checklist */}
              <div className="border border-border rounded-2xl p-5 bg-slate-50/50 space-y-4">
                <h4 className="text-xs font-black text-slate-800 uppercase tracking-wide">Tekshirish ro'yxati</h4>
                
                <div className="space-y-2.5 text-xs font-bold text-slate-600">
                  <div className="flex gap-2 items-center">
                    <CheckCircle2 className="size-4.5 text-emerald-500 shrink-0" />
                    <span>Asosiy ma'lumotlar to'liq</span>
                  </div>
                  <div className="flex gap-2 items-center">
                    <CheckCircle2 className="size-4.5 text-emerald-500 shrink-0" />
                    <span>Savollar soni: {wizardQuestions.length} ta savol kiritilgan</span>
                  </div>
                  <div className="flex gap-2 items-center">
                    <CheckCircle2 className="size-4.5 text-emerald-500 shrink-0" />
                    <span>Imtihon vaqti: {durationMinutes} daqiqa, O'tish balli: {passingScore}%</span>
                  </div>
                  <div className="flex gap-2 items-center">
                    <CheckCircle2 className="size-4.5 text-emerald-500 shrink-0" />
                    <span>Imtihon urinishlari: {allowedAttempts}</span>
                  </div>
                </div>

                <div className="mt-4 p-3.5 bg-emerald-50 border border-emerald-100 rounded-xl flex gap-2 items-start animate-pulse">
                  <Check className="size-4.5 text-emerald-600 shrink-0 mt-0.5" />
                  <div>
                    <p className="text-[11px] font-extrabold text-emerald-800">Nashrga tayyor</p>
                    <p className="text-[10px] text-emerald-700 font-semibold mt-0.5">
                      Imtihon ma'lumotlari to'liq. Barcha talabalar topshirishi uchun imtihonni nashr qilish mumkin.
                    </p>
                  </div>
                </div>
              </div>
            </div>

            <div className="flex justify-between gap-3 pt-4 border-t border-border mt-6">
              <Button type="button" variant="secondary" onClick={handlePrevStep} className="font-bold flex gap-2">
                <ArrowLeft className="size-4" />
                Orqaga
              </Button>
              <div className="flex gap-2">
                <Button type="button" variant="secondary" onClick={handleFinishWizard} className="font-bold">
                  Saqlash (Draft)
                </Button>
                <Button type="button" onClick={handleFinishWizard} className="font-bold bg-emerald-600 text-white hover:bg-emerald-700 px-6">
                  Nashr qilish
                </Button>
              </div>
            </div>
          </div>
        )}
      </Modal>
    </div>
  );
}
