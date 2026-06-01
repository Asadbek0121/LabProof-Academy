"use client";

import { useState } from "react";
import { PageHeader } from "@/components/layout/page-header";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input, Select } from "@/components/ui/input";
import { Badge } from "@/components/ui/badge";
import { StatCard } from "@/components/layout/stat-card";
import { createClient } from "@/lib/supabase/client";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { Edit, Mail, MoreVertical, Plus, Search, Shield, ShieldCheck, Trash2, UserPlus, Users, X } from "lucide-react";

export function AdministratorsPage() {
  const [showAddForm, setShowAddForm] = useState(false);
  const [editId, setEditId] = useState<string | null>(null);
  const [formName, setFormName] = useState("");
  const [formPhone, setFormPhone] = useState("");
  const [formRole, setFormRole] = useState<"admin" | "moderator">("admin");
  const [searchTerm, setSearchTerm] = useState("");

  const supabase = createClient();
  const queryClient = useQueryClient();

  // Fetch admin profiles
  const { data: admins, isLoading } = useQuery({
    queryKey: ["admin-profiles"],
    queryFn: async () => {
      const { data, error } = await supabase
        .from("profiles")
        .select("*")
        .in("role", ["admin", "moderator"])
        .order("created_at", { ascending: false });
      if (error) return [];
      return data || [];
    },
  });

  // Update role mutation
  const updateRoleMutation = useMutation({
    mutationFn: async ({ id, role }: { id: string; role: string }) => {
      const { error } = await supabase
        .from("profiles")
        .update({ role })
        .eq("id", id);
      if (error) throw error;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["admin-profiles"] });
    },
  });

  // Update profile name/phone mutation
  const updateProfileMutation = useMutation({
    mutationFn: async ({ id, full_name, phone }: { id: string; full_name: string; phone: string }) => {
      const { error } = await supabase
        .from("profiles")
        .update({ full_name, phone })
        .eq("id", id);
      if (error) throw error;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["admin-profiles"] });
      handleCancel();
    },
  });

  // Downgrade to student
  const demoteMutation = useMutation({
    mutationFn: async (id: string) => {
      const { error } = await supabase
        .from("profiles")
        .update({ role: "student" })
        .eq("id", id);
      if (error) throw error;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["admin-profiles"] });
    },
  });

  const handleEdit = (admin: any) => {
    setEditId(admin.id);
    setFormName(admin.full_name || "");
    setFormPhone(admin.phone || "");
    setFormRole(admin.role);
    setShowAddForm(true);
  };

  const handleCancel = () => {
    setEditId(null);
    setFormName("");
    setFormPhone("");
    setFormRole("admin");
    setShowAddForm(false);
  };

  const handleSave = () => {
    if (editId) {
      updateProfileMutation.mutate({ id: editId, full_name: formName, phone: formPhone });
      if (formRole) {
        updateRoleMutation.mutate({ id: editId, role: formRole });
      }
    }
  };

  const filteredAdmins = admins?.filter((a) =>
    (a.full_name || "").toLowerCase().includes(searchTerm.toLowerCase()) ||
    (a.phone || "").includes(searchTerm)
  );

  const adminCount = admins?.filter((a) => a.role === "admin").length || 0;
  const modCount = admins?.filter((a) => a.role === "moderator").length || 0;

  const adminStats = [
    { title: "Jami administratorlar", value: String(admins?.length || 0), hint: "Admin + Moderator", tone: "blue" as const, icon: Users },
    { title: "Super Adminlar", value: String(adminCount), hint: "To'liq huquq", tone: "violet" as const, icon: ShieldCheck },
    { title: "Moderatorlar", value: String(modCount), hint: "Cheklangan huquq", tone: "green" as const, icon: Shield },
  ];

  return (
    <>
      <PageHeader
        title="Administratorlar"
        current="Tizim boshqaruvchilari"
        action={
          <Button onClick={() => { handleCancel(); setShowAddForm(true); }}>
            <UserPlus className="size-4" />
            Tahrirlash
          </Button>
        }
      />

      <div className="grid gap-4 md:grid-cols-3 mb-6">
        {adminStats.map((item) => (
          <StatCard key={item.title} item={item} />
        ))}
      </div>

      <div className="grid gap-6 xl:grid-cols-[1fr_420px]">
        {/* Admin list */}
        <Card className="shadow-soft">
          <CardHeader className="border-b border-border">
            <CardTitle className="text-lg font-extrabold">Adminlar Ro'yxati</CardTitle>
            <div className="relative w-72">
              <Search className="absolute left-3 top-1/2 size-4 -translate-y-1/2 text-slate-400" />
              <Input
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                placeholder="Ism yoki telefon..."
                className="pl-10"
              />
            </div>
          </CardHeader>
          <CardContent className="p-0">
            <div className="overflow-x-auto edulab-scrollbar">
              <table className="w-full text-sm">
                <thead className="bg-slate-50 text-left text-xs font-bold uppercase text-slate-500">
                  <tr>
                    <th className="px-5 py-4">Foydalanuvchi</th>
                    <th className="px-5 py-4 text-center">Rol</th>
                    <th className="px-5 py-4 text-center">Telefon</th>
                    <th className="px-5 py-4 text-center">Qo'shilgan sana</th>
                    <th className="px-5 py-4 text-center">Amallar</th>
                  </tr>
                </thead>
                <tbody>
                  {isLoading ? (
                    <tr>
                      <td colSpan={5} className="text-center py-8 text-sm font-semibold text-slate-400">
                        Yuklanmoqda...
                      </td>
                    </tr>
                  ) : filteredAdmins && filteredAdmins.length > 0 ? (
                    filteredAdmins.map((admin) => (
                      <tr key={admin.id} className="border-t border-border hover:bg-slate-50/50 transition">
                        <td className="px-5 py-4">
                          <div className="flex items-center gap-3">
                            <span className="flex size-10 items-center justify-center rounded-full bg-blue-100 text-sm font-bold text-blue-600">
                              {(admin.full_name || "A").split(" ").map((n: string) => n[0]).join("").toUpperCase().slice(0, 2)}
                            </span>
                            <div>
                              <p className="font-bold text-slate-800">{admin.full_name || "Noma'lum"}</p>
                              <p className="text-xs text-slate-500">{admin.id.slice(0, 8)}...</p>
                            </div>
                          </div>
                        </td>
                        <td className="px-5 py-4 text-center">
                          <Badge variant={admin.role === "admin" ? "default" : "slate"}>
                            {admin.role === "admin" ? "Super Admin" : "Moderator"}
                          </Badge>
                        </td>
                        <td className="px-5 py-4 text-center text-slate-600">{admin.phone || "-"}</td>
                        <td className="px-5 py-4 text-center text-slate-500">
                          {new Date(admin.created_at).toLocaleDateString("uz-UZ")}
                        </td>
                        <td className="px-5 py-4">
                          <div className="flex justify-center gap-2">
                            <Button size="sm" variant="secondary" onClick={() => handleEdit(admin)}>
                              <Edit className="size-4" />
                            </Button>
                            <Button
                              size="sm"
                              variant="secondary"
                              className="text-red-600 hover:bg-red-50"
                              onClick={() => {
                                if (confirm(`${admin.full_name || "Foydalanuvchi"}ni admin huquqidan chiqarilsinmi?`)) {
                                  demoteMutation.mutate(admin.id);
                                }
                              }}
                            >
                              <Trash2 className="size-4" />
                            </Button>
                          </div>
                        </td>
                      </tr>
                    ))
                  ) : (
                    <tr>
                      <td colSpan={5} className="text-center py-8 text-sm font-semibold text-slate-400">
                        Administratorlar topilmadi.
                      </td>
                    </tr>
                  )}
                </tbody>
              </table>
            </div>
          </CardContent>
        </Card>

        {/* Edit form */}
        {showAddForm && (
          <Card className="shadow-soft h-fit sticky top-28">
            <CardHeader className="border-b border-border flex flex-row items-center justify-between">
              <CardTitle className="text-lg font-extrabold">
                {editId ? "Administratorni tahrirlash" : "Ma'lumotlarni tahrirlash"}
              </CardTitle>
              <Button variant="ghost" size="icon" onClick={handleCancel}>
                <X className="size-5" />
              </Button>
            </CardHeader>
            <CardContent className="p-5 space-y-4">
              <div>
                <label className="block text-sm font-bold text-slate-700 mb-2">To'liq ism</label>
                <Input
                  value={formName}
                  onChange={(e) => setFormName(e.target.value)}
                  placeholder="Masalan: Asadbek Davronov"
                />
              </div>

              <div>
                <label className="block text-sm font-bold text-slate-700 mb-2">Telefon raqami</label>
                <Input
                  value={formPhone}
                  onChange={(e) => setFormPhone(e.target.value)}
                  placeholder="+998901234567"
                />
              </div>

              <div>
                <label className="block text-sm font-bold text-slate-700 mb-2">Rol</label>
                <Select
                  className="w-full"
                  value={formRole}
                  onChange={(e) => setFormRole(e.target.value as "admin" | "moderator")}
                >
                  <option value="admin">Super Admin (To'liq huquq)</option>
                  <option value="moderator">Moderator (Cheklangan)</option>
                </Select>
              </div>

              <div className="rounded-2xl border border-blue-100 bg-blue-50 p-4 text-xs font-semibold text-blue-800 leading-normal">
                Rol o'zgartirilganda, foydalanuvchi sahifani qayta yuklaganida yangi huquqlar kuchga kiradi.
              </div>

              <Button
                disabled={!formName.trim() || updateProfileMutation.isPending}
                onClick={handleSave}
                className="w-full font-bold"
              >
                {updateProfileMutation.isPending ? "Saqlanmoqda..." : "O'zgarishlarni saqlash"}
              </Button>
            </CardContent>
          </Card>
        )}
      </div>
    </>
  );
}
