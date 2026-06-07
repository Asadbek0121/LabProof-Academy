"use client";

import { useMemo, useState } from "react";
import {
  Copy,
  Download,
  Eye,
  FileAudio,
  FileText,
  FileVideo,
  Filter,
  ImageIcon,
  Link2,
  MoreVertical,
  Music2,
  Play,
  Search,
  Trash2,
  X,
} from "lucide-react";
import { toast } from "sonner";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { PageHeader } from "@/components/layout/page-header";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Input, Select } from "@/components/ui/input";
import { Skeleton } from "@/components/ui/skeleton";
import { deleteMediaAction } from "@/actions/media";
import { useMediaLibrary } from "@/hooks/use-admin-data";
import { cn, formatBytes } from "@/lib/utils";
import type { MediaItem, MediaKind } from "@/lib/types";

const tabs: Array<{ label: string; value: "all" | MediaKind }> = [
  { label: "Barcha fayllar", value: "all" },
  { label: "Rasmlar", value: "image" },
  { label: "Videolar", value: "video" },
  { label: "PDF", value: "pdf" },
  { label: "Audio", value: "voice" },
  { label: "Hujjatlar", value: "document" },
  { label: "Boshqalar", value: "file" },
];

const kindLabels: Record<string, string> = {
  image: "RASM",
  video: "VIDEO",
  round_video: "VIDEO",
  voice: "AUDIO",
  pdf: "PDF",
  document: "DOCX",
  text: "TEXT",
  file: "FILE",
};

