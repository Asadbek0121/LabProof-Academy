import { NextResponse, type NextRequest } from "next/server";
import { createServerClient } from "@supabase/ssr";

type SupabaseCookie = {
  name: string;
  value: string;
  options?: any;
};

const protectedPrefixes = [
  "/dashboard",
  "/categories",
  "/modules",
  "/topics",
  "/lessons",
  "/videos",
  "/tests",
  "/exams",
  "/students",
  "/progress-monitoring",
  "/analytics",
  "/support-requests",
  "/notifications",
  "/certificates",
  "/media-library",
  "/bot-management",
  "/administrators",
  "/settings",
  "/roles",
  "/activity-logs",
];

export async function middleware(request: NextRequest) {
  const hasEnv =
    process.env.NEXT_PUBLIC_SUPABASE_URL &&
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

  console.log("Middleware request:", request.nextUrl.pathname, "hasEnv:", !!hasEnv);

  if (!hasEnv) {
    return NextResponse.next();
  }

  let response = NextResponse.next({ request });

  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() {
          return request.cookies.getAll();
        },
        setAll(cookiesToSet: SupabaseCookie[]) {
          cookiesToSet.forEach(({ name, value }) => request.cookies.set(name, value));
          response = NextResponse.next({ request });
          cookiesToSet.forEach(({ name, value, options }) =>
            response.cookies.set(name, value, options),
          );
        },
      },
    },
  );

  const {
    data: { user },
  } = await supabase.auth.getUser();

  const isProtected = protectedPrefixes.some((prefix) =>
    request.nextUrl.pathname.startsWith(prefix),
  );

  if (isProtected && !user) {
    const url = request.nextUrl.clone();
    url.pathname = "/login";
    url.searchParams.set("next", request.nextUrl.pathname);
    return NextResponse.redirect(url);
  }

  if (isProtected && user) {
    const { data: profile } = await supabase
      .from("profiles")
      .select("role")
      .eq("id", user.id)
      .maybeSingle();
    const role = profile?.role ?? "student";
    const adminOnly =
      request.nextUrl.pathname.startsWith("/settings") ||
      request.nextUrl.pathname.startsWith("/roles") ||
      request.nextUrl.pathname.startsWith("/media-library") ||
      request.nextUrl.pathname.startsWith("/administrators") ||
      request.nextUrl.pathname.startsWith("/activity-logs");

    if (adminOnly && role !== "admin") {
      const url = request.nextUrl.clone();
      url.pathname = "/students";
      url.searchParams.set("denied", "role");
      return NextResponse.redirect(url);
    }
  }

  return response;
}

export const config = {
  matcher: [
    "/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)",
  ],
};
