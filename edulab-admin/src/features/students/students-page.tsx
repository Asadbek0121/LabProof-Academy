"use client";

import { useMemo, useState } from "react";
import {
  Award,
  CheckCircle2,
  ChevronLeft,
  ChevronRight,
  Clock,
  Filter,
  MoreVertical,
  RotateCcw,
  Search,
  SlidersHorizontal,
  TrendingUp,
  Users,
  X,
} from "lucide-react";
import { PageHeader } from "@/components/layout/page-header";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { Input, Select } from "@/components/ui/input";
import { Skeleton } from "@/components/ui/skeleton";
import { useStudents } from "@/hooks/use-admin-data";
import type { Student } from "@/lib/types";
import { cn } from "@/lib/utils";

type StatusFilter = "all" | "Faol" | "O'rtacha" | "Qoniqarsiz";
type ModuleFilter = "all" | "has_progress" | "completed";
type DateFilter = "all" | "7" | "30";
type SortField = "name" | "progress" | "averageScore" | "joinedAt";

const statusMeta = {
  Faol: {
    label: "Faol",
    tone: "emerald",
    badge: "bg-emerald-50 text-emerald-600 border-emerald-100",
    dot: "bg-emerald-500",
    bar: "bg-emerald-500",
  },
  "O'rtacha": {
    label: "O'rtacha",
    tone: "amber",
    badge: "bg-amber-50 text-amber-600 border-amber-100",
    dot: "bg-amber-500",
    bar: "bg-amber-500",
  },
  Qoniqarsiz: {
    label: "Qoniqarsiz",
    tone: "rose",
    badge: "bg-rose-50 text-rose-600 border-rose-100",
    dot: "bg-rose-500",
    bar: "bg-rose-500",
  },
  Nofaol: {
    label: "Nofaol",
    tone: "slate",
    badge: "bg-slate-50 text-slate-500 border-slate-100",
    dot: "bg-slate-400",
    bar: "bg-slate-400",
  },
} as const;

function toNumber(value: number | undefined) {
  return Number.isFinite(value) ? value || 0 : 0;
}

function average(values: number[]) {
  if (values.length === 0) return 0;
  return Math.round(values.reduce((sum, value) => sum + value, 0) / values.length);
}

function parseStudentDate(student: Student) {
  if (student.createdAt) return new Date(student.createdAt).getTime();
  const [day, month, year] = student.joinedAt.split(".").map(Number);
  return new Date(year, month - 1, day).getTime();
}

function lastDays(days: number) {
  return Array.from({ length: days }, (_, index) => {
    const date = new Date();
    date.setDate(date.getDate() - (days - 1 - index));
    return date;
  });
}

function sameDay(a: Date, b: Date) {
  return (
    a.getFullYear() === b.getFullYear() &&
    a.getMonth() === b.getMonth() &&
    a.getDate() === b.getDate()
  );
}

function buildStudentTrend(students: Student[]) {
  const days = lastDays(6);
  return days.map((day) => ({
    label: `${day.getDate().toString().padStart(2, "0")}.${(day.getMonth() + 1)
      .toString()
      .padStart(2, "0")}`,
    value: students.filter((student) => sameDay(new Date(parseStudentDate(student)), day)).length,
  }));
}

function MiniLineChart({ points, color = "#2563eb" }: { points: number[]; color?: string }) {
  const max = Math.max(...points, 1);
  const width = 280;
  const height = 120;
  const coords = points.map((point, index) => {
    const x = points.length <= 1 ? 0 : (index / (points.length - 1)) * width;
    const y = height - (point / max) * (height - 18) - 8;
    return `${x},${y}`;
  });
  const path = coords.length > 0 ? coords.join(" ") : `0,${height}`;
  const area =
    coords.length > 0
      ? `0,${height} ${path} ${width},${height}`
      : `0,${height} ${width},${height}`;

  return (
    <svg viewBox={`0 0 ${width} ${height}`} className="h-32 w-full overflow-visible">
      {[0, 1, 2].map((line) => (
        <line
          key={line}
          x1="0"
          x2={width}
          y1={24 + line * 34}
          y2={24 + line * 34}
          stroke="#e5e7eb"
          strokeWidth="1"
        />
      ))}
      <polygon points={area} fill={color} opacity="0.12" />
      <polyline points={path} fill="none" stroke={color} strokeWidth="4" strokeLinecap="round" />
    </svg>
  );
}