export function MediaLibraryPage() {
  const queryClient = useQueryClient();
  const { data: mediaItems = [], isLoading } = useMediaLibrary();
  const [activeTab, setActiveTab] = useState<(typeof tabs)[number]["value"]>("all");
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [searchTerm, setSearchTerm] = useState("");
  const [typeFilter, setTypeFilter] = useState("all");
  const [sourceFilter, setSourceFilter] = useState("all");
  const [usedFilter, setUsedFilter] = useState("all");
  const [sortBy, setSortBy] = useState("newest");

  const stats = useMemo(() => {
    const totalBytes = mediaItems.reduce((sum, item) => sum + Number(item.bytes || 0), 0);
    const images = mediaItems.filter((item) => item.kind === "image");
    const videos = mediaItems.filter((item) => item.kind === "video" || item.kind === "round_video");
    const pdfs = mediaItems.filter((item) => item.kind === "pdf" || item.kind === "document");
    const others = mediaItems.filter((item) => !["image", "video", "round_video", "pdf", "document"].includes(item.kind));
    const total = Math.max(1, mediaItems.length);
    return {
      totalBytes,
      storagePercent: Math.min(100, Math.round((totalBytes / (100 * 1024 * 1024 * 1024)) * 100)),
      cards: [
        { title: "Rasmlar", value: images.length, hint: `Jami fayllar ichida ${Math.round((images.length / total) * 100)}%`, tone: "blue" as const, icon: ImageIcon },
        { title: "Videolar", value: videos.length, hint: `Jami fayllar ichida ${Math.round((videos.length / total) * 100)}%`, tone: "violet" as const, icon: FileVideo },
        { title: "PDF fayllar", value: pdfs.length, hint: `Jami fayllar ichida ${Math.round((pdfs.length / total) * 100)}%`, tone: "rose" as const, icon: FileText },
        { title: "Boshqalar", value: others.length, hint: `Jami fayllar ichida ${Math.round((others.length / total) * 100)}%`, tone: "blue" as const, icon: FileText },
      ],
    };
  }, [mediaItems]);

  const filteredItems = useMemo(() => {
    return mediaItems
      .filter((item) => {
        const tabMatch =
          activeTab === "all" ||
          item.kind === activeTab ||
          (activeTab === "video" && item.kind === "round_video") ||
          (activeTab === "document" && item.kind === "text");
        const typeMatch = typeFilter === "all" || item.kind === typeFilter || (typeFilter === "video" && item.kind === "round_video");
        const sourceMatch =
          sourceFilter === "all" ||
          item.uploadedBy.toLowerCase() === sourceFilter ||
          (sourceFilter === "system" && item.uploadedBy.toLowerCase() === "tizim") ||
          (sourceFilter === "lesson" && item.publicId.startsWith("lesson:"));
        const usedCount = item.usedIn?.length ?? 0;
        const usedMatch = usedFilter === "all" || (usedFilter === "used" && usedCount > 0) || (usedFilter === "unused" && usedCount === 0);
        const search = searchTerm.trim().toLowerCase();
        const searchMatch =
          !search ||
          item.name.toLowerCase().includes(search) ||
          item.publicId.toLowerCase().includes(search) ||
          item.usedIn.some((place) => place.toLowerCase().includes(search));
        return tabMatch && typeMatch && sourceMatch && usedMatch && searchMatch;
      })
      .sort((a, b) => {
        const timeA = new Date(a.createdAt).getTime();
        const timeB = new Date(b.createdAt).getTime();
        if (sortBy === "oldest") return timeA - timeB;
        if (sortBy === "size-desc") return b.bytes - a.bytes;
        if (sortBy === "size-asc") return a.bytes - b.bytes;
        return timeB - timeA;
      });
  }, [activeTab, mediaItems, searchTerm, sortBy, sourceFilter, typeFilter, usedFilter]);

  const selected = useMemo(() => {
    if (!filteredItems.length) return null;
    return filteredItems.find((item) => item.id === selectedId) ?? filteredItems[0];
  }, [filteredItems, selectedId]);

  const deleteMutation = useMutation({
    mutationFn: async (id: string) => {
      const result = await deleteMediaAction(id);
      if (!result.ok) throw new Error(result.error || "Fayl o'chirilmadi");
    },
    onSuccess: () => {
      toast.success("Fayl o'chirildi");
      setSelectedId(null);
      queryClient.invalidateQueries({ queryKey: ["media-library"] });
      queryClient.invalidateQueries({ queryKey: ["media-stats"] });
      queryClient.invalidateQueries({ queryKey: ["admin-overview-data"] });
    },
    onError: (error: any) => toast.error(error.message || "O'chirishda xatolik"),
  });

  const copyLink = async (url: string) => {
    await navigator.clipboard.writeText(url);
    toast.success("Havola nusxalandi");
  };

  const downloadFile = async (item: MediaItem) => {
    try {
      const response = await fetch(item.secureUrl);
      const blob = await response.blob();
      const url = URL.createObjectURL(blob);
      const link = document.createElement("a");
      link.href = url;
      link.download = item.name;
      link.click();
      URL.revokeObjectURL(url);
      toast.success("Fayl yuklab olindi");
    } catch {
      window.open(item.secureUrl, "_blank");
      toast.info("Fayl yangi oynada ochildi");
    }
  };

  const deleteFile = (item: MediaItem) => {
    if (item.publicId.startsWith("lesson:")) {
      toast.info("Bu fayl mavzu darsiga ulangan. Uni PDF/Text yoki Videolar bo'limidan tahrirlang.");
      return;
    }
    if (confirm(`"${item.name}" faylini o'chirmoqchimisiz?`)) {
      deleteMutation.mutate(item.id);
    }
  };

  return (
    <>
      <PageHeader title="Media kutubxona" current="Media kutubxona" />

      <div className="media-surface -mx-1 -mt-1 space-y-4 pb-4 text-slate-900 dark:text-slate-100">
        <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-5">
          {isLoading ? (
            Array.from({ length: 5 }).map((_, index) => <Skeleton key={index} className="h-[106px] rounded-xl" />)
          ) : (
            <>
              {stats.cards.map((card) => <MediaStatCard key={card.title} {...card} />)}
              <StorageCard bytes={stats.totalBytes} percent={stats.storagePercent} />
            </>
          )}
        </div>

        <div className="grid gap-4 xl:grid-cols-[1fr_360px]">
          <section className="rounded-xl border border-slate-200 bg-white shadow-[0_10px_28px_rgba(27,39,70,0.055)] dark:border-slate-800 dark:bg-slate-900">
            <div className="flex flex-wrap gap-7 border-b border-slate-100 px-4 py-4 text-sm font-black dark:border-slate-800">
              {tabs.map((tab) => (
                <button
                  key={tab.value}
                  type="button"
                  onClick={() => {
                    setActiveTab(tab.value);
                    setSelectedId(null);
                  }}
                  className={cn(
                    "relative border-b-2 border-transparent pb-3 text-slate-500 transition hover:text-blue-600 dark:text-slate-400 dark:hover:text-blue-300",
                    activeTab === tab.value && "border-blue-600 text-blue-600 dark:text-blue-300",
                  )}
                >
                  {tab.label}
                </button>
              ))}
            </div>

            <div className="grid gap-3 border-b border-slate-100 p-4 dark:border-slate-800 lg:grid-cols-[1fr_150px_180px_220px_170px_44px]">
              <div className="relative">
                <Search className="absolute left-3 top-1/2 size-4 -translate-y-1/2 text-slate-400" />
                <Input
                  value={searchTerm}
                  onChange={(event) => setSearchTerm(event.target.value)}
                  placeholder="Fayl nomi bo'yicha qidirish..."
                  className="h-10 rounded-xl pl-10 text-xs font-bold"
                />
              </div>
              <Select value={typeFilter} onChange={(event) => setTypeFilter(event.target.value)} className="h-10 rounded-xl text-xs font-black">
                <option value="all">Turi: Barchasi</option>
                <option value="image">Rasm</option>
                <option value="video">Video</option>
                <option value="voice">Audio</option>
                <option value="pdf">PDF</option>
                <option value="document">Hujjat</option>
                <option value="file">Boshqa</option>
              </Select>
              <Select value={sourceFilter} onChange={(event) => setSourceFilter(event.target.value)} className="h-10 rounded-xl text-xs font-black">
                <option value="all">Manba: Barchasi</option>
                <option value="admin">Admin</option>
                <option value="lesson">Mavzu darslari</option>
                <option value="tizim">Tizim</option>
              </Select>
              <Select value={usedFilter} onChange={(event) => setUsedFilter(event.target.value)} className="h-10 rounded-xl text-xs font-black">
                <option value="all">Foydalanilgan joy: Barchasi</option>
                <option value="used">Ishlatilgan</option>
                <option value="unused">Ishlatilmagan</option>
              </Select>
              <Select value={sortBy} onChange={(event) => setSortBy(event.target.value)} className="h-10 rounded-xl text-xs font-black">
                <option value="newest">Sana: Yangi - Eski</option>
                <option value="oldest">Sana: Eski - Yangi</option>
                <option value="size-desc">Hajm: Katta - Kichik</option>
                <option value="size-asc">Hajm: Kichik - Katta</option>
              </Select>
              <Button
                variant="secondary"
                size="icon"
                className="h-10 w-10 rounded-xl"
                onClick={() => {
                  setSearchTerm("");
                  setTypeFilter("all");
                  setSourceFilter("all");
                  setUsedFilter("all");
                  setSortBy("newest");
                }}
              >
                <Filter className="size-4" />
              </Button>
            </div>

            <div className="overflow-x-auto">
              <table className="w-full min-w-[940px] text-sm">
                <thead className="border-b border-slate-100 text-left text-[11px] font-black text-slate-500 dark:border-slate-800 dark:text-slate-400">
                  <tr>
                    <th className="px-4 py-4">Fayl</th>
                    <th className="px-4 py-4">Turi</th>
                    <th className="px-4 py-4">Hajmi</th>
                    <th className="px-4 py-4">Yuklangan sana</th>
                    <th className="px-4 py-4">Yuklangan joy</th>
                    <th className="px-4 py-4">Foydalanilgan joy</th>
                    <th className="px-4 py-4 text-right">Amallar</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-100 dark:divide-slate-800">
                  {isLoading ? (
                    Array.from({ length: 6 }).map((_, index) => (
                      <tr key={index}><td colSpan={7} className="px-4 py-4"><Skeleton className="h-8 rounded-lg" /></td></tr>
                    ))
                  ) : filteredItems.length ? (
                    filteredItems.map((item) => (
                      <tr
                        key={item.id}
                        onClick={() => setSelectedId(item.id)}
                        className={cn("cursor-pointer transition hover:bg-slate-50/70 dark:hover:bg-slate-950/40", selected?.id === item.id && "bg-blue-50/50 dark:bg-blue-500/10")}
                      >
                        <td className="px-4 py-4">
                          <div className="flex items-center gap-3">
                            <PreviewThumb item={item} />
                            <span className="min-w-0">
                              <span className="block truncate text-xs font-black text-slate-900 dark:text-white">{item.name}</span>
                              <span className="block truncate text-[11px] font-bold text-slate-500 dark:text-slate-400">
                                {item.width && item.height ? `${item.width} x ${item.height}` : item.duration ? formatDuration(item.duration) : item.publicId}
                              </span>
                            </span>
                          </div>
                        </td>
                        <td className="px-4 py-4"><KindBadge kind={item.kind} format={item.format} /></td>
                        <td className="px-4 py-4 text-xs font-bold text-slate-600 dark:text-slate-300">{formatBytes(item.bytes)}</td>
                        <td className="px-4 py-4 text-xs font-bold text-slate-500 dark:text-slate-400">{formatDateTime(item.createdAt)}</td>
                        <td className="px-4 py-4 text-xs font-bold text-slate-600 dark:text-slate-300">{item.uploadedBy}</td>
                        <td className="px-4 py-4">
                          {item.usedIn?.length ? (
                            <span className="inline-flex items-center gap-2 rounded-lg border border-slate-200 px-2.5 py-1.5 text-[11px] font-black text-slate-500 dark:border-slate-800 dark:text-slate-300">
                              <FileText className="size-3.5" />
                              {item.usedIn.length} joyda
                            </span>
                          ) : (
                            <span className="text-xs font-black text-slate-400">-</span>
                          )}
                        </td>
                        <td className="px-4 py-4">
                          <div className="flex justify-end gap-2" onClick={(event) => event.stopPropagation()}>
                            <IconButton title="Ko'rish" onClick={() => window.open(item.secureUrl, "_blank")}><Eye className="size-4" /></IconButton>
                            <IconButton title="Havolani nusxalash" onClick={() => copyLink(item.secureUrl)}><Link2 className="size-4" /></IconButton>
                            <IconButton title="Yuklab olish" onClick={() => downloadFile(item)}><Download className="size-4" /></IconButton>
                            <IconButton title="Batafsil" onClick={() => setSelectedId(item.id)}><MoreVertical className="size-4" /></IconButton>
                          </div>
                        </td>
                      </tr>
                    ))
                  ) : (
                    <tr><td colSpan={7} className="px-4 py-16 text-center text-xs font-bold text-slate-500">Fayllar topilmadi.</td></tr>
                  )}
                </tbody>
              </table>
            </div>

            <div className="flex flex-wrap items-center justify-between gap-3 border-t border-slate-100 px-4 py-4 text-xs font-bold text-slate-500 dark:border-slate-800 dark:text-slate-400">
              <span>Jami {filteredItems.length} ta fayl</span>
              <div className="flex items-center gap-2">
                <IconButton title="Oldingi">‹</IconButton>
                <span className="rounded-lg bg-blue-600 px-3 py-2 text-white">1</span>
                <IconButton title="Keyingi">›</IconButton>
                <Select value="20" onChange={() => undefined} className="h-9 rounded-xl text-xs font-black">
                  <option value="20">20 / sahifa</option>
                </Select>
              </div>
            </div>
          </section>

          <MediaDetails
            item={selected}
            onCopy={copyLink}
            onDownload={downloadFile}
            onDelete={deleteFile}
            deleting={deleteMutation.isPending}
          />
        </div>
      </div>
    </>
  );
}

