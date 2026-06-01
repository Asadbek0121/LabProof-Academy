"use client";

import { useMemo, useState } from "react";
import {
  FileText,
  ImageIcon,
  Mic,
  MoreVertical,
  Paperclip,
  Play,
  Search,
  Send,
  SlidersHorizontal,
  Smile,
  Trash2,
  Video,
  ChevronRight,
  Bot
} from "lucide-react";
import { PageHeader } from "@/components/layout/page-header";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { useConversations } from "@/hooks/use-admin-data";
import { cn } from "@/lib/utils";
import type { ChatMessage } from "@/lib/types";
import { createClient } from "@/lib/supabase/client";
import { useQueryClient } from "@tanstack/react-query";

export function SupportRequestsPage() {
  const conversations = useConversations();
  const [selectedId, setSelectedId] = useState("");
  const [activeTab, setActiveTab] = useState<"bot" | "app">("bot");
  const [inboxSearch, setInboxSearch] = useState("");
  
  const selected = useMemo(() => {
    if (!conversations.data?.length) return null;
    return conversations.data.find((item) => item.id === selectedId) ?? conversations.data[0];
  }, [conversations.data, selectedId]);

  const filteredConversations = useMemo(() => {
    if (!conversations.data) return [];
    return conversations.data.filter((item) => {
      // Filter by active tab (source: telegram for bot, otherwise app)
      const matchesTab = activeTab === "bot" ? item.source === "telegram" : item.source !== "telegram";
      // Filter by search
      const matchesSearch = item.name.toLowerCase().includes(inboxSearch.toLowerCase()) || 
        (item.lastMessage || "").toLowerCase().includes(inboxSearch.toLowerCase());
      return matchesTab && matchesSearch;
    });
  }, [conversations.data, activeTab, inboxSearch]);

  const chatStats = useMemo(() => {
    if (!selected) {
      return {
        total: 0,
        today: 0,
        unread: 0,
        images: 0,
        videos: 0,
        voices: 0,
        files: 0,
      };
    }
    const messages = selected.messages || [];
    const total = messages.length;
    const unread = messages.filter((m) => m.author === "student" && !m.read).length;

    const todayStr = new Date().toDateString();
    const today = messages.filter((m) => {
      if (!m.createdAt) return false;
      return new Date(m.createdAt).toDateString() === todayStr;
    }).length;

    const images = messages.filter((m) => m.kind === "image").length;
    const videos = messages.filter((m) => m.kind === "video" || m.kind === "round_video").length;
    const voices = messages.filter((m) => m.kind === "voice").length;
    const files = messages.filter((m) => m.kind === "pdf" || m.kind === "document" || m.kind === "file").length;

    return { total, today, unread, images, videos, voices, files };
  }, [selected]);

  const [replyText, setReplyText] = useState("");
  const [sending, setSending] = useState(false);
  const supabase = createClient();
  const queryClient = useQueryClient();

  const handleSend = async () => {
    if (!replyText.trim() || !selected) return;

    setSending(true);
    try {
      const studentMessages = selected.messages.filter((m) => m.author === "student");
      const unanswered = studentMessages[studentMessages.length - 1];

      if (unanswered && unanswered.id) {
        const { error } = await supabase
          .from("admin_inbox_messages")
          .update({
            admin_reply: replyText.trim(),
            replied_at: new Date().toISOString(),
            is_read: true,
            admin_read_at: new Date().toISOString(),
          })
          .eq("id", unanswered.id);

        if (error) throw error;

        if (selected.id && selected.id.includes("-")) {
          const { error: notifError } = await supabase.from("notifications").insert({
            title: "Yordam bo'limidan javob",
            body: replyText.trim(),
            target_role: "student",
            target_user_id: selected.id,
            reply_to_inbox_message_id: unanswered.id,
            is_active: true,
            message_kind: "text"
          });
          if (notifError) console.error("Notifikatsiya yaratishda xatolik:", notifError);
        }
      } else {
        const { error } = await supabase
          .from("admin_inbox_messages")
          .insert({
            sender_user_id: selected.id.includes("-") ? selected.id : null,
            telegram_chat_id: !selected.id.includes("-") ? selected.id : null,
            sender_name: selected.name,
            sender_phone: "",
            body: "",
            admin_reply: replyText.trim(),
            replied_at: new Date().toISOString(),
            source: selected.source,
            is_read: true,
            admin_read_at: new Date().toISOString(),
          });

        if (error) throw error;

        if (selected.id && selected.id.includes("-")) {
           const { error: notifError } = await supabase.from("notifications").insert({
            title: "Yordam bo'limidan xabar",
            body: replyText.trim(),
            target_role: "student",
            target_user_id: selected.id,
            is_active: true,
            message_kind: "text"
          });
          if (notifError) console.error("Notifikatsiya yaratishda xatolik:", notifError);
        }
      }

      setReplyText("");
      queryClient.invalidateQueries({ queryKey: ["conversations"] });
    } catch (error) {
      console.error("Xabar yuborishda xatolik:", error);
    } finally {
      setSending(false);
    }
  };

  const handleSelectConversation = async (id: string) => {
    setSelectedId(id);
    const conv = conversations.data?.find((item) => item.id === id);
    if (conv && conv.unread > 0) {
      try {
        const unreadStudentMessages = conv.messages.filter(
          (m) => m.author === "student" && !m.read,
        );
        for (const m of unreadStudentMessages) {
          await supabase
            .from("admin_inbox_messages")
            .update({
              is_read: true,
              admin_read_at: new Date().toISOString(),
            })
            .eq("id", m.id);
        }
        queryClient.invalidateQueries({ queryKey: ["conversations"] });
      } catch (err) {
        console.error("Xabarni o'qildi qilishda xatolik:", err);
      }
    }
  };

  return (
    <>
      <PageHeader title="Yordam So'rovlari" current="Support & Live Chat" />
      
      <div className="grid min-h-[760px] gap-6 xl:grid-cols-[380px_1fr_340px] animate-in fade-in duration-200">
        {/* Left conversations list */}
        <Card className="overflow-hidden border border-border shadow-soft bg-white flex flex-col rounded-2xl h-[780px]">
          <div className="flex gap-2.5 border-b border-slate-100 p-4 bg-slate-50/50">
            <button 
              onClick={() => setActiveTab("bot")}
              className={cn(
                "flex-1 h-9 rounded-xl text-xs font-bold transition-all duration-200 flex items-center justify-center gap-1.5",
                activeTab === "bot" 
                  ? "bg-white text-violet-600 shadow-sm border border-slate-200/50 font-black" 
                  : "text-slate-500 hover:bg-slate-100/50"
              )}
            >
              <Bot className="size-3.5" />
              Telegram bot
            </button>
            <button 
              onClick={() => setActiveTab("app")}
              className={cn(
                "flex-1 h-9 rounded-xl text-xs font-bold transition-all duration-200 flex items-center justify-center gap-1.5",
                activeTab === "app" 
                  ? "bg-white text-violet-600 shadow-sm border border-slate-200/50 font-black" 
                  : "text-slate-500 hover:bg-slate-100/50"
              )}
            >
              <FileText className="size-3.5" />
              Student ilovasi
            </button>
          </div>
          
          <div className="flex gap-2 border-b border-slate-100 p-4">
            <div className="relative flex-1">
              <Search className="absolute left-3.5 top-1/2 size-4 -translate-y-1/2 text-slate-400" />
              <Input 
                value={inboxSearch}
                onChange={(e) => setInboxSearch(e.target.value)}
                placeholder="Suhbatdoshni qidirish..." 
                className="pl-10 h-10 rounded-xl border-slate-200 text-xs font-semibold focus:border-violet-500" 
              />
            </div>
            <Button variant="secondary" size="icon" className="h-10 w-10 border border-slate-200 rounded-xl hover:bg-slate-50">
              <SlidersHorizontal className="size-4 text-slate-500" />
            </Button>
          </div>

          <div className="flex-1 overflow-y-auto p-2 edulab-scrollbar divide-y divide-slate-50">
            {filteredConversations.length > 0 ? (
              filteredConversations.map((conversation) => {
                const isSelected = selectedId === conversation.id || (!selectedId && conversations.data?.[0]?.id === conversation.id);
                return (
                  <button
                    key={conversation.id}
                    onClick={() => handleSelectConversation(conversation.id)}
                    className={cn(
                      "flex w-full items-center gap-3 rounded-xl p-3 text-left transition duration-150 border border-transparent mt-1 first:mt-0",
                      isSelected 
                        ? "bg-violet-50/60 border-violet-100 shadow-sm" 
                        : "hover:bg-slate-50/60",
                    )}
                  >
                    <span className={cn(
                      "flex size-11 shrink-0 items-center justify-center rounded-xl text-white shadow-sm font-black text-sm", 
                      conversation.source === "telegram" 
                        ? "bg-gradient-to-br from-blue-500 to-indigo-600 shadow-blue-100" 
                        : "bg-gradient-to-br from-violet-50 to-indigo-100 text-violet-600 border border-violet-150"
                    )}>
                      {conversation.source === "telegram" ? <Send className="size-5 text-white" /> : conversation.name[0].toUpperCase()}
                    </span>
                    <span className="min-w-0 flex-1">
                      <span className="flex items-center justify-between gap-2">
                        <span className={cn("truncate text-xs font-extrabold text-slate-800", isSelected && "text-violet-950 font-black")}>
                          {conversation.name}
                        </span>
                        <span className="text-[10px] font-bold text-slate-400 shrink-0">{conversation.time}</span>
                      </span>
                      <p className="truncate text-xs text-slate-400 font-semibold mt-1 max-w-[200px]">
                        {conversation.lastMessage}
                      </p>
                    </span>
                    {conversation.unread > 0 ? (
                      <span className="flex size-4.5 shrink-0 items-center justify-center rounded-full bg-violet-600 text-[9px] font-black text-white ml-1">
                        {conversation.unread}
                      </span>
                    ) : null}
                  </button>
                );
              })
            ) : (
              <div className="py-20 text-center text-xs font-semibold text-slate-400 flex flex-col items-center justify-center gap-2">
                <Bot className="size-8 text-slate-300" />
                Suhbatlar topilmadi
              </div>
            )}
          </div>
          
          <div className="border-t border-slate-100 bg-slate-50/20 px-5 py-3.5 text-xs font-bold text-slate-400">
            Jami {filteredConversations.length} ta faol suhbat
          </div>
        </Card>

        {/* Middle message timeline workspace */}
        <Card className="overflow-hidden border border-border shadow-soft bg-white flex flex-col rounded-2xl h-[780px]">
          <header className="flex items-center justify-between border-b border-slate-150/60 p-4.5 bg-slate-50/30">
            <div className="flex items-center gap-3">
              <span className={cn(
                "flex size-11 items-center justify-center rounded-xl text-white font-black text-sm shadow-sm", 
                selected?.source === "telegram" 
                  ? "bg-gradient-to-br from-blue-500 to-indigo-600" 
                  : "bg-gradient-to-br from-violet-50 to-indigo-100 text-violet-600 border border-violet-100"
              )}>
                {selected?.source === "telegram" ? <Send className="size-5" /> : selected?.name[0].toUpperCase()}
              </span>
              <div>
                <div className="flex items-center gap-2">
                  <h2 className="text-sm font-black text-slate-800 leading-none">{selected?.name}</h2>
                  {selected?.label ? (
                    <span className="inline-flex items-center rounded-lg bg-violet-50 text-violet-600 border border-violet-100/50 px-2 py-0.5 text-[9px] font-black uppercase tracking-wider">
                      {selected.label}
                    </span>
                  ) : null}
                </div>
                <div className="flex items-center gap-1.5 mt-1">
                  <span className={cn("size-2 rounded-full", selected?.online ? "bg-emerald-500 animate-pulse" : "bg-slate-300")} />
                  <span className="text-[10px] font-bold text-slate-400">
                    {selected?.online ? "Onlayn" : "Offline"}
                  </span>
                </div>
              </div>
            </div>
            <div className="flex gap-2">
              <Button variant="secondary" size="icon" className="h-9 w-9 border border-slate-200 rounded-lg hover:bg-slate-50">
                <Search className="size-4 text-slate-500" />
              </Button>
              <Button variant="secondary" size="icon" className="h-9 w-9 border border-slate-200 rounded-lg hover:bg-slate-50">
                <MoreVertical className="size-4 text-slate-500" />
              </Button>
            </div>
          </header>

          <div className="flex-1 overflow-y-auto p-5 bg-slate-50/30 edulab-scrollbar flex flex-col gap-4">
            <div className="mb-2 text-center">
              <span className="inline-flex rounded-xl bg-slate-100 border border-slate-200/55 px-3 py-1 text-[9px] font-black uppercase text-slate-400 tracking-wider">
                Muloqot tarixi
              </span>
            </div>
            
            {selected?.messages && selected.messages.length > 0 ? (
              selected.messages.map((message) => (
                <MessageBubble key={message.id} message={message} />
              ))
            ) : (
              <div className="my-auto text-center text-xs font-semibold text-slate-400 flex flex-col items-center justify-center gap-2">
                <Send className="size-10 text-slate-200" />
                Xabarlar mavjud emas. Suhbatni boshlang.
              </div>
            )}
          </div>

          <footer className="flex items-center gap-2.5 border-t border-slate-100 p-4 bg-white">
            <Button variant="ghost" size="icon" className="h-10 w-10 text-slate-400 hover:text-slate-600 hover:bg-slate-50 rounded-xl"><Paperclip className="size-4.5" /></Button>
            <Input
              placeholder="Javob yozing..."
              className="h-11 flex-1 rounded-xl border-slate-200 text-xs font-semibold focus:border-violet-500"
              value={replyText}
              onChange={(e) => setReplyText(e.target.value)}
              onKeyDown={(e) => {
                if (e.key === "Enter" && !e.shiftKey) {
                  e.preventDefault();
                  handleSend();
                }
              }}
              disabled={sending}
            />
            <Button variant="ghost" size="icon" className="h-10 w-10 text-slate-400 hover:text-slate-600 hover:bg-slate-50 rounded-xl"><Smile className="size-4.5" /></Button>
            <Button variant="ghost" size="icon" className="h-10 w-10 text-slate-400 hover:text-slate-600 hover:bg-slate-50 rounded-xl"><Mic className="size-4.5" /></Button>
            <Button 
              onClick={handleSend} 
              disabled={sending || !replyText.trim()}
              className="h-11 w-11 bg-violet-600 hover:bg-violet-700 text-white rounded-xl flex items-center justify-center transition shrink-0"
            >
              <Send className="size-4 text-white" />
            </Button>
          </footer>
        </Card>

        {/* Right conversation statistics details */}
        <Card className="border border-border shadow-soft bg-white rounded-2xl h-[780px] overflow-y-auto edulab-scrollbar">
          <div className="flex flex-col items-center gap-6 p-6 text-center">
            <div className="relative flex size-20 items-center justify-center rounded-2xl bg-gradient-to-br from-violet-500 to-indigo-650 text-white shadow-lg shadow-violet-100">
              {selected?.source === "telegram" ? <Bot className="size-9" /> : <span className="text-3xl font-black">{selected?.name[0].toUpperCase()}</span>}
            </div>
            
            <div>
              <h3 className="text-base font-black text-slate-800 tracking-tight leading-none">{selected?.name ?? "EduLab Bot"}</h3>
              {selected?.label ? (
                <span className="inline-flex rounded-lg bg-violet-50 text-violet-600 border border-violet-100/50 px-2 py-0.5 text-[9px] font-black uppercase tracking-wider mt-2.5">
                  {selected.label}
                </span>
              ) : null}
              <div className="flex items-center justify-center gap-1.5 mt-2">
                <span className={cn("size-2 rounded-full", selected?.online ? "bg-emerald-500" : "bg-slate-300")} />
                <span className="text-[10px] font-bold text-slate-400 uppercase tracking-wide">
                  {selected?.online ? "Onlayn" : "Offline"}
                </span>
              </div>
            </div>

            <InfoBlock
              title={selected?.source === "telegram" ? "Bot haqida" : "Talaba haqida"}
              lines={
                selected?.source === "telegram"
                  ? ["EduLab Academy rasmiy telegram boti.", "Telegram orqali yuborilgan yordam so'rovi."]
                  : ["LabProof Academy talabasi.", "Student mobil ilovasi orqali yuborilgan so'rov."]
              }
            />

            <InfoBlock
              title="Muloqot statistikasi"
              lines={[
                `Jami xabarlar: ${chatStats.total} ta`,
                `Bugun: ${chatStats.today} ta`,
                `O'qilmagan: ${chatStats.unread} ta`,
              ]}
            />

            <InfoBlock
              title="Media, fayllar va havolalar"
              lines={[
                `Rasmlar: ${chatStats.images} ta`,
                `Videolar: ${chatStats.videos} ta`,
                `Ovozli xabarlar: ${chatStats.voices} ta`,
                `Fayllar va hujjatlar: ${chatStats.files} ta`,
              ]}
            />

            <Button variant="ghost" className="mt-6 w-full font-bold h-11 bg-rose-50 text-rose-650 hover:bg-rose-100 border border-rose-100/30 rounded-xl text-xs flex gap-2">
              <Trash2 className="size-4" />
              Suhbatni tozalash
            </Button>
          </div>
        </Card>
      </div>
    </>
  );
}

