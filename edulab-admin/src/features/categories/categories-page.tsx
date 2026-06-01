"use client";

import { useState } from "react";
import { PageHeader } from "@/components/layout/page-header";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { createClient } from "@/lib/supabase/client";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { Edit, Plus, Tags, Trash2 } from "lucide-react";

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
      <PageHeader title="Kurs Kategoriyalari" current="Kategoriyalar" />

      <div className="grid gap-6 xl:grid-cols-[1fr_400px]">
        {/* Categories list */}
        <Card className="shadow-soft">
          <CardHeader>
            <CardTitle className="text-lg font-extrabold flex items-center gap-2">
              <Tags className="size-5 text-primary" />
              Mavjud Kategoriyalar
            </CardTitle>
          </CardHeader>
          <CardContent className="p-0">
            <div className="overflow-x-auto edulab-scrollbar">
              <table className="w-full text-sm">
                <thead className="bg-slate-50 text-left text-xs font-bold uppercase text-slate-500">
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
                      <tr key={c.id} className="border-t border-border hover:bg-slate-50/50">
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
        <Card className="shadow-soft h-fit">
          <CardHeader>
            <CardTitle className="text-lg font-extrabold">
              {editingId ? "Kategoriyani tahrirlash" : "Yangi kategoriya qo'shish"}
            </CardTitle>
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
              <textarea
                value={description}
                onChange={(e) => setDescription(e.target.value)}
                placeholder="Kategoriya haqida qisqacha ma'lumot..."
                className="w-full h-24 p-3 rounded-2xl border border-border text-sm resize-none focus:outline-none focus:border-blue-500"
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