function MediaStatCard({ icon: Icon, title, value, hint, tone }: { icon: React.ElementType; title: string; value: number; hint: string; tone: "blue" | "violet" | "rose" }) {
  const styles = {
    blue: "bg-blue-50 text-blue-600 dark:bg-blue-500/12 dark:text-blue-300",
    violet: "bg-violet-50 text-violet-600 dark:bg-violet-500/12 dark:text-violet-300",
    rose: "bg-rose-50 text-rose-600 dark:bg-rose-500/12 dark:text-rose-300",
  };
  return (
    <div className="rounded-xl border border-slate-200 bg-white p-4 shadow-[0_10px_28px_rgba(27,39,70,0.055)] dark:border-slate-800 dark:bg-slate-900">
      <div className="flex items-center gap-4">
        <span className={cn("flex size-12 items-center justify-center rounded-xl", styles[tone])}><Icon className="size-6" /></span>
        <span className="min-w-0">
          <span className="block text-xs font-black text-slate-600 dark:text-slate-300">{title}</span>
          <span className="mt-1 block text-2xl font-black">{value.toLocaleString("uz-UZ")}</span>
          <span className="mt-1 block truncate text-[11px] font-bold text-slate-500 dark:text-slate-400">{hint}</span>
        </span>
      </div>
    </div>
  );
}

