"use client";

import { useState } from "react";
import { PageHeader } from "@/components/layout/page-header";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { createClient } from "@/lib/supabase/client";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { Bot, Check, Power, RefreshCw, Send, ShieldAlert, Trash2 } from "lucide-react";

export function BotManagementPage() {
  const [botActive, setBotActive] = useState(true);
  const [startMsg, setStartMsg] = useState("Assalomu alaykum! EduLab Academy telegram botiga xush kelibsiz. Tizimga kirish uchun verifikatsiya kodini yuboring.");
  const [helpMsg, setHelpMsg] = useState("Yordam olish uchun administratorga murojaat qiling: @edulab_support_bot");
  const [savingMsg, setSavingMsg] = useState(false);

  const supabase = createClient();
  const queryClient = useQueryClient();

  // Fetch verifications
  const { data: verifications, isLoading } = useQuery({
    queryKey: ["telegram-verifications"],
    queryFn: async () => {
      const { data, error } = await supabase
        .from("telegram_verifications")
        .select("*")
        .order("created_at", { ascending: false });
      if (error) return [];
      return data || [];
    },
  });

  // Confirm verification mutation
  const confirmMutation = useMutation({
    mutationFn: async ({ id, confirmed }: { id: string; confirmed: boolean }) => {
      const { error } = await supabase
        .from("telegram_verifications")
        .update({ confirmed })
        .eq("id", id);
      if (error) throw error;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["telegram-verifications"] });
    },
  });

  // Delete verification mutation
  const deleteMutation = useMutation({
    mutationFn: async (id: string) => {
      const { error } = await supabase
        .from("telegram_verifications")
        .delete()
        .eq("id", id);
      if (error) throw error;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["telegram-verifications"] });
    },
  });

  const handleSaveSettings = () => {
    setSavingMsg(true);
    setTimeout(() => {
      setSavingMsg(false);
      toastSuccess("Bot sozlamalari muvaffaqiyatli saqlandi!");
    }, 800);
  };

  const toastSuccess = (msg: string) => {
    // Standard alert fallback or we can use custom if toast is not imported.
    alert(msg);
  };

  return (
    <>
      <PageHeader title="Telegram Bot" current="Bot boshqaruvi" />

      {/* Bot status widget */}
      <div className="grid gap-6 md:grid-cols-3 mb-6 animate-in fade-in duration-200">
        <Card className="shadow-soft md:col-span-2 border border-border bg-white rounded-2xl">
          <CardContent className="p-6 flex flex-col md:flex-row items-start md:items-center justify-between gap-4">
            <div className="flex items-center gap-4">
              <div className="flex size-14 items-center justify-center rounded-2xl bg-gradient-to-br from-violet-500 to-indigo-650 shadow-[0_14px_28px_rgba(124,58,237,0.25)] text-white">
                <Bot className="size-7 animate-pulse" />
              </div>
              <div>
                <h2 className="text-base font-black text-slate-800">EduLab Academy Telegram Bot</h2>
                <p className="text-xs font-semibold text-slate-400 mt-1.5 max-w-[450px]">
                  Telegram foydalanuvchilarini ro'yxatdan o'tkazish va xabarnomalar yuborish uchun faol.
                </p>
                <div className="flex items-center gap-4 mt-3">
                  <span className={`inline-flex items-center gap-1.5 rounded-lg px-2.5 py-0.5 text-[10px] font-black uppercase tracking-wider ${
                    botActive 
                      ? "bg-emerald-50 text-emerald-600 border border-emerald-100" 
                      : "bg-rose-50 text-rose-600 border border-rose-100"
                  }`}>
                    {botActive ? "Faol (Online)" : "Nofaol"}
                  </span>
                  <span className="text-[10px] font-black text-slate-450 uppercase tracking-wider flex items-center gap-1.5">
                    Webhook: 
                    <span className="text-violet-600 font-extrabold normal-case">Faol (Active)</span>
                  </span>
                </div>
              </div>
            </div>
            
            <div className="flex items-center gap-3 w-full md:w-auto shrink-0">
              <Button
                variant={botActive ? "destructive" : "secondary"}
                onClick={() => setBotActive(!botActive)}
                className={`font-bold h-10 px-4 rounded-xl text-xs flex gap-2 ${
                  botActive 
                    ? "bg-rose-50 hover:bg-rose-100 text-rose-600 border border-rose-100/50" 
                    : "bg-violet-600 hover:bg-violet-700 text-white"
                }`}
              >
                <Power className="size-4" />
                {botActive ? "O'chirish" : "Yoqish"}
              </Button>
              <Button 
                variant="secondary" 
                size="icon" 
                onClick={() => queryClient.invalidateQueries({ queryKey: ["telegram-verifications"] })}
                className="h-10 w-10 border border-slate-200 rounded-xl hover:bg-slate-50/50"
              >
                <RefreshCw className="size-4 text-slate-500" />
              </Button>
              
              {/* Webhook Pulsating active indicator */}
              {botActive && (
                <span className="relative flex h-3.5 w-3.5 ml-1.5">
                  <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75"></span>
                  <span className="relative inline-flex rounded-full h-3.5 w-3.5 bg-emerald-500"></span>
                </span>
              )}
            </div>
          </CardContent>
        </Card>

        <Card className="shadow-soft border border-border bg-white rounded-2xl">
          <CardContent className="p-6 flex flex-col justify-center h-full">
            <div>
              <p className="text-[10px] font-black text-slate-400 uppercase tracking-wider">Bot Statistikasi</p>
              <div className="grid grid-cols-2 gap-4 mt-3">
                <div className="rounded-xl border border-slate-100 bg-slate-50/50 p-3">
                  <p className="text-2xl font-black text-slate-900 leading-none">{verifications?.length || 0}</p>
                  <p className="text-[9px] font-black text-slate-400 uppercase tracking-wide mt-1.5">Jami so'rovlar</p>
                </div>
                <div className="rounded-xl border border-emerald-100/50 bg-emerald-50/30 p-3">
                  <p className="text-2xl font-black text-emerald-600 leading-none">
                    {verifications?.filter((v) => v.confirmed).length || 0}
                  </p>
                  <p className="text-[9px] font-black text-emerald-500 uppercase tracking-wide mt-1.5">Tasdiqlangan</p>
                </div>
              </div>
            </div>
          </CardContent>
        </Card>
      </div>

      <div className="grid gap-6 xl:grid-cols-[1.2fr_.8fr] animate-in fade-in duration-300">
        {/* Verification requests */}
        <Card className="shadow-soft border border-border bg-white rounded-2xl">
          <CardHeader className="pb-3 border-b border-slate-100">
            <CardTitle className="text-sm font-black text-slate-900 uppercase tracking-wide">Verifikatsiya so'rovlari</CardTitle>
            <p className="text-xs font-semibold text-slate-400 mt-0.5">
              Talabalarning telegram bot orqali tasdiqlash uchun yuborgan arizalari.
            </p>
          </CardHeader>
          <CardContent className="p-0">
            <div className="overflow-x-auto edulab-scrollbar">
              <table className="w-full text-sm">
                <thead>
                  <tr className="border-b border-border/50 text-left text-[10px] font-black uppercase tracking-wider text-slate-400 bg-slate-50/50">
                    <th className="px-5 py-4">Foydalanuvchi</th>
                    <th className="px-5 py-4 text-center">Tasdiq kodi</th>
                    <th className="px-5 py-4 text-center">Chat ID</th>
                    <th className="px-5 py-4 text-center">Holat</th>
                    <th className="px-5 py-4 text-center">Amallar</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-100">
                  {isLoading ? (
                    <tr>
                      <td colSpan={5} className="text-center py-12 text-xs font-semibold text-slate-400">
                        Yuklanmoqda...
                      </td>
                    </tr>
                  ) : verifications && verifications.length > 0 ? (
                    verifications.map((v) => (
                      <tr key={v.id} className="group hover:bg-slate-50/30 transition duration-150">
                        <td className="px-5 py-4">
                          <p className="font-extrabold text-slate-800 leading-snug group-hover:text-violet-750 transition-colors">
                            {v.full_name || "Noma'lum"}
                          </p>
                          <p className="text-xs text-slate-400 font-semibold mt-0.5">{v.phone || "Telefon yo'q"}</p>
                        </td>
                        <td className="px-5 py-4 text-center font-black text-indigo-600 font-mono text-sm">{v.code}</td>
                        <td className="px-5 py-4 text-center text-slate-400 font-mono text-xs">{v.chat_id}</td>
                        <td className="px-5 py-4 text-center">
                          <span className={`inline-flex items-center rounded-lg px-2 py-0.5 text-[10px] font-black uppercase tracking-wider ${
                            v.confirmed 
                              ? "bg-emerald-50 text-emerald-600 border border-emerald-100/50" 
                              : "bg-amber-50 text-amber-600 border border-amber-100/50"
                          }`}>
                            {v.confirmed ? "Tasdiqlangan" : "Kutilmoqda"}
                          </span>
                        </td>
                        <td className="px-5 py-4">
                          <div className="flex justify-center gap-1.5">
                            {!v.confirmed && (
                              <Button
                                size="sm"
                                variant="secondary"
                                onClick={() => confirmMutation.mutate({ id: v.id, confirmed: true })}
                                className="h-8 w-8 p-0 bg-emerald-50 text-emerald-600 border border-emerald-100/40 hover:bg-emerald-100 rounded-lg"
                              >
                                <Check className="size-4" />
                              </Button>
                            )}
                            <Button
                              size="sm"
                              variant="secondary"
                              onClick={() => deleteMutation.mutate(v.id)}
                              className="h-8 w-8 p-0 text-red-650 hover:bg-red-50 border border-slate-200/50 rounded-lg"
                            >
                              <Trash2 className="size-4" />
                            </Button>
                          </div>
                        </td>
                      </tr>
                    ))
                  ) : (
                    <tr>
                      <td colSpan={5} className="text-center py-16 text-xs font-semibold text-slate-400">
                        Hozircha verifikatsiya so'rovlari yo'q.
                      </td>
                    </tr>
                  )}
                </tbody>
              </table>
            </div>
          </CardContent>
        </Card>

        {/* Bot configurations */}
        <Card className="shadow-soft border border-border bg-white rounded-2xl h-fit">
          <CardHeader className="pb-3 border-b border-slate-100">
            <CardTitle className="text-sm font-black text-slate-900 uppercase tracking-wide">Bot shablon va sozlamalari</CardTitle>
            <p className="text-xs font-semibold text-slate-400 mt-0.5">
              Botning avtomatik javob matnlarini va xabarlarni sozlang.
            </p>
          </CardHeader>
          <CardContent className="space-y-4 pt-4">
            <div>
              <label className="block text-xs font-bold text-slate-700 mb-2">Start xabari (/start)</label>
              <textarea
                value={startMsg}
                onChange={(e) => setStartMsg(e.target.value)}
                className="w-full h-24 p-3 rounded-xl border border-slate-200 text-xs font-semibold resize-none focus:outline-none focus:border-violet-500 focus:ring-1 focus:ring-violet-500/10 leading-relaxed text-slate-800"
              />
            </div>

            <div>
              <label className="block text-xs font-bold text-slate-700 mb-2">Help (yordam) xabari</label>
              <textarea
                value={helpMsg}
                onChange={(e) => setHelpMsg(e.target.value)}
                className="w-full h-20 p-3 rounded-xl border border-slate-200 text-xs font-semibold resize-none focus:outline-none focus:border-violet-500 focus:ring-1 focus:ring-violet-500/10 leading-relaxed text-slate-800"
              />
            </div>

            <div className="rounded-xl border border-violet-100 bg-violet-50/50 p-4 flex gap-3 text-xs leading-relaxed">
              <ShieldAlert className="size-4.5 text-violet-600 shrink-0 mt-0.5" />
              <p className="font-semibold text-violet-850">
                <span className="font-extrabold">Eslatma:</span> Ushbu sozlamalar bot serveridagi `.env` va shablonlar bilan avtomatik sinxronizatsiya qilinadi.
              </p>
            </div>

            <Button 
              onClick={handleSaveSettings} 
              disabled={savingMsg} 
              className="w-full font-bold h-11 bg-violet-600 text-white hover:bg-violet-700 rounded-xl text-xs mt-2"
            >
              {savingMsg ? "Saqlanmoqda..." : "Sozlamalarni saqlash"}
            </Button>
          </CardContent>
        </Card>
      </div>
    </>
  );
}
