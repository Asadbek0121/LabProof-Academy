"use client";

import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { useEffect, useMemo, useRef, useState } from "react";
import { toast } from "sonner";
import {
  Bell,
  ChevronDown,
  GraduationCap,
  LogOut,
  Mail,
  PanelLeftClose,
  PanelLeftOpen,
  Phone,
  Save,
  Search,
  ShieldCheck,
  X,
  UserRound,
} from "lucide-react";
import { useConversations } from "@/hooks/use-admin-data";
import { useAdminRealtime } from "@/hooks/use-realtime";
import { useAdminStore } from "@/store/admin-store";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { ThemeSwitch } from "@/components/ui/theme-switch";
import { navigation } from "@/components/layout/nav-data";
import { createClient } from "@/lib/supabase/client";
import { cn } from "@/lib/utils";

type AdminProfile = {
  id: string;
  email: string;
  full_name: string | null;
  phone: string | null;
  role: string | null;
};

const LOCAL_ADMIN_PROFILE_KEY = "edulab-admin-local-profile";

function getLocalAdminProfile(): AdminProfile {
  if (typeof window === "undefined") {
    return {
      id: "local-admin",
      email: "admin@labproof.local",
      full_name: "Admin",
      phone: null,
      role: "admin",
    };
  }

  try {
    const saved = localStorage.getItem(LOCAL_ADMIN_PROFILE_KEY);
    if (saved) {
      const parsed = JSON.parse(saved) as Partial<AdminProfile>;
      return {
        id: "local-admin",
        email: parsed.email || "admin@labproof.local",
        full_name: parsed.full_name || "Admin",
        phone: parsed.phone || null,
        role: parsed.role || "admin",
      };
    }
  } catch {
    // Local profile is just a demo convenience; corrupted data falls back safely.
  }

  return {
    id: "local-admin",
    email: "admin@labproof.local",
    full_name: "Admin",
    phone: null,
    role: "admin",
  };
}

function saveLocalAdminProfile(profile: AdminProfile) {
  if (typeof window === "undefined") return;
  localStorage.setItem(LOCAL_ADMIN_PROFILE_KEY, JSON.stringify(profile));
}