function StorageCard({ bytes, percent }: { bytes: number; percent: number }) {
  return (
    <div className="rounded-xl border border-slate-200 bg-white p-4 shadow-[0_10px_28px_rgba(27,39,70,0.055)] dark:border-slate-800 dark:bg-slate-900">
      <p className="text-xs font-black text-slate-600 dark:text-slate-300">Xotira ishlatilishi</p>
      <p className="mt-3 text-xl font-black">{formatBytes(bytes)} <span className="text-sm text-slate-400">/ 100 GB</span></p>
      <div className="mt-4 flex items-center gap-3">
        <span className="h-2 flex-1 overflow-hidden rounded-full bg-slate-100 dark:bg-slate-800">
          <span className="block h-full rounded-full bg-blue-600" style={{ width: `${percent}%` }} />
        </span>
        <span className="text-xs font-black text-slate-500">{percent}%</span>
      </div>
    </div>
  );
}

function MediaDetails({ item, onCopy, onDownload, onDelete, deleting }: { item: MediaItem | null; onCopy: (url: string) => void; onDownload: (item: MediaItem) => void; onDelete: (item: MediaItem) => void; deleting: boolean }) {
  if (!item) {
    return (
      <aside className="rounded-xl border border-slate-200 bg-white p-6 text-center text-xs font-bold text-slate-500 shadow-[0_10px_28px_rgba(27,39,70,0.055)] dark:border-slate-800 dark:bg-slate-900">
        Tafsilotlarni ko'rish uchun faylni tanlang.
      </aside>
    );
  }

  return (
    <aside className="h-fit rounded-xl border border-slate-200 bg-white p-4 shadow-[0_10px_28px_rgba(27,39,70,0.055)] dark:border-slate-800 dark:bg-slate-900 xl:sticky xl:top-24">
      <div className="mb-4 flex items-center justify-between">
        <h3 className="text-base font-black">Fayl ma'lumotlari</h3>
        <button className="rounded-lg p-1.5 text-slate-400 hover:bg-slate-100 dark:hover:bg-slate-800"><X className="size-4" /></button>
      </div>

      <DetailPreview item={item} />

      <div className="mt-4">
        <div className="flex items-center justify-between gap-3">
          <h4 className="min-w-0 flex-1 truncate text-sm font-black">{item.name}</h4>
          <KindBadge kind={item.kind} format={item.format} />
        </div>
        <dl className="mt-4 space-y-3 text-xs font-bold">
          <DetailRow label="Hajmi" value={formatBytes(item.bytes)} />
          <DetailRow label="Format" value={item.format?.toUpperCase() || "-"} />
          <DetailRow label="Yuklangan sana" value={formatDateTime(item.createdAt)} />
          <DetailRow label="Yuklangan joy" value={item.uploadedBy} />
          <DetailRow label="Fayl manbai" value={item.resourceType} />
        </dl>
      </div>

      <div className="mt-4">
        <p className="mb-2 text-xs font-black text-slate-500">URL</p>
        <div className="flex items-center gap-2 rounded-xl border border-slate-200 bg-slate-50 px-3 py-2 dark:border-slate-800 dark:bg-slate-950">
          <span className="min-w-0 flex-1 truncate text-[11px] font-mono text-slate-500">{item.secureUrl}</span>
          <button onClick={() => onCopy(item.secureUrl)} className="text-slate-400 hover:text-blue-600"><Copy className="size-4" /></button>
        </div>
      </div>

      <div className="mt-5">
        <p className="mb-3 text-sm font-black">Foydalanilgan joylar ({item.usedIn?.length ?? 0})</p>
        {item.usedIn?.length ? (
          <ol className="space-y-2 text-xs font-bold">
            {item.usedIn.map((place, index) => (
              <li key={`${place}-${index}`} className="rounded-xl bg-slate-50 p-3 dark:bg-slate-950/45">
                {index + 1}. {place}
              </li>
            ))}
          </ol>
        ) : (
          <p className="rounded-xl bg-slate-50 p-3 text-xs font-bold text-slate-500 dark:bg-slate-950/45">Hali hech qayerda ishlatilmagan.</p>
        )}
      </div>

      <div className="mt-5 grid grid-cols-2 gap-2">
        <Button variant="secondary" className="h-10 rounded-xl text-xs font-black" onClick={() => onDownload(item)}>
          <Download className="size-4" />
          Yuklab olish
        </Button>
        <Button variant="secondary" className="h-10 rounded-xl text-xs font-black" onClick={() => window.open(item.secureUrl, "_blank")}>
          <Eye className="size-4" />
          Ko'rish
        </Button>
      </div>
      <Button
        variant="destructive"
        className="mt-3 h-11 w-full rounded-xl text-xs font-black"
        disabled={deleting || item.publicId.startsWith("lesson:")}
        onClick={() => onDelete(item)}
      >
        <Trash2 className="size-4" />
        {item.publicId.startsWith("lesson:") ? "Darsga ulangan fayl" : "Faylni o'chirish"}
      </Button>
    </aside>
  );
}

