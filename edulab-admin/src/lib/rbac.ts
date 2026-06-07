import { cookies } from "next/headers";
import { LOCAL_ADMIN_SESSION_COOKIE, verifyLocalAdminSession } from "@/lib/admin-local-session";
import { createClient } from "@/lib/supabase/server";

async function hasLocalAdminSession() {
  const cookieStore = await cookies();
  return verifyLocalAdminSession(cookieStore.get(LOCAL_ADMIN_SESSION_COOKIE)?.value);
}

export async function getSessionUser() {
  if (await hasLocalAdminSession()) {
    return null;
  }
  const supabase = await createClient();
  if (!supabase) return null;
  const {
    data: { user },
  } = await supabase.auth.getUser();
  return user;
}

export async function getCurrentRole() {
  if (await hasLocalAdminSession()) {
    return "admin";
  }
  const supabase = await createClient();
  if (!supabase) return "admin";
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return null;
  const { data } = await supabase
    .from("profiles")
    .select("role")
    .eq("id", user.id)
    .maybeSingle();
  return (data?.role as string | undefined) ?? "student";
}

export async function assertAdmin() {
  const role = await getCurrentRole();
  if (role !== "admin" && role !== "teacher") {
    throw new Error("Admin huquqi talab qilinadi.");
  }
}

export const routePermissions: Record<string, string> = {
  "/students": "students.read",
  "/analytics": "analytics.read",
  "/notifications": "notifications.send",
  "/certificates": "certificates.manage",
  "/media-library": "media.manage",
  "/settings": "settings.manage",
  "/roles": "roles.manage",
};
