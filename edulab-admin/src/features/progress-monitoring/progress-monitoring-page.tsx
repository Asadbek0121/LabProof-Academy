"use client";

import { useState } from "react";
import { PageHeader } from "@/components/layout/page-header";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input, Select } from "@/components/ui/input";
import { Badge } from "@/components/ui/badge";
import { useStudents, useModules, useTopics } from "@/hooks/use-admin-data";
import { createClient } from "@/lib/supabase/client";
import { useQuery } from "@tanstack/react-query";
import { Award, BookOpen, CheckCircle, FileText, Search, Play, Users, X } from "lucide-react";

export function ProgressMonitoringPage() {
  const { data: students, isLoading: studentsLoading } = useStudents();
  const { data: modules } = useModules();

  const [selectedStudentId, setSelectedStudentId] = useState<string | null>(null);
  const [searchTerm, setSearchTerm] = useState("");
  const [selectedModuleId, setSelectedModuleId] = useState<string>("all");

  const supabase = createClient();

  // Selected student details
  const selectedStudent = students?.find((s) => s.id === selectedStudentId);

  // Fetch detailed progress for selected student
  const { data: progressDetails } = useQuery({
    queryKey: ["student-detailed-progress", selectedStudentId],
    queryFn: async () => {
      if (!selectedStudentId) return [];
      const { data, error } = await supabase
        .from("topic_progress")
        .select(`
          id,
          pdf_completed,
          video_completed,
          quiz_completed,
          quiz_score,
          topics (
            id,
            title,
            module_id,
            modules (
              title
            )
          )
        `)
        .eq("user_id", selectedStudentId);
      if (error) return [];
      return data || [];
    },
    enabled: !!selectedStudentId,
  });

  // Filter students based on search term
  const filteredStudents = students?.filter((student) => {
    const matchesSearch =
      student.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
      student.phone.includes(searchTerm);
    return matchesSearch;
  });

  return (
    <>
      <PageHeader title="Progress Monitoring" current="Talabalar o'zlashtirishi" />

      <div className="grid gap-6 xl:grid-cols-[400px_1fr]">
        {/* Student list */}
        <Card className="shadow-soft h-[720px] flex flex-col">
          <CardHeader className="pb-3 border-b border-border">
            <CardTitle className="text-lg font-extrabold flex items-center gap-2">
              <Users className="size-5 text-primary" />
              Talabalar
            </CardTitle>
            <div className="relative mt-2">
              <Search className="absolute left-3 top-1/2 size-4 -translate-y-1/2 text-slate-400" />
              <Input
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                placeholder="Ism yoki telefon orqali..."
                className="pl-10"
              />
            </div>
          </CardHeader>
          <CardContent className="flex-1 overflow-y-auto p-3 edulab-scrollbar">
            {studentsLoading ? (
              <div className="text-center py-8 text-sm font-semibold text-slate-400">Yuklanmoqda...</div>
            ) : filteredStudents && filteredStudents.length > 0 ? (
              <div className="flex flex-col gap-2">
                {filteredStudents.map((student) => (
                  <button
                    key={student.id}
                    onClick={() => setSelectedStudentId(student.id)}
                    className={`flex w-full items-center justify-between rounded-2xl p-3 text-left transition hover:bg-slate-50 ${
                      selectedStudentId === student.id ? "bg-blue-50 border border-blue-100" : ""
                    }`}
                  >
                    <div className="flex items-center gap-3">
                      <span className="flex size-10 items-center justify-center rounded-full bg-blue-100 text-sm font-bold text-blue-600">
                        {student.initials}
                      </span>
                      <div>
                        <p className="text-sm font-bold text-slate-800">{student.name}</p>
                        <p className="text-xs text-slate-500">{student.phone || "Telefon yo'q"}</p>
                      </div>
                    </div>
                    <div className="text-right">
                      <p className="text-sm font-extrabold text-blue-600">{student.progress}%</p>
                      <p className="text-[10px] font-semibold text-slate-400">Progress</p>
                    </div>
                  </button>
                ))}
              </div>
            ) : (
              <div className="text-center py-8 text-sm font-semibold text-slate-400">
                Talabalar topilmadi
              </div>
            )}
          </CardContent>
        </Card>

        {/* Detailed stats */}
        <Card className="shadow-soft flex flex-col min-h-[720px]">
          {selectedStudent ? (
            <>
              <CardHeader className="border-b border-border flex flex-row items-center justify-between">
                <div>
                  <CardTitle className="text-xl font-extrabold">{selectedStudent.name}</CardTitle>
                  <p className="text-xs font-semibold text-slate-500">
                    O'rtacha ball: <span className="font-extrabold text-orange-600">{selectedStudent.averageScore}%</span> | Ro'yxatdan o'tgan: {selectedStudent.joinedAt}
                  </p>
                </div>
                <Button variant="ghost" size="icon" onClick={() => setSelectedStudentId(null)}>
                  <X className="size-5" />
                </Button>
              </CardHeader>
              <CardContent className="p-6 flex-1">
                {/* Stats widgets */}
                <div className="grid gap-4 md:grid-cols-3 mb-6">
                  <div className="rounded-2xl border border-border bg-slate-50/50 p-4">
                    <div className="flex items-center justify-between">
                      <span className="text-xs font-bold text-slate-500 uppercase">Jami progress</span>
                      <BookOpen className="size-4 text-blue-600" />
                    </div>
                    <p className="mt-2 text-2xl font-extrabold text-slate-900">{selectedStudent.progress}%</p>
                  </div>
                  <div className="rounded-2xl border border-border bg-slate-50/50 p-4">
                    <div className="flex items-center justify-between">
                      <span className="text-xs font-bold text-slate-500 uppercase">O'rtacha ball</span>
                      <Award className="size-4 text-orange-500" />
                    </div>
                    <p className="mt-2 text-2xl font-extrabold text-orange-600">{selectedStudent.averageScore}%</p>
                  </div>
                  <div className="rounded-2xl border border-border bg-slate-50/50 p-4">
                    <div className="flex items-center justify-between">
                      <span className="text-xs font-bold text-slate-500 uppercase">Tizim holati</span>
                      <CheckCircle className="size-4 text-emerald-500" />
                    </div>
                    <p className="mt-2 text-2xl font-extrabold text-emerald-600">{selectedStudent.status}</p>
                  </div>
                </div>

                {/* Module Filter */}
                <div className="flex items-center gap-3 mb-4">
                  <span className="text-sm font-bold text-slate-600">Modul filteri:</span>
                  <Select
                    className="max-w-[280px]"
                    value={selectedModuleId}
                    onChange={(e) => setSelectedModuleId(e.target.value)}
                  >
                    <option value="all">Barcha modullar</option>
                    {modules?.map((m) => (
                      <option key={m.id} value={m.id}>
                        {m.title}
                      </option>
                    ))}
                  </Select>
                </div>

                {/* Detailed Topics Table */}
                <div className="overflow-x-auto edulab-scrollbar rounded-2xl border border-border">
                  <table className="w-full text-sm">
                    <thead className="bg-slate-50 text-left text-xs font-bold uppercase text-slate-500">
                      <tr>
                        <th className="px-5 py-4">Mavzu</th>
                        <th className="px-5 py-4">Modul</th>
                        <th className="px-5 py-4 text-center">PDF/Text</th>
                        <th className="px-5 py-4 text-center">Video</th>
                        <th className="px-5 py-4 text-center">Mavzu Testi</th>
                        <th className="px-5 py-4 text-center">Test Balli</th>
                      </tr>
                    </thead>
                    <tbody>
                      {progressDetails && progressDetails.length > 0 ? (
                        progressDetails
                          .filter((p: any) => selectedModuleId === "all" || p.topics?.module_id === selectedModuleId)
                          .map((p: any) => (
                            <tr key={p.id} className="border-t border-border hover:bg-slate-50/50">
                              <td className="px-5 py-4 font-bold text-slate-800">{p.topics?.title || "Noma'lum"}</td>
                              <td className="px-5 py-4 text-slate-500">{p.topics?.modules?.title || "Modulsiz"}</td>
                              <td className="px-5 py-4 text-center">
                                <Badge variant={p.pdf_completed ? "success" : "slate"}>
                                  {p.pdf_completed ? "O'qilgan" : "O'qilmagan"}
                                </Badge>
                              </td>
                              <td className="px-5 py-4 text-center">
                                <Badge variant={p.video_completed ? "success" : "slate"}>
                                  {p.video_completed ? "Ko'rilgan" : "Ko'rilmagan"}
                                </Badge>
                              </td>
                              <td className="px-5 py-4 text-center">
                                <Badge variant={p.quiz_completed ? "success" : "slate"}>
                                  {p.quiz_completed ? "Yechilgan" : "Yechilmagan"}
                                </Badge>
                              </td>
                              <td className="px-5 py-4 text-center font-extrabold text-slate-700">
                                {p.quiz_score !== null ? `${p.quiz_score}%` : "-"}
                              </td>
                            </tr>
                          ))
                      ) : (
                        <tr>
                          <td colSpan={6} className="text-center py-8 text-sm font-semibold text-slate-400">
                            Foydalanuvchi hozircha biror darsni boshlamagan.
                          </td>
                        </tr>
                      )}
                    </tbody>
                  </table>
                </div>
              </CardContent>
            </>
          ) : (
            <div className="flex-1 flex flex-col items-center justify-center text-slate-400 p-8">
              <BookOpen className="size-12 mb-3 text-slate-300" />
              <p className="text-lg font-bold">Talabani tanlang</p>
              <p className="text-sm font-semibold text-slate-400 mt-1">
                Progress va darslarni o'zlashtirish tahlilini ko'rish uchun chap tomondan talabani tanlang.
              </p>
            </div>
          )}
        </Card>
      </div>
    </>
  );
}
