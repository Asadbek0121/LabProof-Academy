"use client";

import { useMemo, useState } from "react";
import {
  Copy,
  Download,
  Eye,
  FileAudio,
  FileText,
  Film,
  ImageIcon,
  Link2,
  MoreVertical,
  Music2,
  Play,
  Search,
  SlidersHorizontal,
  Trash2,
  X,
  UploadCloud,
  CheckCircle2,
} from "lucide-react";
import { PageHeader } from "@/components/layout/page-header";
import { StatCard } from "@/components/layout/stat-card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Input, Select } from "@/components/ui/input";
import { Skeleton } from "@/components/ui/skeleton";
import { useMediaLibrary, useMediaStats } from "@/hooks/use-admin-data";
import { cn, formatBytes } from "@/lib/utils";
import type { MediaItem, MediaKind } from "@/lib/types";
import { createClient } from "@/lib/supabase/client";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { toast } from "sonner";

const tabs: Array<{ label: string; value: "all" | MediaKind }> = [
  { label: "Barcha fayllar", value: "all" },
  { label: "Rasmlar", value: "image" },
  { label: "Videolar", value: "video" },
  { label: "PDF", value: "pdf" },
  { label: "Audio", value: "voice" },
  { label: "Hujjatlar", value: "document" },
  { label: "Boshqalar", value: "file" },
];

