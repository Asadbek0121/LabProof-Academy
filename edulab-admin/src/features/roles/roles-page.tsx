"use client";

import { useMemo, useState, useEffect } from "react";
import type * as React from "react";
import {
  Check,
  LockKeyhole,
  Palette,
  Plus,
  Search,
  ShieldCheck,
  Users,
  X,
  Edit2,
  Trash2,
} from "lucide-react";
import { PageHeader } from "@/components/layout/page-header";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Input, Select, Textarea } from "@/components/ui/input";
import { Modal } from "@/components/ui/modal";
import { permissions, roles } from "@/lib/mock-data";
import { cn } from "@/lib/utils";
import { toast } from "sonner";

const modules = ["Talabalar", "Tahlillar", "Xabarnomalar", "Sertifikatlar", "Media", "Sozlamalar", "Rollar"];
const colors = ["#7C3AED", "#2563EB", "#10B981", "#F59E0B", "#EF4444", "#0F172A"];

export function RolesPage() {
  const [mounted, setMounted] = useState(false);
  const [rolesList, setRolesList] = useState(roles);
  const [searchQuery, setSearchQuery] = useState("");
  const [open, setOpen] = useState(false);
  const [editingRole, setEditingRole] = useState<any>(null);

  useEffect(() => {
    setMounted(true);
  }, []);

  const filteredRoles = useMemo(() => {
    return rolesList.filter((role) =>
      role.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
      role.description.toLowerCase().includes(searchQuery.toLowerCase())
    );
  }, [rolesList, searchQuery]);

  const handleCreateOrUpdateRole = (roleData: {
    id?: string;
    name: string;
    description: string;
    color: string;
    permissions: string[];
    moduleAccess: string[];
  }) => {
    if (roleData.id) {
      // Update
      setRolesList((prev) =>
        prev.map((r) => (r.id === roleData.id ? { ...r, ...roleData } : r))
      );
      toast.success("Role ruxsatlari muvaffaqiyatli tahrirlandi");
    } else {
      // Create
      const newRole = {
        ...roleData,
        id: `role_${Date.now()}`,
        users: 0,
      };
      setRolesList((prev) => [...prev, newRole]);
      toast.success("Yangi role muvaffaqiyatli yaratildi");
    }
    setOpen(false);
    setEditingRole(null);
  };

  const handleDeleteRole = (id: string) => {
    const role = rolesList.find((r) => r.id === id);
    if (role?.name === "Admin") {
      toast.error("Admin rolimi o'chirib bo'lmaydi");
      return;
    }
    setRolesList((prev) => prev.filter((r) => r.id !== id));
    toast.success("Role tizimdan o'chirildi");
  };

  const handleOpenCreateModal = () => {
    setEditingRole(null);
    setOpen(true);
  };

  const handleOpenEditModal = (role: any) => {
    setEditingRole(role);
    setOpen(true);
  };

  if (!mounted) {
    return (
      <div className="flex h-screen items-center justify-center">
        <div className="size-8 animate-spin rounded-full border-4 border-violet-600 border-t-transparent" />
      </div>
    );
  }

  return (
    <>
      <PageHeader
        title="Rollar va Ruxsatlar"
        current="Rollar"
        action={
          <Button onClick={handleOpenCreateModal} className="bg-violet-600 text-white hover:bg-violet-700 rounded-xl h-10 text-xs font-bold px-4 flex gap-1.5 shadow-sm">
            <Plus className="size-4" />
            Role yaratish
          </Button>
        }
      />

      {/* Metrics Row (Matching Students Section layout) */}
      <div className="grid gap-4.5 md:grid-cols-2 xl:grid-cols-4">
        <RoleMetric title="Jami rollar" value={String(rolesList.length)} icon={ShieldCheck} tone="violet" hint="Tizim rollari" />
        <RoleMetric title="Joriy Admin" value="1" icon={Users} tone="blue" hint="Super admin" />
        <RoleMetric title="Harakatlar" value={String(permissions.length)} icon={LockKeyhole} tone="green" hint="Ruxsatnomalar" />
        <RoleMetric title="Modul Access" value={String(modules.length)} icon={Palette} tone="orange" hint="Ruxsat etilgan" />
      </div>

      {/* Filter Row (Matching Students Section layout) */}
      <div className="mt-5 flex flex-wrap gap-3 items-center justify-between bg-white border border-slate-100 rounded-2xl p-4 shadow-soft">
        <div className="relative flex-1 min-w-[280px]">
          <Search className="absolute left-3.5 top-1/2 size-4 -translate-y-1/2 text-slate-400" />
          <Input
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            placeholder="Rollar bo'yicha qidirish..."
            className="pl-10 h-10.5 rounded-xl border-slate-200 text-sm font-semibold text-slate-800 focus:border-violet-500 placeholder-slate-450"
          />
        </div>
        <div className="flex gap-2 items-center">
          <Button
            variant="secondary"
            onClick={() => setSearchQuery("")}
            className="h-10.5 rounded-xl border border-slate-200 px-4 font-bold text-xs bg-slate-50 text-slate-700 hover:bg-slate-100"
          >
            Tozalash
          </Button>
        </div>
      </div>

      {/* Roles List Table (Matching Students Section layout) */}
      <div className="mt-5">
        <Card className="border border-slate-100 bg-white rounded-2xl shadow-soft overflow-hidden">
          <CardContent className="p-0">
            <div className="overflow-x-auto edulab-scrollbar">
              <table className="w-full min-w-[800px] text-sm">
                <thead className="bg-slate-50/50 text-left text-[10px] font-bold uppercase tracking-wider text-slate-500 border-b border-slate-100">
                  <tr>
                    <th className="px-5 py-4">Rol nomi</th>
                    <th className="px-5 py-4">Tavsif</th>
                    <th className="px-5 py-4 text-center">Foydalanuvchilar</th>
                    <th className="px-5 py-4 text-center">Modullar</th>
                    <th className="px-5 py-4 text-center">Ruxsatlar</th>
                    <th className="px-5 py-4 text-right">Amallar</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-100">
                  {filteredRoles.map((role) => (
                    <tr key={role.id} className="transition duration-150 hover:bg-slate-50/30">
                      <td className="px-5 py-4">
                        <div className="flex items-center gap-3">
                          <span className="size-3.5 rounded-full ring-2 ring-white shadow-sm shrink-0" style={{ backgroundColor: role.color }} />
                          <span className="font-extrabold text-slate-800 text-sm">{role.name}</span>
                        </div>
                      </td>
                      <td className="px-5 py-4 text-xs font-semibold text-slate-500 max-w-sm truncate">
                        {role.description}
                      </td>
                      <td className="px-5 py-4 text-center">
                        <Badge variant="violet" className="text-[10px] font-bold uppercase px-2 py-0.5 rounded-lg">
                          {role.users} user
                        </Badge>
                      </td>
                      <td className="px-5 py-4 text-center text-xs font-bold text-slate-600">
                        {role.moduleAccess.includes("all") ? modules.length : role.moduleAccess.length} ta modul
                      </td>
                      <td className="px-5 py-4 text-center text-xs font-bold text-slate-600">
                        {role.permissions.length} ta huquq
                      </td>
                      <td className="px-5 py-4 text-right">
                        <div className="flex justify-end gap-1.5">
                          <Button
                            variant="secondary"
                            onClick={() => handleOpenEditModal(role)}
                            className="h-8 rounded-lg px-2.5 text-[10px] font-bold uppercase border border-slate-200 bg-white text-slate-700 hover:bg-slate-50 flex items-center gap-1"
                          >
                            <Edit2 className="size-3" />
                            Tahrirlash
                          </Button>
                          <Button
                            variant="secondary"
                            onClick={() => handleDeleteRole(role.id)}
                            className="h-8 rounded-lg px-2.5 text-[10px] font-bold uppercase border border-rose-100 bg-white text-rose-600 hover:bg-rose-50 flex items-center gap-1"
                          >
                            <Trash2 className="size-3" />
                            O'chirish
                          </Button>
                        </div>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </CardContent>
        </Card>
      </div>

      <CreateOrEditRoleModal
        open={open}
        onOpenChange={setOpen}
        editingRole={editingRole}
        onSave={handleCreateOrUpdateRole}
      />
    </>
  );
}

function CreateOrEditRoleModal({
  open,
  onOpenChange,
  editingRole,
  onSave,
}: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  editingRole: any;
  onSave: (role: any) => void;
}) {
  const [name, setName] = useState("");
  const [description, setDescription] = useState("");
  const [selectedColor, setSelectedColor] = useState(colors[0]);
  const [selectedPermissions, setSelectedPermissions] = useState<string[]>([]);
  const [moduleAccess, setModuleAccess] = useState<string[]>(["all"]);
  
  // Tab control in dialog
  const [activeTab, setActiveTab] = useState<"general" | "modules" | "permissions">("general");

  useEffect(() => {
    if (editingRole) {
      setName(editingRole.name);
      setDescription(editingRole.description);
      setSelectedColor(editingRole.color || colors[0]);
      setSelectedPermissions(editingRole.permissions || []);
      setModuleAccess(editingRole.moduleAccess || ["all"]);
    } else {
      setName("");
      setDescription("");
      setSelectedColor(colors[0]);
      setSelectedPermissions([]);
      setModuleAccess(["all"]);
    }
    setActiveTab("general");
  }, [editingRole, open]);

  const handleTogglePerm = (permId: string) => {
    setSelectedPermissions((prev) =>
      prev.includes(permId) ? prev.filter((id) => id !== permId) : [...prev, permId]
    );
  };

  const handleToggleModule = (modName: string) => {
    const modLower = modName.toLowerCase();
    setModuleAccess((prev) => {
      const isAll = prev.includes("all");
      let updated = [...prev];
      if (isAll) {
        updated = modules.map((m) => m.toLowerCase()).filter((m) => m !== modLower);
      } else {
        if (prev.includes(modLower)) {
          updated = prev.filter((m) => m !== modLower);
        } else {
          updated = [...prev, modLower];
        }
      }
      return updated;
    });
  };

  const handleSave = () => {
    if (!name.trim()) {
      toast.error("Role nomini kiriting");
      return;
    }
    onSave({
      id: editingRole?.id,
      name,
      description,
      color: selectedColor,
      permissions: selectedPermissions,
      moduleAccess,
    });
  };

  const groupedPermissions = useMemo(
    () => permissions.reduce<Record<string, typeof permissions>>((acc, permission) => {
      acc[permission.group] ??= [];
      acc[permission.group].push(permission);
      return acc;
    }, {}),
    []
  );

  return (
    <Modal
      open={open}
      onOpenChange={onOpenChange}
      title={editingRole ? "Rolni tahrirlash" : "Yangi role yaratish"}
      description="Role nomlanishi, ruxsat etilgan modullar va harakatlar huquqini shakllantiring."
      wide
      footer={
        <div className="flex gap-2 justify-end w-full">
          <Button variant="secondary" onClick={() => onOpenChange(false)} className="rounded-xl h-10 text-xs font-bold border border-slate-200 px-4 bg-slate-50 text-slate-700 hover:bg-slate-100">
            Bekor qilish
          </Button>
          <Button onClick={handleSave} className="rounded-xl h-10 text-xs font-bold bg-violet-600 text-white hover:bg-violet-700 px-4 flex gap-1.5 shadow-sm">
            <Check className="size-4" />
            Saqlash
          </Button>
        </div>
      }
    >
      {/* Tab Selectors */}
      <div className="flex border-b border-slate-100 mb-5 gap-4">
        <button
          type="button"
          onClick={() => setActiveTab("general")}
          className={cn(
            "pb-2.5 text-xs font-black uppercase tracking-wider transition-all border-b-2 focus:outline-none",
            activeTab === "general"
              ? "border-violet-600 text-violet-700"
              : "border-transparent text-slate-400 hover:text-slate-600"
          )}
        >
          Umumiy
        </button>
        <button
          type="button"
          onClick={() => setActiveTab("modules")}
          className={cn(
            "pb-2.5 text-xs font-black uppercase tracking-wider transition-all border-b-2 focus:outline-none",
            activeTab === "modules"
              ? "border-violet-600 text-violet-700"
              : "border-transparent text-slate-400 hover:text-slate-600"
          )}
        >
          Modullar ({moduleAccess.includes("all") ? modules.length : moduleAccess.length})
        </button>
        <button
          type="button"
          onClick={() => setActiveTab("permissions")}
          className={cn(
            "pb-2.5 text-xs font-black uppercase tracking-wider transition-all border-b-2 focus:outline-none",
            activeTab === "permissions"
              ? "border-violet-600 text-violet-700"
              : "border-transparent text-slate-400 hover:text-slate-600"
          )}
        >
          Huquqlar ({selectedPermissions.length})
        </button>
      </div>

      <div className="max-h-[50vh] overflow-y-auto pr-2 edulab-scrollbar">
        {activeTab === "general" && (
          <div className="space-y-4">
            <div className="grid gap-2">
              <label className="text-xs font-black text-slate-500 uppercase tracking-wide">Role nomi</label>
              <Input
                value={name}
                onChange={(e) => setName(e.target.value)}
                placeholder="Masalan: Mentor, Moderator..."
                className="h-10.5 rounded-xl border-slate-200 font-semibold focus:border-violet-500"
              />
            </div>

            <div className="grid gap-2">
              <label className="text-xs font-black text-slate-500 uppercase tracking-wide">Tavsif (Description)</label>
              <Textarea
                value={description}
                onChange={(e) => setDescription(e.target.value)}
                placeholder="Role vazifalarini va huquqiy maqsadlarini qisqacha yozing..."
                className="rounded-xl border-slate-200 font-medium text-sm min-h-[100px] focus:border-violet-500"
              />
            </div>

            <div className="grid gap-2.5">
              <label className="text-xs font-black text-slate-500 uppercase tracking-wide">Rang belgilash (Palette Color)</label>
              <div className="flex flex-wrap gap-2.5">
                {colors.map((color) => {
                  const isSelected = selectedColor === color;
                  return (
                    <button
                      key={color}
                      type="button"
                      onClick={() => setSelectedColor(color)}
                      className={cn(
                        "flex size-10 items-center justify-center rounded-xl border transition-all duration-150 focus:outline-none",
                        isSelected
                          ? "ring-4 ring-violet-100 border-violet-500 scale-105"
                          : "border-slate-150 hover:scale-105"
                      )}
                      style={{ backgroundColor: color }}
                    >
                      {isSelected && <Check className="size-4 text-white drop-shadow-sm stroke-[3]" />}
                    </button>
                  );
                })}
              </div>
            </div>
          </div>
        )}

        {activeTab === "modules" && (
          <div className="grid gap-3 md:grid-cols-2">
            {modules.map((module) => {
              const isChecked = moduleAccess.includes("all") || moduleAccess.includes(module.toLowerCase());
              return (
                <button
                  key={module}
                  type="button"
                  onClick={() => handleToggleModule(module)}
                  className={cn(
                    "flex items-center gap-3 rounded-xl border p-4 text-left transition duration-150 focus:outline-none hover:-translate-y-0.5",
                    isChecked
                      ? "border-violet-200 bg-violet-50/40 shadow-sm"
                      : "border-slate-150 bg-white hover:border-slate-250 hover:bg-slate-50"
                  )}
                >
                  <CustomCheckbox checked={isChecked} />
                  <div>
                    <span className={cn(
                      "block text-xs font-black",
                      isChecked ? "text-violet-800" : "text-slate-800"
                    )}>{module}</span>
                  </div>
                </button>
              );
            })}
          </div>
        )}

        {activeTab === "permissions" && (
          <div className="space-y-5">
            {Object.entries(groupedPermissions).map(([group, items]) => (
              <div key={group} className="rounded-xl border border-slate-150 bg-slate-50/20 p-4">
                <p className="text-xs font-black text-slate-500 uppercase tracking-wide border-b border-slate-100 pb-2 mb-3.5">
                  {group}
                </p>
                <div className="grid gap-3 md:grid-cols-2">
                  {items.map((permission) => {
                    const isChecked = selectedPermissions.includes(permission.id);
                    return (
                      <button
                        key={permission.id}
                        type="button"
                        onClick={() => handleTogglePerm(permission.id)}
                        className={cn(
                          "flex items-center gap-3 rounded-xl border p-3.5 text-left transition duration-150 focus:outline-none bg-white",
                          isChecked
                            ? "border-violet-250 bg-violet-50/50 shadow-sm"
                            : "border-slate-150 hover:border-slate-250"
                        )}
                      >
                        <CustomCheckbox checked={isChecked} />
                        <div>
                          <span className={cn(
                            "block text-xs font-black",
                            isChecked ? "text-violet-800" : "text-slate-800"
                          )}>{permission.label}</span>
                          <span className="block text-[9px] font-bold text-slate-450 uppercase tracking-wider mt-0.5">
                            {permission.id}
                          </span>
                        </div>
                      </button>
                    );
                  })}
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </Modal>
  );
}

function CustomCheckbox({ checked, onChange }: { checked: boolean; onChange?: () => void }) {
  return (
    <span
      onClick={onChange}
      className={cn(
        "flex size-5 items-center justify-center rounded-md border transition-all duration-200 cursor-pointer shrink-0",
        checked
          ? "border-violet-600 bg-violet-600 text-white shadow-sm shadow-violet-200"
          : "border-slate-250 bg-slate-50 hover:border-slate-350 text-transparent"
      )}
    >
      <Check className="size-3.5 stroke-[3.5]" />
    </span>
  );
}

function RoleMetric({
  title,
  value,
  icon: Icon,
  tone,
  hint,
}: {
  title: string;
  value: string;
  icon: React.ComponentType<{ className?: string }>;
  tone: "blue" | "green" | "violet" | "orange";
  hint: string;
}) {
  const colors = {
    blue: "bg-blue-50 text-blue-600 border border-blue-100/40",
    green: "bg-emerald-50 text-emerald-600 border border-emerald-100/40",
    violet: "bg-violet-50 text-violet-600 border border-violet-100/40",
    orange: "bg-orange-50 text-orange-600 border border-orange-100/40",
  };
  
  const textColors = {
    blue: "bg-blue-50/50 text-blue-600",
    green: "bg-emerald-50/50 text-emerald-600",
    violet: "bg-violet-50/50 text-violet-600",
    orange: "bg-orange-50/50 text-orange-650",
  };

  return (
    <Card className="border border-slate-100 bg-white rounded-2xl shadow-soft transition-all duration-300 hover:-translate-y-0.5 hover:shadow-md">
      <CardContent className="p-5 flex items-center justify-between">
        <div className="flex items-center gap-4">
          <span className={cn("flex size-11 items-center justify-center rounded-xl", colors[tone])}>
            <Icon className="size-5.5" />
          </span>
          <div>
            <p className="text-2xl font-black text-slate-800 leading-none">{value}</p>
            <p className="text-[10px] font-bold text-slate-400 uppercase tracking-wide mt-2">{title}</p>
          </div>
        </div>
        <Badge className={cn("text-[9px] font-bold uppercase py-0.5 px-2 rounded-lg pointer-events-none", textColors[tone])}>
          {hint}
        </Badge>
      </CardContent>
    </Card>
  );
}
