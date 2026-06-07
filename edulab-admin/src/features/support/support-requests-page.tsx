"use client";

import { useEffect, useRef, useMemo, useState } from "react";
import type { ChangeEvent } from "react";
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
  Bot
} from "lucide-react";
import { PageHeader } from "@/components/layout/page-header";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { ConfirmDialog } from "@/components/ui/confirm-dialog";
import { Input } from "@/components/ui/input";
import { useConversations } from "@/hooks/use-admin-data";
import { cn } from "@/lib/utils";
import type { ChatMessage, Conversation } from "@/lib/types";
import { useQueryClient } from "@tanstack/react-query";

const SUPPORT_EMOJIS = [
  "🙂",
  "😊",
  "😄",
  "👍",
  "✅",
  "🙏",
  "👏",
  "🔥",
  "💯",
  "📌",
  "📎",
  "💬",
  "❗",
  "❓",
  "🎧",
  "🎥",
  "📷",
  "📚",
  "🧪",
  "🚀",
  "✨",
  "🤝",
  "⏳",
  "🔔",
];

export function SupportRequestsPage() {
  const conversations = useConversations();
  const [selectedId, setSelectedId] = useState("");
  const [activeTab, setActiveTab] = useState<"bot" | "app">("bot");
  const [inboxSearch, setInboxSearch] = useState("");
  const [inboxFilterOpen, setInboxFilterOpen] = useState(false);
  const [inboxFilter, setInboxFilter] = useState<"all" | "unread" | "online">("all");
  const [localReplies, setLocalReplies] = useState<Record<string, ChatMessage[]>>({});
  const [pendingAttachment, setPendingAttachment] = useState<ChatMessage | null>(null);
  const [emojiOpen, setEmojiOpen] = useState(false);
  const [recording, setRecording] = useState(false);
  const [messageSearchOpen, setMessageSearchOpen] = useState(false);
  const [messageSearch, setMessageSearch] = useState("");
  const [actionsOpen, setActionsOpen] = useState(false);
  const [destructiveAction, setDestructiveAction] = useState<"clear" | "delete" | null>(null);
  const [destructiveLoading, setDestructiveLoading] = useState(false);
  const [hiddenConversationIds, setHiddenConversationIds] = useState<Set<string>>(() => new Set());
  const [clearedConversationIds, setClearedConversationIds] = useState<Set<string>>(() => new Set());
  const fileInputRef = useRef<HTMLInputElement>(null);
  const recorderRef = useRef<MediaRecorder | null>(null);
  const audioChunksRef = useRef<Blob[]>([]);
  const recordingStartedAtRef = useRef<number>(0);
  const previousUnreadRef = useRef<Record<string, number>>({});
  const unreadBaselineReadyRef = useRef(false);
  const [newMessageNotice, setNewMessageNotice] = useState<Conversation | null>(null);

  const conversationItems = useMemo(() => {
    return (conversations.data ?? [])
      .filter((conversation) => !hiddenConversationIds.has(conversation.id))
      .map((conversation) => {
      if (clearedConversationIds.has(conversation.id)) {
        return {
          ...conversation,
          messages: [],
          lastMessage: "Suhbat tozalandi",
          unread: 0,
        };
      }
      const replies = localReplies[conversation.id];
      if (!replies?.length) return conversation;
      const lastReply = replies[replies.length - 1];
      return {
        ...conversation,
        messages: [...conversation.messages, ...replies],
        lastMessage: lastReply.body,
        time: lastReply.time,
      };
    });
  }, [clearedConversationIds, conversations.data, hiddenConversationIds, localReplies]);

  const filteredConversations = useMemo(() => {
    return conversationItems.filter((item) => {
      // Filter by active tab (source: telegram for bot, otherwise app)
      const matchesTab = activeTab === "bot" ? item.source === "telegram" : item.source !== "telegram";
      // Filter by search
      const matchesSearch = item.name.toLowerCase().includes(inboxSearch.toLowerCase()) || 
        (item.lastMessage || "").toLowerCase().includes(inboxSearch.toLowerCase());
      const matchesFilter =
        inboxFilter === "all" ||
        (inboxFilter === "unread" && item.unread > 0) ||
        (inboxFilter === "online" && item.online);
      return matchesTab && matchesSearch && matchesFilter;
    });
  }, [conversationItems, activeTab, inboxSearch, inboxFilter]);

  const selected = useMemo(() => {
    if (!conversationItems.length) return null;
    return (
      conversationItems.find((item) => item.id === selectedId) ??
      filteredConversations[0] ??
      conversationItems[0]
    );
  }, [conversationItems, filteredConversations, selectedId]);

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

  const visibleMessages = useMemo(() => {
    const messages = selected?.messages ?? [];
    const search = messageSearch.trim().toLowerCase();
    if (!search) return messages;
    return messages.filter((message) => {
      return [
        message.body,
        message.fileName,
        message.fileSize,
        message.time,
      ]
        .filter(Boolean)
        .some((value) => String(value).toLowerCase().includes(search));
    });
  }, [messageSearch, selected]);

  const [replyText, setReplyText] = useState("");
  const [sending, setSending] = useState(false);
  const queryClient = useQueryClient();
  const canSend = Boolean(selected && (replyText.trim() || pendingAttachment));

  useEffect(() => {
    const nextUnread = Object.fromEntries(
      conversationItems.map((item) => [item.id, item.unread] as const),
    );

    if (!unreadBaselineReadyRef.current) {
      previousUnreadRef.current = nextUnread;
      unreadBaselineReadyRef.current = true;
      return;
    }

    const freshConversation = conversationItems.find((item) => {
      return item.unread > (previousUnreadRef.current[item.id] ?? 0);
    });
    previousUnreadRef.current = nextUnread;

    if (!freshConversation) return;
    setNewMessageNotice(freshConversation);
    const timer = window.setTimeout(() => setNewMessageNotice(null), 4500);
    return () => window.clearTimeout(timer);
  }, [conversationItems]);

  const handleSend = async () => {
    if (!canSend || !selected) return;

    setSending(true);
    try {
      const studentMessages = selected.messages.filter((m) => m.author === "student");
      const unanswered = studentMessages[studentMessages.length - 1];
      const outgoingAttachment = pendingAttachment;
      const replyBody =
        replyText.trim() ||
        outgoingAttachment?.body ||
        outgoingAttachment?.fileName ||
        "Fayl yuborildi.";

      const response = await fetch("/api/support/conversations", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          id: selected.id,
          backend: selected.backend,
          messageId: unanswered?.id.replace(/_reply$/, ""),
          replyText: replyBody,
        }),
      });

      if (!response.ok) {
        const payload = (await response.json().catch(() => null)) as { error?: string } | null;
        throw new Error(payload?.error ?? "Xabar yuborilmadi");
      }

      if (selected.backend === "archive" || outgoingAttachment) {
        const now = new Date();
        setLocalReplies((current) => ({
          ...current,
          [selected.id]: [
            ...(current[selected.id] ?? []),
            {
              id: `local_reply_${selected.id}_${now.getTime()}`,
              author: "admin",
              body: replyBody,
              time: now.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" }),
              kind: outgoingAttachment?.kind ?? "text",
              fileName: outgoingAttachment?.fileName,
              fileSize: outgoingAttachment?.fileSize,
              previewUrl: outgoingAttachment?.previewUrl,
              attachmentUrl: outgoingAttachment?.attachmentUrl,
              duration: outgoingAttachment?.duration,
              read: true,
              createdAt: now.toISOString(),
            },
          ],
        }));
      }

      setReplyText("");
      setPendingAttachment(null);
      setEmojiOpen(false);
      queryClient.invalidateQueries({ queryKey: ["conversations"] });
    } catch (error) {
      console.error("Xabar yuborishda xatolik:", error);
    } finally {
      setSending(false);
    }
  };

  const handleFileChange = (event: ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    event.target.value = "";
    if (!file) return;

    const kind = getAttachmentKind(file);
    const url = URL.createObjectURL(file);
    setPendingAttachment({
      id: `pending_file_${Date.now()}`,
      author: "admin",
      body: kind === "image" ? "Rasm biriktirildi." : "Fayl biriktirildi.",
      time: "",
      kind,
      fileName: file.name,
      fileSize: formatAttachmentSize(file.size),
      previewUrl: kind === "image" ? url : undefined,
      attachmentUrl: url,
    });
  };

  const handleEmojiSelect = (emoji: string) => {
    setReplyText((current) => `${current}${emoji}`);
    setEmojiOpen(false);
  };

  const handleVoiceClick = async () => {
    if (recording) {
      recorderRef.current?.stop();
      return;
    }

    if (!navigator.mediaDevices?.getUserMedia || typeof MediaRecorder === "undefined") {
      alert("Brauzer mikrofon yozishni qo'llab-quvvatlamaydi.");
      return;
    }

    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      const recorder = new MediaRecorder(stream);
      audioChunksRef.current = [];
      recordingStartedAtRef.current = Date.now();
      recorderRef.current = recorder;

      recorder.ondataavailable = (event) => {
        if (event.data.size > 0) audioChunksRef.current.push(event.data);
      };
      recorder.onstop = () => {
        const duration = Math.max(1, Math.round((Date.now() - recordingStartedAtRef.current) / 1000));
        const blob = new Blob(audioChunksRef.current, { type: recorder.mimeType || "audio/webm" });
        const url = URL.createObjectURL(blob);
        stream.getTracks().forEach((track) => track.stop());
        setPendingAttachment({
          id: `pending_voice_${Date.now()}`,
          author: "admin",
          body: "Ovozli xabar biriktirildi.",
          time: "",
          kind: "voice",
          fileName: "voice-message.webm",
          fileSize: formatAttachmentSize(blob.size),
          duration: `${duration}s`,
          attachmentUrl: url,
        });
        setRecording(false);
      };

      recorder.start();
      setRecording(true);
    } catch (error) {
      console.error("Mikrofonni ishga tushirishda xatolik:", error);
      setRecording(false);
    }
  };

  const handleSelectConversation = async (id: string) => {
    setSelectedId(id);
    setMessageSearch("");
    setActionsOpen(false);
    const conv = conversations.data?.find((item) => item.id === id);
    if (conv && conv.unread > 0) {
      try {
        const unreadStudentMessages = conv.messages.filter(
          (m) => m.author === "student" && !m.read,
        );
        const response = await fetch("/api/support/conversations", {
          method: "PATCH",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            id: conv.id,
            backend: conv.backend,
            messageIds: unreadStudentMessages.map((m) => m.id.replace(/_reply$/, "")),
          }),
        });
        if (!response.ok) {
          const payload = (await response.json().catch(() => null)) as { error?: string } | null;
          throw new Error(payload?.error ?? "O'qildi holati yangilanmadi");
        }
        queryClient.invalidateQueries({ queryKey: ["conversations"] });
      } catch (err) {
        console.error("Xabarni o'qildi qilishda xatolik:", err);
      }
    }
  };

  const handleMarkSelectedRead = async () => {
    if (!selected) return;
    const unreadStudentMessages = selected.messages.filter((m) => m.author === "student" && !m.read);
    if (!unreadStudentMessages.length) {
      setActionsOpen(false);
      return;
    }

    const response = await fetch("/api/support/conversations", {
      method: "PATCH",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        id: selected.id,
        backend: selected.backend,
        messageIds: unreadStudentMessages.map((m) => m.id.replace(/_reply$/, "")),
      }),
    });

    if (response.ok) {
      queryClient.invalidateQueries({ queryKey: ["conversations"] });
    }
    setActionsOpen(false);
  };

  const handleRefreshConversations = () => {
    queryClient.invalidateQueries({ queryKey: ["conversations"] });
    setActionsOpen(false);
  };

  const handleDestructiveConversationAction = async () => {
    if (!selected || !destructiveAction) return;

    setDestructiveLoading(true);
    try {
      const response = await fetch("/api/support/conversations", {
        method: "DELETE",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          id: selected.id,
          backend: selected.backend,
          action: destructiveAction,
          messageIds: selected.messages.map((message) => message.id),
        }),
      });

      if (!response.ok) {
        const payload = (await response.json().catch(() => null)) as { error?: string } | null;
        throw new Error(payload?.error ?? "Suhbat amali bajarilmadi");
      }

      if (destructiveAction === "delete") {
        setHiddenConversationIds((current) => {
          const next = new Set(current);
          next.add(selected.id);
          return next;
        });
        setSelectedId("");
      } else {
        setClearedConversationIds((current) => {
          const next = new Set(current);
          next.add(selected.id);
          return next;
        });
        setLocalReplies((current) => {
          const next = { ...current };
          delete next[selected.id];
          return next;
        });
      }

      setDestructiveAction(null);
      queryClient.invalidateQueries({ queryKey: ["conversations"] });
    } catch (error) {
      console.error("Suhbatni o'chirishda xatolik:", error);
    } finally {
      setDestructiveLoading(false);
    }
  };

  return (
    <>
      <PageHeader title="Yordam So'rovlari" current="Support & Live Chat" />
      {newMessageNotice ? (
        <button
          type="button"
          onClick={() => {
            setActiveTab(newMessageNotice.source === "telegram" ? "bot" : "app");
            handleSelectConversation(newMessageNotice.id);
            setNewMessageNotice(null);
          }}
          className="fixed right-6 top-24 z-40 flex w-[320px] items-center gap-3 rounded-2xl border border-violet-100 bg-white p-3 text-left shadow-soft ring-1 ring-violet-50 transition hover:-translate-y-0.5 hover:shadow-lg dark:border-violet-500/20 dark:bg-slate-900 dark:ring-violet-400/10"
        >
          <ConversationAvatar conversation={newMessageNotice} size="sm" />
          <span className="min-w-0 flex-1">
            <span className="block text-[10px] font-black uppercase tracking-wider text-violet-600">
              Yangi xabar
            </span>
            <span className="mt-0.5 block truncate text-sm font-black text-slate-800 dark:text-slate-100">
              {newMessageNotice.name}
            </span>
            <span className="mt-0.5 block truncate text-xs font-semibold text-slate-400 dark:text-slate-500">
              {newMessageNotice.lastMessage}
            </span>
          </span>
          <span className="flex size-7 items-center justify-center rounded-lg bg-violet-600 text-white">
            <Send className="size-3.5" />
          </span>
        </button>
      ) : null}
      
      <div className="grid min-h-[760px] gap-6 xl:grid-cols-[380px_1fr_340px] animate-in fade-in duration-200">
        {/* Left conversations list */}
        <Card className="flex h-[780px] flex-col overflow-hidden rounded-2xl border border-border bg-white shadow-soft dark:border-slate-800 dark:bg-slate-900">
          <div className="flex gap-2.5 border-b border-slate-100 bg-slate-50/50 p-4 dark:border-slate-800 dark:bg-slate-950/35">
            <button 
              onClick={() => {
                setActiveTab("bot");
                setSelectedId("");
              }}
              className={cn(
                "flex-1 h-9 rounded-xl text-xs font-bold transition-all duration-200 flex items-center justify-center gap-1.5",
                activeTab === "bot" 
                  ? "border border-slate-200/50 bg-white text-violet-600 shadow-sm dark:border-violet-500/20 dark:bg-violet-500/12 dark:text-violet-300 font-black"
                  : "text-slate-500 hover:bg-slate-100/50 dark:text-slate-400 dark:hover:bg-slate-800/70"
              )}
            >
              <Bot className="size-3.5" />
              Telegram bot
            </button>
            <button 
              onClick={() => {
                setActiveTab("app");
                setSelectedId("");
              }}
              className={cn(
                "flex-1 h-9 rounded-xl text-xs font-bold transition-all duration-200 flex items-center justify-center gap-1.5",
                activeTab === "app" 
                  ? "border border-slate-200/50 bg-white text-violet-600 shadow-sm dark:border-violet-500/20 dark:bg-violet-500/12 dark:text-violet-300 font-black"
                  : "text-slate-500 hover:bg-slate-100/50 dark:text-slate-400 dark:hover:bg-slate-800/70"
              )}
            >
              <FileText className="size-3.5" />
              Student ilovasi
            </button>
          </div>
          
          <div className="flex gap-2 border-b border-slate-100 p-4 dark:border-slate-800">
            <div className="relative flex-1">
              <Search className="absolute left-3.5 top-1/2 size-4 -translate-y-1/2 text-slate-400" />
              <Input 
                value={inboxSearch}
                onChange={(e) => setInboxSearch(e.target.value)}
                placeholder="Suhbatdoshni qidirish..." 
                className="h-10 rounded-xl border-slate-200 pl-10 text-xs font-semibold focus:border-violet-500 dark:border-slate-800 dark:bg-slate-950/55 dark:text-slate-100 dark:placeholder:text-slate-500"
              />
            </div>
            <div className="relative">
              <Button
                variant="secondary"
                size="icon"
                onClick={() => setInboxFilterOpen((open) => !open)}
                className={cn(
                  "h-10 w-10 rounded-xl border border-slate-200 hover:bg-slate-50 dark:border-slate-800 dark:bg-slate-950/55 dark:hover:bg-slate-800",
                  inboxFilter !== "all" && "border-violet-200 bg-violet-50 text-violet-600 dark:border-violet-500/30 dark:bg-violet-500/12 dark:text-violet-300",
                )}
                title="Suhbatlarni filterlash"
              >
                <SlidersHorizontal className="size-4 text-slate-500" />
              </Button>
              {inboxFilterOpen ? (
                <div className="absolute right-0 top-12 z-30 w-44 rounded-lg border border-slate-200 bg-white p-1.5 text-left shadow-soft dark:border-slate-800 dark:bg-slate-950">
                  {[
                    ["all", "Hammasi"],
                    ["unread", "O'qilmaganlar"],
                    ["online", "Onlaynlar"],
                  ].map(([value, label]) => (
                    <button
                      key={value}
                      type="button"
                      onClick={() => {
                        setInboxFilter(value as typeof inboxFilter);
                        setInboxFilterOpen(false);
                      }}
                      className={cn(
                        "block w-full rounded-md px-3 py-2 text-xs font-bold hover:bg-slate-50 dark:hover:bg-slate-800",
                        inboxFilter === value ? "bg-violet-50 text-violet-600 dark:bg-violet-500/12 dark:text-violet-300" : "text-slate-700 dark:text-slate-300",
                      )}
                    >
                      {label}
                    </button>
                  ))}
                </div>
              ) : null}
            </div>
          </div>

          <div className="flex-1 divide-y divide-slate-50 overflow-y-auto p-2 edulab-scrollbar dark:divide-slate-800/60">
            {filteredConversations.length > 0 ? (
              filteredConversations.map((conversation) => {
                const isSelected = selectedId === conversation.id || (!selectedId && filteredConversations[0]?.id === conversation.id);
                return (
                  <button
                    key={conversation.id}
                    onClick={() => handleSelectConversation(conversation.id)}
                    className={cn(
                      "flex w-full items-center gap-3 rounded-xl p-3 text-left transition duration-150 border border-transparent mt-1 first:mt-0",
                      isSelected 
                        ? "border-violet-100 bg-violet-50/60 shadow-sm dark:border-violet-500/20 dark:bg-violet-500/12"
                        : "hover:bg-slate-50/60 dark:hover:bg-slate-800/55",
                    )}
                  >
                    <ConversationAvatar conversation={conversation} size="sm" />
                    <span className="min-w-0 flex-1">
                      <span className="flex items-center justify-between gap-2">
                        <span className={cn("truncate text-xs font-extrabold text-slate-800 dark:text-slate-100", isSelected && "text-violet-950 font-black dark:text-violet-100")}>
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
              <div className="flex flex-col items-center justify-center gap-2 py-20 text-center text-xs font-semibold text-slate-400 dark:text-slate-500">
                <Bot className="size-8 text-slate-300" />
                Suhbatlar topilmadi
              </div>
            )}
          </div>
          
          <div className="border-t border-slate-100 bg-slate-50/20 px-5 py-3.5 text-xs font-bold text-slate-400 dark:border-slate-800 dark:bg-slate-950/30 dark:text-slate-500">
            Jami {filteredConversations.length} ta faol suhbat
          </div>
        </Card>

        {/* Middle message timeline workspace */}
        <Card className="flex h-[780px] flex-col overflow-hidden rounded-2xl border border-border bg-white shadow-soft dark:border-slate-800 dark:bg-slate-900">
          <header className="border-b border-slate-150/60 bg-slate-50/30 px-4 py-3 dark:border-slate-800 dark:bg-slate-950/35">
            <div className="flex min-h-[54px] items-center justify-between gap-3">
            <div className="flex min-w-0 items-center gap-3">
              {selected ? <ConversationAvatar conversation={selected} size="sm" /> : null}
              <div className="min-w-0">
                <div className="flex items-center gap-2">
                  <h2 className="truncate text-sm font-black leading-tight text-slate-800 dark:text-slate-100">{selected?.name}</h2>
                  {selected?.label ? (
                    <span className="inline-flex shrink-0 items-center rounded-lg border border-violet-100/50 bg-violet-50 px-2 py-0.5 text-[9px] font-black uppercase tracking-wider text-violet-600 dark:border-violet-500/20 dark:bg-violet-500/12 dark:text-violet-300">
                      {selected.label}
                    </span>
                  ) : null}
                </div>
                <div className="flex items-center gap-1.5 mt-1">
                  <span className={cn("size-2 rounded-full", selected?.online ? "bg-emerald-500 animate-pulse" : "bg-slate-300")} />
                  <span className="text-[10px] font-bold text-slate-400">
                    {selected ? getStatusLabel(selected) : "Offline"}
                  </span>
                </div>
              </div>
            </div>
            <div className="relative flex shrink-0 gap-2">
              <Button
                variant="secondary"
                size="icon"
                onClick={() => setMessageSearchOpen((open) => !open)}
                title="Suhbat ichidan qidirish"
                className={cn(
                  "h-9 w-9 rounded-lg border border-slate-200 hover:bg-slate-50 dark:border-slate-800 dark:bg-slate-950/55 dark:hover:bg-slate-800",
                  messageSearchOpen && "border-violet-200 bg-violet-50 text-violet-600 dark:border-violet-500/30 dark:bg-violet-500/12 dark:text-violet-300",
                )}
              >
                <Search className="size-4 text-slate-500" />
              </Button>
              <Button
                variant="secondary"
                size="icon"
                onClick={() => setActionsOpen((open) => !open)}
                title="Suhbat amallari"
                className="h-9 w-9 rounded-lg border border-slate-200 hover:bg-slate-50 dark:border-slate-800 dark:bg-slate-950/55 dark:hover:bg-slate-800"
              >
                <MoreVertical className="size-4 text-slate-500" />
              </Button>
              {actionsOpen ? (
                <div className="absolute right-0 top-11 z-30 w-48 rounded-lg border border-slate-200 bg-white p-1.5 text-left shadow-soft dark:border-slate-800 dark:bg-slate-950">
                  <button
                    type="button"
                    onClick={handleRefreshConversations}
                    className="block w-full rounded-md px-3 py-2 text-xs font-bold text-slate-700 hover:bg-slate-50 dark:text-slate-300 dark:hover:bg-slate-800"
                  >
                    Yangilash
                  </button>
                  <button
                    type="button"
                    onClick={handleMarkSelectedRead}
                    className="block w-full rounded-md px-3 py-2 text-xs font-bold text-slate-700 hover:bg-slate-50 dark:text-slate-300 dark:hover:bg-slate-800"
                  >
                    O'qildi qilish
                  </button>
                  <button
                    type="button"
                    onClick={() => {
                      setMessageSearchOpen(true);
                      setActionsOpen(false);
                    }}
                    className="block w-full rounded-md px-3 py-2 text-xs font-bold text-slate-700 hover:bg-slate-50 dark:text-slate-300 dark:hover:bg-slate-800"
                  >
                    Xabar qidirish
                  </button>
                </div>
              ) : null}
            </div>
            </div>
            {messageSearchOpen ? (
              <div className="mt-3">
                <Input
                  value={messageSearch}
                  onChange={(event) => setMessageSearch(event.target.value)}
                  placeholder="Suhbat ichidan qidirish..."
                  className="h-9 rounded-lg border-slate-200 bg-white text-xs font-semibold dark:border-slate-800 dark:bg-slate-950/55 dark:text-slate-100 dark:placeholder:text-slate-500"
                />
              </div>
            ) : null}
          </header>

          <div className="flex flex-1 flex-col gap-4 overflow-y-auto bg-slate-50/30 p-5 edulab-scrollbar dark:bg-slate-950/25">
            <div className="mb-2 text-center">
              <span className="inline-flex rounded-xl border border-slate-200/55 bg-slate-100 px-3 py-1 text-[9px] font-black uppercase tracking-wider text-slate-400 dark:border-slate-800 dark:bg-slate-900 dark:text-slate-500">
                Muloqot tarixi
              </span>
            </div>
            
            {visibleMessages.length > 0 ? (
              visibleMessages.map((message) => (
                <MessageBubble key={message.id} message={message} />
              ))
            ) : (
              <div className="my-auto text-center text-xs font-semibold text-slate-400 flex flex-col items-center justify-center gap-2">
                <Send className="size-10 text-slate-200" />
                {messageSearch ? "Qidiruv bo'yicha xabar topilmadi." : "Xabarlar mavjud emas. Suhbatni boshlang."}
              </div>
            )}
          </div>

          <footer className="border-t border-slate-100 bg-white p-4 dark:border-slate-800 dark:bg-slate-900">
            <input ref={fileInputRef} type="file" className="hidden" onChange={handleFileChange} />
            {pendingAttachment ? (
              <div className="mb-3 flex items-center justify-between gap-3 rounded-lg border border-violet-100 bg-violet-50 px-3 py-2 dark:border-violet-500/20 dark:bg-violet-500/12">
                <div className="min-w-0 text-left">
                  <p className="truncate text-xs font-black text-slate-800 dark:text-slate-100">
                    {pendingAttachment.fileName ?? pendingAttachment.body}
                  </p>
                  <p className="mt-0.5 text-[10px] font-bold text-slate-400">
                    {pendingAttachment.kind === "voice" ? "Ovozli xabar" : pendingAttachment.fileSize ?? "Biriktirilgan fayl"}
                  </p>
                </div>
                <button
                  type="button"
                  onClick={() => setPendingAttachment(null)}
                  className="rounded-md px-2 py-1 text-[10px] font-black text-violet-600 hover:bg-white dark:text-violet-300 dark:hover:bg-slate-800"
                >
                  Olib tashlash
                </button>
              </div>
            ) : null}
            <div className="relative flex items-center gap-2.5">
              {emojiOpen ? (
                <div className="absolute bottom-14 left-14 z-20 grid w-64 grid-cols-8 gap-1 rounded-xl border border-slate-200 bg-white p-2 shadow-soft dark:border-slate-800 dark:bg-slate-950">
                  {SUPPORT_EMOJIS.map((emoji) => (
                    <button
                      key={emoji}
                      type="button"
                      onClick={() => handleEmojiSelect(emoji)}
                      className="flex size-8 items-center justify-center rounded-md text-base hover:bg-slate-50 dark:hover:bg-slate-800"
                    >
                      {emoji}
                    </button>
                  ))}
                </div>
              ) : null}
              <Button
                variant="ghost"
                size="icon"
                onClick={() => fileInputRef.current?.click()}
                disabled={sending || !selected}
                title="Fayl biriktirish"
                className="h-10 w-10 rounded-xl text-slate-400 hover:bg-slate-50 hover:text-slate-600 dark:hover:bg-slate-800 dark:hover:text-slate-200"
              >
                <Paperclip className="size-4.5" />
              </Button>
              <Input
                placeholder="Javob yozing..."
                className="h-11 flex-1 rounded-xl border-slate-200 text-xs font-semibold focus:border-violet-500 dark:border-slate-800 dark:bg-slate-950/55 dark:text-slate-100 dark:placeholder:text-slate-500"
                value={replyText}
                onChange={(e) => setReplyText(e.target.value)}
                onKeyDown={(e) => {
                  if (e.key === "Enter" && !e.shiftKey) {
                    e.preventDefault();
                    handleSend();
                  }
                }}
                disabled={sending || !selected}
              />
              <Button
                variant="ghost"
                size="icon"
                onClick={() => setEmojiOpen((open) => !open)}
                disabled={sending || !selected}
                title="Emoji qo'shish"
                className="h-10 w-10 rounded-xl text-slate-400 hover:bg-slate-50 hover:text-slate-600 dark:hover:bg-slate-800 dark:hover:text-slate-200"
              >
                <Smile className="size-4.5" />
              </Button>
              <Button
                variant="ghost"
                size="icon"
                onClick={handleVoiceClick}
                disabled={sending || !selected}
                title={recording ? "Yozishni tugatish" : "Ovozli xabar yozish"}
                className={cn(
                  "h-10 w-10 rounded-xl hover:bg-slate-50 dark:hover:bg-slate-800",
                  recording ? "bg-rose-50 text-rose-600 dark:bg-rose-500/12 dark:text-rose-300" : "text-slate-400 hover:text-slate-600 dark:hover:text-slate-200",
                )}
              >
                <Mic className="size-4.5" />
              </Button>
              <Button
                onClick={handleSend}
                disabled={sending || !canSend}
                className="h-11 w-11 bg-violet-600 hover:bg-violet-700 text-white rounded-xl flex items-center justify-center transition shrink-0 disabled:opacity-50"
                title="Javob yuborish"
              >
                <Send className="size-4 text-white" />
              </Button>
            </div>
          </footer>
        </Card>

        {/* Right conversation statistics details */}
        <Card className="h-[780px] overflow-y-auto rounded-2xl border border-border bg-white shadow-soft edulab-scrollbar dark:border-slate-800 dark:bg-slate-900">
          <div className="flex flex-col items-center gap-6 p-6 text-center">
            {selected ? <ConversationAvatar conversation={selected} size="lg" /> : null}
            
            <div>
              <h3 className="text-base font-black leading-none tracking-tight text-slate-800 dark:text-slate-100">{selected?.name ?? "EduLab Bot"}</h3>
              {selected?.label ? (
                <span className="mt-2.5 inline-flex rounded-lg border border-violet-100/50 bg-violet-50 px-2 py-0.5 text-[9px] font-black uppercase tracking-wider text-violet-600 dark:border-violet-500/20 dark:bg-violet-500/12 dark:text-violet-300">
                  {selected.label}
                </span>
              ) : null}
              <div className="flex items-center justify-center gap-1.5 mt-2">
                <span className={cn("size-2 rounded-full", selected?.online ? "bg-emerald-500" : "bg-slate-300")} />
                <span className="text-[10px] font-bold text-slate-400 uppercase tracking-wide">
                  {selected ? getStatusLabel(selected) : "Offline"}
                </span>
              </div>
            </div>

            <InfoBlock
              title={selected?.source === "telegram" ? "Telegram ma'lumotlari" : "APK foydalanuvchisi"}
              lines={getProfileLines(selected)}
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

            <Button
              variant="ghost"
              onClick={() => setDestructiveAction("clear")}
              disabled={!selected || destructiveLoading}
              className="mt-6 flex h-11 w-full gap-2 rounded-xl border border-amber-100/60 bg-amber-50 text-xs font-bold text-amber-700 hover:bg-amber-100 disabled:opacity-50 dark:border-amber-500/20 dark:bg-amber-500/12 dark:text-amber-300 dark:hover:bg-amber-500/18"
            >
              <Trash2 className="size-4" />
              Suhbatni tozalash
            </Button>
            <Button
              variant="ghost"
              onClick={() => setDestructiveAction("delete")}
              disabled={!selected || destructiveLoading}
              className="flex h-11 w-full gap-2 rounded-xl border border-rose-100/30 bg-rose-50 text-xs font-bold text-rose-700 hover:bg-rose-100 disabled:opacity-50 dark:border-rose-500/20 dark:bg-rose-500/12 dark:text-rose-300 dark:hover:bg-rose-500/18"
            >
              <Trash2 className="size-4" />
              Butunlay o'chirish
            </Button>
          </div>
        </Card>
      </div>

      <ConfirmDialog
        open={destructiveAction !== null}
        title={
          destructiveAction === "delete"
            ? "Suhbat butunlay o'chirilsinmi?"
            : "Suhbat tarixi tozalansinmi?"
        }
        description={
          destructiveAction === "delete"
            ? "Bu amal suhbatni ro'yxatdan ham olib tashlaydi. Yangi xabar kelsa, suhbat qayta yaratiladi."
            : "Bu amal tanlangan suhbatdagi xabarlar tarixini o'chiradi. Foydalanuvchi profili va yangi xabar qabul qilish saqlanadi."
        }
        confirmLabel={destructiveAction === "delete" ? "Butunlay o'chirish" : "Tozalash"}
        cancelLabel="Bekor qilish"
        variant={destructiveAction === "delete" ? "danger" : "warning"}
        loading={destructiveLoading}
        onConfirm={handleDestructiveConversationAction}
        onCancel={() => {
          if (!destructiveLoading) setDestructiveAction(null);
        }}
      />
    </>
  );
}

function getStatusLabel(conversation: Conversation) {
  if (conversation.online) return "Onlayn";
  return conversation.lastSeenLabel ? `Offline · ${conversation.lastSeenLabel}` : "Offline";
}

function getAttachmentKind(file: File): ChatMessage["kind"] {
  if (file.type.startsWith("image/")) return "image";
  if (file.type.startsWith("video/")) return "video";
  if (file.type.includes("pdf")) return "pdf";
  if (file.type.startsWith("audio/")) return "voice";
  return "document";
}

function formatAttachmentSize(bytes: number) {
  const mb = bytes / (1024 * 1024);
  if (mb >= 1) return `${mb.toFixed(mb >= 10 ? 0 : 1)} MB`;
  return `${Math.max(1, Math.round(bytes / 1024))} KB`;
}

function getProfileLines(conversation: Conversation | null) {
  if (!conversation) return ["Suhbat tanlanmagan."];

  const base =
    conversation.about && conversation.about.length > 0
      ? [...conversation.about]
      : conversation.source === "telegram"
        ? ["Telegram orqali yuborilgan yordam so'rovi."]
        : ["Student ilovasi orqali yuborilgan yordam so'rovi."];

  const addUnique = (line: string) => {
    if (!base.includes(line)) base.push(line);
  };

  if (conversation.username) addUnique(`Username: @${conversation.username}`);
  if (conversation.phone) addUnique(`Telefon: ${conversation.phone}`);
  if (conversation.telegramChatId) addUnique(`Telegram chat ID: ${conversation.telegramChatId}`);
  if (conversation.participantUserId) addUnique(`User ID: ${conversation.participantUserId}`);
  if (conversation.lastSeenLabel) addUnique(`Oxirgi faollik: ${conversation.lastSeenLabel}`);

  return base;
}

function ConversationAvatar({
  conversation,
  size = "sm",
}: {
  conversation: Conversation;
  size?: "sm" | "lg";
}) {
  const sizeClass = size === "lg" ? "size-24 rounded-lg" : "size-11 rounded-lg";
  const iconClass = size === "lg" ? "size-10" : "size-5";
  const initialClass = size === "lg" ? "text-3xl" : "text-sm";
  const label = `${conversation.name} rasmi`;

  if (conversation.avatar) {
    return (
      <img
        src={conversation.avatar}
        alt={label}
        className={cn(sizeClass, "shrink-0 object-cover ring-1 ring-slate-200 dark:ring-slate-700")}
      />
    );
  }

  return (
    <span
      className={cn(
        "flex shrink-0 items-center justify-center text-white shadow-sm",
        sizeClass,
        conversation.source === "telegram"
          ? "bg-gradient-to-br from-blue-500 to-indigo-600"
          : "border border-violet-100 bg-gradient-to-br from-violet-50 to-indigo-100 text-violet-600 dark:border-violet-500/20 dark:from-violet-500/20 dark:to-indigo-500/20 dark:text-violet-300",
      )}
    >
      {conversation.source === "telegram" ? (
        <Send className={cn(iconClass, "text-white")} />
      ) : (
        <span className={cn("font-black", initialClass)}>
          {conversation.name?.[0]?.toUpperCase() ?? "S"}
        </span>
      )}
    </span>
  );
}

function MessageBubble({ message }: { message: ChatMessage }) {
  const mine = message.author === "admin";
  return (
    <div className={cn("flex w-full mb-1", mine ? "justify-end" : "justify-start")}>
      <div className="flex gap-2 items-end max-w-[75%]">
        {!mine && (
          <span className="flex size-7 shrink-0 items-center justify-center rounded-lg bg-slate-200 text-[10px] font-black text-slate-600 dark:bg-slate-800 dark:text-slate-300">
            S
          </span>
        )}
        <div
          className={cn(
            "rounded-2xl p-3.5 shadow-sm text-xs leading-relaxed transition-all duration-200",
            mine 
              ? "rounded-br-none bg-violet-600 text-white"
              : "rounded-bl-none border border-slate-150 bg-white text-slate-800 dark:border-slate-800 dark:bg-slate-900 dark:text-slate-100",
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
  const previewUrl = message.previewUrl ?? message.attachmentUrl;

  if (message.kind === "image" && previewUrl) {
    return (
      <ImageAttachment src={previewUrl} label={message.body || message.fileName || "Rasm"} />
    );
  }
  if (message.kind === "voice") {
    if (message.attachmentUrl) {
      return (
        <div className="mt-3 max-w-[300px] rounded-xl border border-slate-150/50 bg-slate-50 p-2.5 dark:border-slate-800 dark:bg-slate-950/55">
          <audio src={message.attachmentUrl} controls preload="metadata" className="h-9 w-full" />
          {message.duration ? (
            <p className="mt-1 text-right text-[10px] font-bold text-slate-400">{message.duration}</p>
          ) : null}
        </div>
      );
    }

    return (
      <div className="mt-3 flex max-w-[280px] items-center gap-3 rounded-xl border border-slate-150/50 bg-slate-50 p-2.5 dark:border-slate-800 dark:bg-slate-950/55">
        <Play className="size-4.5 text-violet-600" />
        <div className="h-5 flex-1 rounded-full bg-gradient-to-r from-violet-100 via-violet-300 to-violet-100" />
        <span className="text-[10px] font-bold text-slate-400">{message.duration ?? "media yo'q"}</span>
      </div>
    );
  }
  if ((message.kind === "video" || message.kind === "round_video") && message.attachmentUrl) {
    return (
      <div className="mt-3 max-w-[320px] rounded-xl border border-slate-150/50 bg-slate-50 p-2.5 dark:border-slate-800 dark:bg-slate-950/55">
        <video
          src={message.attachmentUrl}
          controls
          preload="metadata"
          playsInline
          className={cn(
            "w-full bg-black",
            message.kind === "round_video" ? "aspect-square rounded-full object-cover" : "aspect-video rounded-lg object-contain",
          )}
        />
        {message.fileName ? (
          <p className="mt-2 truncate text-[11px] font-extrabold text-slate-700 dark:text-slate-200">{message.fileName}</p>
        ) : null}
      </div>
    );
  }
  const Icon = message.kind === "video" || message.kind === "round_video" ? Video : message.kind === "pdf" ? FileText : ImageIcon;
  const fileContent = (
    <>
      <span className="flex size-9 shrink-0 items-center justify-center rounded-xl bg-violet-100 text-violet-600 dark:bg-violet-500/15 dark:text-violet-300">
        <Icon className="size-4.5" />
      </span>
      <div className="min-w-0">
        <p className="truncate text-[11px] font-extrabold text-slate-800 dark:text-slate-100">
          {message.fileName ?? "Media fayl"}
        </p>
        <p className="text-[9px] text-slate-400 font-bold mt-0.5">
          {message.fileSize ?? (message.attachmentUrl ? "Ochish uchun bosing" : "Fayl manzili topilmadi")}
        </p>
      </div>
    </>
  );

  if (message.attachmentUrl) {
    return (
      <a
        href={message.attachmentUrl}
        target="_blank"
        rel="noreferrer"
        className="mt-3 flex max-w-[280px] items-center gap-3 rounded-xl border border-slate-150/50 bg-slate-50 p-2.5 transition hover:border-violet-200 hover:bg-violet-50 dark:border-slate-800 dark:bg-slate-950/55 dark:hover:border-violet-500/30 dark:hover:bg-violet-500/12"
      >
        {fileContent}
      </a>
    );
  }

  return (
    <div className="mt-3 flex max-w-[280px] items-center gap-3 rounded-xl border border-slate-150/50 bg-slate-50 p-2.5 dark:border-slate-800 dark:bg-slate-950/55">
      {fileContent}
    </div>
  );
}

function ImageAttachment({ src, label }: { src: string; label: string }) {
  const [open, setOpen] = useState(false);

  return (
    <>
      <button
        type="button"
        onClick={() => setOpen(true)}
        className="mt-3 block aspect-video w-full max-w-[280px] overflow-hidden rounded-xl border border-slate-100 bg-slate-100 shadow-sm dark:border-slate-800 dark:bg-slate-950"
      >
        <img src={src} alt={label} className="size-full object-cover" />
      </button>
      {open ? (
        <div
          className="fixed inset-0 z-50 flex items-center justify-center bg-slate-950/70 p-6"
          onClick={() => setOpen(false)}
        >
          <button
            type="button"
            className="absolute right-5 top-5 rounded-lg bg-white px-3 py-2 text-xs font-black text-slate-700 dark:bg-slate-900 dark:text-slate-100"
            onClick={() => setOpen(false)}
          >
            Yopish
          </button>
          <img
            src={src}
            alt={label}
            className="max-h-[86vh] max-w-[86vw] rounded-lg bg-white object-contain shadow-soft dark:bg-slate-950"
            onClick={(event) => event.stopPropagation()}
          />
        </div>
      ) : null}
    </>
  );
}

function InfoBlock({ title, lines }: { title: string; lines: string[] }) {
  return (
    <div className="w-full border-t border-slate-100 pt-5 text-left dark:border-slate-800">
      <h4 className="mb-2.5 text-xs font-black uppercase tracking-wider text-slate-400 dark:text-slate-500">{title}</h4>
      <div className="flex flex-col gap-1.5">
        {lines.map((line) => (
          <p key={line} className="text-xs font-bold text-slate-600 dark:text-slate-300">{line}</p>
        ))}
      </div>
    </div>
  );
}
