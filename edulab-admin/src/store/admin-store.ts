"use client";

import { create } from "zustand";
import { persist } from "zustand/middleware";
import type { SettingSection } from "@/lib/types";

type AdminState = {
  sidebarCollapsed: boolean;
  activeSettingSection: SettingSection;
  searchQuery: string;
  notificationsOpen: boolean;
  profileOpen: boolean;
  toggleSidebar: () => void;
  setActiveSettingSection: (section: SettingSection) => void;
  setSearchQuery: (query: string) => void;
  setNotificationsOpen: (open: boolean) => void;
  setProfileOpen: (open: boolean) => void;
};

export const useAdminStore = create<AdminState>()(
  persist(
    (set) => ({
      sidebarCollapsed: false,
      activeSettingSection: "general",
      searchQuery: "",
      notificationsOpen: false,
      profileOpen: false,
      toggleSidebar: () =>
        set((state) => ({ sidebarCollapsed: !state.sidebarCollapsed })),
      setActiveSettingSection: (section) =>
        set({ activeSettingSection: section }),
      setSearchQuery: (query) => set({ searchQuery: query }),
      setNotificationsOpen: (open) => set({ notificationsOpen: open }),
      setProfileOpen: (open) => set({ profileOpen: open }),
    }),
    {
      name: "edulab-admin-store",
      partialize: (state) => ({
        sidebarCollapsed: state.sidebarCollapsed,
        activeSettingSection: state.activeSettingSection,
      }),
    },
  ),
);
