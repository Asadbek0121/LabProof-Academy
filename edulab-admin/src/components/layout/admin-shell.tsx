"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import {
  Bell,
  ChevronDown,
  GraduationCap,
  Menu,
  Moon,
  Search,
  UserRound,
  X,
} from "lucide-react";
import { useAdminRealtime } from "@/hooks/use-realtime";
import { useAdminStore } from "@/store/admin-store";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { navigation } from "@/components/layout/nav-data";
import { cn } from "@/lib/utils";

export function AdminShell({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
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

  return (
    <div className="min-h-screen bg-white text-slate-950">
      <aside
        className={cn(
          "fixed inset-y-0 left-0 z-40 flex flex-col border-r border-white/10 bg-[#031C3D] text-white shadow-[18px_0_60px_rgba(2,6,23,0.18)] transition-all duration-300",
          sidebarCollapsed ? "w-20" : "w-64",
        )}
      >
        <Link href="/students" className="flex h-[84px] items-center gap-3 px-5">
          <div className="flex size-11 items-center justify-center rounded-2xl bg-blue-600 shadow-[0_14px_28px_rgba(37,99,235,0.35)]">
            <GraduationCap className="size-5" />
          </div>
          {!sidebarCollapsed ? (
            <div>
              <p className="text-lg font-extrabold leading-tight">EduLab</p>
              <p className="text-xs text-blue-100/80">Admin Panel</p>
            </div>
          ) : null}
        </Link>

        <nav className="flex-1 overflow-y-auto px-4 pb-4 edulab-scrollbar">
          {navigation.map((group) => (
            <div key={group.label} className="mb-6">
              {!sidebarCollapsed ? (
                <p className="mb-3 px-2 text-xs font-semibold uppercase tracking-wide text-blue-100/55">
                  {group.label}
                </p>
              ) : null}
              <div className="flex flex-col gap-1.5">
                {group.items.map((item) => {
                  const active =
                    pathname === item.href ||
                    (item.href !== "/" && pathname.startsWith(item.href));
                  return (
                    <Link
                      key={item.href}
                      href={item.href}
                      className={cn(
                        "group relative flex h-12 items-center gap-3 rounded-xl px-3 text-sm font-bold text-blue-50/90 transition-all duration-200 hover:bg-white/10",
                        active &&
                          "bg-blue-600 text-white shadow-[0_16px_34px_rgba(37,99,235,0.36)]",
                        sidebarCollapsed && "justify-center px-0",
                      )}
                    >
                      {active ? (
                        <span className="absolute inset-y-2 left-0 w-1 rounded-r-full bg-white/80" />
                      ) : null}
                      <item.icon className="size-5 shrink-0" />
                      {!sidebarCollapsed ? <span>{item.title}</span> : null}
                    </Link>
                  );
                })}
              </div>
            </div>
          ))}
        </nav>

        <div className="p-4">
          <div
            className={cn(
              "flex items-center gap-3 rounded-2xl border border-white/10 bg-white/8 p-3",
              sidebarCollapsed && "justify-center",
            )}
          >
            <div className="flex size-10 items-center justify-center rounded-full bg-blue-600">
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
          sidebarCollapsed ? "pl-20" : "pl-64",
        )}
      >
        <header className="sticky top-0 z-30 flex h-[84px] items-center justify-between border-b border-border bg-white/92 px-6 backdrop-blur">
          <Button variant="secondary" size="icon" onClick={toggleSidebar}>
            {sidebarCollapsed ? <Menu /> : <X />}
          </Button>

          <div className="ml-auto flex items-center gap-4">
            <div className="relative hidden w-[360px] lg:block">
              <Search className="absolute left-4 top-1/2 size-4 -translate-y-1/2 text-slate-400" />
              <Input
                value={searchQuery}
                onChange={(event) => setSearchQuery(event.target.value)}
                placeholder="Qidirish..."
                className="h-12 rounded-2xl pl-11 pr-16"
              />
              <span className="absolute right-3 top-1/2 -translate-y-1/2 rounded-lg bg-slate-100 px-2 py-1 text-xs font-semibold text-slate-500">
                Ctrl /
              </span>
            </div>

            <div className="relative">
              <Button
                variant="secondary"
                size="icon"
                onClick={() => setNotificationsOpen(!notificationsOpen)}
              >
                <Bell />
              </Button>
              <span className="absolute -right-1 -top-1 flex size-5 items-center justify-center rounded-full bg-red-500 text-[10px] font-bold text-white">
                3
              </span>
              {notificationsOpen ? (
                <div className="absolute right-0 mt-3 w-80 rounded-2xl border border-border bg-white p-3 shadow-soft">
                  <p className="px-2 pb-2 text-sm font-bold">Bildirishnomalar</p>
                  {["Yangi xabar qabul qilindi", "Sertifikat tasdiqlandi", "Backup muvaffaqiyatli"].map((item) => (
                    <div key={item} className="rounded-xl px-3 py-2 text-sm hover:bg-slate-50">
                      {item}
                    </div>
                  ))}
                </div>
              ) : null}
            </div>

            <Button variant="secondary" size="icon">
              <Moon />
            </Button>

            <div className="relative">
              <button
                onClick={() => setProfileOpen(!profileOpen)}
                className="flex h-12 items-center gap-3 rounded-2xl border border-border bg-white px-3 shadow-sm transition hover:border-blue-200"
              >
                <span className="flex size-9 items-center justify-center rounded-full bg-blue-600 text-white">
                  <UserRound className="size-5" />
                </span>
                <span className="hidden text-left sm:block">
                  <span className="block text-sm font-bold leading-tight">Admin</span>
                  <span className="block text-xs text-slate-500">Super Admin</span>
                </span>
                <ChevronDown className="size-4 text-slate-500" />
              </button>
              {profileOpen ? (
                <div className="absolute right-0 mt-3 w-56 rounded-2xl border border-border bg-white p-2 text-sm shadow-soft">
                  <Link className="block rounded-xl px-3 py-2 hover:bg-slate-50" href="/settings/security">
                    Profil va xavfsizlik
                  </Link>
                  <Link className="block rounded-xl px-3 py-2 hover:bg-slate-50" href="/roles">
                    Rollar
                  </Link>
                  <button className="w-full rounded-xl px-3 py-2 text-left text-red-600 hover:bg-red-50">
                    Chiqish
                  </button>
                </div>
              ) : null}
            </div>
          </div>
        </header>

        <main className="mx-auto min-h-[calc(100vh-84px)] max-w-[1680px] bg-white px-6 py-6">
          {children}
        </main>
      </div>
    </div>
  );
}
