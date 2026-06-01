"use client";

import { useEffect } from "react";
import { useQueryClient } from "@tanstack/react-query";
import { createClient } from "@/lib/supabase/client";

export function useAdminRealtime() {
  const queryClient = useQueryClient();

  useEffect(() => {
    if (
      !process.env.NEXT_PUBLIC_SUPABASE_URL ||
      !process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY
    ) {
      return;
    }

    const supabase = createClient();
    const channel = supabase
      .channel("admin-panel")
      .on(
        "postgres_changes",
        { event: "*", schema: "public", table: "notification_messages" },
        () => {
          void queryClient.invalidateQueries({ queryKey: ["conversations"] });
        },
      )
      .on(
        "postgres_changes",
        { event: "*", schema: "public", table: "media_library" },
        () => {
          void queryClient.invalidateQueries({ queryKey: ["media-library"] });
        },
      )
      .on(
        "postgres_changes",
        { event: "*", schema: "public", table: "certificates" },
        () => {
          void queryClient.invalidateQueries({ queryKey: ["certificates"] });
        },
      )
      .subscribe();

    return () => {
      void supabase.removeChannel(channel);
    };
  }, [queryClient]);
}
