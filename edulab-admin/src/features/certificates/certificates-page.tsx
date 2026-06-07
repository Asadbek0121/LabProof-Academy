"use client";

import { useEffect, useMemo, useState } from "react";
import {
  ArrowRight,
  Award,
  CalendarDays,
  Check,
  CheckCircle2,
  ChevronDown,
  ChevronLeft,
  ChevronRight,
  Clock3,
  Download,
  Eye,
  FileUp,
  Filter,
  Link2,
  Loader2,
  MoreVertical,
  Pencil,
  Plus,
  QrCode,
  Search,
  Settings,
  Share2,
  ShieldCheck,
  Upload,
  X,
} from "lucide-react";
import { toast } from "sonner";
import { useQueryClient } from "@tanstack/react-query";
import { PageHeader } from "@/components/layout/page-header";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Input, Select } from "@/components/ui/input";
import { createCertificateAction } from "@/actions/certificates";
import { useCertificates, useModules, useStudents } from "@/hooks/use-admin-data";
import { cn } from "@/lib/utils";

type StatusFilter = "all" | "issued" | "pending";
type CertRow = {
  id: string;
  student: string;
  email: string;
  module: string;
  date: string;
  status: "Berilgan" | "Kutilmoqda";
  certificateUrl: string | null;
  verifyUrl: string;
  initials: string;
};

type UploadResponse = {
  ok?: boolean;
  error?: string;
  media?: {
    secure_url?: string;
  };
};

const MAX_CERTIFICATE_FILE_SIZE = 10 * 1024 * 1024;

async function readUploadResponse(response: Response): Promise<UploadResponse | null> {
  const text = await response.text();
  if (!text.trim()) return null;

  try {
    return JSON.parse(text) as UploadResponse;
  } catch {
    return {
      ok: false,
      error: response.ok
        ? "Server noto'g'ri javob qaytardi."
        : `Server xatoligi (${response.status}). Iltimos, qayta urinib ko'ring.`,
    };
  }
}

