"use client";

import { useState } from "react";
import { PageHeader } from "@/components/layout/page-header";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input, Textarea } from "@/components/ui/input";
import { createClient } from "@/lib/supabase/client";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { CheckCircle2, Edit, FolderTree, Plus, Tags, Trash2 } from "lucide-react";

export function CategoriesPage() {
  const [name, setName] = useState("");
  const [description, setDescription] = useState("");
  const [editingId, setEditingId] = useState<string | null>(null);

  const supabase = createClient();
  const queryClient = useQueryClient();

  // Fetch categories
  const { data: categories, isLoading } = useQuery({
    queryKey: ["categories"],
    queryFn: async () => {
      const { data, error } = await supabase
        .from("categories")
        .select("*")
        .order("created_at", { ascending: false });
      if (error) return [];
      return data || [];
    },
  });

  // Create or Update mutation
  const saveMutation = useMutation({
    mutationFn: async () => {
      if (editingId) {
        const { error } = await supabase
          .from("categories")
          .update({ name, description })
          .eq("id", editingId);
        if (error) throw error;
      } else {
        const { error } = await supabase
          .from("categories")
          .insert([{ name, description }]);
        if (error) throw error;
      }
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["categories"] });
      setName("");
      setDescription("");
      setEditingId(null);
    },
  });

  // Delete mutation
  const deleteMutation = useMutation({
    mutationFn: async (id: string) => {
      const { error } = await supabase.from("categories").delete().eq("id", id);
      if (error) throw error;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["categories"] });
    },
  });

  const handleEdit = (category: any) => {
    setEditingId(category.id);
    setName(category.name);
    setDescription(category.description || "");
  };

  const handleCancel = () => {
    setEditingId(null);
    setName("");
    setDescription("");
  };

  return (
    <>
      <PageHeader
        title="Kurs kategoriyalari"
        current="Kategoriyalar"
        action={
          <Button
            onClick={() => {
              setEditingId(null);
              setName("");
              setDescription("");
            }}
          >
            <Plus className="size-4" />
            Yangi kategoriya
          </Button>
        }
      />

      <div className="mb-5 grid gap-4 md:grid-cols-3">
        <div className="rounded-lg border border-slate-200 bg-white p-4 shadow-sm">
          <div className="flex items-center gap-3">
            <span className="flex size-10 items-center justify-center rounded-lg bg-blue-50 text-blue-600">
              <Tags className="size-5" />
            </span>
            <div>
              <p className="text-xs font-extrabold uppercase tracking-wide text-slate-400">Jami</p>
              <p className="text-2xl font-black text-slate-950">{categories?.length ?? 0}</p>
            </div>
          </div>
        </div>
        <div className="rounded-lg border border-slate-200 bg-white p-4 shadow-sm">
          <div className="flex items-center gap-3">
            <span className="flex size-10 items-center justify-center rounded-lg bg-emerald-50 text-emerald-600">
              <CheckCircle2 className="size-5" />
            </span>
            <div>
              <p className="text-xs font-extrabold uppercase tracking-wide text-slate-400">Student app</p>
              <p className="text-sm font-bold text-slate-800">Modul va kurslarga ulanadi</p>
            </div>
          </div>
        </div>
        <div className="rounded-lg border border-slate-200 bg-white p-4 shadow-sm">
          <div className="flex items-center gap-3">
            <span className="flex size-10 items-center justify-center rounded-lg bg-indigo-50 text-indigo-600">
              <FolderTree className="size-5" />
            </span>
            <div>
              <p className="text-xs font-extrabold uppercase tracking-wide text-slate-400">Tartib</p>
              <p className="text-sm font-bold text-slate-800">Kategoriyalar nomi aniq bo‘lsin</p>
            </div>
          </div>
        </div>
      </div>

      <div className="grid gap-6 xl:grid-cols-[1fr_400px]">
        {/* Categories list */}
        <Card className="overflow-hidden">
          <CardHeader>
            <div>
              <CardTitle className="flex items-center gap-2 text-lg font-extrabold">
                <Tags className="size-5 text-primary" />
                Mavjud kategoriyalar
              </CardTitle>
              <CardDescription>Student app modullari shu kategoriyalar bilan guruhlanadi.</CardDescription>
            </div>
          </CardHeader>
          <CardContent className="p-0">
            <div className="overflow-x-auto edulab-scrollbar">
              <table className="w-full text-sm">
                <thead className="border-b border-slate-200 bg-slate-50 text-left text-xs font-extrabold uppercase tracking-wide text-slate-500">
                  <tr>
                    <th className="px-5 py-4">Nomi</th>
                    <th className="px-5 py-4">Tavsifi</th>
                    <th className="px-5 py-4 text-center">Yaratilgan sana</th>
                    <th className="px-5 py-4 text-center">Amallar</th>
                  </tr>
                </thead>
                <tbody>
                  {isLoading ? (
                    <tr>
                      <td colSpan={4} className="text-center py-8 text-sm font-semibold text-slate-400">
                        Yuklanmoqda...
                      </td>
                    </tr>
                  ) : categories && categories.length > 0 ? (
                    categories.map((c) => (
                      <tr key={c.id} className="border-t border-slate-100 hover:bg-blue-50/40">
                        <td className="px-5 py-4 font-bold text-slate-800">{c.name}</td>
                        <td className="px-5 py-4 text-slate-600 max-w-[280px] truncate">{c.description || "-"}</td>
                        <td className="px-5 py-4 text-center text-slate-500">
                          {new Date(c.created_at).toLocaleDateString("uz-UZ")}
                        </td>
                        <td className="px-5 py-4">
                          <div className="flex justify-center gap-2">
                            <Button size="sm" variant="secondary" onClick={() => handleEdit(c)}>
                              <Edit className="size-4" />
                            </Button>
                            <Button
                              size="sm"
                              variant="secondary"
                              onClick={() => {
                                if (confirm("Haqiqatan ham bu kategoriyani o'chirib tashlamoqchimisiz?")) {
                                  deleteMutation.mutate(c.id);
                                }
                              }}
                              className="text-red-600 hover:bg-red-50"
                            >
                              <Trash2 className="size-4" />
                            </Button>
                          </div>
                        </td>
                      </tr>
                    ))
                  ) : (
                    <tr>
                      <td colSpan={4} className="text-center py-8 text-sm font-semibold text-slate-400">
                        Hozircha kategoriyalar yo'q.
                      </td>
                    </tr>
                  )}
                </tbody>
              </table>
            </div>
          </CardContent>
        </Card>

        {/* Create/Edit form */}
        <Card className="h-fit">
          <CardHeader>
            <div>
              <CardTitle className="text-lg font-extrabold">
                {editingId ? "Kategoriyani tahrirlash" : "Yangi kategoriya qo'shish"}
              </CardTitle>
              <CardDescription>
                Nom va tavsif student appdagi learning oqimida tushunarli ko‘rinadi.
              </CardDescription>
            </div>
          </CardHeader>
          <CardContent className="space-y-4">
            <div>
              <label className="block text-sm font-bold text-slate-700 mb-2">Kategoriya nomi</label>
              <Input
                value={name}
                onChange={(e) => setName(e.target.value)}
                placeholder="Masalan: Biokimyo, Mikrobiologiya..."
              />
            </div>

            <div>
              <label className="block text-sm font-bold text-slate-700 mb-2">Kategoriya tavsifi</label>
              <Textarea
                value={description}
                onChange={(e) => setDescription(e.target.value)}
                placeholder="Kategoriya haqida qisqacha ma'lumot..."
                className="h-28"
              />
            </div>

            <div className="flex gap-3 pt-2">
              {editingId && (
                <Button variant="secondary" className="flex-1" onClick={handleCancel}>
                  Bekor qilish
                </Button>
              )}
              <Button
                disabled={!name.trim() || saveMutation.isPending}
                onClick={() => saveMutation.mutate()}
                className="flex-1 font-bold"
              >
                {editingId ? "Saqlash" : "Qo'shish"}
              </Button>
            </div>
          </CardContent>
        </Card>
      </div>
    </>
  );
}
