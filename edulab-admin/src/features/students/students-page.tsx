"use client";

import { useState } from "react";
import { cn } from "@/lib/utils";
import { Eye, Filter, MoreVertical, Pencil, Search, Trash2, X, GraduationCap, Phone, Mail, Calendar, MapPin, BadgePercent, Activity, CheckSquare } from "lucide-react";
import { PageHeader } from "@/components/layout/page-header";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Input, Select } from "@/components/ui/input";
import { Skeleton } from "@/components/ui/skeleton";
import dynamic from "next/dynamic";

const DonutChart = dynamic(
  () => import("@/components/charts/donut-chart").then((mod) => mod.DonutChart),
  { ssr: false, loading: () => <div className="h-56 bg-slate-50/50 rounded-xl animate-pulse" /> }
);

import { useStudentStats, useStudents, useModules } from "@/hooks/use-admin-data";
import { createClient } from "@/lib/supabase/client";
import { useMutation, useQueryClient } from "@tanstack/react-query";

export function StudentsPage() {
  const queryClient = useQueryClient();
  const supabase = createClient();

  const stats = useStudentStats();
  const studentsQuery = useStudents();
  const modulesQuery = useModules();

  // Search & Filter State
  const [searchTerm, setSearchTerm] = useState("");
  const [selectedModule, setSelectedModule] = useState("all");
  const [selectedStatus, setSelectedStatus] = useState("all");
  const [sortField, setSortField] = useState<"name" | "progress" | "averageScore" | "joinedAt">("name");
  const [sortOrder, setSortOrder] = useState<"asc" | "desc">("asc");
  const [currentPage, setCurrentPage] = useState(1);
  const [itemsPerPage, setItemsPerPage] = useState(20);

  // Selected student for View/Edit Modals
  const [viewStudent, setViewStudent] = useState<any | null>(null);
  const [editStudent, setEditStudent] = useState<any | null>(null);

  // Edit Form Fields
  const [formName, setFormName] = useState("");
  const [formPhone, setFormPhone] = useState("");
  const [formGender, setFormGender] = useState("");
  const [formAge, setFormAge] = useState<number | "">("");
  const [formRegion, setFormRegion] = useState("");
  const [formDistrict, setFormDistrict] = useState("");

  // Edit Mutation
  const updateStudentMutation = useMutation({
    mutationFn: async ({ id, full_name, phone, gender, age, region, district }: any) => {
      const { error } = await supabase
        .from("profiles")
        .update({
          full_name,
          phone,
          gender,
          age: age ? Number(age) : null,
          region,
          district,
          updated_at: new Date().toISOString()
        })
        .eq("id", id);
      if (error) throw error;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["students"] });
      queryClient.invalidateQueries({ queryKey: ["student-stats"] });
      setEditStudent(null);
    }
  });

  // Delete Mutation (demote to student or delete from DB. Let's do delete for admin capability)
  const deleteStudentMutation = useMutation({
    mutationFn: async (id: string) => {
      const { error } = await supabase.from("profiles").delete().eq("id", id);
      if (error) throw error;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["students"] });
      queryClient.invalidateQueries({ queryKey: ["student-stats"] });
    }
  });

  const handleOpenEdit = (student: any) => {
    setEditStudent(student);
    setFormName(student.name || "");
    setFormPhone(student.phone || "");
    setFormGender(student.gender || "");
    setFormAge(student.age || "");
    setFormRegion(student.region || "");
    setFormDistrict(student.district || "");
  };

  const handleSaveEdit = () => {
    if (editStudent) {
      updateStudentMutation.mutate({
        id: editStudent.id,
        full_name: formName,
        phone: formPhone,
        gender: formGender,
        age: formAge,
        region: formRegion,
        district: formDistrict
      });
    }
  };

  const handleDelete = (student: any) => {
    if (confirm(`Talaba "${student.name}" tizimdan butunlay o'chirilsinmi? Ushbu amal ortga qaytarilmaydi.`)) {
      deleteStudentMutation.mutate(student.id);
    }
  };

  // 1. Filter students
  const filteredStudents = studentsQuery.data?.filter((s: any) => {
    const matchesSearch =
      s.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
      s.email.toLowerCase().includes(searchTerm.toLowerCase()) ||
      s.phone.includes(searchTerm);

    const matchesStatus =
      selectedStatus === "all" ||
      (selectedStatus === "faol" && s.status === "Faol") ||
      (selectedStatus === "nofaol" && s.status === "Nofaol");

    // If filtering by specific module, check if student has progress or results in it
    // Note: useStudents returns modules count. Let's filter by completed modules > 0 if yes
    const matchesModule =
      selectedModule === "all" ||
      (selectedModule === "has_progress" && s.progress > 0) ||
      (selectedModule === "completed" && s.modules > 0);

    return matchesSearch && matchesStatus && matchesModule;
  }) || [];

  // 2. Sort students
  const sortedStudents = [...filteredStudents].sort((a: any, b: any) => {
    let aVal = a[sortField];
    let bVal = b[sortField];

    if (sortField === "joinedAt") {
      // Parse DD.MM.YYYY
      const parseDate = (dStr: string) => {
        const parts = dStr.split(".");
        return new Date(Number(parts[2]), Number(parts[1]) - 1, Number(parts[0])).getTime();
      };
      aVal = parseDate(a.joinedAt);
      bVal = parseDate(b.joinedAt);
    }

    if (typeof aVal === "string") {
      return sortOrder === "asc" ? aVal.localeCompare(bVal) : bVal.localeCompare(aVal);
    } else {
      return sortOrder === "asc" ? aVal - bVal : bVal - aVal;
    }
  });

  // 3. Paginate students
  const totalItems = sortedStudents.length;
  const totalPages = Math.ceil(totalItems / itemsPerPage) || 1;
  const indexOfLastItem = currentPage * itemsPerPage;
  const indexOfFirstItem = indexOfLastItem - itemsPerPage;
  const currentStudents = sortedStudents.slice(indexOfFirstItem, indexOfLastItem);

  // Dynamic Chart Calculations
  const activeCount = filteredStudents.filter((s: any) => s.status === "Faol").length;
  const inactiveCount = filteredStudents.length - activeCount;
  const donutData = [
    { name: "Faol talabalar", value: activeCount, color: "#10B981" },
    { name: "Nofaol talabalar", value: inactiveCount, color: "#94A3B8" },
  ];

  const renderSortHeader = (label: string, field: typeof sortField) => {
    const isSorted = sortField === field;
    return (
      <th
        className="px-6 py-4 cursor-pointer hover:bg-slate-100/50 hover:text-slate-900 transition-colors select-none group whitespace-nowrap text-slate-400 font-bold uppercase tracking-wider text-[11px]"
        onClick={() => {
          setSortField(field);
          setSortOrder(sortField === field && sortOrder === "asc" ? "desc" : "asc");
        }}
      >
        <div className="flex items-center gap-1">
          <span>{label}</span>
          <span className={cn(
            "transition-opacity duration-200 text-[10px]",
            isSorted ? "opacity-100 text-violet-600 font-extrabold" : "opacity-0 group-hover:opacity-60 text-slate-400"
          )}>
            {isSorted ? (sortOrder === "asc" ? "▲" : "▼") : "⇅"}
          </span>
        </div>
      </th>
    );
  };

  return (
    <>
      <PageHeader title="Talabalar" current="Talabalar boshqaruvi" />
      <div className="grid gap-6 xl:grid-cols-[1fr_360px] animate-in fade-in duration-200">
        <div className="flex min-w-0 flex-col gap-6">
          {/* Statistics widgets */}
          <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
            {stats.isLoading ? (
              Array.from({ length: 4 }).map((_, index) => (
                <Skeleton key={index} className="h-[105px] w-full rounded-2xl" />
              ))
            ) : (
              stats.data?.map((item) => {
                const Icon = item.icon;
                const isBlue = item.tone === "blue";
                const isGreen = item.tone === "green";
                const isOrange = item.tone === "orange";
                const isViolet = item.tone === "violet";

                return (
                  <Card 
                    key={item.title} 
                    className="p-5 transition-all duration-300 hover:-translate-y-0.5 hover:shadow-soft bg-white border border-border/80 rounded-2xl flex items-center gap-4"
                  >
                    <div className={cn(
                      "flex size-12 shrink-0 items-center justify-center rounded-xl border shadow-sm",
                      isBlue && "bg-indigo-50 text-indigo-600 border-indigo-100/50",
                      isGreen && "bg-emerald-50 text-emerald-600 border-emerald-100/50",
                      isOrange && "bg-amber-50 text-amber-600 border-amber-100/50",
                      isViolet && "bg-violet-50 text-violet-600 border-violet-100/50"
                    )}>
                      <Icon className="size-5" />
                    </div>
                    <div className="min-w-0 flex-1 ml-3.5">
                      <p className="text-[11px] font-bold text-slate-400 uppercase tracking-wider truncate">
                        {item.title}
                      </p>
                      <p className="text-2xl font-black text-slate-900 mt-0.5 leading-none">
                        {item.value}
                      </p>
                      <div className="mt-2">
                        <span className={cn(
                          "inline-flex items-center gap-0.5 text-[9px] font-extrabold px-2 py-0.5 rounded-lg border shadow-sm",
                          isBlue && "bg-indigo-50/50 border-indigo-100/30 text-indigo-600",
                          isGreen && "bg-emerald-50/50 border-emerald-100/30 text-emerald-600",
                          isOrange && "bg-amber-50/50 border-amber-100/30 text-amber-600",
                          isViolet && "bg-violet-50/50 border-violet-100/30 text-violet-600"
                        )}>
                          {item.hint}
                        </span>
                      </div>
                    </div>
                  </Card>
                );
              })
            )}
          </div>

          {/* Table management card */}
          <Card className="shadow-soft border border-border/80 rounded-2xl bg-white overflow-hidden">
            <CardHeader className="border-b border-border/50 bg-slate-50/10 px-6 py-5">
              <div className="grid w-full gap-4 xl:grid-cols-[1fr_180px_180px_110px]">
                <div className="relative">
                  <Search className="absolute left-4 top-1/2 size-4 -translate-y-1/2 text-slate-400 pointer-events-none" />
                  <Input
                    value={searchTerm}
                    onChange={(e) => { setSearchTerm(e.target.value); setCurrentPage(1); }}
                    placeholder="Ism, telefon yoki email..."
                    className="pl-11 border-border/80 focus:border-violet-500 focus:ring-violet-500/10 h-11 rounded-xl text-xs font-semibold placeholder:text-slate-400"
                  />
                </div>
                <Select 
                  value={selectedModule} 
                  onChange={(e) => { setSelectedModule(e.target.value); setCurrentPage(1); }}
                  className="border-border/80 focus:border-violet-500 focus:ring-violet-500/10 h-11 rounded-xl text-xs font-bold text-slate-700 bg-white"
                >
                  <option value="all">Barcha darslar</option>
                  <option value="has_progress">Progressi borlar</option>
                  <option value="completed">Modul yakunlaganlar</option>
                </Select>
                <Select 
                  value={selectedStatus} 
                  onChange={(e) => { setSelectedStatus(e.target.value); setCurrentPage(1); }}
                  className="border-border/80 focus:border-violet-500 focus:ring-violet-500/10 h-11 rounded-xl text-xs font-bold text-slate-700 bg-white"
                >
                  <option value="all">Barcha statuslar</option>
                  <option value="faol">Faol (Active)</option>
                  <option value="nofaol">Nofaol (Inactive)</option>
                </Select>
                <Button 
                  variant="secondary" 
                  onClick={() => { setSearchTerm(""); setSelectedModule("all"); setSelectedStatus("all"); setCurrentPage(1); }}
                  className="h-11 rounded-xl border border-slate-200 text-slate-600 bg-white hover:bg-slate-50 text-xs font-bold shadow-sm"
                >
                  Tozalash
                </Button>
              </div>
            </CardHeader>
            <CardContent className="p-0">
              <div className="overflow-x-auto edulab-scrollbar">
                <table className="w-full min-w-[900px] text-sm">
                  <thead className="bg-slate-50/50 text-left">
                    <tr>
                      {renderSortHeader("Talaba", "name")}
                      <th className="px-6 py-4 text-slate-400 font-bold uppercase tracking-wider text-[11px] whitespace-nowrap">Telefon</th>
                      <th className="px-6 py-4 text-slate-400 font-bold uppercase tracking-wider text-[11px] whitespace-nowrap">Modullar</th>
                      {renderSortHeader("Progress", "progress")}
                      {renderSortHeader("O'rtacha ball", "averageScore")}
                      <th className="px-6 py-4 text-slate-400 font-bold uppercase tracking-wider text-[11px] whitespace-nowrap">Holat</th>
                      {renderSortHeader("Ro'yxatdan o'tgan", "joinedAt")}
                      <th className="px-6 py-4 text-center text-slate-400 font-bold uppercase tracking-wider text-[11px] whitespace-nowrap">Amallar</th>
                    </tr>
                  </thead>
                  <tbody>
                    {studentsQuery.isLoading ? (
                      Array.from({ length: 5 }).map((_, index) => (
                        <tr key={index} className="border-t border-border/50">
                          <td colSpan={8} className="px-6 py-5">
                            <Skeleton className="h-6 w-full rounded-lg" />
                          </td>
                        </tr>
                      ))
                    ) : currentStudents.length > 0 ? (
                      currentStudents.map((student: any) => (
                        <tr key={student.id} className="border-t border-border/50 transition hover:bg-slate-50/50">
                          <td className="px-6 py-4">
                            <div className="flex items-center gap-3">
                              <span className="flex size-10 shrink-0 items-center justify-center rounded-xl bg-gradient-to-br from-violet-50 to-indigo-50 border border-violet-100/50 text-sm font-black text-violet-700 shadow-sm">
                                {student.initials}
                              </span>
                              <div className="min-w-0">
                                <span className="block font-extrabold text-slate-900 truncate max-w-[180px] leading-snug">{student.name}</span>
                                <span className="text-slate-400 text-[11px] font-semibold truncate block max-w-[180px] mt-0.5">{student.email}</span>
                              </div>
                            </div>
                          </td>
                          <td className="px-6 py-4 font-semibold text-slate-700 text-xs whitespace-nowrap">{student.phone || "-"}</td>
                          <td className="px-6 py-4 font-extrabold text-slate-600 text-xs">{student.modules} ta</td>
                          <td className="px-6 py-4">
                            <div className="flex items-center gap-2.5">
                              <span className="font-extrabold text-slate-900 text-xs min-w-[28px]">{student.progress}%</span>
                              <div className="h-1.5 w-18 overflow-hidden rounded-full bg-slate-100 shrink-0 relative">
                                <div
                                  className="absolute left-0 top-0 h-full bg-gradient-to-r from-emerald-400 to-emerald-500 rounded-full"
                                  style={{ width: `${student.progress}%` }}
                                />
                              </div>
                            </div>
                          </td>
                          <td className="px-6 py-4 font-extrabold text-violet-600 text-xs">{student.averageScore}%</td>
                          <td className="px-6 py-4">
                            <Badge 
                              variant={student.status === "Faol" ? "success" : "slate"} 
                              className="gap-1.5 px-2.5 py-0.5 text-[10px] font-extrabold rounded-lg select-none shrink-0"
                            >
                              <span className={cn(
                                "size-1.5 rounded-full",
                                student.status === "Faol" ? "bg-emerald-500 animate-pulse" : "bg-slate-400"
                              )} />
                              {student.status}
                            </Badge>
                          </td>
                          <td className="px-6 py-4 text-slate-500 text-xs font-medium whitespace-nowrap">{student.joinedAt}</td>
                          <td className="px-6 py-4">
                            <div className="flex justify-center gap-1.5">
                              <Button 
                                variant="ghost" 
                                size="sm" 
                                className="size-8 p-0 text-slate-400 hover:bg-violet-50 hover:text-violet-600 border border-slate-100 rounded-lg shadow-sm"
                                onClick={() => setViewStudent(student)}
                              >
                                <Eye className="size-4" />
                              </Button>
                              <Button 
                                variant="ghost" 
                                size="sm" 
                                className="size-8 p-0 text-slate-400 hover:bg-indigo-50 hover:text-indigo-600 border border-slate-100 rounded-lg shadow-sm"
                                onClick={() => handleOpenEdit(student)}
                              >
                                <Pencil className="size-4" />
                              </Button>
                              <Button 
                                variant="ghost" 
                                size="sm" 
                                className="size-8 p-0 text-slate-400 hover:bg-red-50 hover:text-red-600 border border-slate-100 rounded-lg shadow-sm"
                                onClick={() => handleDelete(student)}
                              >
                                <Trash2 className="size-4" />
                              </Button>
                            </div>
                          </td>
                        </tr>
                      ))
                    ) : (
                      <tr>
                        <td colSpan={8} className="text-center py-12 font-bold text-slate-400 text-xs">
                          Talabalar topilmadi.
                        </td>
                      </tr>
                    )}
                  </tbody>
                </table>
              </div>

              {/* Pagination controls */}
              <div className="flex flex-wrap items-center justify-between gap-4 border-t border-border/50 px-6 py-4 text-xs text-slate-500 font-bold">
                <span>Jami {totalItems} ta talabadan {indexOfFirstItem + 1}-{Math.min(indexOfLastItem, totalItems)} ko'rsatilmoqda</span>
                <div className="flex items-center gap-2">
                  <Button
                    variant="secondary"
                    size="sm"
                    disabled={currentPage === 1}
                    onClick={() => setCurrentPage((p) => Math.max(1, p - 1))}
                    className="h-8 text-[11px] font-bold px-3 border-slate-200"
                  >
                    Oldingi
                  </Button>
                  <span className="font-extrabold text-slate-700 bg-slate-100/60 px-3 py-1.5 rounded-lg border border-slate-200/40">{currentPage} / {totalPages}</span>
                  <Button
                    variant="secondary"
                    size="sm"
                    disabled={currentPage === totalPages}
                    onClick={() => setCurrentPage((p) => Math.min(totalPages, p + 1))}
                    className="h-8 text-[11px] font-bold px-3 border-slate-200"
                  >
                    Keyingi
                  </Button>
                  <Select
                    className="h-8 w-28 ml-2 text-[11px] font-bold text-slate-600"
                    value={itemsPerPage}
                    onChange={(e) => { setItemsPerPage(Number(e.target.value)); setCurrentPage(1); }}
                  >
                    <option value={10}>10 / sahifa</option>
                    <option value={20}>20 / sahifa</option>
                    <option value={50}>50 / sahifa</option>
                  </Select>
                </div>
              </div>
            </CardContent>
          </Card>
        </div>

        {/* Sidebar Charts and Top Students list */}
        <aside className="flex flex-col gap-6">
          <Card className="shadow-soft border border-border/80 rounded-2xl bg-white overflow-hidden">
            <CardHeader className="pb-2 border-b border-border/50 px-6 py-5 bg-slate-50/10">
              <CardTitle className="text-xs font-black uppercase tracking-wider text-slate-400">
                Foydalanish Holati
              </CardTitle>
            </CardHeader>
            <CardContent className="pt-6">
              <DonutChart label={String(filteredStudents.length)} chartData={donutData} />
              <div className="grid gap-3 text-xs mt-4">
                <div className="flex items-center justify-between rounded-xl border border-slate-100 p-2.5 bg-slate-50/20">
                  <span className="flex items-center gap-2 text-slate-600 font-bold">
                    <span className="bg-emerald-500 size-2.5 rounded-full animate-pulse" />
                    Faol (Telegram faol)
                  </span>
                  <span className="font-black text-slate-900 text-sm">{activeCount}</span>
                </div>
                <div className="flex items-center justify-between rounded-xl border border-slate-100 p-2.5 bg-slate-50/20">
                  <span className="flex items-center gap-2 text-slate-600 font-bold">
                    <span className="bg-slate-400 size-2.5 rounded-full" />
                    Nofaol (Tizimda sust)
                  </span>
                  <span className="font-black text-slate-900 text-sm">{inactiveCount}</span>
                </div>
              </div>
            </CardContent>
          </Card>

          <Card className="shadow-soft border border-border/80 rounded-2xl bg-white overflow-hidden">
            <CardHeader className="pb-2 border-b border-border/50 px-6 py-5 bg-slate-50/10">
              <CardTitle className="text-xs font-black uppercase tracking-wider text-slate-400">
                Top 5 Talabalar
              </CardTitle>
            </CardHeader>
            <CardContent className="flex flex-col gap-3.5 pt-5">
              {studentsQuery.isLoading ? (
                Array.from({ length: 3 }).map((_, i) => <Skeleton key={i} className="h-12 w-full rounded-xl" />)
              ) : studentsQuery.data && studentsQuery.data.length > 0 ? (
                [...studentsQuery.data]
                  .sort((a, b) => b.averageScore - a.averageScore)
                  .slice(0, 5)
                  .map((student: any, index: number) => {
                    const isTop1 = index === 0;
                    const isTop2 = index === 1;
                    const isTop3 = index === 2;

                    return (
                      <div 
                        key={student.id} 
                        className="flex items-center gap-3 border border-border/60 p-2.5 rounded-xl transition-all hover:border-slate-300 hover:bg-slate-50/30"
                      >
                        <span className={cn(
                          "flex size-8 shrink-0 items-center justify-center rounded-lg font-black text-xs border shadow-sm",
                          isTop1 && "bg-amber-50 border-amber-200 text-amber-600",
                          isTop2 && "bg-slate-100 border-slate-200 text-slate-600",
                          isTop3 && "bg-orange-50 border-orange-200/50 text-orange-600",
                          !isTop1 && !isTop2 && !isTop3 && "bg-slate-50 border-slate-100 text-slate-500"
                        )}>
                          {index + 1}
                        </span>
                        <div className="min-w-0 flex-1 ml-1">
                          <p className="truncate text-xs font-black text-slate-800 leading-snug">{student.name}</p>
                          <p className="text-[10px] font-bold text-slate-400 mt-0.5">O'rtacha: <span className="text-indigo-600 font-extrabold">{student.averageScore}%</span></p>
                        </div>
                        <span className="font-extrabold text-emerald-600 text-[10px] shrink-0 bg-emerald-50 px-2 py-0.5 rounded-lg border border-emerald-100/50">{student.progress}% progress</span>
                      </div>
                    );
                  })
              ) : (
                <p className="text-xs text-slate-400 font-bold text-center py-6">Top talabalar ro'yxati bo'sh</p>
              )}
            </CardContent>
          </Card>
        </aside>
      </div>

      {/* VIEW MODAL */}
      {viewStudent && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-900/60 backdrop-blur-sm p-4">
          <Card className="w-full max-w-lg max-h-[90vh] overflow-y-auto shadow-2xl relative edulab-scrollbar rounded-2xl border border-border bg-white">
            <button 
              className="absolute right-4 top-4 size-8 flex items-center justify-center text-slate-400 hover:text-slate-600 hover:bg-slate-100 rounded-lg transition-colors" 
              onClick={() => setViewStudent(null)}
            >
              <X className="size-4" />
            </button>
            <CardHeader className="border-b border-border pb-5 px-6 pt-6">
              <div className="flex items-center gap-4">
                <span className="flex size-14 shrink-0 items-center justify-center rounded-xl bg-gradient-to-br from-violet-100 to-indigo-100 border border-violet-200 font-black text-violet-700 text-xl shadow-sm">
                  {viewStudent.initials}
                </span>
                <div className="min-w-0">
                  <CardTitle className="text-base font-black text-slate-900 truncate leading-snug">{viewStudent.name}</CardTitle>
                  <p className="text-xs font-semibold text-slate-400 truncate mt-0.5">{viewStudent.email}</p>
                </div>
              </div>
            </CardHeader>
            <CardContent className="p-6 space-y-6">
              <div className="grid grid-cols-2 gap-4">
                <div className="bg-slate-50/50 border border-slate-100 p-3 rounded-xl space-y-1">
                  <p className="text-[10px] font-bold text-slate-400 uppercase tracking-wide">Telefon raqami</p>
                  <p className="text-xs font-extrabold text-slate-700 flex items-center gap-2">
                    <Phone className="size-4 text-violet-500" /> {viewStudent.phone || "-"}
                  </p>
                </div>
                <div className="bg-slate-50/50 border border-slate-100 p-3 rounded-xl space-y-1">
                  <p className="text-[10px] font-bold text-slate-400 uppercase tracking-wide">Ro'yxatdan o'tgan</p>
                  <p className="text-xs font-extrabold text-slate-700 flex items-center gap-2">
                    <Calendar className="size-4 text-indigo-500" /> {viewStudent.joinedAt}
                  </p>
                </div>
                <div className="bg-slate-50/50 border border-slate-100 p-3 rounded-xl space-y-1">
                  <p className="text-[10px] font-bold text-slate-400 uppercase tracking-wide">Tizim holati</p>
                  <div className="pt-0.5">
                    <Badge variant={viewStudent.status === "Faol" ? "success" : "slate"} className="gap-1.5 px-2.5 py-0.5 text-[10px] font-extrabold rounded-lg">
                      <span className={cn(
                        "size-1.5 rounded-full",
                        viewStudent.status === "Faol" ? "bg-emerald-500 animate-pulse" : "bg-slate-400"
                      )} />
                      {viewStudent.status}
                    </Badge>
                  </div>
                </div>
                <div className="bg-slate-50/50 border border-slate-100 p-3 rounded-xl space-y-1">
                  <p className="text-[10px] font-bold text-slate-400 uppercase tracking-wide">Tamomlangan modullar</p>
                  <p className="text-xs font-extrabold text-slate-700 flex items-center gap-2">
                    <GraduationCap className="size-4 text-amber-500" /> {viewStudent.modules} ta modul
                  </p>
                </div>
              </div>

              <div className="border-t border-border/60 pt-5 space-y-4">
                <h4 className="text-xs font-black text-slate-800 uppercase tracking-wider">O'zlashtirish darajasi</h4>
                <div className="grid grid-cols-2 gap-4">
                  <div className="bg-slate-50/80 p-3.5 rounded-xl border border-slate-100 flex items-center gap-3">
                    <div className="size-10 flex items-center justify-center text-blue-600 bg-blue-50 p-2 rounded-lg border border-blue-100/50">
                      <BadgePercent className="size-5" />
                    </div>
                    <div>
                      <p className="text-[9px] font-bold text-slate-400 uppercase">O'rtacha ball</p>
                      <p className="text-base font-black text-slate-900 mt-0.5">{viewStudent.averageScore}%</p>
                    </div>
                  </div>
                  <div className="bg-slate-50/80 p-3.5 rounded-xl border border-slate-100 flex items-center gap-3">
                    <div className="size-10 flex items-center justify-center text-emerald-600 bg-emerald-50 p-2 rounded-lg border border-emerald-100/50">
                      <Activity className="size-5" />
                    </div>
                    <div>
                      <p className="text-[9px] font-bold text-slate-400 uppercase">Kurs progressi</p>
                      <p className="text-base font-black text-slate-900 mt-0.5">{viewStudent.progress}%</p>
                    </div>
                  </div>
                </div>
              </div>

              <div className="border-t border-border/60 pt-5">
                <h4 className="text-xs font-black text-slate-800 uppercase tracking-wider mb-3.5">Manzil ma'lumotlari</h4>
                <div className="bg-slate-50/40 p-4 rounded-xl border border-slate-100/80 space-y-3.5 text-xs text-slate-700 font-medium">
                  <div className="flex items-center gap-3 border-b border-slate-100 pb-2.5">
                    <MapPin className="size-4 text-rose-500 shrink-0" />
                    <span>Viloyat: <strong className="text-slate-950 font-bold ml-1">{viewStudent.region || "Kiritilmagan"}</strong></span>
                  </div>
                  <div className="flex items-center gap-3 pl-7">
                    <span>Tuman/Shahar: <strong className="text-slate-950 font-bold ml-1">{viewStudent.district || "Kiritilmagan"}</strong></span>
                  </div>
                </div>
              </div>

              <div className="flex justify-end pt-5 border-t border-border/60">
                <Button 
                  variant="secondary" 
                  onClick={() => setViewStudent(null)}
                  className="font-bold border-slate-200 text-slate-700 hover:bg-slate-50 h-10 px-5 text-xs rounded-xl shadow-sm"
                >
                  Yopish
                </Button>
              </div>
            </CardContent>
          </Card>
        </div>
      )}

      {/* EDIT MODAL */}
      {editStudent && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-900/60 backdrop-blur-sm p-4">
          <Card className="w-full max-w-md shadow-2xl relative rounded-2xl border border-border bg-white overflow-hidden">
            <button 
              className="absolute right-4 top-4 size-8 flex items-center justify-center text-slate-400 hover:text-slate-600 hover:bg-slate-100 rounded-lg transition-colors" 
              onClick={() => setEditStudent(null)}
            >
              <X className="size-4" />
            </button>
            <CardHeader className="border-b border-border px-6 py-5 bg-slate-50/10">
              <CardTitle className="text-sm font-black text-slate-900 uppercase tracking-wide">Talaba ma'lumotlarini tahrirlash</CardTitle>
            </CardHeader>
            <CardContent className="p-6 space-y-4">
              <div>
                <label className="block text-[11px] font-black text-slate-500 uppercase tracking-wide mb-2">To'liq ismi</label>
                <Input
                  value={formName}
                  onChange={(e) => setFormName(e.target.value)}
                  placeholder="Ism va familiya"
                  className="border-border/80 focus:border-violet-500 focus:ring-violet-500/10 text-xs font-semibold"
                />
              </div>

              <div>
                <label className="block text-[11px] font-black text-slate-500 uppercase tracking-wide mb-2">Telefon raqami</label>
                <Input
                  value={formPhone}
                  onChange={(e) => setFormPhone(e.target.value)}
                  placeholder="+998901234567"
                  className="border-border/80 focus:border-violet-500 focus:ring-violet-500/10 text-xs font-semibold"
                />
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-[11px] font-black text-slate-500 uppercase tracking-wide mb-2">Jinsi</label>
                  <Select 
                    value={formGender} 
                    onChange={(e) => setFormGender(e.target.value)}
                    className="border-border/80 focus:border-violet-500 focus:ring-violet-500/10 w-full text-xs font-bold text-slate-700 bg-white"
                  >
                    <option value="">Tanlang</option>
                    <option value="male">Erkak</option>
                    <option value="female">Ayol</option>
                  </Select>
                </div>
                <div>
                  <label className="block text-[11px] font-black text-slate-500 uppercase tracking-wide mb-2">Yoshi</label>
                  <Input
                    type="number"
                    value={formAge}
                    onChange={(e) => setFormAge(e.target.value === "" ? "" : Number(e.target.value))}
                    placeholder="Masalan: 22"
                    className="border-border/80 focus:border-violet-500 focus:ring-violet-500/10 text-xs font-semibold"
                  />
                </div>
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-[11px] font-black text-slate-500 uppercase tracking-wide mb-2">Viloyat</label>
                  <Input
                    value={formRegion}
                    onChange={(e) => setFormRegion(e.target.value)}
                    placeholder="Viloyat nomi"
                    className="border-border/80 focus:border-violet-500 focus:ring-violet-500/10 text-xs font-semibold"
                  />
                </div>
                <div>
                  <label className="block text-[11px] font-black text-slate-500 uppercase tracking-wide mb-2">Tuman</label>
                  <Input
                    value={formDistrict}
                    onChange={(e) => setFormDistrict(e.target.value)}
                    placeholder="Tuman nomi"
                    className="border-border/80 focus:border-violet-500 focus:ring-violet-500/10 text-xs font-semibold"
                  />
                </div>
              </div>

              <div className="flex justify-end gap-3 pt-5 border-t border-border/60">
                <Button 
                  variant="secondary" 
                  onClick={() => setEditStudent(null)}
                  className="font-bold border-slate-200 text-slate-700 hover:bg-slate-50 h-10 px-5 text-xs rounded-xl shadow-sm"
                >
                  Bekor qilish
                </Button>
                <Button 
                  onClick={handleSaveEdit} 
                  disabled={updateStudentMutation.isPending || !formName.trim()}
                  className="font-bold h-10 px-5 text-xs rounded-xl bg-violet-600 hover:bg-violet-700 shadow-sm"
                >
                  {updateStudentMutation.isPending ? "Saqlanmoqda..." : "Saqlash"}
                </Button>
              </div>
            </CardContent>
          </Card>
        </div>
      )}
    </>
  );
}

