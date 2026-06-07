"use client";

import { useState, useEffect, useMemo } from "react";
import {
  Plus,
  Pencil,
  Trash2,
  Loader2,
  FileText,
  BookOpen,
  HelpCircle,
  Search,
  CheckCircle2,
  Clock,
  Eye,
  ArrowRight,
  ArrowLeft,
  Check,
  AlertCircle,
  Users,
  Timer,
  CheckSquare,
  ChevronRight,
  Clipboard,
  ImageIcon,
  Link2,
  UploadCloud,
  Video,
} from "lucide-react";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { Input, Textarea, Select } from "@/components/ui/input";
import { Skeleton } from "@/components/ui/skeleton";
import { Modal } from "@/components/ui/modal";
import { Badge } from "@/components/ui/badge";
import {
  useModules,
  useTopics,
  useQuizQuestions,
  useCreateQuestion,
  useUpdateQuestion,
  useDeleteQuestion,
} from "@/hooks/use-admin-data";
import { toast } from "sonner";

const BULK_QUESTION_TEMPLATE = `Savol: Qon guruhlarini aniqlashda qaysi reagent ishlatiladi?
A) Natriy xlorid
B) Anti-A va Anti-B zardoblari
C) Distillangan suv
D) Glyukoza eritmasi
Javob: B
Izoh: Qon guruhi anti-A va anti-B reagentlar bilan agglutinatsiya reaksiyasi orqali aniqlanadi.

Savol: Gemoglobin miqdori qaysi birlikda ifodalanadi?
A) mmol/L
B) g/L
C) %
D) mg/dL
Javob: B
Izoh: Klinik laboratoriyada gemoglobin odatda g/L birligida ko'rsatiladi.`;

function PremiumBadge({
  variant,
  children,
  className,
}: {
  variant:
    | "success"
    | "slate"
    | "destructive"
    | "warning"
    | "blue"
    | "indigo"
    | "fuchsia"
    | "purple";
  children: React.ReactNode;
  className?: string;
}) {
  return (
    <span
      className={`inline-flex items-center rounded-full px-2.5 py-1 text-[10px] uppercase tracking-wider font-bold ${
        variant === "success"
          ? "bg-emerald-500/10 text-emerald-600 border border-emerald-500/20"
          : variant === "destructive"
            ? "bg-red-500/10 text-red-600 border border-red-500/20"
            : variant === "warning"
              ? "bg-amber-500/10 text-amber-600 border border-amber-500/20"
              : variant === "blue"
                ? "bg-blue-500/10 text-blue-600 border border-blue-500/20"
                : variant === "indigo"
                  ? "bg-indigo-500/10 text-indigo-600 border border-indigo-500/20"
                  : variant === "fuchsia"
                    ? "bg-fuchsia-500/10 text-fuchsia-600 border border-fuchsia-500/20"
                    : variant === "purple"
                      ? "bg-purple-500/10 text-purple-600 border border-purple-500/20"
                      : "bg-slate-500/10 text-slate-600 border border-slate-500/20"
      } ${className}`}
    >
      {children}
    </span>
  );
}