function DonutStatus({ active, averageCount, poor }: { active: number; averageCount: number; poor: number }) {
  const total = Math.max(active + averageCount + poor, 1);
  const activePercent = (active / total) * 100;
  const averagePercent = (averageCount / total) * 100;

  return (
    <div className="flex items-center justify-between gap-4">
      <div
        className="grid size-20 place-items-center rounded-full"
        style={{
          background: `conic-gradient(#22c55e 0 ${activePercent}%, #f59e0b ${activePercent}% ${
            activePercent + averagePercent
          }%, #ef4444 ${activePercent + averagePercent}% 100%)`,
        }}
      >
        <div className="size-12 rounded-full bg-white shadow-inner" />
      </div>
      <div className="min-w-0 flex-1 space-y-2 text-xs font-extrabold text-slate-500">
        <div className="flex items-center justify-between gap-3">
          <span className="flex items-center gap-2"><i className="size-2 rounded-full bg-emerald-500" />Faol</span>
          <span className="text-slate-900">{active}</span>
        </div>
        <div className="flex items-center justify-between gap-3">
          <span className="flex items-center gap-2"><i className="size-2 rounded-full bg-amber-500" />O'rtacha</span>
          <span className="text-slate-900">{averageCount}</span>
        </div>
        <div className="flex items-center justify-between gap-3">
          <span className="flex items-center gap-2"><i className="size-2 rounded-full bg-rose-500" />Qoniqarsiz</span>
          <span className="text-slate-900">{poor}</span>
        </div>
      </div>
    </div>
  );
}

