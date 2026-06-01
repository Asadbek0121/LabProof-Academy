"use client";

import { useState, useMemo, useEffect } from "react";
import {
  ArrowLeft,
  ArrowRight,
  Award,
  CalendarDays,
  Check,
  CheckCircle2,
  Clock3,
  Download,
  Eye,
  FileUp,
  Plus,
  QrCode,
  Search,
  ShieldCheck,
  Upload,
  X,
  Loader2,
  RefreshCw
} from "lucide-react";
import { PageHeader } from "@/components/layout/page-header";
import { StatCard } from "@/components/layout/stat-card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Input, Select } from "@/components/ui/input";
import { useCertificates, useStudents, useModules } from "@/hooks/use-admin-data";
import { createCertificateAction } from "@/actions/certificates";
import { toast } from "sonner";
import { cn } from "@/lib/utils";
import { useQueryClient } from "@tanstack/react-query";

export function CertificatesPage() {
  const queryClient = useQueryClient();
  const { data: certificates = [], isLoading: isCertsLoading } = useCertificates();
  const { data: students = [], isLoading: isStudentsLoading } = useStudents();
  const { data: modules = [], isLoading: isModulesLoading } = useModules();

  const [activeTab, setActiveTab] = useState<"certificates" | "templates">("certificates");
  
  // Search & Filter State
  const [searchTerm, setSearchTerm] = useState("");
  const [selectedModuleFilter, setSelectedModuleFilter] = useState("all");

  // Wizard state
  const [step, setStep] = useState(1);
  const [selectedStudentId, setSelectedStudentId] = useState("");
  const [selectedModuleId, setSelectedModuleId] = useState("");
  const [fileUrl, setFileUrl] = useState("");
  const [uploading, setUploading] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [issuedCertDetails, setIssuedCertDetails] = useState<{
    certificateId: string;
    qrDataUrl: string;
    verifyUrl: string;
  } | null>(null);

  // Set default selection when data loads
  useEffect(() => {
    if (students.length > 0 && !selectedStudentId) {
      setSelectedStudentId(students[0].id);
    }
  }, [students, selectedStudentId]);

  useEffect(() => {
    if (modules.length > 0 && !selectedModuleId) {
      setSelectedModuleId(modules[0].id);
    }
  }, [modules, selectedModuleId]);

  // Dynamic statistics
  const certStats = useMemo(() => {
    return [
      { title: "Jami sertifikatlar", value: String(certificates.length), hint: "Barchasini ko'rish", tone: "violet" as const, icon: Award },
      { title: "Berilgan", value: String(certificates.length), hint: "Sertifikatlar ro'yxati", tone: "green" as const, icon: CheckCircle2 },
      { title: "Kutilmoqda", value: "0", hint: "Kutilayotganlar", tone: "orange" as const, icon: Clock3 },
    ];
  }, [certificates]);

  // Filter certificates
  const filteredCertificates = useMemo(() => {
    return certificates.filter((c) => {
      const matchesSearch = 
        c.student.toLowerCase().includes(searchTerm.toLowerCase()) ||
        c.email.toLowerCase().includes(searchTerm.toLowerCase());
      const matchesModule = 
        selectedModuleFilter === "all" || 
        c.module.toLowerCase() === selectedModuleFilter.toLowerCase();
      return matchesSearch && matchesModule;
    });
  }, [certificates, searchTerm, selectedModuleFilter]);

  // Selected student for preview
  const activeStudent = useMemo(() => {
    return students.find((s) => s.id === selectedStudentId);
  }, [students, selectedStudentId]);

  const handleFileUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;
    setUploading(true);
    const formData = new FormData();
    formData.append("file", file);
    formData.append("kind", "pdf");

    try {
      const res = await fetch("/api/media/upload", {
        method: "POST",
        body: formData,
      });
      const data = await res.json();
      if (data.ok && data.media) {
        setFileUrl(data.media.secure_url);
        toast.success("Sertifikat fayli muvaffaqiyatli yuklandi");
      } else {
        toast.error(data.error || "Yuklashda xatolik");
      }
    } catch (err) {
      toast.error("Tizimda xatolik yuz berdi");
    } finally {
      setUploading(false);
    }
  };

  const handleCreateCertificate = async () => {
    if (!selectedStudentId) {
      toast.error("Talabani tanlang");
      return;
    }
    if (!selectedModuleId) {
      toast.error("Modulni tanlang");
      return;
    }
    if (!fileUrl) {
      toast.error("Iltimos, sertifikat faylini yuklang yoki URL manzilini kiriting");
      return;
    }

    setIsSubmitting(true);
    try {
      const student = students.find((s) => s.id === selectedStudentId);
      const mod = modules.find((m) => m.id === selectedModuleId);
      const title = `${student?.name || "Talaba"} - ${mod?.title || "Modul"} sertifikati`;

      const result = await createCertificateAction({
        studentId: selectedStudentId,
        moduleId: selectedModuleId,
        title,
        certificateFileUrl: fileUrl,
      });

      if (result.ok && result.certificateId && result.qrDataUrl && result.verifyUrl) {
        setIssuedCertDetails({
          certificateId: result.certificateId,
          qrDataUrl: result.qrDataUrl,
          verifyUrl: result.verifyUrl,
        });
        toast.success("Sertifikat muvaffaqiyatli yaratildi");
        queryClient.invalidateQueries({ queryKey: ["certificates"] });
        setStep(3);
      } else {
        toast.error(result.error || "Sertifikat yaratishda xatolik yuz berdi");
      }
    } catch (err: any) {
      toast.error(err.message || "Tizim xatoligi");
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleResetWizard = () => {
    setStep(1);
    setFileUrl("");
    setIssuedCertDetails(null);
  };

  return (
    <>
      <PageHeader
        title="Sertifikatlar"
        current="Sertifikatlar"
        action={
          <div className="flex gap-1.5 rounded-2xl border border-border p-1 bg-white shadow-sm">
            <button
              onClick={() => setActiveTab("certificates")}
              className={cn(
                "rounded-xl px-4 py-1.5 text-xs font-bold transition duration-200",
                activeTab === "certificates" 
                  ? "bg-violet-600 text-white shadow font-black" 
                  : "text-slate-500 hover:bg-slate-100",
              )}
            >
              Sertifikatlar
            </button>
            <button
              onClick={() => setActiveTab("templates")}
              className={cn(
                "rounded-xl px-4 py-1.5 text-xs font-bold transition duration-200",
                activeTab === "templates" 
                  ? "bg-violet-600 text-white shadow font-black" 
                  : "text-slate-500 hover:bg-slate-100",
              )}
            >
              Shablonlar
            </button>
          </div>
        }
      />

      {activeTab === "certificates" ? (
        <div className="grid gap-6 xl:grid-cols-[1fr_400px] animate-in fade-in duration-200">
          <div className="flex min-w-0 flex-col gap-5">
            <div className="grid gap-4 grid-cols-3">
              {certStats.map((item) => (
                <StatCard key={item.title} item={item} />
              ))}
            </div>

            <Card className="border border-border bg-white rounded-2xl">
              <CardHeader className="border-b border-slate-100 flex flex-row items-center justify-between pb-3.5">
                <CardTitle className="text-sm font-black text-slate-900 uppercase tracking-wide flex items-center gap-2">
                  <Award className="size-4.5 text-violet-600 animate-pulse" />
                  Berilgan Sertifikatlar
                </CardTitle>
                <Button 
                  onClick={handleResetWizard} 
                  variant="secondary"
                  className="font-bold border border-slate-200 hover:bg-slate-100 text-slate-650 h-8.5 rounded-lg text-xs flex gap-1.5"
                >
                  <RefreshCw className="size-3.5" />
                  Wizardni tozalash
                </Button>
              </CardHeader>
              <CardContent className="p-0">
                <div className="grid gap-3 border-b border-slate-100 p-4.5 xl:grid-cols-[1fr_180px_180px] bg-slate-50/30">
                  <div className="relative">
                    <Search className="absolute left-3.5 top-1/2 size-4 -translate-y-1/2 text-slate-400" />
                    <Input 
                      placeholder="Talaba ismi yoki email orqali..." 
                      className="pl-10 h-10 rounded-xl border-slate-200 text-xs font-semibold focus:border-violet-500" 
                      value={searchTerm}
                      onChange={(e) => setSearchTerm(e.target.value)}
                    />
                  </div>
                  <Select
                    value={selectedModuleFilter}
                    onChange={(e) => setSelectedModuleFilter(e.target.value)}
                    className="h-10 rounded-xl border-slate-200 text-xs font-bold text-slate-500"
                  >
                    <option value="all">Barcha modullar</option>
                    {modules.map((m) => (
                      <option key={m.id} value={m.title}>
                        {m.title}
                      </option>
                    ))}
                  </Select>
                  <Button 
                    variant="secondary" 
                    onClick={() => { setSearchTerm(""); setSelectedModuleFilter("all"); }}
                    className="h-10 rounded-xl border border-slate-200 hover:bg-slate-100 text-slate-700 text-xs font-bold"
                  >
                    Filtrni tozalash
                  </Button>
                </div>

                <div className="overflow-x-auto edulab-scrollbar">
                  <table className="w-full min-w-[760px] text-sm">
                    <thead>
                      <tr className="border-b border-border/50 text-left text-[10px] font-black uppercase tracking-wider text-slate-400 bg-slate-50/50">
                        {["Talaba", "Modul", "Sana", "Holat", "Amallar"].map((head) => (
                          <th key={head} className="px-5 py-4">
                            {head}
                          </th>
                        ))}
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-slate-100">
                      {isCertsLoading ? (
                        <tr>
                          <td colSpan={5} className="text-center py-12 text-xs font-semibold text-slate-400">
                            Yuklanmoqda...
                          </td>
                        </tr>
                      ) : filteredCertificates.length > 0 ? (
                        filteredCertificates.map((certificate, index) => (
                          <tr key={`${certificate.id}-${index}`} className="group hover:bg-slate-50/30 transition duration-150">
                            <td className="px-5 py-4.5">
                              <div className="flex items-center gap-3">
                                <span className="flex size-10 shrink-0 items-center justify-center rounded-xl bg-gradient-to-br from-violet-50 to-indigo-100 text-sm font-black text-violet-600 border border-violet-100/50">
                                  {certificate.student[0].toUpperCase()}
                                </span>
                                <span>
                                  <span className="block font-bold text-slate-800 group-hover:text-violet-750 transition-colors">{certificate.student}</span>
                                  <span className="text-xs text-slate-400 font-semibold mt-0.5">{certificate.email}</span>
                                </span>
                              </div>
                            </td>
                            <td className="px-5 py-4.5 font-bold text-slate-700">{certificate.module}</td>
                            <td className="px-5 py-4.5 text-slate-500 font-semibold text-xs">{certificate.date}</td>
                            <td className="px-5 py-4.5">
                              <Badge variant={certificate.status === "Berilgan" ? "success" : "warning"}>
                                {certificate.status}
                              </Badge>
                            </td>
                            <td className="px-5 py-4.5">
                              <div className="flex gap-1.5">
                                <a href={certificate.qrCode} target="_blank" rel="noreferrer">
                                  <Button variant="secondary" size="icon" className="h-8 w-8 border border-slate-200 text-slate-500 hover:bg-slate-100 rounded-lg" title="Ko'rish"><Eye className="size-4" /></Button>
                                </a>
                                <Button
                                  variant="secondary"
                                  size="icon"
                                  className="h-8 w-8 border border-slate-200 text-slate-500 hover:bg-slate-100 rounded-lg"
                                  title="Yuklab olish"
                                  onClick={() => {
                                    const url = certificate.certificateUrl;
                                    if (!url) {
                                      toast.error("Sertifikat fayli mavjud emas. Avval faylni yuklang.");
                                      return;
                                    }
                                    // Use fetch + blob to force download for cross-origin files
                                    fetch(url)
                                      .then((res) => {
                                        if (!res.ok) throw new Error("Fayl yuklab olinmadi");
                                        return res.blob();
                                      })
                                      .then((blob) => {
                                        const blobUrl = URL.createObjectURL(blob);
                                        const a = document.createElement("a");
                                        a.href = blobUrl;
                                        a.download = `${certificate.id}.pdf`;
                                        document.body.appendChild(a);
                                        a.click();
                                        setTimeout(() => {
                                          document.body.removeChild(a);
                                          URL.revokeObjectURL(blobUrl);
                                        }, 100);
                                        toast.success("Sertifikat yuklab olindi");
                                      })
                                      .catch(() => {
                                        // Fallback: open in new tab
                                        window.open(url, "_blank");
                                        toast.info("Fayl yangi oynada ochildi");
                                      });
                                  }}
                                >
                                  <Download className="size-4" />
                                </Button>
                              </div>
                            </td>
                          </tr>
                        ))
                      ) : (
                        <tr>
                          <td colSpan={5} className="text-center py-16 text-xs font-semibold text-slate-400">
                            Sertifikatlar topilmadi.
                          </td>
                        </tr>
                      )}
                    </tbody>
                  </table>
                </div>

                <div className="border-t border-slate-100 bg-slate-50/20 px-5 py-3.5 text-xs font-bold text-slate-400">
                  Jami {filteredCertificates.length} ta sertifikat
                </div>
              </CardContent>
            </Card>
          </div>

          {/* Certificate Issuing Wizard Sidebar */}
          <Card className="sticky top-24 h-fit border border-border bg-white rounded-2xl shadow-soft">
            <CardHeader className="border-b border-slate-100 flex flex-row justify-between items-center pb-3.5">
              <CardTitle className="text-sm font-black text-slate-900 uppercase tracking-wide">Yangi sertifikat yaratish</CardTitle>
              {step > 1 && (
                <Button variant="ghost" size="icon" onClick={handleResetWizard} className="h-8 w-8 rounded-lg text-slate-400 hover:bg-slate-50">
                  <X className="size-4" />
                </Button>
              )}
            </CardHeader>
            <CardContent className="p-5">
              <div className="mb-6 grid grid-cols-3 gap-2.5">
                {["Talaba", "Yuklash", "QR kod"].map((label, index) => {
                  const current = index + 1;
                  return (
                    <button
                      key={label}
                      onClick={() => {
                        if (current < step) setStep(current);
                      }}
                      disabled={current > step && !issuedCertDetails}
                      className={cn(
                        "flex flex-col items-center gap-1.5 rounded-xl border border-slate-150 p-2.5 text-center transition duration-200",
                        step === current && "border-violet-200 bg-violet-50/40 shadow-sm",
                        step > current && "border-emerald-250 bg-emerald-50/40",
                      )}
                    >
                      <span
                        className={cn(
                          "flex size-7 items-center justify-center rounded-lg bg-slate-100 text-xs font-extrabold text-slate-500",
                          step === current && "bg-violet-600 text-white",
                          step > current && "bg-emerald-500 text-white",
                        )}
                      >
                        {step > current ? <Check className="size-3.5" /> : current}
                      </span>
                      <span className="text-[10px] font-bold text-slate-600 tracking-tight">{label}</span>
                    </button>
                  );
                })}
              </div>

              {step === 1 && (
                <div className="space-y-5">
                  <div className="grid gap-1.5">
                    <span className="text-xs font-bold text-slate-700">Talabani tanlang *</span>
                    {isStudentsLoading ? (
                      <div className="h-10.5 bg-slate-50 rounded-xl animate-pulse" />
                    ) : (
                      <Select 
                        className="w-full font-semibold text-slate-800" 
                        value={selectedStudentId} 
                        onChange={(e) => setSelectedStudentId(e.target.value)}
                      >
                        {students.map((student) => (
                          <option key={student.id} value={student.id}>{student.name}</option>
                        ))}
                      </Select>
                    )}
                  </div>

                  {activeStudent && (
                    <div className="flex items-center gap-3 rounded-xl border border-slate-150 bg-slate-50/50 p-3.5">
                      <span className="flex size-10 shrink-0 items-center justify-center rounded-xl bg-gradient-to-br from-violet-50 to-indigo-100 font-black text-sm text-violet-600 border border-violet-100/50">
                        {activeStudent.initials}
                      </span>
                      <div className="min-w-0 flex-1">
                        <p className="truncate text-xs font-extrabold text-slate-850 leading-snug">{activeStudent.name}</p>
                        <p className="truncate text-[10px] text-slate-400 font-bold mt-0.5">{activeStudent.phone}</p>
                      </div>
                    </div>
                  )}

                  <div className="grid gap-1.5">
                    <span className="text-xs font-bold text-slate-700">Modulni tanlang *</span>
                    {isModulesLoading ? (
                      <div className="h-10.5 bg-slate-50 rounded-xl animate-pulse" />
                    ) : (
                      <Select 
                        className="w-full font-semibold text-slate-800" 
                        value={selectedModuleId} 
                        onChange={(e) => setSelectedModuleId(e.target.value)}
                      >
                        {modules.map((m) => (
                          <option key={m.id} value={m.id}>{m.title}</option>
                        ))}
                      </Select>
                    )}
                  </div>

                  <div className="rounded-xl border border-violet-105 bg-violet-50/50 p-4 text-xs font-semibold text-violet-850 leading-relaxed">
                    Talaba va modul tanlangandan so'ng, keyingi qadamda sertifikat PDF/Image faylini yuklaysiz.
                  </div>

                  <div className="flex justify-end pt-3">
                    <Button 
                      onClick={() => setStep(2)} 
                      disabled={!selectedStudentId || !selectedModuleId}
                      className="flex items-center gap-2 bg-violet-600 hover:bg-violet-700 text-white rounded-xl text-xs font-bold h-10 px-5"
                    >
                      Keyingi
                      <ArrowRight className="size-4" />
                    </Button>
                  </div>
                </div>
              )}

              {step === 2 && (
                <div className="space-y-5">
                  <div className="rounded-2xl border border-dashed border-violet-200 bg-violet-50/20 p-8 text-center relative cursor-pointer hover:bg-violet-50/40 transition">
                    <input 
                      type="file" 
                      onChange={handleFileUpload} 
                      className="absolute inset-0 opacity-0 cursor-pointer" 
                      accept="application/pdf,image/*" 
                    />
                    <Upload className="mx-auto size-9 text-violet-600 animate-bounce" />
                    <p className="mt-3 text-xs font-extrabold text-slate-700">Sertifikat faylini yuklang</p>
                    <p className="mt-1 text-[10px] text-slate-400 font-semibold">PDF, PNG yoki JPG. Cloudinary orqali yuklanadi.</p>
                  </div>

                  {uploading && (
                    <div className="flex items-center justify-center gap-2 py-2 text-xs font-bold text-slate-455 animate-pulse">
                      <Loader2 className="size-4 animate-spin text-violet-600" />
                      Fayl serverga yuklanmoqda...
                    </div>
                  )}

                  <div className="grid gap-1.5">
                    <span className="text-xs font-bold text-slate-700">Fayl URL manzili</span>
                    <Input 
                      placeholder="https://cloudinary.com/..." 
                      value={fileUrl}
                      onChange={(e) => setFileUrl(e.target.value)}
                      className="h-10 rounded-xl border-slate-200 font-semibold text-xs"
                    />
                  </div>

                  <div className="flex justify-between pt-3 border-t border-slate-100">
                    <Button variant="secondary" onClick={() => setStep(1)} className="flex items-center gap-2 border border-slate-200 rounded-xl text-xs font-bold h-10 px-4">
                      <ArrowLeft className="size-4" />
                      Oldingi
                    </Button>
                    <Button 
                      onClick={handleCreateCertificate} 
                      disabled={!fileUrl || isSubmitting || uploading}
                      className="flex items-center gap-2 bg-violet-600 hover:bg-violet-700 text-white rounded-xl text-xs font-bold h-10 px-4"
                    >
                      {isSubmitting && <Loader2 className="size-4 animate-spin mr-1" />}
                      Sertifikat yaratish
                      <Check className="size-4" />
                    </Button>
                  </div>
                </div>
              )}

              {step === 3 && issuedCertDetails && (
                <div className="space-y-5 animate-in zoom-in-95 duration-200">
                  <div className="flex flex-col items-center justify-center p-3 border border-slate-150 bg-slate-50/50 rounded-2xl">
                    <img 
                      src={issuedCertDetails.qrDataUrl} 
                      alt="Verification QR Code" 
                      className="w-36 h-36 border border-slate-200 rounded-xl shadow-sm bg-white"
                    />
                    <p className="text-[10px] font-black text-slate-400 mt-2.5 uppercase tracking-wider">VERIFIKATSIYA QR-KODI</p>
                  </div>

                  <div className="rounded-xl border border-slate-150 p-4 text-xs font-semibold space-y-2 text-slate-700 bg-white">
                    <p className="flex justify-between">
                      <span className="text-slate-400">Sertifikat ID:</span>
                      <span className="font-extrabold text-slate-800">{issuedCertDetails.certificateId}</span>
                    </p>
                    <p className="flex justify-between">
                      <span className="text-slate-400">Havola:</span>
                      <a 
                        href={issuedCertDetails.verifyUrl} 
                        target="_blank" 
                        rel="noreferrer"
                        className="text-violet-600 font-extrabold hover:underline truncate max-w-[160px]"
                      >
                        Tekshirish havolasi
                      </a>
                    </p>
                  </div>

                  <div className="rounded-xl border border-emerald-100 bg-emerald-50/40 p-4 text-center">
                    <ShieldCheck className="mx-auto size-9 text-emerald-600 animate-pulse" />
                    <p className="mt-2 text-xs font-black text-emerald-700 uppercase tracking-wide">Sertifikat Tasdiqlandi</p>
                    <p className="mt-1 text-[10px] font-semibold text-emerald-700/80 leading-relaxed">QR-kod orqali o'quvchilar va ish beruvchilar tekshirishlari mumkin.</p>
                  </div>

                  <Button onClick={handleResetWizard} className="w-full font-bold h-11 bg-violet-600 text-white hover:bg-violet-700 rounded-xl text-xs">
                    Yangi sertifikat yaratish
                  </Button>
                </div>
              )}
            </CardContent>
          </Card>
        </div>
      ) : (
        <CertificateTemplates />
      )}
    </>
  );
}

const templates = [
  { id: 1, name: "Klassik Sertifikat", desc: "An'anaviy gold dizayn", color: "from-amber-600 to-yellow-500", icon: "🏅", default: true },
  { id: 2, name: "Zamonaviy Gradient", desc: "Gradient rang sxemasi", color: "from-violet-600 to-indigo-500", icon: "✨", default: false },
  { id: 3, name: "Minimal Oq", desc: "Oddiy va toza dizayn", color: "from-slate-600 to-slate-400", icon: "📄", default: false },
  { id: 4, name: "Premium Qora", desc: "To'q rangdagi elegantlik", color: "from-slate-900 to-slate-700", icon: "🎖️", default: false },
  { id: 5, name: "Ilmiy Uslub", desc: "Akademik sertifikat", color: "from-emerald-600 to-teal-500", icon: "🔬", default: false },
  { id: 6, name: "Kreativ Rang", desc: "Yorqin va zamonaviy", color: "from-pink-500 to-orange-400", icon: "🎨", default: false },
];

function CertificateTemplates() {
  const [tmplList, setTmplList] = useState(templates);

  const handleMakeDefault = (id: number) => {
    setTmplList((list) => 
      list.map((t) => ({
        ...t,
        default: t.id === id,
      }))
    );
    toast.success("Tanlangan shablon standart sifatida belgilandi");
  };

  return (
    <div className="space-y-6 animate-in fade-in duration-200">
      <Card className="shadow-soft border border-border bg-white rounded-2xl">
        <CardHeader className="border-b border-slate-100 flex flex-row items-center justify-between pb-3.5">
          <div>
            <CardTitle className="text-sm font-black text-slate-900 uppercase tracking-wide flex items-center gap-2">
              <FileUp className="size-4.5 text-violet-600 animate-bounce" />
              Sertifikat Shablonlari
            </CardTitle>
            <p className="text-xs font-semibold text-slate-400 mt-0.5">Talabalar uchun sertifikat dizayn shablonlarini boshqarish</p>
          </div>
          <Button 
            onClick={() => toast.info("Shablon yuklash uchun dizayn faylini tanlang (Maksimum 10MB)")}
            className="bg-violet-600 hover:bg-violet-700 text-white rounded-xl text-xs font-bold h-9 px-4 flex gap-1.5"
          >
            <Upload className="size-4" />
            Yangi shablon
          </Button>
        </CardHeader>
        <CardContent className="p-6">
          <div className="grid gap-5 md:grid-cols-2 xl:grid-cols-3">
            {tmplList.map((tmpl) => (
              <div
                key={tmpl.id}
                className="group relative overflow-hidden rounded-2xl border border-slate-150 transition hover:border-violet-300 hover:shadow-md bg-white"
              >
                {/* Visual preview */}
                <div className={`relative h-40 bg-gradient-to-br ${tmpl.color} flex items-center justify-center`}>
                  <span className="text-5.5 drop-shadow-md select-none">{tmpl.icon}</span>
                  {tmpl.default && (
                    <span className="absolute top-3 right-3 rounded-lg bg-white/20 backdrop-blur-sm px-2.5 py-1 text-[10px] font-black uppercase text-white tracking-wider">
                      Standart
                    </span>
                  )}
                  <div className="absolute inset-0 bg-black/0 group-hover:bg-black/10 transition" />
                </div>

                {/* Info */}
                <div className="p-4">
                  <h3 className="text-sm font-extrabold text-slate-800 leading-snug group-hover:text-violet-750 transition-colors">{tmpl.name}</h3>
                  <p className="text-xs text-slate-400 font-semibold mt-1">{tmpl.desc}</p>
                  <div className="mt-4 flex gap-2">
                    <Button 
                      size="sm" 
                      variant="secondary" 
                      className="flex-1 font-bold border border-slate-200 hover:bg-slate-50 text-slate-700 rounded-lg text-xs h-8.5"
                      onClick={() => toast.info(`Shablon: ${tmpl.name} predprosmotri`)}
                    >
                      <Eye className="size-3.5 mr-1 text-slate-400" />
                      Ko'rish
                    </Button>
                    {!tmpl.default ? (
                      <Button 
                        size="sm" 
                        className="flex-1 font-bold bg-violet-600 text-white hover:bg-violet-700 rounded-lg text-xs h-8.5" 
                        onClick={() => handleMakeDefault(tmpl.id)}
                      >
                        <Check className="size-3.5 mr-1" />
                        Standart qilish
                      </Button>
                    ) : (
                      <Button size="sm" variant="secondary" className="flex-1 text-emerald-605 bg-emerald-50 hover:bg-emerald-50 font-bold border border-emerald-100 rounded-lg text-xs h-8.5" disabled>
                        <CheckCircle2 className="size-3.5 mr-1 text-emerald-500" />
                        Faol
                      </Button>
                    )}
                  </div>
                </div>
              </div>
            ))}
          </div>

          <div 
            onClick={() => toast.info("Shablon yuklash oynasi")}
            className="mt-6 rounded-2xl border border-dashed border-slate-200 p-8 text-center hover:border-violet-300 hover:bg-slate-50/50 transition cursor-pointer"
          >
            <Upload className="mx-auto size-8 text-slate-350 mb-3" />
            <p className="text-xs font-extrabold text-slate-650">Yangi shablon yuklash</p>
            <p className="text-[10px] text-slate-400 font-semibold mt-1">PNG, PDF yoki SVG formatida, maksimum 10MB</p>
          </div>
        </CardContent>
      </Card>
    </div>
  );
}