export function CertificatesPage() {
  const queryClient = useQueryClient();
  const { data: certificates = [], isLoading: certsLoading } = useCertificates();
  const { data: students = [], isLoading: studentsLoading } = useStudents();
  const { data: modules = [], isLoading: modulesLoading } = useModules();

  const [statusFilter, setStatusFilter] = useState<StatusFilter>("all");
  const [searchTerm, setSearchTerm] = useState("");
  const [moduleFilter, setModuleFilter] = useState("all");
  const [dateFilter, setDateFilter] = useState("all");
  const [drawerOpen, setDrawerOpen] = useState(false);
  const [step, setStep] = useState(1);
  const [selectedStudentId, setSelectedStudentId] = useState("");
  const [selectedModuleId, setSelectedModuleId] = useState("");
  const [fileUrl, setFileUrl] = useState("");
  const [uploading, setUploading] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [createdCert, setCreatedCert] = useState<{ id: string; qrDataUrl: string; verifyUrl: string } | null>(null);

  useEffect(() => {
    if (!selectedStudentId && students.length) setSelectedStudentId(students[0].id);
  }, [selectedStudentId, students]);

  useEffect(() => {
    if (!selectedModuleId && modules.length) setSelectedModuleId(modules[0].id);
  }, [modules, selectedModuleId]);

  const selectedStudent = students.find((student) => student.id === selectedStudentId);
  const selectedModule = modules.find((module: any) => module.id === selectedModuleId);

  const pendingRows = useMemo(() => {
    const certifiedStudentIds = new Set(
      certificates.map((certificate: any) => certificate.student.toLowerCase()),
    );
    return students
      .filter((student) => !certifiedStudentIds.has(student.name.toLowerCase()))
      .map((student) => ({
        id: `pending-${student.id}`,
        student: student.name,
        email: student.email,
        module: modules[0]?.title || "Modul tanlanmagan",
        date: student.joinedAt,
        status: "Kutilmoqda" as const,
        certificateUrl: null,
        verifyUrl: "",
        initials: student.initials || student.name.slice(0, 1).toUpperCase(),
      }));
  }, [certificates, modules, students]);

  const issuedRows: CertRow[] = useMemo(
    () =>
      certificates.map((certificate: any) => ({
        id: certificate.id,
        student: certificate.student,
        email: certificate.email,
        module: certificate.module,
        date: certificate.date,
        status: "Berilgan" as const,
        certificateUrl: certificate.certificateUrl,
        verifyUrl: certificate.qrCode,
        initials: certificate.student
          .split(" ")
          .map((part: string) => part[0])
          .join("")
          .toUpperCase()
          .slice(0, 2),
      })),
    [certificates],
  );

  const allRows = useMemo(() => [...issuedRows, ...pendingRows], [issuedRows, pendingRows]);
  const filteredRows = useMemo(() => {
    const now = Date.now();
    const dayMs = 24 * 60 * 60 * 1000;
    return allRows.filter((row) => {
      const search = searchTerm.trim().toLowerCase();
      const matchesSearch = !search || row.student.toLowerCase().includes(search) || row.email.toLowerCase().includes(search);
      const matchesStatus =
        statusFilter === "all" ||
        (statusFilter === "issued" && row.status === "Berilgan") ||
        (statusFilter === "pending" && row.status === "Kutilmoqda");
      const matchesModule = moduleFilter === "all" || row.module === moduleFilter;
      const rowDate = new Date(row.date.replace(" - ", " ")).getTime();
      const matchesDate =
        dateFilter === "all" ||
        Number.isNaN(rowDate) ||
        (dateFilter === "7" && now - rowDate <= 7 * dayMs) ||
        (dateFilter === "30" && now - rowDate <= 30 * dayMs);
      return matchesSearch && matchesStatus && matchesModule && matchesDate;
    });
  }, [allRows, dateFilter, moduleFilter, searchTerm, statusFilter]);

  const stats = {
    total: allRows.length,
    issued: issuedRows.length,
    pending: pendingRows.length,
  };
  const issuedPercent = stats.total ? Math.round((stats.issued / stats.total) * 100) : 0;
  const pendingPercent = stats.total ? 100 - issuedPercent : 0;
  const previewCertificate = issuedRows.find((row) => row.certificateUrl) ?? issuedRows[0];

  const resetWizard = () => {
    setStep(1);
    setFileUrl("");
    setCreatedCert(null);
  };

  const openWizard = () => {
    resetWizard();
    setDrawerOpen(true);
  };

  const handleFileUpload = async (event: React.ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    if (!file) return;

    if (file.size > MAX_CERTIFICATE_FILE_SIZE) {
      toast.error("Fayl hajmi 10MB dan oshmasligi kerak");
      event.target.value = "";
      return;
    }

    setUploading(true);
    const formData = new FormData();
    formData.append("file", file);
    formData.append("kind", file.type.startsWith("image/") ? "image" : "pdf");

    try {
      const response = await fetch("/api/media/upload", { method: "POST", body: formData });
      const data = await readUploadResponse(response);
      if (!response.ok || !data?.ok || !data.media?.secure_url) {
        throw new Error(data?.error || "Fayl yuklanmadi");
      }
      setFileUrl(data.media.secure_url);
      toast.success("Sertifikat fayli yuklandi");
    } catch (error: any) {
      toast.error(error.message || "Fayl yuklashda xatolik");
    } finally {
      setUploading(false);
      event.target.value = "";
    }
  };

  const createCertificate = async () => {
    if (!selectedStudentId || !selectedModuleId) {
      toast.error("Talaba va modulni tanlang");
      return;
    }
    if (!fileUrl) {
      toast.error("Sertifikat faylini yuklang yoki URL kiriting");
      return;
    }
    setSubmitting(true);
    try {
      const result = await createCertificateAction({
        studentId: selectedStudentId,
        moduleId: selectedModuleId,
        title: `${selectedStudent?.name || "Talaba"} - ${selectedModule?.title || "Modul"}`,
        certificateFileUrl: fileUrl,
      });
      if (!result.ok || !result.certificateId || !result.qrDataUrl || !result.verifyUrl) {
        throw new Error(result.error || "Sertifikat yaratilmadi");
      }
      setCreatedCert({ id: result.certificateId, qrDataUrl: result.qrDataUrl, verifyUrl: result.verifyUrl });
      setStep(3);
      await queryClient.invalidateQueries({ queryKey: ["certificates"] });
      await queryClient.invalidateQueries({ queryKey: ["admin-overview-data"] });
      toast.success("Sertifikat yaratildi");
    } catch (error: any) {
      toast.error(error.message || "Tizim xatoligi");
    } finally {
      setSubmitting(false);
    }
  };

  const downloadCertificate = async (row: CertRow) => {
    if (!row.certificateUrl) {
      toast.error("Bu sertifikat fayli hali yuklanmagan");
      return;
    }
    try {
      const response = await fetch(row.certificateUrl);
      const blob = await response.blob();
      const blobUrl = URL.createObjectURL(blob);
      const link = document.createElement("a");
      link.href = blobUrl;
      link.download = `${row.student}-${row.id}.pdf`;
      document.body.appendChild(link);
      link.click();
      document.body.removeChild(link);
      URL.revokeObjectURL(blobUrl);
      toast.success("Sertifikat yuklab olindi");
    } catch {
      window.open(row.certificateUrl, "_blank");
      toast.info("Fayl yangi oynada ochildi");
    }
  };

  const shareCertificate = async (row: CertRow) => {
    if (!row.verifyUrl) {
      toast.error("Kutilayotgan sertifikatda havola yo'q");
      return;
    }
    const url = `${window.location.origin}${row.verifyUrl}`;
    await navigator.clipboard.writeText(url);
    toast.success("Tekshirish havolasi nusxalandi");
  };

  const exportCsv = () => {
    const csv = [
      ["Talaba", "Email", "Modul", "Sana", "Holat"],
      ...filteredRows.map((row) => [row.student, row.email, row.module, row.date, row.status]),
    ]
      .map((row) => row.map((cell) => `"${String(cell).replaceAll('"', '""')}"`).join(","))
      .join("\n");
    const blob = new Blob([csv], { type: "text/csv;charset=utf-8" });
    const url = URL.createObjectURL(blob);
    const link = document.createElement("a");
    link.href = url;
    link.download = "sertifikatlar.csv";
    link.click();
    URL.revokeObjectURL(url);
    toast.success("Sertifikatlar eksport qilindi");
  };

  return (
    <>
      <PageHeader title="Sertifikatlar" current="Sertifikatlar" />

      <div className="certificates-surface -mx-1 -mt-1 space-y-4 pb-4 text-slate-900 dark:text-slate-100">
        <div className="grid gap-4 md:grid-cols-3 xl:max-w-4xl">
          <SummaryCard icon={Award} title="Jami sertifikatlar" value={stats.total} hint="Barcha sertifikatlar" tone="blue" />
          <SummaryCard icon={CheckCircle2} title="Berilgan" value={stats.issued} hint="URL tayyor" tone="green" />
          <SummaryCard icon={Clock3} title="Kutilmoqda" value={stats.pending} hint="Hali sertifikat yo'q" tone="amber" />
        </div>

        <div className="grid gap-4 xl:grid-cols-[1fr_340px]">
          <section className="rounded-xl border border-slate-200 bg-white shadow-[0_10px_28px_rgba(27,39,70,0.055)] dark:border-slate-800 dark:bg-slate-900">
            <div className="flex flex-wrap items-center justify-between gap-3 border-b border-slate-100 px-4 py-4 dark:border-slate-800">
              <div className="flex flex-wrap gap-6 text-sm font-black">
                <TabButton active={statusFilter === "all"} onClick={() => setStatusFilter("all")}>Barcha sertifikatlar</TabButton>
                <TabButton active={statusFilter === "issued"} onClick={() => setStatusFilter("issued")}>Berilgan</TabButton>
                <TabButton active={statusFilter === "pending"} onClick={() => setStatusFilter("pending")}>Kutilmoqda</TabButton>
              </div>
              <Button onClick={openWizard} className="h-10 rounded-xl px-4 text-xs font-black">
                <Plus className="size-4" />
                Yangi sertifikat yaratish
              </Button>
            </div>

            <div className="grid gap-3 border-b border-slate-100 p-4 dark:border-slate-800 lg:grid-cols-[1fr_104px_190px_180px]">
              <div className="relative">
                <Search className="absolute left-3 top-1/2 size-4 -translate-y-1/2 text-slate-400" />
                <Input
                  value={searchTerm}
                  onChange={(event) => setSearchTerm(event.target.value)}
                  placeholder="Talaba ismi yoki email..."
                  className="h-10 rounded-xl pl-10 text-xs font-bold"
                />
              </div>
              <Select value={statusFilter} onChange={(event) => setStatusFilter(event.target.value as StatusFilter)} className="h-10 rounded-xl text-xs font-black">
                <option value="all">Filtr</option>
                <option value="issued">Berilgan</option>
                <option value="pending">Kutilmoqda</option>
              </Select>
              <Select value={dateFilter} onChange={(event) => setDateFilter(event.target.value)} className="h-10 rounded-xl text-xs font-black">
                <option value="all">Barcha sanalar</option>
                <option value="7">So'nggi 7 kun</option>
                <option value="30">So'nggi 30 kun</option>
              </Select>
              <Select value={moduleFilter} onChange={(event) => setModuleFilter(event.target.value)} className="h-10 rounded-xl text-xs font-black">
                <option value="all">Barcha modullar</option>
                {modules.map((module: any) => (
                  <option key={module.id} value={module.title}>{module.title}</option>
                ))}
              </Select>
            </div>

            <div className="overflow-x-auto">
              <table className="w-full min-w-[860px] text-sm">
                <thead className="border-b border-slate-100 text-left text-[11px] font-black text-slate-500 dark:border-slate-800 dark:text-slate-400">
                  <tr>
                    <th className="px-4 py-4">Talaba</th>
                    <th className="px-4 py-4">Modul</th>
                    <th className="px-4 py-4">Sana <ChevronDown className="inline size-3" /></th>
                    <th className="px-4 py-4">Holat <ChevronDown className="inline size-3" /></th>
                    <th className="px-4 py-4">Sertifikat</th>
                    <th className="px-4 py-4 text-right">Amallar</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-100 dark:divide-slate-800">
                  {certsLoading ? (
                    <tr><td colSpan={6} className="px-4 py-12 text-center text-xs font-bold text-slate-500">Yuklanmoqda...</td></tr>
                  ) : filteredRows.length ? (
                    filteredRows.map((row) => (
                      <tr key={row.id} className="transition hover:bg-slate-50/70 dark:hover:bg-slate-950/40">
                        <td className="px-4 py-4">
                          <div className="flex items-center gap-3">
                            <span className="flex size-9 items-center justify-center rounded-full bg-slate-100 text-xs font-black text-slate-600 dark:bg-slate-800 dark:text-slate-300">
                              {row.initials || row.student[0]}
                            </span>
                            <span className="min-w-0">
                              <span className="block truncate text-xs font-black text-slate-900 dark:text-white">{row.student}</span>
                              <span className="block truncate text-[11px] font-bold text-slate-500 dark:text-slate-400">{row.email}</span>
                            </span>
                          </div>
                        </td>
                        <td className="px-4 py-4 text-xs font-bold text-slate-600 dark:text-slate-300">{row.module}</td>
                        <td className="px-4 py-4 text-xs font-bold text-slate-500 dark:text-slate-400">{row.date}</td>
                        <td className="px-4 py-4">
                          <Badge variant={row.status === "Berilgan" ? "success" : "warning"}>{row.status}</Badge>
                        </td>
                        <td className="px-4 py-4">
                          {row.status === "Berilgan" ? (
                            <a href={row.verifyUrl} target="_blank" rel="noreferrer" className="inline-flex items-center gap-2 text-xs font-black text-blue-600 hover:underline dark:text-blue-300">
                              Ko'rish <Link2 className="size-3.5" />
                            </a>
                          ) : (
                            <span className="text-xs font-black text-slate-400">-</span>
                          )}
                        </td>
                        <td className="px-4 py-4">
                          <div className="flex justify-end gap-2">
                            <IconButton title="Ko'rish" disabled={!row.verifyUrl} onClick={() => row.verifyUrl && window.open(row.verifyUrl, "_blank")}>
                              <Eye className="size-4" />
                            </IconButton>
                            <IconButton title="Yuklab olish" disabled={!row.certificateUrl} onClick={() => downloadCertificate(row)}>
                              <Download className="size-4" />
                            </IconButton>
                            <IconButton title="Ulashish" disabled={!row.verifyUrl} onClick={() => shareCertificate(row)}>
                              <Share2 className="size-4" />
                            </IconButton>
                            <IconButton title="Batafsil" onClick={() => toast.info(`${row.student}: ${row.status}`)}>
                              <MoreVertical className="size-4" />
                            </IconButton>
                          </div>
                        </td>
                      </tr>
                    ))
                  ) : (
                    <tr><td colSpan={6} className="px-4 py-14 text-center text-xs font-bold text-slate-500">Sertifikatlar topilmadi.</td></tr>
                  )}
                </tbody>
              </table>
            </div>

            <div className="flex flex-wrap items-center justify-between gap-3 border-t border-slate-100 px-4 py-4 text-xs font-bold text-slate-500 dark:border-slate-800 dark:text-slate-400">
              <span>Jami {filteredRows.length} ta yozuv</span>
              <div className="flex items-center gap-2">
                <IconButton title="Oldingi"><ChevronLeft className="size-4" /></IconButton>
                <span className="rounded-lg bg-blue-600 px-3 py-2 text-white">1</span>
                <IconButton title="Keyingi"><ChevronRight className="size-4" /></IconButton>
              </div>
            </div>
          </section>

          <aside className="space-y-4">
            <SidePanel title="Sertifikat statistikasi">
              <div className="grid grid-cols-[124px_1fr] items-center gap-4">
                <div className="relative flex size-28 items-center justify-center rounded-full" style={{ background: `conic-gradient(#22C55E 0 ${issuedPercent}%, #F59E0B ${issuedPercent}% 100%)` }}>
                  <div className="flex size-20 flex-col items-center justify-center rounded-full bg-white text-center dark:bg-slate-900">
                    <span className="text-xl font-black text-emerald-600">{stats.total}</span>
                    <span className="text-[10px] font-bold text-slate-500">Jami</span>
                  </div>
                </div>
                <div className="space-y-3 text-xs font-bold">
                  <LegendDot color="bg-emerald-500" label="Berilgan" value={`${stats.issued} (${issuedPercent}%)`} />
                  <LegendDot color="bg-amber-500" label="Kutilmoqda" value={`${stats.pending} (${pendingPercent}%)`} />
                </div>
              </div>
            </SidePanel>

            <SidePanel title="Sertifikat namunasi">
              <CertificatePreview row={previewCertificate} />
              <Button variant="secondary" className="mt-4 h-10 w-full rounded-xl text-xs font-black" onClick={() => toast.info("Shablon tahrirlash keyingi sozlamalarda ulanadi")}>
                <Pencil className="size-4" />
                Namunani o'zgartirish
              </Button>
            </SidePanel>

            <SidePanel title="Tezkor amallar">
              <div className="space-y-2">
                <QuickAction icon={Pencil} label="Sertifikat shablonini tahrirlash" onClick={() => toast.info("Shablon sozlamalari tayyorlanmoqda")} />
                <QuickAction icon={QrCode} label="Sertifikat QR sozlamalari" onClick={() => toast.info("QR sozlamalari ochiladi")} />
                <QuickAction icon={FileUp} label="Sertifikatni ommaviy yaratish" onClick={openWizard} />
                <QuickAction icon={Download} label="Sertifikatlarni eksport qilish" onClick={exportCsv} />
              </div>
            </SidePanel>
          </aside>
        </div>
      </div>

      {drawerOpen && (
        <div className="fixed inset-0 z-50 flex justify-end bg-slate-950/30 backdrop-blur-sm">
          <div className="h-full w-full max-w-[460px] overflow-y-auto border-l border-slate-200 bg-white p-6 shadow-2xl dark:border-slate-800 dark:bg-slate-950">
            <div className="mb-7 flex items-center justify-between">
              <h2 className="text-lg font-black">Yangi sertifikat yaratish</h2>
              <button className="rounded-lg p-2 text-slate-400 hover:bg-slate-100 dark:hover:bg-slate-900" onClick={() => setDrawerOpen(false)}>
                <X className="size-5" />
              </button>
            </div>

            <Stepper step={step} />

            {step === 1 && (
              <div className="mt-8 space-y-5">
                <Field label="Talabani tanlang">
                  <Select value={selectedStudentId} onChange={(event) => setSelectedStudentId(event.target.value)} className="h-12 w-full rounded-xl text-sm">
                    {studentsLoading ? <option>Yuklanmoqda...</option> : students.map((student) => <option key={student.id} value={student.id}>{student.name}</option>)}
                  </Select>
                </Field>
                {selectedStudent && (
                  <SelectedBox title={selectedStudent.name} subtitle={selectedStudent.email} initials={selectedStudent.initials} onClear={() => setSelectedStudentId("")} />
                )}
                <Field label="Modulni tanlang">
                  <Select value={selectedModuleId} onChange={(event) => setSelectedModuleId(event.target.value)} className="h-12 w-full rounded-xl text-sm">
                    {modulesLoading ? <option>Yuklanmoqda...</option> : modules.map((module: any) => <option key={module.id} value={module.id}>{module.title}</option>)}
                  </Select>
                </Field>
                <InfoBox>Talaba tanlangandan so'ng sertifikatga noyob QR kod biriktiriladi.</InfoBox>
                <Button onClick={() => setStep(2)} disabled={!selectedStudentId || !selectedModuleId} className="ml-auto flex h-11 rounded-xl px-6 text-xs font-black">
                  Keyingi <ArrowRight className="size-4" />
                </Button>
              </div>
            )}

            {step === 2 && (
              <div className="mt-8 space-y-5">
                <Field label="Sertifikat faylini yuklang">
                  <label className="relative flex min-h-36 cursor-pointer flex-col items-center justify-center rounded-xl border border-dashed border-blue-200 bg-blue-50/40 p-6 text-center transition hover:bg-blue-50 dark:border-blue-500/30 dark:bg-blue-500/10">
                    <input type="file" className="absolute inset-0 cursor-pointer opacity-0" accept="application/pdf,image/*" onChange={handleFileUpload} />
                    {uploading ? <Loader2 className="size-8 animate-spin text-blue-600" /> : <Upload className="size-8 text-blue-600" />}
                    <span className="mt-3 text-xs font-black">Faylni shu yerga tashlang yoki tanlang</span>
                    <span className="mt-1 text-[11px] font-bold text-slate-500">PDF, PNG, JPG. Maks. 10MB.</span>
                  </label>
                </Field>
                <Field label="Fayl URL manzili">
                  <Input value={fileUrl} onChange={(event) => setFileUrl(event.target.value)} placeholder="https://..." className="h-11 rounded-xl text-xs font-bold" />
                </Field>
                <div className="flex justify-between pt-3">
                  <Button variant="secondary" onClick={() => setStep(1)} className="h-11 rounded-xl text-xs font-black">Oldingi</Button>
                  <Button onClick={createCertificate} disabled={!fileUrl || submitting || uploading} className="h-11 rounded-xl text-xs font-black">
                    {submitting ? <Loader2 className="size-4 animate-spin" /> : <Check className="size-4" />}
                    Sertifikatni yaratish
                  </Button>
                </div>
              </div>
            )}

            {step === 3 && createdCert && (
              <div className="mt-8 space-y-5">
                <InfoBox tone="success">QR kod generatsiya qilindi. Ushbu QR kod orqali sertifikat haqiqiyligi tekshiriladi.</InfoBox>
                <div className="grid gap-4 sm:grid-cols-[150px_1fr]">
                  <img src={createdCert.qrDataUrl} alt="QR kod" className="size-36 rounded-xl border border-slate-200 bg-white p-2" />
                  <div className="rounded-xl border border-slate-200 bg-slate-50 p-4 text-xs font-bold dark:border-slate-800 dark:bg-slate-900">
                    <p className="text-slate-400">Sertifikat ID</p>
                    <p className="mt-1 break-all font-black text-slate-900 dark:text-white">{createdCert.id}</p>
                    <p className="mt-4 text-slate-400">Tekshirish havolasi</p>
                    <a href={createdCert.verifyUrl} target="_blank" rel="noreferrer" className="mt-1 block break-all text-blue-600 dark:text-blue-300">{createdCert.verifyUrl}</a>
                  </div>
                </div>
                <Button onClick={openWizard} className="h-11 w-full rounded-xl text-xs font-black">Yana sertifikat yaratish</Button>
              </div>
            )}
          </div>
        </div>
      )}
    </>
  );
}