export function AdminShell({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  const router = useRouter();
  const conversations = useConversations();
  const supabase = useMemo(() => createClient(), []);
  const headerRef = useRef<HTMLDivElement>(null);
  const searchInputRef = useRef<HTMLInputElement>(null);
  const [searchOpen, setSearchOpen] = useState(false);
  const [darkMode, setDarkMode] = useState(false);
  const [profileModalOpen, setProfileModalOpen] = useState(false);
  const [profileLoading, setProfileLoading] = useState(false);
  const [profileSaving, setProfileSaving] = useState(false);
  const [adminProfile, setAdminProfile] = useState<AdminProfile | null>(null);
  const [profileName, setProfileName] = useState("");
  const [profilePhone, setProfilePhone] = useState("");
  const {
    sidebarCollapsed,
    searchQuery,
    notificationsOpen,
    profileOpen,
    toggleSidebar,
    setSearchQuery,
    setNotificationsOpen,
    setProfileOpen,
  } = useAdminStore();

  useAdminRealtime();

  useEffect(() => {
    let alive = true;

    const loadProfile = async () => {
      const { data: userData } = await supabase.auth.getUser();
      const user = userData.user;
      if (!user) {
        if (!alive) return;
        const localProfile = getLocalAdminProfile();
        setAdminProfile(localProfile);
        setProfileName(localProfile.full_name || "");
        setProfilePhone(localProfile.phone || "");
        return;
      }
      if (!alive) return;

      const { data: profile } = await supabase
        .from("profiles")
        .select("id, full_name, phone, role")
        .eq("id", user.id)
        .maybeSingle();

      if (!alive) return;
      const nextProfile: AdminProfile = {
        id: user.id,
        email: user.email || "email yo'q",
        full_name: profile?.full_name ?? user.user_metadata?.full_name ?? null,
        phone: profile?.phone ?? null,
        role: profile?.role ?? "admin",
      };
      setAdminProfile(nextProfile);
      setProfileName(nextProfile.full_name || "");
      setProfilePhone(nextProfile.phone || "");
    };

    loadProfile();
    return () => {
      alive = false;
    };
  }, [supabase]);

  useEffect(() => {
    const savedTheme = localStorage.getItem("edulab-theme");
    const shouldUseDark =
      savedTheme === "dark" ||
      (!savedTheme && window.matchMedia?.("(prefers-color-scheme: dark)").matches);
    setDarkMode(shouldUseDark);
    document.documentElement.classList.toggle("dark", shouldUseDark);
  }, []);

  useEffect(() => {
    document.documentElement.classList.toggle("dark", darkMode);
    localStorage.setItem("edulab-theme", darkMode ? "dark" : "light");
  }, [darkMode]);

  useEffect(() => {
    const handleKeyDown = (event: KeyboardEvent) => {
      if ((event.ctrlKey || event.metaKey) && event.key === "/") {
        event.preventDefault();
        searchInputRef.current?.focus();
        setSearchOpen(true);
      }
      if (event.key === "Escape") {
        setSearchOpen(false);
        setNotificationsOpen(false);
        setProfileOpen(false);
      }
    };
    const handleClick = (event: MouseEvent) => {
      if (!headerRef.current?.contains(event.target as Node)) {
        setSearchOpen(false);
        setNotificationsOpen(false);
        setProfileOpen(false);
      }
    };
    window.addEventListener("keydown", handleKeyDown);
    window.addEventListener("mousedown", handleClick);
    return () => {
      window.removeEventListener("keydown", handleKeyDown);
      window.removeEventListener("mousedown", handleClick);
    };
  }, [setNotificationsOpen, setProfileOpen]);

  const recentConversations = conversations.data ?? [];
  const unreadCount = recentConversations.reduce((sum, item) => sum + item.unread, 0);
  const notificationItems = recentConversations
    .filter((item) => item.unread > 0)
    .slice(0, 5);

  const searchResults = useMemo(() => {
    const query = searchQuery.trim().toLowerCase();
    if (!query) return [];

    const navResults = navigation.flatMap((group) =>
      group.items
        .filter((item) => {
          return (
            item.title.toLowerCase().includes(query) ||
            item.href.toLowerCase().includes(query)
          );
        })
        .map((item) => ({
          key: `nav:${item.href}`,
          title: item.title,
          subtitle: group.label,
          href: item.href,
        })),
    );

    const supportResults = recentConversations
      .filter((item) => {
        return (
          item.name.toLowerCase().includes(query) ||
          item.lastMessage.toLowerCase().includes(query) ||
          item.username?.toLowerCase().includes(query) ||
          item.telegramChatId?.toLowerCase().includes(query)
        );
      })
      .slice(0, 4)
      .map((item) => ({
        key: `support:${item.id}`,
        title: item.name,
        subtitle: `${item.label ?? "SUPPORT"} · ${item.lastMessage}`,
        href: "/support-requests",
      }));

    return [...navResults, ...supportResults].slice(0, 7);
  }, [recentConversations, searchQuery]);

  const openSearchResult = (href: string) => {
    router.push(href);
    setSearchOpen(false);
    setSearchQuery("");
  };

  const displayName = adminProfile?.full_name?.trim() || "Admin";
  const displayRole = adminProfile?.role === "teacher" ? "Teacher" : adminProfile?.role === "admin" ? "Super Admin" : "Admin";

  const openProfileModal = async () => {
    setProfileOpen(false);
    setProfileModalOpen(true);
    setProfileLoading(true);
    const { data: userData, error: userError } = await supabase.auth.getUser();
    if (userError || !userData.user) {
      const localProfile = getLocalAdminProfile();
      setAdminProfile(localProfile);
      setProfileName(localProfile.full_name || "");
      setProfilePhone(localProfile.phone || "");
      setProfileLoading(false);
      return;
    }

    const { data: profile, error } = await supabase
      .from("profiles")
      .select("id, full_name, phone, role")
      .eq("id", userData.user.id)
      .maybeSingle();

    if (error) {
      toast.error(error.message || "Profil jadvalidan ma'lumot olinmadi");
      setProfileLoading(false);
      return;
    }

    const nextProfile: AdminProfile = {
      id: userData.user.id,
      email: userData.user.email || "email yo'q",
      full_name: profile?.full_name ?? userData.user.user_metadata?.full_name ?? null,
      phone: profile?.phone ?? null,
      role: profile?.role ?? "admin",
    };
    setAdminProfile(nextProfile);
    setProfileName(nextProfile.full_name || "");
    setProfilePhone(nextProfile.phone || "");
    setProfileLoading(false);
  };

  const saveProfile = async () => {
    if (!adminProfile) {
      toast.error("Profil sessiyasi topilmadi");
      return;
    }

    setProfileSaving(true);
    if (adminProfile.id === "local-admin") {
      const localProfile = {
        ...adminProfile,
        full_name: profileName.trim() || "Admin",
        phone: profilePhone.trim() || null,
      };
      saveLocalAdminProfile(localProfile);
      setAdminProfile(localProfile);
      toast.success("Profil ma'lumotlari saqlandi");
      setProfileSaving(false);
      setProfileModalOpen(false);
      return;
    }

    const { error } = await supabase
      .from("profiles")
      .update({
        full_name: profileName.trim() || null,
        phone: profilePhone.trim() || null,
      })
      .eq("id", adminProfile.id);

    if (error) {
      toast.error(error.message || "Profil saqlanmadi");
      setProfileSaving(false);
      return;
    }

    const nextProfile = {
      ...adminProfile,
      full_name: profileName.trim() || null,
      phone: profilePhone.trim() || null,
    };
    setAdminProfile(nextProfile);
    toast.success("Profil ma'lumotlari saqlandi");
    setProfileSaving(false);
    setProfileModalOpen(false);
  };

  return (
    <div className="admin-shell admin-compact min-h-screen bg-slate-50 text-slate-950 transition-colors dark:bg-slate-950 dark:text-slate-100">
      <aside
        className={cn(
          "fixed inset-y-0 left-0 z-40 flex flex-col border-r border-white/10 bg-[#071B3A] text-white shadow-[14px_0_36px_rgba(15,23,42,0.18)] transition-all duration-300",
          sidebarCollapsed ? "w-[72px] xl:w-[76px]" : "w-[220px] xl:w-[248px]",
        )}
      >
        <Link href="/students" className="flex h-[68px] items-center gap-3 border-b border-white/10 px-4 xl:h-[76px] xl:px-5">
          <div className="flex size-10 items-center justify-center rounded-lg bg-blue-600 shadow-[0_10px_22px_rgba(37,99,235,0.28)]">
            <GraduationCap className="size-5" />
          </div>
          {!sidebarCollapsed ? (
            <div>
              <p className="text-base font-extrabold leading-tight">LabProof</p>
              <p className="text-xs font-semibold text-blue-100/70">Admin Panel</p>
            </div>
          ) : null}
        </Link>

        <nav className="flex-1 overflow-y-auto px-2.5 py-3 edulab-scrollbar xl:px-3 xl:py-4">
          {navigation.map((group) => (
            <div key={group.label} className="mb-4 xl:mb-5">
              {!sidebarCollapsed ? (
                <p className="mb-2 px-2 text-[11px] font-extrabold uppercase tracking-[0.18em] text-blue-100/45">
                  {group.label}
                </p>
              ) : null}
              <div className="flex flex-col gap-1">
                {group.items.map((item) => {
                  const active =
                    pathname === item.href ||
                    (item.href !== "/" && pathname.startsWith(item.href));
                  return (
                    <Link
                      key={item.href}
                      href={item.href}
                      className={cn(
                        "group relative flex h-10 items-center gap-3 rounded-lg px-3 text-[13px] font-bold text-blue-50/82 transition-all duration-200 hover:bg-white/9 hover:text-white xl:h-11 xl:text-sm",
                        active &&
                          "bg-white/13 text-white ring-1 ring-white/10 shadow-[inset_3px_0_0_rgba(96,165,250,0.9)]",
                        sidebarCollapsed && "justify-center px-0",
                      )}
                    >
                      <item.icon className={cn("size-5 shrink-0", active ? "text-blue-200" : "text-blue-100/80")} />
                      {!sidebarCollapsed ? <span>{item.title}</span> : null}
                    </Link>
                  );
                })}
              </div>
            </div>
          ))}
        </nav>

        <div className="p-3 xl:p-4">
          <div
            className={cn(
              "flex items-center gap-3 rounded-lg border border-white/10 bg-white/7 p-3",
              sidebarCollapsed && "justify-center",
            )}
          >
            <div className="flex size-9 items-center justify-center rounded-md bg-blue-600">
              <UserRound className="size-5" />
            </div>
            {!sidebarCollapsed ? (
              <>
                <div className="min-w-0 flex-1">
                  <p className="truncate text-sm font-bold">Admin</p>
                  <p className="truncate text-xs text-blue-100/75">Super Admin</p>
                </div>
                <button className="rounded-lg p-1 text-blue-100/70 hover:bg-white/10">
                  <ChevronDown className="size-4" />
                </button>
              </>
            ) : null}
          </div>
        </div>
      </aside>

      <div
        className={cn(
          "min-h-screen transition-[padding] duration-300",
          sidebarCollapsed ? "pl-[72px] xl:pl-[76px]" : "pl-[220px] xl:pl-[248px]",
        )}
      >
        <header
          ref={headerRef}
          className="sticky top-0 z-30 flex h-[68px] items-center justify-between border-b border-slate-200 bg-white/92 px-4 backdrop-blur-xl transition-colors dark:border-slate-800 dark:bg-[#070B16]/94 xl:h-[76px] xl:px-6"
        >
          <Button
            variant="secondary"
            size="icon"
            onClick={toggleSidebar}
            aria-label={sidebarCollapsed ? "Yon menyuni ochish" : "Yon menyuni yopish"}
            className="admin-header-icon"
          >
            {sidebarCollapsed ? <PanelLeftOpen /> : <PanelLeftClose />}
          </Button>

          <div className="ml-auto flex items-center gap-2.5">
            <div className="relative hidden w-[320px] lg:block xl:w-[420px]">
              <Search className="absolute left-4 top-1/2 size-4.5 -translate-y-1/2 text-slate-400 dark:text-slate-500" />
              <Input
                ref={searchInputRef}
                value={searchQuery}
                onChange={(event) => {
                  setSearchQuery(event.target.value);
                  setSearchOpen(true);
                }}
                onFocus={() => setSearchOpen(true)}
                onKeyDown={(event) => {
                  if (event.key === "Enter" && searchResults[0]) {
                    event.preventDefault();
                    openSearchResult(searchResults[0].href);
                  }
                }}
                placeholder="Qidirish..."
                className="h-11 rounded-xl border-slate-200 bg-slate-50/80 pl-11 pr-16 text-sm font-semibold shadow-inner shadow-slate-200/35 transition focus:bg-white dark:border-slate-800 dark:bg-slate-900/72 dark:text-slate-100 dark:shadow-none dark:placeholder:text-slate-500"
              />
              <span className="absolute right-2.5 top-1/2 -translate-y-1/2 rounded-lg bg-white px-2.5 py-1.5 text-[11px] font-black text-slate-400 ring-1 ring-slate-200 dark:bg-slate-950 dark:text-slate-500 dark:ring-slate-800">
                Ctrl /
              </span>
              {searchOpen && searchQuery.trim() ? (
                <div className="absolute left-0 top-12 z-40 w-full rounded-lg border border-border bg-white p-2 shadow-soft dark:border-slate-800 dark:bg-slate-900">
                  {searchResults.length ? (
                    searchResults.map((item) => (
                      <button
                        key={item.key}
                        type="button"
                        onClick={() => openSearchResult(item.href)}
                        className="block w-full rounded-md px-3 py-2 text-left hover:bg-slate-50 dark:hover:bg-slate-800"
                      >
                        <span className="block text-sm font-bold text-slate-800 dark:text-slate-100">
                          {item.title}
                        </span>
                        <span className="mt-0.5 block truncate text-xs font-semibold text-slate-400">
                          {item.subtitle}
                        </span>
                      </button>
                    ))
                  ) : (
                    <div className="px-3 py-6 text-center text-xs font-bold text-slate-400">
                      Natija topilmadi
                    </div>
                  )}
                </div>
              ) : null}
            </div>

            <div className="relative">
              <Button
                variant="secondary"
                size="icon"
                onClick={() => setNotificationsOpen(!notificationsOpen)}
                aria-label="Bildirishnomalar"
                className="admin-header-icon"
              >
                <Bell />
              </Button>
              {unreadCount > 0 ? (
                <span className="absolute -right-1 -top-1 flex size-5 items-center justify-center rounded-full bg-red-500 text-[10px] font-bold text-white">
                  {unreadCount > 9 ? "9+" : unreadCount}
                </span>
              ) : null}
              {notificationsOpen ? (
                <div className="absolute right-0 mt-3 w-[22rem] rounded-xl border border-border bg-white p-3 shadow-soft dark:border-slate-800 dark:bg-slate-900 dark:text-slate-100">
                  <div className="flex items-center justify-between px-2 pb-2">
                    <p className="text-sm font-bold">Bildirishnomalar</p>
                    <Link
                      href="/support-requests"
                      onClick={() => setNotificationsOpen(false)}
                      className="text-xs font-bold text-blue-600 hover:underline"
                    >
                      Hammasi
                    </Link>
                  </div>
                  {notificationItems.length ? (
                    notificationItems.map((item) => (
                      <Link
                        key={item.id}
                        href="/support-requests"
                        onClick={() => setNotificationsOpen(false)}
                        className="block rounded-md px-3 py-2 hover:bg-slate-50 dark:hover:bg-slate-800"
                      >
                        <span className="flex items-center justify-between gap-3">
                          <span className="truncate text-sm font-bold">{item.name}</span>
                          <span className="rounded-full bg-red-50 px-2 py-0.5 text-[10px] font-black text-red-600">
                            {item.unread}
                          </span>
                        </span>
                        <span className="mt-1 block truncate text-xs font-semibold text-slate-400">
                          {item.lastMessage}
                        </span>
                      </Link>
                    ))
                  ) : (
                    <div className="px-3 py-6 text-center text-xs font-bold text-slate-400">
                      Yangi bildirishnoma yo'q
                    </div>
                  )}
                </div>
              ) : null}
            </div>

            <div className="admin-theme-switch-shell">
              <ThemeSwitch checked={darkMode} onCheckedChange={setDarkMode} />
            </div>

            <div className="relative">
              <button
                onClick={() => setProfileOpen(!profileOpen)}
                aria-label="Admin profil menyusi"
                className="flex h-10 min-w-[176px] items-center gap-2 rounded-xl border border-slate-200 bg-white px-2.5 shadow-sm shadow-slate-200/45 transition hover:border-blue-200 hover:bg-blue-50/45 dark:border-slate-800 dark:bg-slate-900 dark:text-slate-100 dark:shadow-none dark:hover:border-blue-900 dark:hover:bg-slate-800 xl:h-11 xl:min-w-[220px] xl:gap-3 xl:px-3"
              >
                <span className="flex size-8 items-center justify-center rounded-lg bg-blue-600 text-white shadow-[0_10px_22px_rgba(37,99,235,0.24)] xl:size-9">
                  <UserRound className="size-5" />
                </span>
                <span className="hidden text-left sm:block">
                  <span className="block max-w-[116px] truncate text-sm font-black leading-tight xl:max-w-[150px]">{displayName}</span>
                  <span className="block text-xs text-slate-500">{displayRole}</span>
                </span>
                <ChevronDown className="size-4 text-slate-500" />
              </button>
              {profileOpen ? (
                <div className="absolute right-0 mt-3 w-56 rounded-xl border border-border bg-white p-2 text-sm shadow-soft dark:border-slate-800 dark:bg-slate-900 dark:text-slate-100">
                  <button
                    type="button"
                    onClick={openProfileModal}
                    className="flex w-full items-center gap-2 rounded-md px-3 py-2 text-left font-semibold text-slate-700 hover:bg-slate-50 dark:text-slate-100 dark:hover:bg-slate-800"
                  >
                    <UserRound className="size-4" />
                    Profil
                  </button>
                  <Link
                    className="flex w-full items-center gap-2 rounded-md px-3 py-2 text-left font-semibold text-red-600 hover:bg-red-50 dark:hover:bg-red-500/10"
                    href="/logout"
                  >
                    <LogOut className="size-4" />
                    Chiqish
                  </Link>
                </div>
              ) : null}
            </div>
          </div>
        </header>

        <main className="mx-auto min-h-[calc(100vh-68px)] max-w-[1680px] bg-slate-50 px-4 py-4 transition-colors dark:bg-slate-950 xl:min-h-[calc(100vh-76px)] xl:px-6 xl:py-6">
          {children}
        </main>
      </div>

      {profileModalOpen ? (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-950/35 p-4 backdrop-blur-sm dark:bg-slate-950/70">
          <div
            role="dialog"
            aria-modal="true"
            aria-label="Admin profili"
            className="w-full max-w-2xl overflow-hidden rounded-2xl border border-slate-200 bg-white shadow-[0_24px_70px_rgba(15,23,42,0.2)] dark:border-slate-800 dark:bg-slate-900"
          >
            <div className="flex items-start justify-between gap-4 border-b border-slate-100 p-5 dark:border-slate-800">
              <div className="flex items-center gap-4">
                <div className="flex size-14 items-center justify-center rounded-2xl bg-blue-600 text-white shadow-[0_14px_28px_rgba(37,99,235,0.26)]">
                  <UserRound className="size-7" />
                </div>
                <div>
                  <h2 className="text-xl font-black text-slate-950 dark:text-slate-100">Admin profili</h2>
                  <p className="mt-1 text-sm font-semibold text-slate-500 dark:text-slate-400">
                    Shaxsiy ma'lumotlarni ko'rish va tahrirlash
                  </p>
                </div>
              </div>
              <Button variant="ghost" size="icon" onClick={() => setProfileModalOpen(false)} aria-label="Yopish">
                <X />
              </Button>
            </div>

            {profileLoading ? (
              <div className="flex min-h-[280px] items-center justify-center text-sm font-bold text-slate-400">
                <span className="mr-3 size-5 animate-spin rounded-full border-2 border-blue-600 border-t-transparent" />
                Profil yuklanmoqda...
              </div>
            ) : (
              <div className="space-y-5 p-5">
                <div className="grid gap-3 sm:grid-cols-3">
                  <ProfileInfo icon={Mail} label="Email" value={adminProfile?.email || "email yo'q"} />
                  <ProfileInfo icon={ShieldCheck} label="Rol" value={displayRole} />
                  <ProfileInfo icon={Phone} label="Telefon" value={adminProfile?.phone || "Kiritilmagan"} />
                </div>

                <div className="grid gap-4 sm:grid-cols-2">
                  <label className="space-y-2">
                    <span className="text-xs font-black uppercase tracking-[0.14em] text-slate-400">Ism familiya</span>
                    <Input
                      value={profileName}
                      onChange={(event) => setProfileName(event.target.value)}
                      placeholder="Admin ismi"
                      className="h-11 rounded-xl border-slate-200 text-sm font-bold"
                    />
                  </label>
                  <label className="space-y-2">
                    <span className="text-xs font-black uppercase tracking-[0.14em] text-slate-400">Telefon</span>
                    <Input
                      value={profilePhone}
                      onChange={(event) => setProfilePhone(event.target.value)}
                      placeholder="+998 ..."
                      className="h-11 rounded-xl border-slate-200 text-sm font-bold"
                    />
                  </label>
                </div>

                <div className="rounded-2xl border border-blue-100 bg-blue-50/70 p-4 text-sm font-semibold leading-6 text-blue-900 dark:border-blue-500/20 dark:bg-blue-500/10 dark:text-blue-200">
                  Email va rol xavfsizlik sababli shu oynada o'zgartirilmaydi. Rol o'zgarishi kerak bo'lsa, administratorlar yoki rollar bo'limidan boshqariladi.
                </div>
              </div>
            )}

            <div className="flex flex-wrap items-center justify-between gap-3 border-t border-slate-100 p-5 dark:border-slate-800">
              <Link
                href="/logout"
                className="inline-flex h-10 items-center justify-center gap-2 rounded-xl border border-red-200 bg-red-50 px-4 text-sm font-black text-red-600 transition hover:bg-red-100 dark:border-red-500/20 dark:bg-red-500/10 dark:text-red-300"
              >
                <LogOut className="size-4" />
                Chiqish
              </Link>
              <div className="flex items-center gap-2">
                <Button variant="secondary" onClick={() => setProfileModalOpen(false)}>
                  Bekor qilish
                </Button>
                <Button onClick={saveProfile} disabled={profileLoading || profileSaving}>
                  <Save className="size-4" />
                  {profileSaving ? "Saqlanmoqda..." : "Saqlash"}
                </Button>
              </div>
            </div>
          </div>
        </div>
      ) : null}
    </div>
  );
}

function ProfileInfo({
  icon: Icon,
  label,
  value,
}: {
  icon: typeof UserRound;
  label: string;
  value: string;
}) {
  return (
    <div className="rounded-2xl border border-slate-100 bg-slate-50/80 p-4 dark:border-slate-800 dark:bg-slate-950/40">
      <Icon className="mb-3 size-5 text-blue-600" />
      <p className="text-[11px] font-black uppercase tracking-[0.14em] text-slate-400">{label}</p>
      <p className="mt-1 truncate text-sm font-black text-slate-900 dark:text-slate-100">{value}</p>
    </div>
  );
}