export function MediaLibraryPage() {
  const queryClient = useQueryClient();
  const supabase = createClient();

  const { data: mediaItems = [], isLoading: isMediaLoading } = useMediaLibrary();
  const statsQuery = useMediaStats();

  const [activeTab, setActiveTab] = useState<(typeof tabs)[number]["value"]>("all");
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [searchTerm, setSearchTerm] = useState("");
  const [sortBy, setSortBy] = useState("newest");

  // Filter items
  const filteredItems = useMemo(() => {
    let result = mediaItems;
    
    // Tab Filter
    if (activeTab !== "all") {
      result = result.filter((item: any) => item.kind === activeTab);
    }

    // Search Filter
    if (searchTerm.trim() !== "") {
      result = result.filter((item: any) => 
        item.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
        item.publicId.toLowerCase().includes(searchTerm.toLowerCase())
      );
    }

    // Sorting
    result = [...result].sort((a: any, b: any) => {
      const timeA = new Date(a.createdAt).getTime();
      const timeB = new Date(b.createdAt).getTime();
      
      if (sortBy === "newest") return timeB - timeA;
      if (sortBy === "oldest") return timeA - timeB;
      if (sortBy === "size-desc") return b.bytes - a.bytes;
      if (sortBy === "size-asc") return a.bytes - b.bytes;
      return 0;
    });

    return result;
  }, [mediaItems, activeTab, searchTerm, sortBy]);

  // Selected Item
  const selected = useMemo(() => {
    if (filteredItems.length === 0) return null;
    if (selectedId) {
      const found = filteredItems.find((item: any) => item.id === selectedId);
      if (found) return found;
    }
    return filteredItems[0];
  }, [filteredItems, selectedId]);

  // Delete Mutation
  const deleteMutation = useMutation({
    mutationFn: async (id: string) => {
      const { error } = await supabase.from("media_library").delete().eq("id", id);
      if (error) throw error;
    },
    onSuccess: () => {
      toast.success("Media fayli muvaffaqiyatli o'chirildi");
      queryClient.invalidateQueries({ queryKey: ["media-library"] });
      queryClient.invalidateQueries({ queryKey: ["media-stats"] });
      setSelectedId(null);
    },
    onError: (err: any) => {
      toast.error(err.message || "Faylni o'chirishda xatolik yuz berdi");
    }
  });

  const handleDelete = (item: any) => {
    if (confirm(`Media fayli "${item.name}" ni o'chirib tashlamoqchimisiz?`)) {
      deleteMutation.mutate(item.id);
    }
  };

  const handleCopyLink = (url: string) => {
    navigator.clipboard.writeText(url);
    toast.success("Havola buferga ko'chirildi!");
  };

  return (
    <>
      <PageHeader title="Media kutubxona" current="Media kutubxona" />
      <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-5 mb-6">
        {statsQuery.isLoading
          ? Array.from({ length: 4 }).map((_, idx) => (
              <Skeleton key={idx} className="h-24 rounded-2xl" />
            ))
          : statsQuery.data?.map((item) => (
              <StatCard key={item.title} item={item} />
            ))}
        <Card className="shadow-soft">
          <CardContent className="p-5 flex flex-col justify-between h-full">
            <div>
              <p className="text-xs font-bold text-slate-400 uppercase">Bulut xotirasi</p>
              <p className="mt-2 text-2xl font-extrabold text-slate-800">Cloudinary</p>
              <p className="text-[10px] font-semibold text-slate-400 mt-1">Real-time sync faol</p>
            </div>
          </CardContent>
        </Card>
      </div>

      <div className="grid gap-6 xl:grid-cols-[1fr_380px]">
        <Card className="shadow-soft">
          <CardHeader className="border-b border-border">
            <div className="flex flex-wrap gap-5">
              {tabs.map((tab) => (
                <button
                  key={tab.value}
                  onClick={() => { setActiveTab(tab.value); setSelectedId(null); }}
                  className={cn(
                    "relative pb-3 text-sm font-bold text-slate-500 transition hover:text-primary",
                    activeTab === tab.value && "text-primary",
                  )}
                >
                  {tab.label}
                  {activeTab === tab.value ? (
                    <span className="absolute inset-x-0 -bottom-px h-0.5 rounded-full bg-primary" />
                  ) : null}
                </button>
              ))}
            </div>
          </CardHeader>
          <CardContent className="p-0">
            <div className="grid gap-3 border-b border-border p-4 xl:grid-cols-[1fr_180px_180px]">
              <div className="relative">
                <Search className="absolute left-3 top-1/2 size-4 -translate-y-1/2 text-slate-400" />
                <Input
                  value={searchTerm}
                  onChange={(e) => setSearchTerm(e.target.value)}
                  placeholder="Fayl nomi bo'yicha qidirish..."
                  className="pl-10"
                />
              </div>
              <Select value={sortBy} onChange={(e) => setSortBy(e.target.value)}>
                <option value="newest">Yangi - Eski</option>
                <option value="oldest">Eski - Yangi</option>
                <option value="size-desc">Katta - Kichik</option>
                <option value="size-asc">Kichik - Katta</option>
              </Select>
              <Button onClick={() => { setSearchTerm(""); setSortBy("newest"); }} variant="secondary">
                Tozalash
              </Button>
            </div>

            <div className="overflow-x-auto edulab-scrollbar">
              <table className="w-full min-w-[850px] text-sm">
                <thead className="bg-slate-50 text-left text-xs font-bold uppercase text-slate-500">
                  <tr>
                    <th className="px-5 py-4">Foydalanuvchi/Fayl</th>
                    <th className="px-5 py-4">Turi</th>
                    <th className="px-5 py-4">Hajmi</th>
                    <th className="px-5 py-4">Yuklangan sana</th>
                    <th className="px-5 py-4">Yuklovchi</th>
                    <th className="px-5 py-4 text-center">Amallar</th>
                  </tr>
                </thead>
                <tbody>
                  {isMediaLoading ? (
                    Array.from({ length: 5 }).map((_, idx) => (
                      <tr key={idx} className="border-t border-border">
                        <td colSpan={6} className="px-5 py-4">
                          <Skeleton className="h-6 w-full" />
                        </td>
                      </tr>
                    ))
                  ) : filteredItems.length > 0 ? (
                    filteredItems.map((item: any) => (
                      <tr
                        key={item.id}
                        className={cn(
                          "cursor-pointer border-t border-border transition hover:bg-blue-50/30",
                          selected?.id === item.id && "bg-blue-50/40"
                        )}
                        onClick={() => setSelectedId(item.id)}
                      >
                        <td className="px-5 py-4">
                          <div className="flex items-center gap-3">
                            <PreviewThumb item={item} />
                            <div className="min-w-0 max-w-[200px]">
                              <span className="block font-bold truncate text-slate-800">{item.name}</span>
                              <span className="text-slate-500 text-xs truncate block">
                                {item.width && item.height ? `${item.width}x${item.height}` : item.duration ? formatDuration(item.duration) : "fayl"}
                              </span>
                            </div>
                          </div>
                        </td>
                        <td className="px-5 py-4">
                          <Badge variant={item.kind === "pdf" ? "danger" : item.kind === "image" ? "success" : item.kind === "voice" ? "warning" : "slate"}>
                            {item.format.toUpperCase()}
                          </Badge>
                        </td>
                        <td className="px-5 py-4 font-semibold text-slate-600">{formatBytes(item.bytes)}</td>
                        <td className="px-5 py-4 text-slate-500 text-xs">
                          {new Date(item.createdAt).toLocaleDateString("uz-UZ")}
                        </td>
                        <td className="px-5 py-4 font-bold text-slate-700">{item.uploadedBy}</td>
                        <td className="px-5 py-4">
                          <div className="flex justify-center gap-2" onClick={(e) => e.stopPropagation()}>
                            <Button variant="secondary" size="icon" onClick={() => handleCopyLink(item.secureUrl)}>
                              <Copy className="size-4" />
                            </Button>
                            <a href={item.secureUrl} target="_blank" rel="noopener noreferrer">
                              <Button variant="secondary" size="icon">
                                <Eye className="size-4" />
                              </Button>
                            </a>
                            <Button variant="secondary" size="icon" className="text-red-600 hover:bg-red-50" onClick={() => handleDelete(item)}>
                              <Trash2 className="size-4" />
                            </Button>
                          </div>
                        </td>
                      </tr>
                    ))
                  ) : (
                    <tr>
                      <td colSpan={6} className="text-center py-10 font-bold text-slate-400">
                        Fayllar topilmadi.
                      </td>
                    </tr>
                  )}
                </tbody>
              </table>
            </div>

            <div className="flex flex-wrap items-center justify-between gap-3 border-t border-border px-5 py-4 text-sm text-slate-500">
              <span>Jami {filteredItems.length} ta fayl ko'rsatilmoqda</span>
            </div>
          </CardContent>
        </Card>

        {selected ? (
          <MediaDetails item={selected} onCopy={handleCopyLink} onDelete={handleDelete} />
        ) : (
          <Card className="shadow-soft h-fit p-6 text-center text-slate-400 font-bold">
            Tafsilotlarni ko'rish uchun faylni tanlang.
          </Card>
        )}
      </div>
    </>
  );
}