function MessageBubble({ message }: { message: ChatMessage }) {
  const mine = message.author === "admin";
  return (
    <div className={cn("flex w-full mb-1", mine ? "justify-end" : "justify-start")}>
      <div className="flex gap-2 items-end max-w-[75%]">
        {!mine && (
          <span className="flex size-7 items-center justify-center rounded-lg bg-slate-200 text-[10px] font-black text-slate-600 shrink-0">
            S
          </span>
        )}
        <div
          className={cn(
            "rounded-2xl p-3.5 shadow-sm text-xs leading-relaxed transition-all duration-200",
            mine 
              ? "bg-violet-600 text-white rounded-br-none" 
              : "bg-white text-slate-800 border border-slate-150 rounded-bl-none",
          )}
        >
          <p className="whitespace-pre-wrap">{message.body}</p>
          {message.kind !== "text" ? <Attachment message={message} /> : null}
          <p className={cn("mt-2 text-right text-[9px] font-semibold", mine ? "text-violet-200" : "text-slate-400")}>
            {message.time}
          </p>
        </div>
      </div>
    </div>
  );
}

function Attachment({ message }: { message: ChatMessage }) {
  if (message.kind === "image" && message.previewUrl) {
    return (
      <div
        aria-label={message.body}
        className="mt-3 aspect-video w-full max-w-[280px] rounded-xl bg-cover bg-center border border-slate-100 shadow-sm"
        style={{ backgroundImage: `url(${message.previewUrl})` }}
      />
    );
  }
  if (message.kind === "voice") {
    return (
      <div className="mt-3 flex items-center gap-3 rounded-xl bg-slate-50 border border-slate-150/50 p-2.5 max-w-[280px]">
        <Play className="size-4.5 text-violet-600" />
        <div className="h-5 flex-1 rounded-full bg-gradient-to-r from-violet-100 via-violet-300 to-violet-100" />
        <span className="text-[10px] font-bold text-slate-400">{message.duration}</span>
      </div>
    );
  }
  const Icon = message.kind === "video" || message.kind === "round_video" ? Video : message.kind === "pdf" ? FileText : ImageIcon;
  return (
    <div className="mt-3 flex items-center gap-3 rounded-xl bg-slate-50 border border-slate-150/50 p-2.5 max-w-[280px]">
      <span className="flex size-9 items-center justify-center rounded-xl bg-violet-100 text-violet-600 shrink-0">
        <Icon className="size-4.5" />
      </span>
      <div className="min-w-0">
        <p className="text-[11px] font-extrabold text-slate-800 truncate">{message.fileName}</p>
        <p className="text-[9px] text-slate-400 font-bold mt-0.5">{message.fileSize}</p>
      </div>
    </div>
  );
}

function InfoBlock({ title, lines }: { title: string; lines: string[] }) {
  return (
    <div className="w-full border-t border-slate-100 pt-5 text-left">
      <h4 className="mb-2.5 text-xs font-black text-slate-400 uppercase tracking-wider">{title}</h4>
      <div className="flex flex-col gap-1.5">
        {lines.map((line) => (
          <p key={line} className="text-xs font-bold text-slate-600">{line}</p>
        ))}
      </div>
    </div>
  );
}