function SummaryCard({ icon: Icon, title, value, hint, tone }: { icon: React.ElementType; title: string; value: number; hint: string; tone: "blue" | "green" | "amber" }) {
  const colors = {
    blue: "bg-blue-50 text-blue-600 dark:bg-blue-500/12 dark:text-blue-300",
    green: "bg-emerald-50 text-emerald-600 dark:bg-emerald-500/12 dark:text-emerald-300",
    amber: "bg-amber-50 text-amber-600 dark:bg-amber-500/12 dark:text-amber-300",
  };
  return (
    <div className="rounded-xl border border-slate-200 bg-white p-4 shadow-[0_10px_28px_rgba(27,39,70,0.055)] dark:border-slate-800 dark:bg-slate-900">
      <div className="flex items-center gap-4">
        <span className={cn("flex size-14 items-center justify-center rounded-xl", colors[tone])}><Icon className="size-7" /></span>
        <span>
          <span className="block text-xs font-black text-slate-600 dark:text-slate-300">{title}</span>
          <span className="mt-1 block text-3xl font-black">{value}</span>
          <span className={cn("mt-2 block text-xs font-black", tone === "blue" ? "text-blue-600 dark:text-blue-300" : tone === "green" ? "text-emerald-600 dark:text-emerald-300" : "text-amber-600 dark:text-amber-300")}>{hint}</span>
        </span>
      </div>
    </div>
  );
}