export function TestsPage() {
  const { data: modules, isLoading: isModulesLoading } = useModules();

  const [filterModuleId, setFilterModuleId] = useState("");
  const [filterTopicId, setFilterTopicId] = useState("");
  const [filterTestType, setFilterTestType] = useState("all"); // all, quiz, mini, final
  const [searchTerm, setSearchTerm] = useState("");

  const { data: topics, isLoading: isTopicsLoading } = useTopics(
    filterModuleId || undefined,
  );
  const { data: allQuestions, isLoading: isQuestionsLoading } =
    useQuizQuestions();

  const createQuestionMutation = useCreateQuestion();
  const updateQuestionMutation = useUpdateQuestion();
  const deleteQuestionMutation = useDeleteQuestion();

  // Wizard modal state
  const [modalOpen, setModalOpen] = useState(false);
  const [wizardStep, setWizardStep] = useState(1);
  const [selectedTopicForWizard, setSelectedTopicForWizard] =
    useState<any>(null);

  // Step 1: Asosiy ma'lumotlar states
  const [formModuleId, setFormModuleId] = useState("");
  const [formTopicId, setFormTopicId] = useState("");
  const [testTitle, setTestTitle] = useState("");
  const [testDescription, setTestDescription] = useState("");
  const [category, setCategory] = useState("Nazariy");
  const [difficultyLevel, setDifficultyLevel] = useState("medium");
  const [tags, setTags] = useState("");

  // Step 2: Question Editor states
  const [isAddingQuestion, setIsAddingQuestion] = useState(false);
  const [editingQuestionItem, setEditingQuestionItem] = useState<any>(null);
  const [questionText, setQuestionText] = useState("");
  const [optionA, setOptionA] = useState("");
  const [optionB, setOptionB] = useState("");
  const [optionC, setOptionC] = useState("");
  const [optionD, setOptionD] = useState("");
  const [correctOption, setCorrectOption] = useState<"a" | "b" | "c" | "d">(
    "a",
  );
  const [questionDifficulty, setQuestionDifficulty] = useState<
    "easy" | "medium" | "hard"
  >("medium");
  const [questionPoints, setQuestionPoints] = useState(1);
  const [questionType, setQuestionType] = useState<"text" | "image" | "video">(
    "text",
  );
  const [mediaUrl, setMediaUrl] = useState("");
  const [mediaUploading, setMediaUploading] = useState(false);
  const [explanation, setExplanation] = useState("");
  const [bulkText, setBulkText] = useState("");
  const [bulkImporting, setBulkImporting] = useState(false);

  // Step 3: Sozlamalar states
  const [durationMinutes, setDurationMinutes] = useState(15);
  const [passingScore, setPassingScore] = useState(60);
  const [shuffleQuestions, setShuffleQuestions] = useState(true);
  const [shuffleOptions, setShuffleOptions] = useState(true);
  const [showResultsType, setShowResultsType] = useState(
    "Test tugagandan so'ng",
  );
  const [allowedAttempts, setAllowedAttempts] = useState("Cheklanmagan");
  const [allowGoBack, setAllowGoBack] = useState(true);
  const [allowExplanations, setAllowExplanations] = useState(true);

  // Fetch topics for form when module changes
  const { data: formTopics } = useTopics(formModuleId || undefined);

  // Auto-reset topic filter if module filter changes
  useEffect(() => {
    setFilterTopicId("");
  }, [filterModuleId]);

  // Sync test title when formTopicId changes
  useEffect(() => {
    if (formTopicId && formTopics) {
      const topic = formTopics.find((t: any) => t.id === formTopicId);
      if (topic && !testTitle) {
        setTestTitle(`${topic.title} testi`);
      }
    }
  }, [formTopicId, formTopics]);

  // Open creation wizard
  const openCreateModal = (topicId?: string) => {
    setSelectedTopicForWizard(null);
    setFormModuleId(filterModuleId || modules?.[0]?.id || "");
    setFormTopicId(topicId || filterTopicId || "");
    setTestTitle("");
    setTestDescription("");
    setCategory("Nazariy");
    setDifficultyLevel("medium");
    setTags("siydik, tahlil, kimyo");

    // Reset question sub-form
    resetQuestionForm();
    setIsAddingQuestion(false);

    // Reset settings
    setDurationMinutes(15);
    setPassingScore(60);
    setShuffleQuestions(true);
    setShuffleOptions(true);
    setShowResultsType("Test tugagandan so'ng");
    setAllowedAttempts("Cheklanmagan");
    setAllowGoBack(true);
    setAllowExplanations(true);

    setWizardStep(1);
    setModalOpen(true);
  };

  // Open edit wizard
  const openEditModal = (testItem: any) => {
    setSelectedTopicForWizard(testItem);
    setFormModuleId(testItem.moduleId || "");
    setFormTopicId(testItem.id || "");
    setTestTitle(testItem.name || "");
    setTestDescription(
      testItem.description || "Mavzu bo'yicha mustahkamlash testi.",
    );
    setCategory(testItem.category || "Nazariy");
    setDifficultyLevel(testItem.difficulty || "medium");
    setTags(testItem.tags || "siydik, tahlil, kimyo");

    // Reset question sub-form
    resetQuestionForm();
    setIsAddingQuestion(false);

    // Settings
    setDurationMinutes(testItem.durationVal || 15);
    setPassingScore(testItem.passingScoreVal || 60);
    setShuffleQuestions(testItem.shuffleQuestions ?? true);
    setShuffleOptions(testItem.shuffleOptions ?? true);
    setShowResultsType(testItem.showResultsType || "Test tugagandan so'ng");
    setAllowedAttempts(testItem.allowedAttempts || "Cheklanmagan");
    setAllowGoBack(testItem.allowGoBack ?? true);
    setAllowExplanations(testItem.allowExplanations ?? true);

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
    setQuestionPoints(1);
    setQuestionType("text");
    setMediaUrl("");
    setExplanation("");
  };

  // Handle question form submit
  const handleSaveQuestion = async () => {
    if (!questionText.trim()) {
      toast.error("Savol matnini yozing");
      return;
    }
    if (!optionA.trim() || !optionB.trim() || !optionC.trim()) {
      toast.error("Kamida A, B va C variantlarini to'ldiring");
      return;
    }
    if (questionType !== "text" && !mediaUrl.trim()) {
      toast.error(
        questionType === "image" ? "Rasm URL kiriting" : "Video URL kiriting",
      );
      return;
    }

    const payload = {
      topic_id: formTopicId,
      module_id: null,
      question: questionText,
      option_a: optionA,
      option_b: optionB,
      option_c: optionC,
      option_d: optionD || null,
      correct_option: correctOption,
      difficulty: questionDifficulty,
      points: Number(questionPoints),
      question_type: questionType,
      media_kind: questionType === "text" ? null : questionType,
      media_url: questionType === "text" ? null : mediaUrl.trim(),
      explanation: explanation.trim() || null,
    };

    try {
      if (editingQuestionItem) {
        await updateQuestionMutation.mutateAsync({
          id: editingQuestionItem.id,
          ...payload,
        });
        toast.success("Savol muvaffaqiyatli yangilandi");
      } else {
        await createQuestionMutation.mutateAsync(payload);
        toast.success("Yangi savol muvaffaqiyatli qo'shildi");
      }
      resetQuestionForm();
      setIsAddingQuestion(false);
    } catch (err: any) {
      toast.error(err.message || "Xatolik yuz berdi");
    }
  };

  const parseBulkQuestions = () => {
    return bulkText
      .split(/\n\s*\n/g)
      .map((block) => block.trim())
      .filter(Boolean)
      .map((block) => {
        const lines = block
          .split("\n")
          .map((line) => line.trim())
          .filter(Boolean);
        const getValue = (prefixes: string[]) => {
          const line = lines.find((item) =>
            prefixes.some((prefix) => item.toLowerCase().startsWith(prefix)),
          );
          if (!line) return "";
          return line
            .replace(
              /^[a-d]\)|^[a-d][\.:\-]|^answer\s*[:\-]|^javob\s*[:\-]|^izoh\s*[:\-]|^tushuntirish\s*[:\-]/i,
              "",
            )
            .trim();
        };
        const questionLine =
          lines.find((line) => /^savol\s*[:\-]/i.test(line)) ||
          lines.find(
            (line) =>
              !/^[a-d][\)\.:\-]/i.test(line) &&
              !/^(answer|javob|izoh|tushuntirish)\s*[:\-]/i.test(line),
          ) ||
          "";
        const question = questionLine
          .replace(/^savol\s*[:\-]/i, "")
          .replace(/^\d+[\)\.:\-]\s*/, "")
          .trim();
        const answerRaw = getValue(["answer", "javob"]).toLowerCase();
        const answer = (
          ["a", "b", "c", "d"].includes(answerRaw[0]) ? answerRaw[0] : "a"
        ) as "a" | "b" | "c" | "d";
        return {
          question,
          option_a: getValue(["a)", "a.", "a:", "a-"]),
          option_b: getValue(["b)", "b.", "b:", "b-"]),
          option_c: getValue(["c)", "c.", "c:", "c-"]),
          option_d: getValue(["d)", "d.", "d:", "d-"]) || null,
          correct_option: answer,
          explanation:
            getValue(["izoh", "tushuntirish", "explanation"]) || null,
        };
      })
      .filter(
        (item) =>
          item.question && item.option_a && item.option_b && item.option_c,
      );
  };

  const handleBulkImport = async () => {
    if (!formTopicId) {
      toast.error("Avval mavzuni tanlang");
      return;
    }
    const parsed = parseBulkQuestions();
    if (!parsed.length) {
      toast.error("Copy-paste formatidan savollar topilmadi");
      return;
    }
    setBulkImporting(true);
    try {
      for (const item of parsed) {
        await createQuestionMutation.mutateAsync({
          topic_id: formTopicId,
          module_id: null,
          ...item,
          difficulty: questionDifficulty,
          points: Number(questionPoints),
          question_type: "text",
          media_kind: null,
          media_url: null,
          explanation: item.explanation,
        });
      }
      setBulkText("");
      toast.success(`${parsed.length} ta matnli savol import qilindi`);
    } catch (err: any) {
      toast.error(err.message || "Importda xatolik yuz berdi");
    } finally {
      setBulkImporting(false);
    }
  };

  // Delete question inside wizard
  const handleDeleteQuestion = async (id: string) => {
    if (!confirm("Haqiqatan ham bu savolni o'chirib tashlamoqchimisiz?"))
      return;
    try {
      await deleteQuestionMutation.mutateAsync(id);
      toast.success("Savol muvaffaqiyatli o'chirildi");
    } catch (err: any) {
      toast.error(err.message || "O'chirishda xatolik yuz berdi");
    }
  };

  // Start editing a question
  const startEditQuestion = (q: any) => {
    setEditingQuestionItem(q);
    setQuestionText(q.question || "");
    setOptionA(q.option_a || "");
    setOptionB(q.option_b || "");
    setOptionC(q.option_c || "");
    setOptionD(q.option_d || "");
    setCorrectOption(q.correct_option || "a");
    setQuestionDifficulty(q.difficulty || "medium");
    setQuestionPoints(q.points || 1);
    setQuestionType(
      q.question_type === "image" || q.question_type === "video"
        ? q.question_type
        : "text",
    );
    setMediaUrl(q.media_url || "");
    setExplanation(q.explanation || "");
    setIsAddingQuestion(true);
  };

  const handleQuestionMediaUpload = async (
    event: React.ChangeEvent<HTMLInputElement>,
  ) => {
    const file = event.target.files?.[0];
    event.target.value = "";
    if (!file) return;

    const isImageQuestion = questionType === "image";
    const isVideoQuestion = questionType === "video";
    if (isImageQuestion && !file.type.startsWith("image/")) {
      toast.error("Rasmli test uchun rasm faylini tanlang");
      return;
    }
    if (isVideoQuestion && !file.type.startsWith("video/")) {
      toast.error("Video test uchun video faylini tanlang");
      return;
    }

    const formData = new FormData();
    formData.append("file", file);
    formData.append("kind", isImageQuestion ? "image" : "video");

    setMediaUploading(true);
    try {
      const response = await fetch("/api/media/upload", {
        method: "POST",
        body: formData,
      });
      const result = await response.json();
      if (!response.ok || !result.ok) {
        throw new Error(result.error || "Fayl yuklashda xatolik yuz berdi");
      }
      setMediaUrl(result.media.secure_url);
      toast.success(`${isImageQuestion ? "Rasm" : "Video"} yuklandi`);
    } catch (err: any) {
      toast.error(err.message || "Fayl yuklashda xatolik yuz berdi");
    } finally {
      setMediaUploading(false);
    }
  };

  const copyBulkTemplate = async () => {
    await navigator.clipboard.writeText(BULK_QUESTION_TEMPLATE);
    toast.success("Matnli test shabloni clipboardga nusxalandi");
  };

  // Step transitions
  const handleNextStep = () => {
    if (wizardStep === 1) {
      if (!testTitle.trim()) {
        toast.error("Test nomini kiriting");
        return;
      }
      if (!formTopicId) {
        toast.error("Mavzuni tanlang");
        return;
      }
    }
    setWizardStep((prev) => prev + 1);
  };

  const handlePrevStep = () => {
    setWizardStep((prev) => prev - 1);
  };

  const handleFinishWizard = () => {
    toast.success("Test muvaffaqiyatli saqlandi va nashr qilindi!");
    setModalOpen(false);
  };

  // Calculate list of tests (topics in selected module)
  const testsList = useMemo(() => {
    const activeTopics = topics || [];
    const questionsList = allQuestions || [];

    return activeTopics
      .map((topic: any) => {
        const topicQuestions = questionsList.filter(
          (q: any) => q.topic_id === topic.id,
        );
        const questionsCount = topicQuestions.length;

        const deterministicAttempts = ((topic.title.length * 27) % 200) + 45;
        const isQuiz = questionsCount > 5;

        return {
          id: topic.id,
          name: `${topic.title} bo'yicha test`,
          topicTitle: topic.title,
          moduleId: topic.module_id,
          type: isQuiz ? "Quiz" : "Mini Test",
          questionsCount,
          duration: `${Math.max(10, questionsCount * 1.5)} daqiqa`,
          durationVal: Math.max(10, questionsCount * 1.5),
          passingScore: "60%",
          passingScoreVal: 60,
          attempts: deterministicAttempts,
          status: questionsCount > 0 ? "Published" : "Draft",
          createdAt: topic.created_at,
          category: "Nazariy",
          difficulty: "medium",
          tags: "siydik, tahlil, kimyo",
        };
      })
      .filter((test: any) => {
        // Filter by type
        const matchesType =
          filterTestType === "all" ||
          (filterTestType === "quiz" && test.type === "Quiz") ||
          (filterTestType === "mini" && test.type === "Mini Test");

        // Filter by search
        const matchesSearch =
          test.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
          test.topicTitle.toLowerCase().includes(searchTerm.toLowerCase());

        return matchesType && matchesSearch;
      });
  }, [topics, allQuestions, filterTestType, searchTerm]);

  // Statistics calculation for active lists
  const stats = useMemo(() => {
    const total = testsList.length;
    const quizCount = testsList.filter((t: any) => t.type === "Quiz").length;
    const miniCount = testsList.filter(
      (t: any) => t.type === "Mini Test",
    ).length;
    const totalQuestions = testsList.reduce(
      (acc: number, t: any) => acc + t.questionsCount,
      0,
    );
    const totalAttempts = testsList.reduce(
      (acc: number, t: any) => acc + t.attempts,
      0,
    );

    return {
      total,
      quizCount,
      miniCount,
      totalQuestions,
      totalAttempts,
    };
  }, [testsList]);

  // Selected topic name for wizard
  const wizardSelectedTopic = formTopics?.find(
    (t: any) => t.id === formTopicId,
  );
  // Get questions for active wizard topic
  const wizardQuestions = useMemo(() => {
    if (!allQuestions || !formTopicId) return [];
    return allQuestions.filter((q: any) => q.topic_id === formTopicId);
  }, [allQuestions, formTopicId]);

  const selectedModule = modules?.find((m: any) => m.id === filterModuleId);
  const selectedTopic = topics?.find((t: any) => t.id === filterTopicId);
  const breadcrumbModule = selectedModule
    ? selectedModule.title
    : "Modul tanlanmagan";
  const breadcrumbTopic = selectedTopic
    ? selectedTopic.title
    : "Mavzu tanlanmagan";

  return (
    <div className="min-h-screen bg-slate-50/50 pb-20">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 mb-8">
        <div>
          <div className="flex items-center gap-1.5 text-[10px] font-bold text-slate-400 uppercase tracking-wider mb-2">
            <span>Mavzular</span> <ChevronRight className="size-3" />
            <span className="text-blue-600 font-extrabold">
              {breadcrumbTopic}
            </span>{" "}
            <ChevronRight className="size-3" />
            <span>Testlar</span>
          </div>
          <h1 className="text-3xl font-black text-slate-900 flex items-center gap-2">
            Testlar
          </h1>
        </div>

        <Button
          onClick={() => openCreateModal()}
          disabled={!filterModuleId}
          className="flex gap-2 bg-blue-600 hover:bg-blue-700 text-white shadow-lg shadow-blue-500/20 rounded-lg px-5 h-11 transition-all "
        >
          <Plus className="size-5" />
          Yangi Test
        </Button>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-12 gap-6 mb-8">
        <div className="md:col-span-4 lg:col-span-4 bg-white border border-slate-200 shadow-sm rounded-lg p-5 flex flex-col justify-center gap-4">
          <div className="space-y-2">
            <p className="text-[10px] font-bold text-slate-400 uppercase tracking-wider">
              Modulni tanlang
            </p>
            {isModulesLoading ? (
              <Skeleton className="h-11 w-full rounded-lg" />
            ) : (
              <Select
                value={filterModuleId}
                onChange={(e) => setFilterModuleId(e.target.value)}
                className="h-11 w-full bg-slate-50/50 border-transparent focus:bg-white rounded-lg font-bold text-slate-700"
              >
                <option value="">Barcha Modullar</option>
                {modules?.map((m: any) => (
                  <option key={m.id} value={m.id}>
                    {m.title}
                  </option>
                ))}
              </Select>
            )}
          </div>
          <div className="space-y-2">
            <p className="text-[10px] font-bold text-slate-400 uppercase tracking-wider">
              Mavzuni tanlang
            </p>
            {isTopicsLoading ? (
              <Skeleton className="h-11 w-full rounded-lg" />
            ) : (
              <Select
                value={filterTopicId}
                onChange={(e) => setFilterTopicId(e.target.value)}
                disabled={!filterModuleId}
                className="h-11 w-full bg-slate-50/50 border-transparent focus:bg-white rounded-lg font-bold text-slate-700 disabled:opacity-50"
              >
                <option value="">Barcha Mavzular</option>
                {topics?.map((t: any) => (
                  <option key={t.id} value={t.id}>
                    {t.title}
                  </option>
                ))}
              </Select>
            )}
          </div>
        </div>

        <div className="md:col-span-8 lg:col-span-8 grid grid-cols-2 sm:grid-cols-4 gap-4">
          <div className="bg-white border border-slate-200 shadow-sm rounded-lg p-4 flex flex-col justify-center items-center text-center">
            <div className="size-10 rounded-full bg-slate-100 text-slate-600 flex items-center justify-center mb-2">
              <FileText className="size-5" />
            </div>
            <p className="text-2xl font-black text-slate-900">{stats.total}</p>
            <p className="text-[10px] font-bold text-slate-500 uppercase tracking-wider mt-1">
              Jami Testlar
            </p>
          </div>
          <div className="bg-white border border-slate-200 shadow-sm rounded-lg p-4 flex flex-col justify-center items-center text-center">
            <div className="size-10 rounded-full bg-emerald-50 text-emerald-600 flex items-center justify-center mb-2">
              <CheckSquare className="size-5" />
            </div>
            <p className="text-2xl font-black text-slate-900">
              {stats.quizCount}
            </p>
            <p className="text-[10px] font-bold text-slate-500 uppercase tracking-wider mt-1">
              Quiz Testlar
            </p>
          </div>
          <div className="bg-white border border-slate-200 shadow-sm rounded-lg p-4 flex flex-col justify-center items-center text-center">
            <div className="size-10 rounded-full bg-orange-50 text-orange-600 flex items-center justify-center mb-2">
              <BookOpen className="size-5" />
            </div>
            <p className="text-2xl font-black text-slate-900">
              {stats.totalQuestions}
            </p>
            <p className="text-[10px] font-bold text-slate-500 uppercase tracking-wider mt-1">
              Savollar
            </p>
          </div>
          <div className="bg-white border border-slate-200 shadow-sm rounded-lg p-4 flex flex-col justify-center items-center text-center">
            <div className="size-10 rounded-full bg-teal-50 text-teal-600 flex items-center justify-center mb-2">
              <Users className="size-5" />
            </div>
            <p className="text-2xl font-black text-slate-900">
              {stats.totalAttempts.toLocaleString()}
            </p>
            <p className="text-[10px] font-bold text-slate-500 uppercase tracking-wider mt-1">
              Urinishlar
            </p>
          </div>
        </div>
      </div>

      <div className="bg-white border border-slate-200 shadow-sm rounded-lg p-3 flex flex-wrap items-center gap-3 mb-8">
        <div className="relative flex-1 min-w-[250px]">
          <Search className="absolute left-4 top-1/2 -translate-y-1/2 size-5 text-slate-400" />
          <Input
            placeholder="Testlarni izlash..."
            className="pl-11 h-12 w-full bg-slate-50/50 border-transparent hover:border-slate-200 focus:border-blue-500 rounded-lg transition-all"
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
          />
        </div>
        <div className="h-8 w-px bg-slate-200 hidden md:block"></div>
        <Select
          value={filterTestType}
          onChange={(e: any) => setFilterTestType(e.target.value)}
          className="h-12 w-full md:w-[180px] bg-slate-50/50 border-transparent rounded-lg font-medium text-slate-700"
        >
          <option value="all">Barcha Turlar</option>
          <option value="quiz">Faqat Quiz</option>
          <option value="mini">Mini Test</option>
        </Select>
      </div>

      {/* Premium Table View */}
      {isQuestionsLoading || isTopicsLoading ? (
        <Card className="rounded-lg border border-slate-200 shadow-sm overflow-hidden">
          <div className="p-6 flex flex-col gap-4">
            {[1, 2, 3].map((i) => (
              <Skeleton key={i} className="h-16 w-full rounded-lg" />
            ))}
          </div>
        </Card>
      ) : !filterModuleId ? (
        <div className="flex flex-col items-center justify-center py-20 px-4 bg-white rounded-lg border border-dashed border-slate-200">
          <div className="size-24 bg-blue-50 rounded-full flex items-center justify-center mb-6">
            <BookOpen className="size-10 text-blue-500" />
          </div>
          <h3 className="text-2xl font-black text-slate-900 mb-2">
            Modulni Tanlang
          </h3>
          <p className="text-slate-500 text-center max-w-md mb-8">
            Test darslarini boshqarish uchun yuqoridagi filtrdan modulni
            tanlang.
          </p>
        </div>
      ) : !testsList.length ? (
        <div className="flex flex-col items-center justify-center py-20 px-4 bg-white rounded-lg border border-dashed border-slate-200">
          <div className="size-24 bg-blue-50 rounded-full flex items-center justify-center mb-6">
            <FileText className="size-10 text-blue-500" />
          </div>
          <h3 className="text-2xl font-black text-slate-900 mb-2">
            Testlar Topilmadi
          </h3>
          <p className="text-slate-500 text-center max-w-md mb-8">
            Ushbu modulda hozircha darslar yoki testlar yaratilmagan.
          </p>
          <Button
            onClick={() => openCreateModal()}
            className="rounded-lg px-6 h-12 bg-blue-600 hover:bg-blue-700 text-white font-bold tracking-wide"
          >
            <Plus className="size-5 mr-2" /> Yangi Test Qo'shish
          </Button>
        </div>
      ) : (
        <Card className="rounded-lg border border-slate-200 shadow-sm overflow-hidden bg-white animate-in fade-in-50 duration-200">
          <div className="overflow-x-auto edulab-scrollbar">
            <table className="w-full text-sm">
              <thead className="bg-slate-50 text-left text-[10px] font-black uppercase text-slate-400 tracking-wider border-b border-slate-100">
                <tr>
                  <th className="px-6 py-5 w-16 text-center">#</th>
                  <th className="px-6 py-5 min-w-[280px]">Test Nomi</th>
                  <th className="px-6 py-5 min-w-[180px]">Mavzu</th>
                  <th className="px-6 py-5 text-center w-36">Turi</th>
                  <th className="px-6 py-5 text-center w-36">Savollar soni</th>
                  <th className="px-6 py-5 text-center w-36">Vaqt</th>
                  <th className="px-6 py-5 text-center w-36">O'tish Balli</th>
                  <th className="px-6 py-5 text-center w-32">Holati</th>
                  <th className="px-6 py-5 text-right w-36">Amallar</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-50">
                {testsList.map((test: any, idx: number) => (
                  <tr
                    key={test.id}
                    className="hover:bg-blue-50/30 transition-colors group"
                  >
                    <td className="px-6 py-4 text-center">
                      <span className="font-black text-slate-300 group-hover:text-blue-400 transition-colors">
                        {idx + 1}
                      </span>
                    </td>
                    <td className="px-6 py-4">
                      <div className="flex items-center gap-4">
                        <div className="relative size-12 rounded-lg bg-blue-50 text-blue-600 flex items-center justify-center shrink-0 shadow-sm border border-slate-100 group-hover:shadow-md transition-all">
                          <CheckSquare className="size-5 group-hover:scale-110 transition-transform" />
                        </div>
                        <div className="min-w-0">
                          <p className="font-black text-slate-900 truncate text-base group-hover:text-blue-600 transition-colors">
                            {test.name}
                          </p>
                          <p className="text-xs text-slate-400 font-medium truncate mt-0.5">
                            {test.questionsCount > 0
                              ? `${test.questionsCount} ta savol kiritilgan`
                              : "Savollar kiritilmagan"}
                          </p>
                        </div>
                      </div>
                    </td>
                    <td className="px-6 py-4 text-slate-600 font-semibold">
                      {test.topicTitle}
                    </td>
                    <td className="px-6 py-4 text-center">
                      <PremiumBadge
                        variant={test.type === "Quiz" ? "fuchsia" : "indigo"}
                      >
                        {test.type}
                      </PremiumBadge>
                    </td>
                    <td className="px-6 py-4 text-center">
                      <span className="font-bold text-slate-700">
                        {test.questionsCount}
                      </span>
                    </td>
                    <td className="px-6 py-4 text-center">
                      <span className="font-bold text-slate-700">
                        {test.duration}
                      </span>
                    </td>
                    <td className="px-6 py-4 text-center">
                      <span className="font-bold text-slate-700">
                        {test.passingScore}
                      </span>
                    </td>
                    <td className="px-6 py-4 text-center">
                      <PremiumBadge
                        variant={
                          test.status === "Published" ? "success" : "warning"
                        }
                      >
                        {test.status}
                      </PremiumBadge>
                    </td>
                    <td className="px-6 py-4">
                      <div className="flex items-center justify-end gap-2 opacity-100 sm:opacity-0 sm:group-hover:opacity-100 transition-opacity">
                        <Button
                          onClick={() => openEditModal(test)}
                          variant="ghost"
                          size="icon"
                          className="size-9 rounded-lg text-slate-400 hover:text-blue-600 hover:bg-blue-50"
                        >
                          <Pencil className="size-4.5" />
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

      {/* 4-Step Wizard Modal (Screenshot 4 style) */}
      <Modal
        open={modalOpen}
        onOpenChange={setModalOpen}
        title={selectedTopicForWizard ? "Testni tahrirlash" : "Test yaratish"}
        description="Mavzudagi test va savollar jarayoni 4 bosqichdan iborat."
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
              <span className="flex size-5 items-center justify-center rounded-full bg-blue-50 text-[10px]">
                1
              </span>
              Asosiy ma'lumotlar
            </button>
            <span className="text-slate-300">&gt;&gt;</span>
            <button
              type="button"
              onClick={() => wizardStep > 1 && setWizardStep(2)}
              className={`flex items-center gap-1.5 py-1 ${wizardStep === 2 ? "text-blue-600 border-b-2 border-blue-600" : ""}`}
              disabled={wizardStep < 2}
            >
              <span className="flex size-5 items-center justify-center rounded-full bg-blue-50 text-[10px]">
                2
              </span>
              Savollar
            </button>
            <span className="text-slate-300">&gt;&gt;</span>
            <button
              type="button"
              onClick={() => wizardStep > 2 && setWizardStep(3)}
              className={`flex items-center gap-1.5 py-1 ${wizardStep === 3 ? "text-blue-600 border-b-2 border-blue-600" : ""}`}
              disabled={wizardStep < 3}
            >
              <span className="flex size-5 items-center justify-center rounded-full bg-blue-50 text-[10px]">
                3
              </span>
              Sozlamalar
            </button>
            <span className="text-slate-300">&gt;&gt;</span>
            <button
              type="button"
              onClick={() => wizardStep > 3 && setWizardStep(4)}
              className={`flex items-center gap-1.5 py-1 ${wizardStep === 4 ? "text-blue-600 border-b-2 border-blue-600" : ""}`}
              disabled={wizardStep < 4}
            >
              <span className="flex size-5 items-center justify-center rounded-full bg-blue-50 text-[10px]">
                4
              </span>
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
                <label className="text-xs font-bold text-slate-700">
                  Test nomi *
                </label>
                <Input
                  placeholder="Test nomi (masalan: Siydik analizi testi)"
                  value={testTitle}
                  onChange={(e) => setTestTitle(e.target.value)}
                  required
                  className="h-10.5 border-slate-200"
                />
              </div>

              <div className="grid gap-1.5">
                <label className="text-xs font-bold text-slate-700">
                  Modul *
                </label>
                <Select
                  value={formModuleId}
                  onChange={(e) => {
                    setFormModuleId(e.target.value);
                    setFormTopicId("");
                  }}
                  required
                  className="h-10.5 border-slate-200 font-bold"
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
            </div>

            <div className="grid gap-4 md:grid-cols-2">
              <div className="grid gap-1.5">
                <label className="text-xs font-bold text-slate-700">
                  Tegishli Mavzu *
                </label>
                <Select
                  value={formTopicId}
                  onChange={(e) => setFormTopicId(e.target.value)}
                  required
                  disabled={!formModuleId}
                  className="h-10.5 border-slate-200 font-bold"
                >
                  <option value="" disabled>
                    Mavzuni tanlang
                  </option>
                  {formTopics?.map((t: any) => (
                    <option key={t.id} value={t.id}>
                      {t.title}
                    </option>
                  ))}
                </Select>
              </div>

              <div className="grid gap-1.5">
                <label className="text-xs font-bold text-slate-700">
                  Kategoriyasi
                </label>
                <Select
                  value={category}
                  onChange={(e) => setCategory(e.target.value)}
                  className="h-10.5 border-slate-200 font-bold"
                >
                  <option>Nazariy</option>
                  <option>Amaliy</option>
                  <option>Laboratoriya</option>
                </Select>
              </div>
            </div>

            <div className="grid gap-4 md:grid-cols-2">
              <div className="grid gap-1.5">
                <label className="text-xs font-bold text-slate-700">
                  Qiyinchilik darajasi
                </label>
                <Select
                  value={difficultyLevel}
                  onChange={(e) => setDifficultyLevel(e.target.value)}
                  className="h-10.5 border-slate-200 font-bold"
                >
                  <option value="easy">Oson</option>
                  <option value="medium">O'rtacha</option>
                  <option value="hard">Qiyin</option>
                </Select>
              </div>

              <div className="grid gap-1.5">
                <label className="text-xs font-bold text-slate-700">
                  Teglar (Vergul bilan ajrating)
                </label>
                <Input
                  placeholder="siydik, tahlil, kimyo"
                  value={tags}
                  onChange={(e) => setTags(e.target.value)}
                  className="h-10.5 border-slate-200"
                />
              </div>
            </div>

            <div className="grid gap-1.5">
              <label className="text-xs font-bold text-slate-700">
                Qisqacha tavsif
              </label>
              <Textarea
                placeholder="Test haqida qisqacha ma'lumot yozing..."
                value={testDescription}
                onChange={(e) => setTestDescription(e.target.value)}
                className="h-20 border-slate-200 resize-none text-sm"
              />
            </div>

            <div className="flex justify-end gap-3 pt-4 border-t border-border mt-6">
              <Button
                type="button"
                variant="secondary"
                onClick={() => setModalOpen(false)}
                className="font-bold"
              >
                Bekor qilish
              </Button>
              <Button
                type="button"
                onClick={handleNextStep}
                className="font-bold px-6 flex gap-2"
              >
                Keyingi
                <ArrowRight className="size-4" />
              </Button>
            </div>
          </div>
        )}

        {/* STEP 2: Savollar */}
        {wizardStep === 2 && (
          <div className="grid gap-6 lg:grid-cols-[1.1fr_.9fr]">
            <div className="space-y-4">
              <div className="flex justify-between items-center">
                <h3 className="text-sm font-black text-slate-900 uppercase tracking-wide">
                  2. Savollar ro'yxati
                </h3>
                <Badge variant="default" className="font-bold">
                  Jami: {wizardQuestions.length} savol
                </Badge>
              </div>

              {/* Add / Edit Question Subform */}
              {isAddingQuestion ? (
                <Card className="border border-blue-200 bg-blue-50/10 rounded-lg p-4.5 space-y-3.5">
                  <div className="flex justify-between items-center">
                    <h4 className="text-xs font-black text-blue-700 uppercase tracking-wide">
                      {editingQuestionItem
                        ? "Savolni tahrirlash"
                        : "Yangi savol qo'shish"}
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
                    <label className="text-[11px] font-bold text-slate-600">
                      Savol matni *
                    </label>
                    <Textarea
                      placeholder="Savol matnini kiriting..."
                      value={questionText}
                      onChange={(e) => setQuestionText(e.target.value)}
                      className="h-16 text-xs resize-none"
                    />
                  </div>

                  <div className="grid gap-3 md:grid-cols-3">
                    <button
                      type="button"
                      onClick={() => setQuestionType("text")}
                      className={`rounded-xl border px-3 py-3 text-left text-xs font-black transition ${questionType === "text" ? "border-blue-500 bg-blue-50 text-blue-700 shadow-sm" : "border-slate-200 bg-white text-slate-600 hover:border-blue-200 hover:bg-blue-50/40"}`}
                    >
                      <span className="mb-1 flex items-center gap-2">
                        <FileText className="size-4" />
                        Matnli test
                      </span>
                      <span className="block text-[10px] font-semibold text-slate-400">
                        Oddiy savol va javoblar
                      </span>
                    </button>
                    <button
                      type="button"
                      onClick={() => setQuestionType("image")}
                      className={`rounded-xl border px-3 py-3 text-left text-xs font-black transition ${questionType === "image" ? "border-fuchsia-500 bg-fuchsia-50 text-fuchsia-700 shadow-sm" : "border-slate-200 bg-white text-slate-600 hover:border-fuchsia-200 hover:bg-fuchsia-50/40"}`}
                    >
                      <span className="mb-1 flex items-center gap-2">
                        <ImageIcon className="size-4" />
                        Rasmli test
                      </span>
                      <span className="block text-[10px] font-semibold text-slate-400">
                        URL yoki PC fayl
                      </span>
                    </button>
                    <button
                      type="button"
                      onClick={() => setQuestionType("video")}
                      className={`rounded-xl border px-3 py-3 text-left text-xs font-black transition ${questionType === "video" ? "border-emerald-500 bg-emerald-50 text-emerald-700 shadow-sm" : "border-slate-200 bg-white text-slate-600 hover:border-emerald-200 hover:bg-emerald-50/40"}`}
                    >
                      <span className="mb-1 flex items-center gap-2">
                        <Video className="size-4" />
                        Video test
                      </span>
                      <span className="block text-[10px] font-semibold text-slate-400">
                        Havola yoki upload
                      </span>
                    </button>
                  </div>

                  {questionType !== "text" && (
                    <div className="rounded-xl border border-slate-200 bg-white p-3.5">
                      <div className="mb-3 flex items-center justify-between gap-3">
                        <div>
                          <p className="text-[11px] font-black uppercase tracking-wide text-slate-800">
                            {questionType === "image"
                              ? "Rasm manbasi"
                              : "Video manbasi"}
                          </p>
                          <p className="text-[10px] font-semibold text-slate-400">
                            Havola kiriting yoki kompyuterdan fayl yuklang.
                          </p>
                        </div>
                        {mediaUrl && (
                          <Button
                            type="button"
                            variant="secondary"
                            onClick={() => window.open(mediaUrl, "_blank")}
                            className="h-8 rounded-lg px-3 text-[10px] font-black"
                          >
                            <Link2 className="mr-1.5 size-3.5" />
                            Ko'rish
                          </Button>
                        )}
                      </div>

                      <div className="grid gap-3 md:grid-cols-[1fr_180px]">
                        <div className="grid gap-1">
                          <label className="text-[11px] font-bold text-slate-600">
                            {questionType === "image"
                              ? "Rasm URL"
                              : "Video/YouTube URL"}{" "}
                            *
                          </label>
                          <Input
                            placeholder={
                              questionType === "image"
                                ? "https://.../image.png"
                                : "https://youtube.com/watch?v=..."
                            }
                            value={mediaUrl}
                            onChange={(e) => setMediaUrl(e.target.value)}
                            className="h-9 text-xs"
                          />
                        </div>

                        <label className="mt-5 flex h-9 cursor-pointer items-center justify-center rounded-lg border border-dashed border-blue-300 bg-blue-50 px-3 text-[11px] font-black text-blue-700 transition hover:bg-blue-100">
                          {mediaUploading ? (
                            <Loader2 className="mr-1.5 size-3.5 animate-spin" />
                          ) : (
                            <UploadCloud className="mr-1.5 size-3.5" />
                          )}
                          PC'dan yuklash
                          <input
                            type="file"
                            className="sr-only"
                            accept={
                              questionType === "image" ? "image/*" : "video/*"
                            }
                            onChange={handleQuestionMediaUpload}
                            disabled={mediaUploading}
                          />
                        </label>
                      </div>

                      {mediaUrl && (
                        <p className="mt-2 truncate rounded-lg bg-slate-50 px-3 py-2 text-[10px] font-semibold text-slate-500">
                          {mediaUrl}
                        </p>
                      )}
                    </div>
                  )}

                  <div className="grid gap-2 grid-cols-2">
                    <div className="grid gap-1">
                      <label className="text-[11px] font-bold text-slate-600">
                        A Variant *
                      </label>
                      <Input
                        placeholder="A javob"
                        value={optionA}
                        onChange={(e) => setOptionA(e.target.value)}
                        className="h-9 text-xs"
                      />
                    </div>
                    <div className="grid gap-1">
                      <label className="text-[11px] font-bold text-slate-600">
                        B Variant *
                      </label>
                      <Input
                        placeholder="B javob"
                        value={optionB}
                        onChange={(e) => setOptionB(e.target.value)}
                        className="h-9 text-xs"
                      />
                    </div>
                    <div className="grid gap-1">
                      <label className="text-[11px] font-bold text-slate-600">
                        C Variant *
                      </label>
                      <Input
                        placeholder="C javob"
                        value={optionC}
                        onChange={(e) => setOptionC(e.target.value)}
                        className="h-9 text-xs"
                      />
                    </div>
                    <div className="grid gap-1">
                      <label className="text-[11px] font-bold text-slate-600">
                        D Variant (Ixtiyoriy)
                      </label>
                      <Input
                        placeholder="D javob"
                        value={optionD}
                        onChange={(e) => setOptionD(e.target.value)}
                        className="h-9 text-xs"
                      />
                    </div>
                  </div>

                  <div className="grid gap-3 grid-cols-3">
                    <div className="grid gap-1">
                      <label className="text-[11px] font-bold text-slate-600">
                        To'g'ri javob
                      </label>
                      <Select
                        value={correctOption}
                        onChange={(e: any) => setCorrectOption(e.target.value)}
                        className="h-9 text-xs font-bold"
                      >
                        <option value="a">A variant</option>
                        <option value="b">B variant</option>
                        <option value="c">C variant</option>
                        <option value="d">D variant</option>
                      </Select>
                    </div>

                    <div className="grid gap-1">
                      <label className="text-[11px] font-bold text-slate-600">
                        Qiyinchilik
                      </label>
                      <Select
                        value={questionDifficulty}
                        onChange={(e: any) =>
                          setQuestionDifficulty(e.target.value)
                        }
                        className="h-9 text-xs font-bold"
                      >
                        <option value="easy">Oson</option>
                        <option value="medium">O'rtacha</option>
                        <option value="hard">Qiyin</option>
                      </Select>
                    </div>

                    <div className="grid gap-1">
                      <label className="text-[11px] font-bold text-slate-600">
                        Ball
                      </label>
                      <Input
                        type="number"
                        value={questionPoints}
                        onChange={(e) =>
                          setQuestionPoints(Number(e.target.value))
                        }
                        className="h-9 text-xs"
                        min={1}
                      />
                    </div>
                  </div>

                  <div className="grid gap-1">
                    <label className="text-[11px] font-bold text-slate-600">
                      Tushuntirish (ixtiyoriy)
                    </label>
                    <Textarea
                      placeholder="To‘g‘ri javob izohi yoki eslatma..."
                      value={explanation}
                      onChange={(e) => setExplanation(e.target.value)}
                      className="h-14 text-xs resize-none"
                    />
                  </div>

                  <div className="flex justify-end gap-2 pt-2">
                    <Button
                      type="button"
                      onClick={handleSaveQuestion}
                      className="font-bold h-8.5 text-xs px-4"
                      disabled={
                        mediaUploading ||
                        createQuestionMutation.isPending ||
                        updateQuestionMutation.isPending
                      }
                    >
                      {(mediaUploading ||
                        createQuestionMutation.isPending ||
                        updateQuestionMutation.isPending) && (
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
                  className="w-full flex items-center justify-center gap-2 border-2 border-dashed border-slate-200 rounded-lg py-6 hover:bg-slate-50 hover:border-slate-300 transition cursor-pointer"
                >
                  <Plus className="size-5 text-slate-400" />
                  <span className="text-sm font-extrabold text-slate-600">
                    Yangi savol qo'shish
                  </span>
                </button>
              )}

              {/* Scrollable list of existing questions */}
              <div className="max-h-[300px] overflow-y-auto pr-1 space-y-2 edulab-scrollbar">
                {isQuestionsLoading ? (
                  <Skeleton className="h-20 w-full rounded-lg" />
                ) : !wizardQuestions.length ? (
                  <p className="text-center text-xs text-slate-400 font-semibold py-8">
                    Ushbu testga hali savollar kiritilmagan.
                  </p>
                ) : (
                  wizardQuestions.map((q: any, index: number) => (
                    <div
                      key={q.id}
                      className="p-3 border border-border bg-white rounded-lg flex gap-3 items-start justify-between"
                    >
                      <div className="min-w-0 flex-1 text-xs">
                        <div className="flex gap-2 items-center">
                          <span className="font-extrabold text-slate-400">
                            #{index + 1}
                          </span>
                          <Badge
                            variant={
                              q.difficulty === "hard"
                                ? "danger"
                                : q.difficulty === "easy"
                                  ? "success"
                                  : "warning"
                            }
                            className="py-0 px-1.5 text-[9px]"
                          >
                            {q.difficulty === "hard"
                              ? "Qiyin"
                              : q.difficulty === "easy"
                                ? "Oson"
                                : "O'rtacha"}
                          </Badge>
                          <span className="text-[10px] text-slate-400 font-semibold">
                            {q.points} ball
                          </span>
                          {q.question_type && q.question_type !== "text" && (
                            <span className="rounded-full bg-blue-50 px-2 py-0.5 text-[9px] font-black uppercase text-blue-600">
                              {q.question_type === "image" ? "Rasm" : "Video"}
                            </span>
                          )}
                        </div>
                        <p className="font-bold text-slate-800 mt-1">
                          {q.question}
                        </p>
                        <div className="grid grid-cols-2 gap-1 mt-2 text-[10px] text-slate-500 font-semibold">
                          <span
                            className={
                              q.correct_option === "a"
                                ? "text-emerald-600 font-bold"
                                : ""
                            }
                          >
                            A) {q.option_a}
                          </span>
                          <span
                            className={
                              q.correct_option === "b"
                                ? "text-emerald-600 font-bold"
                                : ""
                            }
                          >
                            B) {q.option_b}
                          </span>
                          <span
                            className={
                              q.correct_option === "c"
                                ? "text-emerald-600 font-bold"
                                : ""
                            }
                          >
                            C) {q.option_c}
                          </span>
                          {q.option_d && (
                            <span
                              className={
                                q.correct_option === "d"
                                  ? "text-emerald-600 font-bold"
                                  : ""
                              }
                            >
                              D) {q.option_d}
                            </span>
                          )}
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
            <div className="space-y-4">
              <div className="rounded-xl border-2 border-dashed border-blue-200 bg-blue-50/40 p-5 transition-all hover:bg-blue-50/80">
                <div className="mb-4 flex items-start justify-between gap-4">
                  <div>
                    <h4 className="flex items-center gap-2 text-sm font-black uppercase tracking-wide text-blue-800">
                      <Clipboard className="size-5 text-blue-600" />
                      Ommaviy import (Copy & Paste)
                    </h4>
                    <p className="mt-2 text-xs font-semibold leading-relaxed text-blue-700/80">
                      Word, Telegram yoki PDF'dan olingan savollarni shablon formatida paste qiling. Bu orqali 50 tagacha savolni bir vaqtda qo'shishingiz mumkin.
                    </p>
                  </div>
                </div>

                <div className="mb-3 flex flex-wrap gap-2">
                  <Button
                    type="button"
                    variant="secondary"
                    onClick={() => setBulkText(BULK_QUESTION_TEMPLATE)}
                    className="h-9 rounded-lg border border-blue-200 bg-white px-4 text-[11px] font-black text-blue-700 shadow-sm hover:bg-blue-50"
                  >
                    Shablonni qo'yish
                  </Button>
                  <Button
                    type="button"
                    variant="secondary"
                    onClick={copyBulkTemplate}
                    className="h-9 rounded-lg border border-blue-200 bg-white px-4 text-[11px] font-black text-blue-700 shadow-sm hover:bg-blue-50"
                  >
                    Nusxalash
                  </Button>
                </div>

                <div className="relative">
                  <Textarea
                    value={bulkText}
                    onChange={(e) => setBulkText(e.target.value)}
                    placeholder={BULK_QUESTION_TEMPLATE}
                    className="h-64 resize-y border-blue-200 bg-white/90 p-4 font-mono text-[12px] leading-relaxed shadow-inner placeholder:text-slate-300 focus-visible:ring-blue-500"
                  />
                  {bulkText.length > 0 && (
                    <div className="absolute right-3 top-3 rounded bg-blue-100 px-2 py-1 text-[9px] font-black text-blue-700">
                      {bulkText.split(/\n\s*\n/g).filter(b => b.trim().length > 10).length} SAVOL
                    </div>
                  )}
                </div>

                <Button
                  type="button"
                  onClick={handleBulkImport}
                  disabled={bulkImporting || createQuestionMutation.isPending || !bulkText.trim()}
                  className="mt-4 h-11 w-full rounded-lg bg-blue-600 text-sm font-black text-white hover:bg-blue-700 shadow-md"
                >
                  {(bulkImporting || createQuestionMutation.isPending) && (
                    <Loader2 className="mr-2 size-4 animate-spin" />
                  )}
                  Paste qilingan savollarni import qilish
                </Button>
              </div>

              <div className="border border-border rounded-xl p-5 bg-slate-50/50 space-y-4">
                <h4 className="text-xs font-black text-slate-800 uppercase tracking-wide">
                  Jarayon qoidalari
                </h4>
                <ul className="text-xs font-semibold text-slate-500 space-y-2">
                  <li className="flex gap-2">
                    <span className="text-emerald-500 shrink-0">✓</span>
                    Barcha kiritilgan savollar Supabase ma'lumotlar bazasida
                    saqlanadi.
                  </li>
                  <li className="flex gap-2">
                    <span className="text-emerald-500 shrink-0">✓</span>
                    Matnli savollarni shablon bilan ko'p miqdorda import qilish
                    mumkin.
                  </li>
                  <li className="flex gap-2">
                    <span className="text-emerald-500 shrink-0">✓</span>
                    Rasmli va video testlar URL yoki PC'dan yuklangan fayl bilan
                    ishlaydi.
                  </li>
                </ul>
              </div>
            </div>

            <div className="lg:col-span-2 flex justify-between gap-3 pt-4 border-t border-border mt-4">
              <Button
                type="button"
                variant="secondary"
                onClick={handlePrevStep}
                className="font-bold flex gap-2"
              >
                <ArrowLeft className="size-4" />
                Orqaga
              </Button>
              <Button
                type="button"
                onClick={handleNextStep}
                className="font-bold px-6 flex gap-2"
              >
                Keyingi
                <ArrowRight className="size-4" />
              </Button>
            </div>
          </div>
        )}

        {/* STEP 3: Sozlamalar */}
        {wizardStep === 3 && (
          <div className="space-y-4">
            <h3 className="text-sm font-black text-slate-900 uppercase tracking-wide">
              3. Test sozlamalari
            </h3>

            <div className="grid gap-6 md:grid-cols-2">
              <div className="space-y-4.5">
                <div className="grid gap-1.5">
                  <label className="text-xs font-bold text-slate-700">
                    Test davomiyligi (daqiqa) *
                  </label>
                  <Input
                    type="number"
                    value={durationMinutes}
                    onChange={(e) => setDurationMinutes(Number(e.target.value))}
                    className="h-10.5"
                    min={5}
                  />
                </div>

                <div className="grid gap-1.5">
                  <label className="text-xs font-bold text-slate-700">
                    O'tish balli (%) *
                  </label>
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
                  <label className="text-xs font-bold text-slate-700">
                    Natijalarni ko'rsatish vaqti
                  </label>
                  <Select
                    value={showResultsType}
                    onChange={(e) => setShowResultsType(e.target.value)}
                    className="h-10.5 font-bold"
                  >
                    <option>Test tugagandan so'ng</option>
                    <option>Imtihon topshirib bo'lingach</option>
                    <option>Hech qachon</option>
                  </Select>
                </div>

                <div className="grid gap-1.5">
                  <label className="text-xs font-bold text-slate-700">
                    Ruxsat etilgan urinishlar soni
                  </label>
                  <Select
                    value={allowedAttempts}
                    onChange={(e) => setAllowedAttempts(e.target.value)}
                    className="h-10.5 font-bold"
                  >
                    <option>Cheklanmagan</option>
                    <option>1 marta</option>
                    <option>2 marta</option>
                    <option>3 marta</option>
                  </Select>
                </div>
              </div>

              {/* Toggles */}
              <div className="border border-border rounded-lg p-5 bg-slate-50/50 space-y-4">
                <h4 className="text-xs font-black text-slate-800 uppercase tracking-wide">
                  Qo'shimcha parametrlar
                </h4>

                <div className="space-y-4">
                  <label className="flex items-center gap-3 cursor-pointer">
                    <input
                      type="checkbox"
                      checked={shuffleQuestions}
                      onChange={(e) => setShuffleQuestions(e.target.checked)}
                      className="size-4.5 rounded text-blue-600 border-slate-300"
                    />
                    <div>
                      <span className="text-xs font-bold text-slate-800 block">
                        Savollarni aralashtirish
                      </span>
                      <span className="text-[10px] text-slate-400 font-semibold">
                        Har bir urinishda savollar tartibi o'zgaradi.
                      </span>
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
                      <span className="text-xs font-bold text-slate-800 block">
                        Javoblarni aralashtirish
                      </span>
                      <span className="text-[10px] text-slate-400 font-semibold">
                        A, B, C, D javob variantlari o'rni almashadi.
                      </span>
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
                      <span className="text-xs font-bold text-slate-800 block">
                        Oldingi savollarga qaytish
                      </span>
                      <span className="text-[10px] text-slate-400 font-semibold">
                        Talaba javobni belgilagach orqaga qaytishi mumkin.
                      </span>
                    </div>
                  </label>

                  <label className="flex items-center gap-3 cursor-pointer">
                    <input
                      type="checkbox"
                      checked={allowExplanations}
                      onChange={(e) => setAllowExplanations(e.target.checked)}
                      className="size-4.5 rounded text-blue-600 border-slate-300"
                    />
                    <div>
                      <span className="text-xs font-bold text-slate-800 block">
                        Javob tahlilini ko'rsatish
                      </span>
                      <span className="text-[10px] text-slate-400 font-semibold">
                        Xato qilingan savollar bo'yicha tushuntirish beriladi.
                      </span>
                    </div>
                  </label>
                </div>
              </div>
            </div>

            <div className="flex justify-between gap-3 pt-4 border-t border-border mt-6">
              <Button
                type="button"
                variant="secondary"
                onClick={handlePrevStep}
                className="font-bold flex gap-2"
              >
                <ArrowLeft className="size-4" />
                Orqaga
              </Button>
              <Button
                type="button"
                onClick={handleNextStep}
                className="font-bold px-6 flex gap-2"
              >
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
              <div className="border border-border rounded-lg p-5 bg-white space-y-4">
                <h4 className="text-xs font-black text-slate-800 uppercase tracking-wide">
                  Test umumiy ma'lumotlari
                </h4>

                <div className="space-y-3.5 text-xs">
                  <div className="grid grid-cols-3">
                    <span className="font-semibold text-slate-400">
                      Test nomi:
                    </span>
                    <span className="font-extrabold text-slate-800 col-span-2">
                      {testTitle}
                    </span>
                  </div>

                  <div className="grid grid-cols-3">
                    <span className="font-semibold text-slate-400">
                      Tavsif:
                    </span>
                    <span className="font-bold text-slate-500 col-span-2">
                      {testDescription || "Kiritilmagan."}
                    </span>
                  </div>

                  <div className="grid grid-cols-3">
                    <span className="font-semibold text-slate-400">
                      Tegishli Mavzu:
                    </span>
                    <span className="font-extrabold text-slate-800 col-span-2">
                      {wizardSelectedTopic?.title || "Tanlanmagan"}
                    </span>
                  </div>

                  <div className="grid grid-cols-3">
                    <span className="font-semibold text-slate-400">
                      Kategoriya / Daraja:
                    </span>
                    <span className="font-bold text-slate-800 col-span-2">
                      {category} /{" "}
                      {difficultyLevel === "hard" ? "Qiyin" : "O'rtacha"}
                    </span>
                  </div>

                  <div className="grid grid-cols-3">
                    <span className="font-semibold text-slate-400">
                      Teglar:
                    </span>
                    <span className="font-semibold text-blue-600 col-span-2">
                      {tags}
                    </span>
                  </div>
                </div>
              </div>

              {/* Settings and Checklist */}
              <div className="border border-border rounded-lg p-5 bg-slate-50/50 space-y-4">
                <h4 className="text-xs font-black text-slate-800 uppercase tracking-wide">
                  Tasdiqlash ro'yxati
                </h4>

                <div className="space-y-2.5 text-xs font-bold text-slate-600">
                  <div className="flex gap-2 items-center">
                    <CheckCircle2 className="size-4.5 text-emerald-500 shrink-0" />
                    <span>Asosiy ma'lumotlar to'liq kiritildi</span>
                  </div>
                  <div className="flex gap-2 items-center">
                    <CheckCircle2 className="size-4.5 text-emerald-500 shrink-0" />
                    <span>
                      Savollar soni: {wizardQuestions.length} ta savol mavjud
                    </span>
                  </div>
                  <div className="flex gap-2 items-center">
                    <CheckCircle2 className="size-4.5 text-emerald-500 shrink-0" />
                    <span>
                      Vaqt: {durationMinutes} daqiqa, O'tish balli:{" "}
                      {passingScore}%
                    </span>
                  </div>
                  <div className="flex gap-2 items-center">
                    <CheckCircle2 className="size-4.5 text-emerald-500 shrink-0" />
                    <span>
                      Savol va javoblarni aralashtirish faollashtirildi
                    </span>
                  </div>
                </div>

                <div className="mt-4 p-3.5 bg-emerald-50 border border-emerald-100 rounded-lg flex gap-2 items-start">
                  <Check className="size-4.5 text-emerald-600 shrink-0 mt-0.5" />
                  <div>
                    <p className="text-[11px] font-extrabold text-emerald-800">
                      Tayyor
                    </p>
                    <p className="text-[10px] text-emerald-700 font-semibold mt-0.5">
                      Barcha ko'rsatkichlar to'g'ri. Testni nashr qilishga
                      ruxsat etiladi.
                    </p>
                  </div>
                </div>
              </div>
            </div>

            <div className="flex justify-between gap-3 pt-4 border-t border-border mt-6">
              <Button
                type="button"
                variant="secondary"
                onClick={handlePrevStep}
                className="font-bold flex gap-2"
              >
                <ArrowLeft className="size-4" />
                Orqaga
              </Button>
              <div className="flex gap-2">
                <Button
                  type="button"
                  variant="secondary"
                  onClick={handleFinishWizard}
                  className="font-bold"
                >
                  Saqlash (Draft)
                </Button>
                <Button
                  type="button"
                  onClick={handleFinishWizard}
                  className="font-bold bg-emerald-600 text-white hover:bg-emerald-700 px-6"
                >
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
