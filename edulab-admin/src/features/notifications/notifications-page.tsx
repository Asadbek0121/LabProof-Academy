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
import { Bell, BellOff, BellRing, Megaphone, Plus, Send, Trash2, ToggleLeft, ToggleRight, X } from "lucide-react";

export function NotificationsPage() {
  const [showCreate, setShowCreate] = useState(false);
  const [title, setTitle] = useState("");
  const [body, setBody] = useState("");
  const [targetRole, setTargetRole] = useState("student");

  const supabase = createClient();
  const queryClient = useQueryClient();

  // Fetch all broadcast notifications
  const { data: notifications, isLoading } = useQuery({
    queryKey: ["broadcast-notifications"],
    queryFn: async () => {
      const { data, error } = await supabase
        .from("notifications")
        .select("*")
        .is("reply_to_inbox_message_id", null)
        .order("created_at", { ascending: false });
      if (error) return [];
      return data || [];
    },
  });

  // Create notification
  const createMutation = useMutation({
    mutationFn: async () => {
      const { error } = await supabase.from("notifications").insert({
        title,
        body,
        target_role: targetRole,
        is_active: true,
        message_kind: "text",
      });
      if (error) throw error;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["broadcast-notifications"] });
      setTitle("");
      setBody("");
      setShowCreate(false);
    },
  });

  // Toggle active status
  const toggleMutation = useMutation({
    mutationFn: async ({ id, is_active }: { id: string; is_active: boolean }) => {
      const { error } = await supabase
        .from("notifications")
        .update({ is_active })
        .eq("id", id);
      if (error) throw error;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["broadcast-notifications"] });
    },
  });

  // Delete notification
  const deleteMutation = useMutation({
    mutationFn: async (id: string) => {
      const { error } = await supabase.from("notifications").delete().eq("id", id);
      if (error) throw error;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["broadcast-notifications"] });
    },
  });

  const activeCount = notifications?.filter((n) => n.is_active).length || 0;
  const totalCount = notifications?.length || 0;

  const notifStats = [
    { title: "Jami bildirishnomalar", value: String(totalCount), hint: "Barcha yuborilganlar", tone: "violet" as const, icon: Bell },
    { title: "Faol bildirishnomalar", value: String(activeCount), hint: "Hozirda faol", tone: "green" as const, icon: BellRing },
    { title: "O'chirilganlar", value: String(totalCount - activeCount), hint: "Nofaollar", tone: "orange" as const, icon: BellOff },
  ];

  return (
    <>
      <PageHeader
        title="Xabarnomalar"
        current="Ommaviy bildirishnomalar"
        action={
          <Button onClick={() => setShowCreate(true)} className="flex gap-2 font-bold px-5 bg-violet-600 text-white hover:bg-violet-700 rounded-xl h-10 text-xs shadow-sm">
            <Plus className="size-4" />
            Yangi bildirishnoma
          </Button>
        }
      />

      <div className="grid gap-4 md:grid-cols-3 mb-6 animate-in fade-in duration-200">
        {notifStats.map((item) => (
          <StatCard key={item.title} item={item} />
        ))}
      </div>

      <div className="grid gap-6 xl:grid-cols-[1fr_400px] animate-in fade-in duration-350">
        {/* Notifications list */}
        <Card className="shadow-soft border border-border bg-white rounded-2xl">
          <CardHeader className="border-b border-slate-100 pb-3.5">
            <CardTitle className="text-sm font-black text-slate-900 uppercase tracking-wide flex items-center gap-2">
              <Megaphone className="size-4.5 text-violet-600 animate-pulse" />
              Yuborilgan Bildirishnomalar
            </CardTitle>
          </CardHeader>
          <CardContent className="p-0">
            <div className="overflow-x-auto edulab-scrollbar">
              <table className="w-full text-sm">
                <thead>
                  <tr className="border-b border-border/50 text-left text-[10px] font-black uppercase tracking-wider text-slate-400 bg-slate-50/50">
                    <th className="px-5 py-4">Sarlavha</th>
                    <th className="px-5 py-4">Matn</th>
                    <th className="px-5 py-4 text-center">Maqsadli guruh</th>
                    <th className="px-5 py-4 text-center">Holat</th>
                    <th className="px-5 py-4 text-center">Sana</th>
                    <th className="px-5 py-4 text-center">Amallar</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-100">
                  {isLoading ? (
                    <tr>
                      <td colSpan={6} className="text-center py-12 text-xs font-semibold text-slate-400">
                        Yuklanmoqda...
                      </td>
                    </tr>
                  ) : notifications && notifications.length > 0 ? (
                    notifications.map((n) => (
                      <tr key={n.id} className="group hover:bg-slate-50/30 transition duration-150">
                        <td className="px-5 py-4 font-bold text-slate-800 max-w-[200px] truncate group-hover:text-violet-755 transition-colors">
                          {n.title}
                        </td>
                        <td className="px-5 py-4 text-slate-500 font-semibold max-w-[240px] truncate">{n.body}</td>
                        <td className="px-5 py-4 text-center">
                          <span className={`inline-flex items-center rounded-lg px-2 py-0.5 text-[10px] font-black uppercase tracking-wider ${
                            n.target_role === "student" 
                              ? "bg-violet-50 text-violet-605 border border-violet-100" 
                              : n.target_role === "admin" 
                                ? "bg-amber-50 text-amber-600 border border-amber-100" 
                                : "bg-slate-50 text-slate-600 border border-slate-150"
                          }`}>
                            {n.target_role === "student" ? "Talabalar" : n.target_role === "admin" ? "Adminlar" : "Barchaga"}
                          </span>
                        </td>
                        <td className="px-5 py-4 text-center">
                          <Badge variant={n.is_active ? "success" : "warning"}>
                            {n.is_active ? "Faol" : "Nofaol"}
                          </Badge>
                        </td>
                        <td className="px-5 py-4 text-center text-slate-450 font-bold text-xs">
                          {new Date(n.created_at).toLocaleDateString("uz-UZ")}{" "}
                          {new Date(n.created_at).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })}
                        </td>
                        <td className="px-5 py-4">
                          <div className="flex justify-center gap-1.5">
                            <Button
                              size="sm"
                              variant="secondary"
                              onClick={() => toggleMutation.mutate({ id: n.id, is_active: !n.is_active })}
                              className={`h-8 w-8 p-0 rounded-lg border ${
                                n.is_active 
                                  ? "text-orange-500 hover:bg-orange-50 border-orange-100/50" 
                                  : "text-emerald-500 hover:bg-emerald-50 border-emerald-100/50"
                              }`}
                            >
                              {n.is_active ? <ToggleRight className="size-4" /> : <ToggleLeft className="size-4" />}
                            </Button>
                            <Button
                              size="sm"
                              variant="secondary"
                              onClick={() => deleteMutation.mutate(n.id)}
                              className="h-8 w-8 p-0 text-red-650 hover:bg-red-50 border border-slate-200/55 rounded-lg"
                            >
                              <Trash2 className="size-4" />
                            </Button>
                          </div>
                        </td>
                      </tr>
                    ))
                  ) : (
                    <tr>
                      <td colSpan={6} className="text-center py-16 text-xs font-semibold text-slate-400">
                        <Bell className="mx-auto mb-2.5 text-slate-300 size-8 animate-pulse" />
                        Hozircha bildirishnomalar yuborilmagan.
                      </td>
                    </tr>
                  )}
                </tbody>
              </table>
            </div>
          </CardContent>
        </Card>

        {/* Create form */}
        <div className="min-w-0">
          {showCreate ? (
            <Card className="shadow-soft border border-border bg-white rounded-2xl h-fit sticky top-24 animate-in zoom-in-95 duration-200">
              <CardHeader className="border-b border-slate-100 flex flex-row items-center justify-between pb-3.5">
                <CardTitle className="text-sm font-black text-slate-900 uppercase tracking-wide">Yangi bildirishnoma</CardTitle>
                <Button variant="ghost" size="icon" onClick={() => setShowCreate(false)} className="h-8 w-8 rounded-lg text-slate-400 hover:bg-slate-50">
                  <X className="size-4" />
                </Button>
              </CardHeader>
              <CardContent className="p-5 space-y-4">
                <div>
                  <label className="block text-xs font-bold text-slate-700 mb-2">Sarlavha *</label>
                  <Input
                    value={title}
                    onChange={(e) => setTitle(e.target.value)}
                    placeholder="Masalan: Yangi modul qo'shildi!"
                    className="h-10.5 rounded-xl border-slate-200 text-sm font-semibold text-slate-800 focus:border-violet-500"
                  />
                </div>

                <div>
                  <label className="block text-xs font-bold text-slate-700 mb-2">Bildirishnoma matni *</label>
                  <textarea
                    value={body}
                    onChange={(e) => setBody(e.target.value)}
                    placeholder="Batafsil xabar matni..."
                    className="w-full h-28 p-3 rounded-xl border border-slate-200 text-xs font-semibold resize-none focus:outline-none focus:border-violet-500 focus:ring-1 focus:ring-violet-500/10 leading-relaxed text-slate-800"
                  />
                </div>

                <div>
                  <label className="block text-xs font-bold text-slate-700 mb-2">Maqsadli guruh</label>
                  <Select
                    className="w-full font-bold text-xs uppercase tracking-wider text-slate-500 h-10.5 rounded-xl"
                    value={targetRole}
                    onChange={(e) => setTargetRole(e.target.value)}
                  >
                    <option value="student">Talabalarga</option>
                    <option value="admin">Adminlarga</option>
                    <option value="all">Barchaga</option>
                  </Select>
                </div>

                <div className="rounded-xl border border-emerald-100 bg-emerald-50/40 p-4 flex gap-3 text-xs leading-relaxed text-emerald-800">
                  <Send className="size-4.5 text-emerald-600 shrink-0 mt-0.5 animate-bounce" />
                  <p className="font-semibold">
                    <span className="font-extrabold">Eslatma:</span> Bildirishnoma yuborilganidan so'ng barcha maqsadli foydalanuvchilar ilovasida ko'rinadi.
                  </p>
                </div>

                <Button
                  disabled={!title.trim() || !body.trim() || createMutation.isPending}
                  onClick={() => createMutation.mutate()}
                  className="w-full font-bold h-11 bg-violet-600 text-white hover:bg-violet-700 rounded-xl text-xs flex gap-2"
                >
                  <Send className="size-4 text-white" />
                  {createMutation.isPending ? "Yuborilmoqda..." : "Bildirishnomani yuborish"}
                </Button>
              </CardContent>
            </Card>
          ) : (
            <Card className="border border-dashed border-slate-200 bg-slate-50/30 p-8 rounded-2xl text-center flex flex-col items-center justify-center h-48 cursor-pointer hover:border-violet-300 hover:bg-slate-50 transition" onClick={() => setShowCreate(true)}>
              <Plus className="size-8 text-slate-350 mb-3" />
              <p className="text-xs font-extrabold text-slate-650">Yangi ommaviy xabarnoma yozish</p>
              <p className="text-[10px] text-slate-400 font-semibold mt-1">Barcha foydalanuvchilarga bildirishnoma yuboring</p>
            </Card>
          )}
        </div>
      </div>
    </>
  );
}
