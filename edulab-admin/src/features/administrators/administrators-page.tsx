"use client";

import { useMemo, useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { toast } from "sonner";
import {
  CalendarDays,
  Edit,
  Mail,
  Search,
  Shield,
  ShieldCheck,
  Trash2,
  UserCheck,
  UserPlus,
  Users,
  X,
} from "lucide-react";
import { PageHeader } from "@/components/layout/page-header";
import { StatCard } from "@/components/layout/stat-card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Input, Select } from "@/components/ui/input";
import { createClient } from "@/lib/supabase/client";
import { cn } from "@/lib/utils";

type AdminProfile = {
  id: string;
  full_name: string | null;
  email?: string | null;
  phone: string | null;
  role: "admin" | "teacher";
  created_at: string;
};

export function AdministratorsPage() {
  const [showEditForm, setShowEditForm] = useState(false);
  const [editId, setEditId] = useState<string | null>(null);
  const [formName, setFormName] = useState("");
  const [formPhone, setFormPhone] = useState("");
  const [formRole, setFormRole] = useState<"admin" | "teacher">("admin");
  const [searchTerm, setSearchTerm] = useState("");
  const [roleFilter, setRoleFilter] = useState<"all" | "admin" | "teacher">("all");

  const supabase = createClient();
  const queryClient = useQueryClient();

  const { data: admins = [], isLoading } = useQuery({
    queryKey: ["admin-profiles"],
    queryFn: async () => {
      const { data, error } = await supabase
        .from("profiles")
        .select("*")
        .in("role", ["admin", "teacher"])
        .order("created_at", { ascending: false });
      if (error) {
        toast.error(error.message || "Administratorlar yuklanmadi");
        return [];
      }
      return (data || []) as AdminProfile[];
    },
  });

  const updateRoleMutation = useMutation({
    mutationFn: async ({ id, role }: { id: string; role: "admin" | "teacher" }) => {
      const { error } = await supabase.from("profiles").update({ role }).eq("id", id);
      if (error) throw error;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["admin-profiles"] });
      toast.success("Administrator roli yangilandi");
    },
    onError: (error) => toast.error(error.message || "Rol yangilanmadi"),
  });

  const updateProfileMutation = useMutation({
    mutationFn: async ({ id, full_name, phone }: { id: string; full_name: string; phone: string }) => {
      const { error } = await supabase.from("profiles").update({ full_name, phone }).eq("id", id);
      if (error) throw error;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["admin-profiles"] });
      handleCancel();
      toast.success("Administrator ma'lumotlari saqlandi");
    },
    onError: (error) => toast.error(error.message || "Ma'lumot saqlanmadi"),
  });

  const demoteMutation = useMutation({
    mutationFn: async (id: string) => {
      const { error } = await supabase.from("profiles").update({ role: "student" }).eq("id", id);
      if (error) throw error;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["admin-profiles"] });
      toast.success("Foydalanuvchi admin huquqidan chiqarildi");
    },
    onError: (error) => toast.error(error.message || "Huquqni o'zgartirib bo'lmadi"),
  });

  const filteredAdmins = useMemo(() => {
    return admins.filter((admin) => {
      const query = searchTerm.toLowerCase();
      const matchesSearch =
        (admin.full_name || "").toLowerCase().includes(query) ||
        (admin.email || "").toLowerCase().includes(query) ||
        (admin.phone || "").includes(searchTerm);
      const matchesRole = roleFilter === "all" || admin.role === roleFilter;
      return matchesSearch && matchesRole;
    });
  }, [admins, roleFilter, searchTerm]);

  const adminCount = admins.filter((admin) => admin.role === "admin").length;
  const teacherCount = admins.filter((admin) => admin.role === "teacher").length;
  const latestAdminDate = admins[0]?.created_at ? new Date(admins[0].created_at).toLocaleDateString("uz-UZ") : "-";

  const adminStats = [
    { title: "Jami administratorlar", value: String(admins.length), hint: "Admin + Teacher", tone: "blue" as const, icon: Users },
    { title: "Super Adminlar", value: String(adminCount), hint: "To'liq huquq", tone: "violet" as const, icon: ShieldCheck },
    { title: "Teacher/Moderator", value: String(teacherCount), hint: "Cheklangan huquq", tone: "green" as const, icon: Shield },
  ];

  const handleEdit = (admin: AdminProfile) => {
    setEditId(admin.id);
    setFormName(admin.full_name || "");
    setFormPhone(admin.phone || "");
    setFormRole(admin.role);
    setShowEditForm(true);
  };

  const handleCancel = () => {
    setEditId(null);
    setFormName("");
    setFormPhone("");
    setFormRole("admin");
    setShowEditForm(false);
  };

  const handleSave = () => {
    if (!editId) {
      toast.error("Avval administratorni tanlang");
      return;
    }
    updateProfileMutation.mutate({ id: editId, full_name: formName.trim(), phone: formPhone.trim() });
    updateRoleMutation.mutate({ id: editId, role: formRole });
  };

  return (
    <>
      <PageHeader
        title="Administratorlar"
        current="Tizim boshqaruvchilari"
        action={
          <Button onClick={() => setShowEditForm(true)} className="h-10 rounded-xl bg-blue-600 px-4 text-xs font-black text-white hover:bg-blue-700">
            <UserPlus className="size-4" />
            Admin tanlash
          </Button>
        }
      />

      <div className="mb-5 grid gap-4 md:grid-cols-3">
        {adminStats.map((item) => (
          <StatCard key={item.title} item={item} />
        ))}
      </div>

      <Card className="mb-5 rounded-2xl border border-slate-100 bg-white shadow-soft">
        <CardContent className="flex flex-wrap items-center justify-between gap-3 p-4">
          <div className="relative min-w-[260px] flex-1">
            <Search className="absolute left-3.5 top-1/2 size-4 -translate-y-1/2 text-slate-400" />
            <Input
              value={searchTerm}
              onChange={(event) => setSearchTerm(event.target.value)}
              placeholder="Ism, email yoki telefon..."
              className="h-10.5 rounded-xl border-slate-200 pl-10 text-sm font-semibold"
            />
          </div>
          <div className="flex flex-wrap gap-2">
            {(["all", "admin", "teacher"] as const).map((role) => (
              <Button
                key={role}
                type="button"
                variant="secondary"
                onClick={() => setRoleFilter(role)}
                className={cn(
                  "h-10.5 rounded-xl border px-4 text-xs font-black",
                  roleFilter === role
                    ? "border-blue-200 bg-blue-50 text-blue-700"
                    : "border-slate-200 bg-white text-slate-600 hover:bg-slate-50",
                )}
              >
                {role === "all" ? "Barchasi" : role === "admin" ? "Super Admin" : "Teacher"}
              </Button>
            ))}
          </div>
        </CardContent>
      </Card>

      <div className="grid gap-5 xl:grid-cols-[1fr_360px] 2xl:grid-cols-[1fr_420px]">
        <Card className="overflow-hidden rounded-2xl border border-slate-100 bg-white shadow-soft">
          <CardHeader className="border-b border-slate-100">
            <div>
              <CardTitle className="text-lg font-black">Adminlar ro'yxati</CardTitle>
              <p className="mt-1 text-xs font-semibold text-slate-500">Admin panelga kirish huquqiga ega foydalanuvchilar.</p>
            </div>
            <Badge className="bg-blue-50 text-blue-600">{filteredAdmins.length} ta</Badge>
          </CardHeader>
          <CardContent className="p-0">
            {isLoading ? (
              <div className="flex flex-col items-center justify-center py-16 text-sm font-bold text-slate-400">
                <div className="mb-4 size-8 animate-spin rounded-full border-4 border-blue-600 border-t-transparent" />
                Yuklanmoqda...
              </div>
            ) : filteredAdmins.length > 0 ? (
              <div className="divide-y divide-slate-100">
                {filteredAdmins.map((admin) => (
                  <div key={admin.id} className="grid gap-4 p-4 transition hover:bg-slate-50/70 lg:grid-cols-[minmax(0,1fr)_170px_150px_120px] lg:items-center">
                    <div className="flex min-w-0 items-center gap-3">
                      <span className={cn(
                        "flex size-11 shrink-0 items-center justify-center rounded-2xl text-sm font-black",
                        admin.role === "admin" ? "bg-blue-50 text-blue-600" : "bg-emerald-50 text-emerald-600",
                      )}>
                        {(admin.full_name || "A").split(" ").map((name) => name[0]).join("").toUpperCase().slice(0, 2)}
                      </span>
                      <div className="min-w-0">
                        <p className="truncate text-sm font-black text-slate-900">{admin.full_name || "Noma'lum admin"}</p>
                        <p className="mt-1 truncate text-xs font-semibold text-slate-500">{admin.email || admin.id}</p>
                      </div>
                    </div>
                    <div>
                      <Badge className={cn(admin.role === "admin" ? "bg-blue-50 text-blue-600" : "bg-emerald-50 text-emerald-600")}>
                        {admin.role === "admin" ? "Super Admin" : "Teacher / Moderator"}
                      </Badge>
                    </div>
                    <div className="flex items-center gap-2 text-xs font-bold text-slate-500">
                      <Mail className="size-4 text-slate-400" />
                      <span className="truncate">{admin.phone || "Telefon yo'q"}</span>
                    </div>
                    <div className="flex justify-start gap-2 lg:justify-end">
                      <Button size="sm" variant="secondary" onClick={() => handleEdit(admin)} className="h-9 rounded-xl border border-slate-200 bg-white px-3 text-slate-600">
                        <Edit className="size-4" />
                      </Button>
                      <Button
                        size="sm"
                        variant="secondary"
                        className="h-9 rounded-xl border border-rose-100 bg-rose-50 px-3 text-rose-600 hover:bg-rose-100"
                        onClick={() => {
                          if (confirm(`${admin.full_name || "Foydalanuvchi"}ni admin huquqidan chiqarilsinmi?`)) {
                            demoteMutation.mutate(admin.id);
                          }
                        }}
                      >
                        <Trash2 className="size-4" />
                      </Button>
                    </div>
                  </div>
                ))}
              </div>
            ) : (
              <div className="py-16 text-center">
                <UserCheck className="mx-auto mb-3 size-10 text-slate-300" />
                <p className="text-sm font-black text-slate-800">Administrator topilmadi</p>
                <p className="mt-1 text-xs font-semibold text-slate-500">Qidiruv yoki filtrni o'zgartirib ko'ring.</p>
              </div>
            )}
          </CardContent>
        </Card>

        <div className="space-y-5">
          <Card className="rounded-2xl border border-slate-100 bg-white shadow-soft">
            <CardHeader>
              <CardTitle className="text-base font-black">Rol xavfsizligi</CardTitle>
            </CardHeader>
            <CardContent className="space-y-3">
              <AdminInsight icon={ShieldCheck} title="Super Admin" value={`${adminCount} ta`} tone="blue" />
              <AdminInsight icon={Shield} title="Teacher / Moderator" value={`${teacherCount} ta`} tone="green" />
              <AdminInsight icon={CalendarDays} title="Oxirgi admin" value={latestAdminDate} tone="slate" />
            </CardContent>
          </Card>

          {showEditForm ? (
            <Card className="sticky top-28 h-fit rounded-2xl border border-slate-100 bg-white shadow-soft">
              <CardHeader className="border-b border-slate-100">
                <CardTitle className="text-base font-black">
                  {editId ? "Administratorni tahrirlash" : "Admin tanlanmagan"}
                </CardTitle>
                <Button variant="ghost" size="icon" onClick={handleCancel} className="rounded-xl">
                  <X className="size-5" />
                </Button>
              </CardHeader>
              <CardContent className="space-y-4 p-5">
                {!editId ? (
                  <div className="rounded-2xl border border-amber-100 bg-amber-50 p-4 text-xs font-bold leading-relaxed text-amber-700">
                    Chap ro'yxatdan administratorni tanlang. Yangi admin yaratish Supabase Auth orqali alohida account ochishni talab qiladi.
                  </div>
                ) : null}
                <div>
                  <label className="mb-2 block text-xs font-black uppercase tracking-wide text-slate-500">To'liq ism</label>
                  <Input value={formName} onChange={(event) => setFormName(event.target.value)} placeholder="Masalan: Asadbek Davronov" className="h-11 rounded-xl font-semibold" />
                </div>
                <div>
                  <label className="mb-2 block text-xs font-black uppercase tracking-wide text-slate-500">Telefon raqami</label>
                  <Input value={formPhone} onChange={(event) => setFormPhone(event.target.value)} placeholder="+998901234567" className="h-11 rounded-xl font-semibold" />
                </div>
                <div>
                  <label className="mb-2 block text-xs font-black uppercase tracking-wide text-slate-500">Rol</label>
                  <Select className="h-11 w-full rounded-xl font-bold" value={formRole} onChange={(event) => setFormRole(event.target.value as "admin" | "teacher")}>
                    <option value="admin">Super Admin (To'liq huquq)</option>
                    <option value="teacher">Teacher / Moderator (Cheklangan)</option>
                  </Select>
                </div>
                <Button
                  disabled={!editId || !formName.trim() || updateProfileMutation.isPending || updateRoleMutation.isPending}
                  onClick={handleSave}
                  className="h-11 w-full rounded-xl bg-blue-600 text-xs font-black text-white hover:bg-blue-700"
                >
                  {updateProfileMutation.isPending || updateRoleMutation.isPending ? "Saqlanmoqda..." : "O'zgarishlarni saqlash"}
                </Button>
              </CardContent>
            </Card>
          ) : null}
        </div>
      </div>
    </>
  );
}

function AdminInsight({
  icon: Icon,
  title,
  value,
  tone,
}: {
  icon: React.ComponentType<{ className?: string }>;
  title: string;
  value: string;
  tone: "blue" | "green" | "slate";
}) {
  const colors = {
    blue: "bg-blue-50 text-blue-600",
    green: "bg-emerald-50 text-emerald-600",
    slate: "bg-slate-100 text-slate-600",
  };
  return (
    <div className="flex items-center justify-between rounded-2xl border border-slate-100 bg-slate-50/60 p-3">
      <div className="flex items-center gap-3">
        <span className={cn("grid size-10 place-items-center rounded-xl", colors[tone])}>
          <Icon className="size-5" />
        </span>
        <span className="text-xs font-black text-slate-600">{title}</span>
      </div>
      <span className="text-sm font-black text-slate-950">{value}</span>
    </div>
  );
}