function DetailPreview({ item }: { item: MediaItem }) {
  if (item.kind === "image") {
    return <img src={item.secureUrl} alt={item.name} className="h-44 w-full rounded-xl object-cover" />;
  }
  if (item.kind === "video" || item.kind === "round_video") {
    return (
      <div className="relative overflow-hidden rounded-xl bg-slate-900">
        <video src={item.secureUrl} controls className="h-44 w-full object-cover" />
        <span className="absolute bottom-3 right-3 rounded-md bg-black/65 px-2 py-1 text-[11px] font-black text-white">{item.duration ? formatDuration(item.duration) : "VIDEO"}</span>
      </div>
    );
  }
  if (item.kind === "voice") {
    return (
      <div className="rounded-xl border border-slate-200 bg-slate-50 p-4 dark:border-slate-800 dark:bg-slate-950">
        <audio src={item.secureUrl} controls className="w-full" />
      </div>
    );
  }
  const Icon = getMediaIcon(item.kind);
  return (
    <div className="flex h-44 flex-col items-center justify-center rounded-xl bg-slate-50 text-slate-500 dark:bg-slate-950">
      <Icon className="size-12" />
      <span className="mt-2 text-xs font-black">{item.format?.toUpperCase() || item.kind}</span>
    </div>
  );
}

