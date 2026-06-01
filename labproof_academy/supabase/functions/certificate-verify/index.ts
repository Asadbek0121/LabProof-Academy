import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.4";

Deno.serve(async (request) => {
  const url = new URL(request.url);
  const certificateCode = url.searchParams.get("code") ?? url.pathname.split("/").pop();

  if (!certificateCode) {
    return Response.json({ ok: false, error: "certificate_code_required" }, { status: 400 });
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
  );

  const { data, error } = await supabase
    .from("certificates")
    .select("certificate_code,title,status,issued_at,verify_url,user_id,module_id,modules(title)")
    .eq("certificate_code", certificateCode)
    .maybeSingle();

  if (error) {
    return Response.json({ ok: false, error: error.message }, { status: 500 });
  }

  if (!data || data.status !== "issued") {
    return Response.json({ ok: false, valid: false, message: "Sertifikat topilmadi" }, { status: 404 });
  }

  const { data: profile } = await supabase
    .from("profiles")
    .select("full_name")
    .eq("id", data.user_id)
    .maybeSingle();

  return Response.json({
    ok: true,
    valid: true,
    message: "Sertifikat haqiqiy",
    certificate: {
      ...data,
      student_name: profile?.full_name ?? null,
    },
  });
});