function TabButton({ active, onClick, children }: { active: boolean; onClick: () => void; children: React.ReactNode }) {
  return (
    <button type="button" onClick={onClick} className={cn("border-b-2 border-transparent pb-3 text-slate-500 transition dark:text-slate-400", active && "border-blue-600 text-blue-600 dark:text-blue-300")}>
      {children}
    </button>
  );
}

function IconButton({ children, title, onClick, disabled }: { children: React.ReactNode; title: string; onClick?: () => void; disabled?: boolean }) {
  return (
    <button
      type="button"
      title={title}
      disabled={disabled}
      onClick={onClick}
      className="inline-flex size-9 items-center justify-center rounded-lg border border-slate-200 bg-white text-slate-500 shadow-sm transition hover:bg-slate-50 disabled:cursor-not-allowed disabled:opacity-45 dark:border-slate-800 dark:bg-slate-950 dark:text-slate-300 dark:hover:bg-slate-900"
    >
      {children}
    </button>
  );
}

function SidePanel({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section className="rounded-xl border border-slate-200 bg-white p-4 shadow-[0_10px_28px_rgba(27,39,70,0.055)] dark:border-slate-800 dark:bg-slate-900">
      <h3 className="mb-4 text-base font-black">{title}</h3>
      {children}
    </section>
  );
}