export function StudentsPage() {
  const studentsQuery = useStudents();
  const students = studentsQuery.data ?? [];

  const [searchTerm, setSearchTerm] = useState("");
  const [moduleFilter, setModuleFilter] = useState<ModuleFilter>("all");
  const [statusFilter, setStatusFilter] = useState<StatusFilter>("all");
  const [groupFilter, setGroupFilter] = useState("all");
  const [dateFilter, setDateFilter] = useState<DateFilter>("all");
  const [filtersOpen, setFiltersOpen] = useState(true);
  const [sortField, setSortField] = useState<SortField>("joinedAt");
  const [sortOrder, setSortOrder] = useState<"asc" | "desc">("desc");
  const [currentPage, setCurrentPage] = useState(1);
  const [itemsPerPage, setItemsPerPage] = useState(20);
  const [selectedStudent, setSelectedStudent] = useState<Student | null>(null);

  const statusCounts = useMemo(() => {
    const active = students.filter((student) => student.status === "Faol").length;
    const averageCount = students.filter((student) => student.status === "O'rtacha").length;
    const poor = students.filter(
      (student) => student.status === "Qoniqarsiz" || student.status === "Nofaol",
    ).length;
    return { active, averageCount, poor };
  }, [students]);

  const trend = useMemo(() => buildStudentTrend(students), [students]);
  const averageScore = average(students.map((student) => toNumber(student.averageScore)));
  const averageProgress = average(students.map((student) => toNumber(student.progress)));
  const inactiveCount = statusCounts.poor;

  const filteredStudents = useMemo(() => {
    const query = searchTerm.trim().toLowerCase();
    const now = Date.now();

    return students.filter((student) => {
      const matchesSearch =
        query.length === 0 ||
        student.name.toLowerCase().includes(query) ||
        student.email.toLowerCase().includes(query) ||
        student.phone.toLowerCase().includes(query);
      const matchesStatus = statusFilter === "all" || student.status === statusFilter;
      const matchesModule =
        moduleFilter === "all" ||
        (moduleFilter === "has_progress" && student.progress > 0) ||
        (moduleFilter === "completed" && student.modules > 0);
      const matchesGroup = groupFilter === "all" || !student.group;
      const matchesDate =
        dateFilter === "all" ||
        now - parseStudentDate(student) <= Number(dateFilter) * 24 * 60 * 60 * 1000;

      return matchesSearch && matchesStatus && matchesModule && matchesGroup && matchesDate;
    });
  }, [dateFilter, groupFilter, moduleFilter, searchTerm, statusFilter, students]);

  const sortedStudents = useMemo(() => {
    return [...filteredStudents].sort((a, b) => {
      const aValue = sortField === "joinedAt" ? parseStudentDate(a) : a[sortField];
      const bValue = sortField === "joinedAt" ? parseStudentDate(b) : b[sortField];

      if (typeof aValue === "string" && typeof bValue === "string") {
        return sortOrder === "asc" ? aValue.localeCompare(bValue) : bValue.localeCompare(aValue);
      }

      return sortOrder === "asc"
        ? Number(aValue) - Number(bValue)
        : Number(bValue) - Number(aValue);
    });
  }, [filteredStudents, sortField, sortOrder]);

  const totalItems = sortedStudents.length;
  const totalPages = Math.max(Math.ceil(totalItems / itemsPerPage), 1);
  const safeCurrentPage = Math.min(currentPage, totalPages);
  const indexOfFirstItem = (safeCurrentPage - 1) * itemsPerPage;
  const currentStudents = sortedStudents.slice(indexOfFirstItem, indexOfFirstItem + itemsPerPage);
  const topStudents = useMemo(
    () =>
      [...students]
        .sort((a, b) => b.progress - a.progress || b.averageScore - a.averageScore)
        .slice(0, 3),
    [students],
  );

  const resetFilters = () => {
    setSearchTerm("");
    setModuleFilter("all");
    setStatusFilter("all");
    setGroupFilter("all");
    setDateFilter("all");
    setCurrentPage(1);
  };

  const changeSort = (field: SortField) => {
    setSortField(field);
    setSortOrder((current) => (sortField === field && current === "desc" ? "asc" : "desc"));
  };

  const statCards = [
    {
      title: "Jami talabalar",
      value: students.length,
      hint: "Barcha talabalar",
      icon: Users,
      tone: "blue",
    },
    {
      title: "Faol talabalar",
      value: statusCounts.active,
      hint: students.length > 0 ? `${Math.round((statusCounts.active / students.length) * 100)}.0%` : "0%",
      icon: CheckCircle2,
      tone: "green",
    },
    {
      title: "O'rtacha ball",
      value: `${averageScore}%`,
      hint: "Umumiy o'rtacha",
      icon: Clock,
      tone: "amber",
    },
    {
      title: "Progress (o'rtacha)",
      value: `${averageProgress}%`,
      hint: "Umumiy progress",
      icon: TrendingUp,
      tone: "violet",
    },
  ];

  return (
    <>
      <PageHeader title="Talabalar" current="Talabalar" />

      <div className="space-y-5 animate-in fade-in duration-200">
        <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-[repeat(4,minmax(0,1fr))_1.45fr]">
          {studentsQuery.isLoading ? (
            Array.from({ length: 5 }).map((_, index) => (
              <Skeleton key={index} className="h-28 rounded-2xl" />
            ))
          ) : (
            <>
              {statCards.map((item) => {
                const Icon = item.icon;
                return (
                  <Card key={item.title} className="rounded-2xl border border-slate-200/80 bg-white shadow-sm">
                    <CardContent className="flex h-full items-center gap-4 p-5">
                      <div
                        className={cn(
                          "grid size-14 place-items-center rounded-2xl border",
                          item.tone === "blue" && "border-blue-100 bg-blue-50 text-blue-600",
                          item.tone === "green" && "border-emerald-100 bg-emerald-50 text-emerald-600",
                          item.tone === "amber" && "border-amber-100 bg-amber-50 text-amber-600",
                          item.tone === "violet" && "border-violet-100 bg-violet-50 text-violet-600",
                        )}
                      >
                        <Icon className="size-6" />
                      </div>
                      <div className="min-w-0">
                        <p className="text-xs font-black text-slate-500">{item.title}</p>
                        <p className="mt-1 text-3xl font-black leading-none text-slate-950">{item.value}</p>
                        <p
                          className={cn(
                            "mt-2 text-xs font-extrabold",
                            item.tone === "blue" && "text-blue-600",
                            item.tone === "green" && "text-emerald-600",
                            item.tone === "amber" && "text-amber-600",
                            item.tone === "violet" && "text-violet-600",
                          )}
                        >
                          {item.hint}
                        </p>
                      </div>
                    </CardContent>
                  </Card>
                );
              })}

              <Card className="rounded-2xl border border-slate-200/80 bg-white shadow-sm">
                <CardContent className="p-5">
                  <p className="mb-4 text-xs font-black text-slate-600">Holatlar bo'yicha</p>
                  <DonutStatus {...statusCounts} />
                </CardContent>
              </Card>
            </>
          )}
        </div>

        <div className="grid gap-5 xl:grid-cols-[minmax(0,1fr)_360px]">
          <Card className="overflow-hidden rounded-2xl border border-slate-200/80 bg-white shadow-sm">
            <div className="flex flex-wrap items-center justify-between gap-3 border-b border-slate-100 px-6 py-4">
              <div className="flex flex-wrap gap-8">
                {(["all", "Faol", "O'rtacha", "Qoniqarsiz"] as StatusFilter[]).map((status) => (
                  <button
                    key={status}
                    type="button"
                    onClick={() => {
                      setStatusFilter(status);
                      setCurrentPage(1);
                    }}
                    className={cn(
                      "relative py-2 text-sm font-black text-slate-500 transition hover:text-blue-600",
                      statusFilter === status && "text-blue-600",
                    )}
                  >
                    {status === "all" ? "Barcha" : status}
                    {statusFilter === status && (
                      <span className="absolute -bottom-[17px] left-0 h-0.5 w-full rounded-full bg-blue-600" />
                    )}
                  </button>
                ))}
              </div>

              <div className="flex flex-wrap items-center gap-3">
                <Button
                  variant="secondary"
                  onClick={resetFilters}
                  className="h-10 gap-2 rounded-xl border border-slate-200 bg-white text-xs font-black text-slate-600 shadow-sm"
                >
                  <RotateCcw className="size-4" />
                  Filtrlarni tozalash
                </Button>
                <Button
                  variant="secondary"
                  onClick={() => setFiltersOpen((open) => !open)}
                  className="h-10 gap-2 rounded-xl border-blue-200 bg-white text-xs font-black text-blue-600 shadow-sm"
                >
                  <Filter className="size-4" />
                  Filtrlar
                </Button>
              </div>
            </div>

            {filtersOpen && (
              <div className="grid gap-3 border-b border-slate-100 bg-slate-50/30 px-6 py-4 lg:grid-cols-[1.3fr_1fr_1fr_1fr_1fr_auto]">
                <div className="relative">
                  <Search className="absolute left-4 top-1/2 size-4 -translate-y-1/2 text-slate-400" />
                  <Input
                    value={searchTerm}
                    onChange={(event) => {
                      setSearchTerm(event.target.value);
                      setCurrentPage(1);
                    }}
                    placeholder="Talabani qidirish..."
                    className="h-11 rounded-xl border-slate-200 bg-white pl-11 text-xs font-bold"
                  />
                </div>
                <Select
                  value={moduleFilter}
                  onChange={(event) => {
                    setModuleFilter(event.target.value as ModuleFilter);
                    setCurrentPage(1);
                  }}
                  className="h-11 rounded-xl border-slate-200 bg-white text-xs font-bold text-slate-600"
                >
                  <option value="all">Barcha modullar</option>
                  <option value="has_progress">Progressi bor</option>
                  <option value="completed">Modul yakunlagan</option>
                </Select>
                <Select
                  value={statusFilter}
                  onChange={(event) => {
                    setStatusFilter(event.target.value as StatusFilter);
                    setCurrentPage(1);
                  }}
                  className="h-11 rounded-xl border-slate-200 bg-white text-xs font-bold text-slate-600"
                >
                  <option value="all">Barcha statuslar</option>
                  <option value="Faol">Faol</option>
                  <option value="O'rtacha">O'rtacha</option>
                  <option value="Qoniqarsiz">Qoniqarsiz</option>
                </Select>
                <Select
                  value={groupFilter}
                  onChange={(event) => {
                    setGroupFilter(event.target.value);
                    setCurrentPage(1);
                  }}
                  className="h-11 rounded-xl border-slate-200 bg-white text-xs font-bold text-slate-600"
                >
                  <option value="all">Barcha guruhlar</option>
                  <option value="empty">Guruh biriktirilmagan</option>
                </Select>
                <Select
                  value={dateFilter}
                  onChange={(event) => {
                    setDateFilter(event.target.value as DateFilter);
                    setCurrentPage(1);
                  }}
                  className="h-11 rounded-xl border-slate-200 bg-white text-xs font-bold text-slate-600"
                >
                  <option value="all">Sana oralig'i</option>
                  <option value="7">So'nggi 7 kun</option>
                  <option value="30">So'nggi 30 kun</option>
                </Select>
                <Button
                  variant="secondary"
                  onClick={() => {
                    setSortField("name");
                    setSortOrder("asc");
                  }}
                  className="size-11 rounded-xl border border-slate-200 bg-white p-0 text-slate-500 shadow-sm"
                  title="Jadvalni ism bo'yicha tartiblash"
                >
                  <SlidersHorizontal className="size-5" />
                </Button>
              </div>
            )}

            <div className="overflow-x-auto edulab-scrollbar">
              <table className="w-full min-w-[1040px] text-left text-sm">
                <thead className="border-b border-slate-100 bg-white">
                  <tr className="text-[11px] font-black text-slate-500">
                    <th className="w-12 px-5 py-4">
                      <input type="checkbox" className="size-4 rounded border-slate-300" aria-label="Barcha talabalarni tanlash" />
                    </th>
                    <th className="px-3 py-4">
                      <button onClick={() => changeSort("name")} className="font-black">Talaba</button>
                    </th>
                    <th className="px-3 py-4">Telefon</th>
                    <th className="px-3 py-4">Modullar</th>
                    <th className="px-3 py-4">
                      <button onClick={() => changeSort("progress")} className="font-black">Progress</button>
                    </th>
                    <th className="px-3 py-4">
                      <button onClick={() => changeSort("averageScore")} className="font-black">O'rtacha ball</button>
                    </th>
                    <th className="px-3 py-4">Status</th>
                    <th className="px-3 py-4">Guruh</th>
                    <th className="px-3 py-4">
                      <button onClick={() => changeSort("joinedAt")} className="font-black">Qo'shilgan sana</button>
                    </th>
                    <th className="px-5 py-4 text-center">Amallar</th>
                  </tr>
                </thead>
                <tbody>
                  {studentsQuery.isLoading ? (
                    Array.from({ length: 7 }).map((_, index) => (
                      <tr key={index} className="border-b border-slate-100">
                        <td colSpan={10} className="px-5 py-4">
                          <Skeleton className="h-10 rounded-xl" />
                        </td>
                      </tr>
                    ))
                  ) : currentStudents.length > 0 ? (
                    currentStudents.map((student) => {
                      const meta = statusMeta[student.status];
                      return (
                        <tr key={student.id} className="border-b border-slate-100 transition hover:bg-slate-50/80">
                          <td className="px-5 py-4">
                            <input type="checkbox" className="size-4 rounded border-slate-300" aria-label={`${student.name} tanlash`} />
                          </td>
                          <td className="px-3 py-4">
                            <div className="flex items-center gap-3">
                              <span className="grid size-10 place-items-center rounded-full bg-blue-50 text-xs font-black text-blue-700">
                                {student.initials}
                              </span>
                              <div className="min-w-0">
                                <p className="truncate text-sm font-black text-slate-950">{student.name}</p>
                                <p className="truncate text-xs font-bold text-slate-400">{student.email}</p>
                              </div>
                            </div>
                          </td>
                          <td className="px-3 py-4 text-xs font-bold text-slate-700">{student.phone || "-"}</td>
                          <td className="px-3 py-4 text-xs font-black text-slate-700">{student.modules} modul</td>
                          <td className="px-3 py-4">
                            <div className="flex items-center gap-3">
                              <div className="h-1.5 w-24 overflow-hidden rounded-full bg-slate-100">
                                <div className={cn("h-full rounded-full", meta.bar)} style={{ width: `${student.progress}%` }} />
                              </div>
                              <span className="w-9 text-right text-xs font-black text-slate-700">{student.progress}%</span>
                            </div>
                          </td>
                          <td className="px-3 py-4 text-xs font-black text-slate-700">{student.averageScore}%</td>
                          <td className="px-3 py-4">
                            <Badge className={cn("gap-1.5 rounded-lg border px-2 py-0.5 text-[10px] font-black", meta.badge)}>
                              <span className={cn("size-1.5 rounded-full", meta.dot)} />
                              {meta.label}
                            </Badge>
                          </td>
                          <td className="px-3 py-4 text-xs font-bold text-slate-700">{student.group || "Guruh yo'q"}</td>
                          <td className="px-3 py-4 text-xs font-bold text-slate-700">{student.joinedAt}</td>
                          <td className="px-5 py-4">
                            <div className="flex justify-center">
                              <Button
                                variant="secondary"
                                onClick={() => setSelectedStudent(student)}
                                className="size-9 rounded-xl border border-slate-200 bg-white p-0 text-slate-600 shadow-sm"
                                title="Talaba haqida"
                              >
                                <MoreVertical className="size-4" />
                              </Button>
                            </div>
                          </td>
                        </tr>
                      );
                    })
                  ) : (
                    <tr>
                      <td colSpan={10} className="px-5 py-16 text-center text-sm font-bold text-slate-400">
                        Hozircha bu filterlarga mos real talaba topilmadi.
                      </td>
                    </tr>
                  )}
                </tbody>
              </table>
            </div>

            <div className="flex flex-wrap items-center justify-between gap-3 px-6 py-5 text-xs font-bold text-slate-500">
              <span>Jami {totalItems} ta talaba</span>
              <div className="flex items-center gap-2">
                <Button
                  variant="secondary"
                  disabled={safeCurrentPage === 1}
                  onClick={() => setCurrentPage((page) => Math.max(1, page - 1))}
                  className="size-9 rounded-xl border border-slate-200 bg-white p-0 shadow-sm"
                >
                  <ChevronLeft className="size-4" />
                </Button>
                {[1, 2, 3].filter((page) => page <= totalPages).map((page) => (
                  <Button
                    key={page}
                    variant={safeCurrentPage === page ? "default" : "secondary"}
                    onClick={() => setCurrentPage(page)}
                    className={cn(
                      "size-9 rounded-xl p-0 text-xs font-black",
                      safeCurrentPage !== page && "border border-slate-200 bg-white text-slate-600 shadow-sm",
                    )}
                  >
                    {page}
                  </Button>
                ))}
                {totalPages > 3 && <span className="px-2">...</span>}
                {totalPages > 3 && (
                  <Button
                    variant="secondary"
                    onClick={() => setCurrentPage(totalPages)}
                    className="size-9 rounded-xl border border-slate-200 bg-white p-0 text-xs font-black text-slate-600 shadow-sm"
                  >
                    {totalPages}
                  </Button>
                )}
                <Button
                  variant="secondary"
                  disabled={safeCurrentPage === totalPages}
                  onClick={() => setCurrentPage((page) => Math.min(totalPages, page + 1))}
                  className="size-9 rounded-xl border border-slate-200 bg-white p-0 shadow-sm"
                >
                  <ChevronRight className="size-4" />
                </Button>
                <Select
                  value={itemsPerPage}
                  onChange={(event) => {
                    setItemsPerPage(Number(event.target.value));
                    setCurrentPage(1);
                  }}
                  className="ml-3 h-9 w-32 rounded-xl border-slate-200 bg-white text-xs font-bold"
                >
                  <option value={10}>10 / sahifa</option>
                  <option value={20}>20 / sahifa</option>
                  <option value={50}>50 / sahifa</option>
                </Select>
              </div>
            </div>
          </Card>

          <aside className="space-y-5">
            <Card className="rounded-2xl border border-slate-200/80 bg-white shadow-sm">
              <CardContent className="p-5">
                <div className="mb-4 flex items-center justify-between">
                  <h3 className="text-sm font-black text-slate-950">Talabalar statistikasi</h3>
                  <Badge className="rounded-lg border border-slate-100 bg-white text-[10px] font-black text-slate-500">Ushbu oy</Badge>
                </div>
                <MiniLineChart points={trend.map((item) => item.value)} />
                <div className="mt-2 grid grid-cols-2 gap-4 text-xs font-black">
                  <div>
                    <p className="text-slate-400">Yangi talabalar</p>
                    <p className="mt-1 text-xl text-emerald-600">+{trend.reduce((sum, item) => sum + item.value, 0)}</p>
                  </div>
                  <div>
                    <p className="text-slate-400">Faol talabalar</p>
                    <p className="mt-1 text-xl text-blue-600">{statusCounts.active}</p>
                  </div>
                </div>
              </CardContent>
            </Card>

            <Card className="rounded-2xl border border-slate-200/80 bg-white shadow-sm">
              <CardContent className="p-5">
                <h3 className="mb-4 text-sm font-black text-slate-950">Eng faol talabalar</h3>
                <div className="space-y-4">
                  {studentsQuery.isLoading ? (
                    Array.from({ length: 3 }).map((_, index) => <Skeleton key={index} className="h-10 rounded-xl" />)
                  ) : topStudents.length > 0 ? (
                    topStudents.map((student, index) => (
                      <div key={student.id} className="grid grid-cols-[24px_36px_1fr_90px] items-center gap-3">
                        <span className="text-xs font-black text-slate-400">{index + 1}</span>
                        <span className="grid size-9 place-items-center rounded-full bg-blue-50 text-xs font-black text-blue-700">
                          {student.initials}
                        </span>
                        <span className="truncate text-xs font-black text-slate-800">{student.name}</span>
                        <div className="flex items-center gap-2">
                          <div className="h-1.5 flex-1 overflow-hidden rounded-full bg-slate-100">
                            <div className="h-full rounded-full bg-emerald-500" style={{ width: `${student.progress}%` }} />
                          </div>
                          <span className="w-8 text-right text-xs font-black text-slate-600">{student.progress}%</span>
                        </div>
                      </div>
                    ))
                  ) : (
                    <p className="py-6 text-center text-xs font-bold text-slate-400">Faol talabalar hali yo'q</p>
                  )}
                </div>
              </CardContent>
            </Card>

            <Card className="rounded-2xl border border-slate-200/80 bg-white shadow-sm">
              <CardContent className="flex items-center justify-between gap-4 p-5">
                <div className="grid size-12 place-items-center rounded-2xl border border-amber-100 bg-amber-50 text-amber-600">
                  <Award className="size-5" />
                </div>
                <div className="min-w-0 flex-1">
                  <h3 className="text-sm font-black text-slate-950">Eslatma</h3>
                  <p className="mt-1 text-xs font-bold text-slate-500">Faol bo'lmagan talabalar soni: {inactiveCount}</p>
                </div>
                <Button
                  variant="ghost"
                  onClick={() => {
                    setStatusFilter("Qoniqarsiz");
                    setCurrentPage(1);
                  }}
                  className="h-9 rounded-xl text-xs font-black text-blue-600"
                >
                  Ko'rish
                </Button>
              </CardContent>
            </Card>
          </aside>
        </div>
      </div>

      {selectedStudent && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-950/50 p-4 backdrop-blur-sm">
          <Card className="w-full max-w-lg overflow-hidden rounded-2xl border border-slate-200 bg-white shadow-2xl">
            <CardContent className="p-0">
              <div className="flex items-center justify-between border-b border-slate-100 p-6">
                <div className="flex items-center gap-4">
                  <span className="grid size-14 place-items-center rounded-2xl bg-blue-50 text-lg font-black text-blue-700">
                    {selectedStudent.initials}
                  </span>
                  <div>
                    <h3 className="text-lg font-black text-slate-950">{selectedStudent.name}</h3>
                    <p className="text-xs font-bold text-slate-400">{selectedStudent.email}</p>
                  </div>
                </div>
                <Button
                  variant="ghost"
                  onClick={() => setSelectedStudent(null)}
                  className="size-9 rounded-xl p-0 text-slate-500"
                >
                  <X className="size-4" />
                </Button>
              </div>
              <div className="grid gap-3 p-6 text-sm font-bold text-slate-700 sm:grid-cols-2">
                <div className="rounded-xl border border-slate-100 bg-slate-50 p-4">
                  <p className="text-[10px] font-black uppercase text-slate-400">Telefon</p>
                  <p className="mt-1">{selectedStudent.phone || "-"}</p>
                </div>
                <div className="rounded-xl border border-slate-100 bg-slate-50 p-4">
                  <p className="text-[10px] font-black uppercase text-slate-400">Qo'shilgan sana</p>
                  <p className="mt-1">{selectedStudent.joinedAt}</p>
                </div>
                <div className="rounded-xl border border-slate-100 bg-slate-50 p-4">
                  <p className="text-[10px] font-black uppercase text-slate-400">Modullar</p>
                  <p className="mt-1">{selectedStudent.modules} modul</p>
                </div>
                <div className="rounded-xl border border-slate-100 bg-slate-50 p-4">
                  <p className="text-[10px] font-black uppercase text-slate-400">Guruh</p>
                  <p className="mt-1">{selectedStudent.group || "Guruh yo'q"}</p>
                </div>
                <div className="rounded-xl border border-slate-100 bg-slate-50 p-4">
                  <p className="text-[10px] font-black uppercase text-slate-400">Progress</p>
                  <p className="mt-1">{selectedStudent.progress}%</p>
                </div>
                <div className="rounded-xl border border-slate-100 bg-slate-50 p-4">
                  <p className="text-[10px] font-black uppercase text-slate-400">O'rtacha ball</p>
                  <p className="mt-1">{selectedStudent.averageScore}%</p>
                </div>
              </div>
              <div className="flex justify-end border-t border-slate-100 p-5">
                <Button onClick={() => setSelectedStudent(null)} className="rounded-xl px-5 text-xs font-black">
                  Yopish
                </Button>
              </div>
            </CardContent>
          </Card>
        </div>
      )}
    </>
  );
}
