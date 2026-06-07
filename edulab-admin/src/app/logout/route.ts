import { NextResponse } from "next/server";
import { createClient } from "@/lib/supabase/server";
import { hasSupabaseEnv } from "@/lib/env";
import { LOCAL_ADMIN_SESSION_COOKIE } from "@/lib/admin-local-session";

export async function GET(request: Request) {
  if (hasSupabaseEnv()) {
    try {
      const supabase = await createClient();
      await supabase.auth.signOut();
    } catch {
      // Local admin sessions do not require Supabase to be available.
    }
  }

  const response = NextResponse.redirect(new URL("/login", request.url));
  response.cookies.delete(LOCAL_ADMIN_SESSION_COOKIE);
  return response;
}