function LegendDot({ color, label, value }: { color: string; label: string; value: string }) {
  return (
    <div className="flex items-center gap-2">
      <span className={cn("size-2.5 rounded-full", color)} />
      <span className="min-w-0 flex-1 text-slate-600 dark:text-slate-300">{label}</span>
      <span className="font-black">{value}</span>
    </div>
  );
}

function CertificatePreview({ row }: { row?: CertRow }) {
  return (
    <div className="overflow-hidden rounded-xl border border-amber-200 bg-[#fffaf0] p-4 text-center shadow-inner dark:border-amber-500/20 dark:bg-amber-500/10">
      <div className="border-4 border-double border-amber-400 bg-white px-4 py-6 text-slate-900">
        <p className="text-[10px] font-black tracking-[0.24em] text-slate-500">LABPROOF ACADEMY</p>
        <h4 className="mt-3 text-2xl font-black tracking-wide">SERTIFIKAT</h4>
        <p className="mt-4 text-xs text-slate-500">Ushbu sertifikat</p>
        <p className="mt-1 text-lg font-black">{row?.student || "Talaba tanlanmagan"}</p>
        <p className="mt-3 text-xs text-slate-500">modulni muvaffaqiyatli yakunlagani uchun berildi.</p>
        <p className="mt-1 text-sm font-black">{row?.module || "Modul tanlanmagan"}</p>
        <div className="mt-5 flex items-end justify-between text-[10px] font-bold text-slate-500">
          <span>Direktor</span>
          <QrCode className="size-10 text-slate-800" />
        </div>
      </div>
    </div>
  );
}

