"use server";

import { redirect } from "next/navigation";
import { cookies } from "next/headers";
import { createClient } from "@/lib/supabase/server";
import {
  createLocalAdminSession,
  getLocalAdminCookieOptions,
  LOCAL_ADMIN_SESSION_COOKIE,
} from "@/lib/admin-local-session";

export type LoginActionResult = {
  ok: boolean;
  error: string;
};

function safeRedirectPath(value: FormDataEntryValue | null) {
  const fallback = "/students";
  if (typeof value !== "string" || !value.startsWith("/") || value.startsWith("//")) {
    return fallback;
  }
  return value;
}

function getSimpleLogin() {
  return process.env.ADMIN_SIMPLE_LOGIN || "admin";
}

function getSimplePassword() {
  return process.env.ADMIN_SIMPLE_PASSWORD || "1234";
}

export async function loginAdmin(
  _previousState: LoginActionResult,
  formData: FormData,
): Promise<LoginActionResult> {
  const rawLogin = formData.get("login");
  const rawPassword = formData.get("password");
  const nextPath = safeRedirectPath(formData.get("next"));

  const login = typeof rawLogin === "string" ? rawLogin.trim() : "";
  const password = typeof rawPassword === "string" ? rawPassword : "";

  if (!login || !password) {
    return { ok: false, error: "Login va parolni kiriting." };
  }

  if (login === getSimpleLogin() && password === getSimplePassword()) {
    const cookieStore = await cookies();
    const session = await createLocalAdminSession(login);
    cookieStore.set(LOCAL_ADMIN_SESSION_COOKIE, session, getLocalAdminCookieOptions());
    redirect(nextPath);
  }

  const supabase = await createClient();
  const { data, error } = await supabase.auth.signInWithPassword({
    email: login,
    password,
  });

  if (error || !data.user) {
    return { ok: false, error: "Login yoki parol noto'g'ri." };
  }

  const { data: profile, error: profileError } = await supabase
    .from("profiles")
    .select("role")
    .eq("id", data.user.id)
    .maybeSingle();

  if (profileError || !profile || !["admin", "teacher"].includes(profile.role ?? "")) {
    await supabase.auth.signOut();
    return { ok: false, error: "Ruxsat berilmagan. Faqat admin yoki teacher kira oladi." };
  }

  redirect(nextPath);
}
