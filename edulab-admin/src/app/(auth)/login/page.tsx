"use client";

import { GraduationCap, LockKeyhole, Mail, Loader2 } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { useState } from "react";
import { createClient } from "@/lib/supabase/client";
import { useRouter } from "next/navigation";

export default function LoginPage() {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const supabase = createClient();
  const router = useRouter();

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!email || !password) {
      setError("Email va parolni kiriting.");
      return;
    }

    setLoading(true);
    setError("");

    try {
      const { data, error: signInError } = await supabase.auth.signInWithPassword({
        email,
        password,
      });

      if (signInError) {
        setError(signInError.message);
        setLoading(false);
        return;
      }

      // Check if user role is admin or teacher in profiles
      const { data: profile, error: profileError } = await supabase
        .from("profiles")
        .select("role")
        .eq("id", data.user?.id)
        .maybeSingle();

      if (profileError || !profile || (profile.role !== "admin" && profile.role !== "teacher")) {
        await supabase.auth.signOut();
        setError("Ruxsat berilmagan. Faqat adminlar kirishi mumkin.");
        setLoading(false);
        return;
      }

      router.push("/students");
      router.refresh();
    } catch (err: any) {
      setError(err.message || "Tizimga kirishda xatolik yuz berdi.");
      setLoading(false);
    }
  };

  return (
    <main className="grid min-h-screen place-items-center bg-slate-50 px-4">
      <Card className="w-full max-w-md">
        <CardContent className="p-7">
          <div className="mb-7 flex items-center gap-3">
            <span className="flex size-12 items-center justify-center rounded-2xl bg-blue-600 text-white">
              <GraduationCap className="size-6" />
            </span>
            <div>
              <h1 className="text-2xl font-extrabold">EduLab Admin</h1>
              <p className="text-sm text-slate-500">JWT session persistence va RBAC protection.</p>
            </div>
          </div>
          <form onSubmit={handleLogin} className="space-y-4">
            {error && (
              <div className="rounded-lg bg-red-50 p-3 text-sm font-medium text-red-600">
                {error}
              </div>
            )}
            <div className="grid gap-2 text-sm font-bold">
              <span>Email</span>
              <span className="relative">
                <Mail className="absolute left-3 top-1/2 size-4 -translate-y-1/2 text-slate-400" />
                <Input
                  className="pl-10"
                  placeholder="admin@edulab.uz"
                  type="email"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  disabled={loading}
                />
              </span>
            </div>
            <div className="grid gap-2 text-sm font-bold">
              <span>Parol</span>
              <span className="relative">
                <LockKeyhole className="absolute left-3 top-1/2 size-4 -translate-y-1/2 text-slate-400" />
                <Input
                  className="pl-10"
                  placeholder="********"
                  type="password"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  disabled={loading}
                />
              </span>
            </div>
            <Button className="w-full" type="submit" disabled={loading}>
              {loading ? (
                <>
                  <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                  Yuklanmoqda...
                </>
              ) : (
                "Kirish"
              )}
            </Button>
          </form>
        </CardContent>
      </Card>
    </main>
  );
}