function QuickAction({ icon: Icon, label, onClick }: { icon: React.ElementType; label: string; onClick: () => void }) {
  return (
    <button type="button" onClick={onClick} className="flex w-full items-center gap-3 rounded-xl border border-slate-200 bg-white px-3 py-3 text-left text-xs font-black text-slate-700 transition hover:border-blue-200 hover:bg-blue-50 hover:text-blue-600 dark:border-slate-800 dark:bg-slate-950 dark:text-slate-300 dark:hover:bg-slate-900">
      <span className="flex size-8 items-center justify-center rounded-lg bg-blue-50 text-blue-600 dark:bg-blue-500/12 dark:text-blue-300"><Icon className="size-4" /></span>
      <span className="min-w-0 flex-1 truncate">{label}</span>
      <ChevronRight className="size-4 text-slate-400" />
    </button>
  );
}

function Stepper({ step }: { step: number }) {
  const labels = ["Talaba", "Sertifikat yuklash", "QR kod va yakunlash"];
  return (
    <div className="grid grid-cols-3 gap-3">
      {labels.map((label, index) => {
        const current = index + 1;
        const done = step > current;
        const active = step === current;
        return (
          <div key={label} className="text-center">
            <span className={cn("mx-auto flex size-8 items-center justify-center rounded-full border text-xs font-black", active && "border-blue-600 bg-blue-600 text-white", done && "border-emerald-500 bg-emerald-500 text-white", !active && !done && "border-slate-200 text-slate-400 dark:border-slate-800")}>{done ? <Check className="size-4" /> : current}</span>
            <p className={cn("mt-2 text-[11px] font-black", active ? "text-blue-600 dark:text-blue-300" : "text-slate-500")}>{label}</p>
          </div>
        );
      })}
    </div>
  );
}