function MediaDetails({ item, onCopy, onDelete }: { item: any; onCopy: (url: string) => void; onDelete: (item: any) => void }) {
  return (
    <Card className="sticky top-28 h-fit overflow-hidden shadow-soft">
      <CardHeader className="border-b border-border">
        <CardTitle className="text-lg font-extrabold">Fayl Tafsilotlari</CardTitle>
      </CardHeader>
      <CardContent className="space-y-5 p-5">
        <div className="relative overflow-hidden rounded-2xl border border-border bg-slate-50 flex items-center justify-center min-h-[160px]">
          {item.kind === "image" ? (
            <img src={item.secureUrl} alt={item.name} className="max-h-[160px] object-contain rounded-2xl" />
          ) : item.kind === "video" ? (
            <div className="relative w-full aspect-video bg-black flex items-center justify-center text-white rounded-2xl">
              <Film className="size-12 opacity-60" />
              <span className="absolute bottom-2 right-2 bg-black/60 px-2 py-0.5 rounded text-xs">Video</span>
            </div>
          ) : (
            <div className="flex flex-col items-center gap-2">
              <FileText className="size-12 text-blue-500" />
              <span className="text-xs font-bold uppercase text-slate-500">{item.format} hujjat</span>
            </div>
          )}
        </div>

        <div>
          <div className="flex items-center gap-2">
            <h3 className="min-w-0 flex-1 truncate text-base font-extrabold text-slate-800">{item.name}</h3>
            <Badge variant="slate">{item.kind}</Badge>
          </div>
          <dl className="mt-4 grid gap-3 text-xs font-semibold text-slate-600">
            {[
              ["Public ID", item.publicId],
              ["Hajmi", formatBytes(item.bytes)],
              ["Format", item.format.toUpperCase()],
              ["Yuklangan sana", new Date(item.createdAt).toLocaleString("uz-UZ")],
              ["Yuklovchi", item.uploadedBy],
              ["Turi", item.resourceType],
            ].map(([label, value]) => (
              <div key={label} className="flex justify-between gap-4 border-b border-slate-50 pb-2">
                <dt className="text-slate-400">{label}</dt>
                <dd className="max-w-[180px] truncate text-right font-bold text-slate-800">{value}</dd>
              </div>
            ))}
          </dl>
        </div>

        <div>
          <p className="mb-2 text-xs font-bold text-slate-400 uppercase">Havola (URL)</p>
          <div className="flex items-center gap-2 rounded-xl border border-border bg-slate-50 px-3 py-2 text-xs">
            <span className="min-w-0 flex-1 truncate text-slate-500 font-mono">{item.secureUrl}</span>
            <button onClick={() => onCopy(item.secureUrl)} className="text-slate-400 hover:text-slate-600 shrink-0">
              <Copy className="size-4" />
            </button>
          </div>
        </div>

        <Button variant="destructive" className="w-full font-bold" onClick={() => onDelete(item)}>
          <Trash2 className="size-4" />
          Faylni o'chirish
        </Button>
      </CardContent>
    </Card>
  );
}

function PreviewThumb({ item }: { item: any }) {
  const Icon = getMediaIcon(item.kind);
  if (item.kind === "image") {
    return (
      <img
        src={item.secureUrl}
        alt={item.name}
        className="size-12 overflow-hidden rounded-xl object-cover border border-slate-100 shrink-0"
      />
    );
  }
  return (
    <span className="flex size-12 items-center justify-center rounded-xl bg-blue-50 text-primary shrink-0">
      <Icon className="size-5" />
    </span>
  );
}

function getMediaIcon(kind: MediaKind) {
  if (kind === "image") return ImageIcon;
  if (kind === "video" || kind === "round_video") return Film;
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