function PreviewThumb({ item }: { item: MediaItem }) {
  if (item.kind === "image") {
    return <img src={item.secureUrl} alt={item.name} className="size-12 shrink-0 rounded-lg object-cover" />;
  }
  if (item.kind === "video" || item.kind === "round_video") {
    return (
      <span className="relative flex size-12 shrink-0 items-center justify-center overflow-hidden rounded-lg bg-violet-100 text-violet-600 dark:bg-violet-500/15 dark:text-violet-300">
        <Play className="size-5 fill-current" />
      </span>
    );
  }
  const Icon = getMediaIcon(item.kind);
  return (
    <span className="flex size-12 shrink-0 items-center justify-center rounded-lg bg-blue-50 text-blue-600 dark:bg-blue-500/12 dark:text-blue-300">
      <Icon className="size-5" />
    </span>
  );
}

function KindBadge({ kind, format }: { kind: MediaKind; format?: string }) {
  const label = kindLabels[kind] ?? format?.toUpperCase() ?? "FILE";
  const variant = kind === "image" ? "success" : kind === "pdf" ? "danger" : kind === "voice" ? "warning" : kind === "video" || kind === "round_video" ? "violet" : "slate";
  return <Badge variant={variant as any}>{label}</Badge>;
}

function DetailRow({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex justify-between gap-4 border-b border-slate-100 pb-2 dark:border-slate-800">
      <dt className="text-slate-500">{label}</dt>
      <dd className="max-w-[190px] truncate text-right font-black">{value}</dd>
    </div>
  );
}

function IconButton({ children, title, onClick }: { children: React.ReactNode; title: string; onClick?: () => void }) {
  return (
    <button
      type="button"
      title={title}
      onClick={onClick}
      className="inline-flex size-9 items-center justify-center rounded-lg border border-slate-200 bg-white text-slate-500 shadow-sm transition hover:bg-slate-50 dark:border-slate-800 dark:bg-slate-950 dark:text-slate-300 dark:hover:bg-slate-900"
    >
      {children}
    </button>
  );
}

function getMediaIcon(kind: MediaKind) {
  if (kind === "image") return ImageIcon;
  if (kind === "video" || kind === "round_video") return FileVideo;
  if (kind === "voice") return FileAudio;
  if (kind === "pdf") return FileText;
  if (kind === "document") return FileText;
  return Music2;
}

function formatDuration(seconds: number) {
  const minutes = Math.floor(seconds / 60);
  const rest = Math.floor(seconds % 60).toString().padStart(2, "0");
  return `${minutes}:${rest}`;
}

function formatDateTime(value: string) {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return value;
  return date.toLocaleString("uz-UZ", {
    day: "2-digit",
    month: "2-digit",
    year: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  });
}