function Field({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <label className="block">
      <span className="mb-2 block text-xs font-black text-slate-700 dark:text-slate-300">{label}</span>
      {children}
    </label>
  );
}

function SelectedBox({ title, subtitle, initials, onClear }: { title: string; subtitle: string; initials: string; onClear: () => void }) {
  return (
    <div className="flex items-center gap-3 rounded-xl border border-slate-200 bg-slate-50 p-3 dark:border-slate-800 dark:bg-slate-900">
      <span className="flex size-10 items-center justify-center rounded-full bg-slate-200 text-xs font-black text-slate-700 dark:bg-slate-800 dark:text-slate-200">{initials}</span>
      <span className="min-w-0 flex-1">
        <span className="block truncate text-sm font-black">{title}</span>
        <span className="block truncate text-xs font-bold text-slate-500">{subtitle}</span>
      </span>
      <button type="button" onClick={onClear} className="rounded-lg p-1 text-slate-400 hover:bg-slate-200 dark:hover:bg-slate-800"><X className="size-4" /></button>
    </div>
  );
}

function InfoBox({ children, tone = "info" }: { children: React.ReactNode; tone?: "info" | "success" }) {
  return (
    <div className={cn("flex gap-3 rounded-xl border p-4 text-xs font-bold leading-relaxed", tone === "success" ? "border-emerald-200 bg-emerald-50 text-emerald-700 dark:border-emerald-500/20 dark:bg-emerald-500/10 dark:text-emerald-300" : "border-blue-200 bg-blue-50 text-blue-700 dark:border-blue-500/20 dark:bg-blue-500/10 dark:text-blue-300")}>
      {tone === "success" ? <ShieldCheck className="mt-0.5 size-4 shrink-0" /> : <Settings className="mt-0.5 size-4 shrink-0" />}
      <span>{children}</span>
    </div>
  );
}
