import { Award, CheckCircle2, ShieldCheck } from "lucide-react";

export default async function CertificateVerifyPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;

  return (
    <main className="min-h-screen bg-slate-50 px-4 py-10">
      <section className="mx-auto max-w-4xl overflow-hidden rounded-2xl border border-[#E5E7EB] bg-white shadow-card">
        <div className="grid gap-0 lg:grid-cols-[.9fr_1.1fr]">
          <div className="bg-[#031C3D] p-8 text-white">
            <div className="flex size-14 items-center justify-center rounded-2xl bg-blue-600 shadow-[0_18px_34px_rgba(37,99,235,.35)]">
              <Award className="size-7" />
            </div>
            <h1 className="mt-8 text-3xl font-extrabold">Sertifikat haqiqiy</h1>
            <p className="mt-3 text-blue-100">
              Ushbu sertifikat EduLab Academy tizimida QR kod orqali tekshirildi.
            </p>
            <div className="mt-8 rounded-2xl border border-white/10 bg-white/8 p-4">
              <p className="text-sm text-blue-100">Certificate ID</p>
              <p className="mt-1 break-all text-xl font-extrabold">{id}</p>
            </div>
          </div>
          <div className="p-8">
            <div className="flex items-center gap-4 rounded-2xl bg-emerald-50 p-5 text-emerald-700">
              <CheckCircle2 className="size-10" />
              <div>
                <p className="text-lg font-extrabold">Tekshiruv muvaffaqiyatli</p>
                <p className="text-sm font-medium">QR scan qilinganda shu verify sahifasi ochiladi.</p>
              </div>
            </div>
            <dl className="mt-8 divide-y divide-border text-sm">
              {[
                ["Talaba", "Asadbek Davronov"],
                ["Modul", "Laboratoriya ishlari"],
                ["Berilgan sana", "14.05.2026"],
                ["Status", "Haqiqiy"],
              ].map(([label, value]) => (
                <div key={label} className="flex justify-between gap-4 py-4">
                  <dt className="text-slate-500">{label}</dt>
                  <dd className="text-right font-extrabold">{value}</dd>
                </div>
              ))}
            </dl>
            <div className="mt-8 flex items-center gap-3 rounded-2xl border border-blue-100 bg-blue-50 p-4 text-sm font-semibold text-blue-700">
              <ShieldCheck className="size-5" />
              Sertifikat ma'lumotlari Supabase orqali server tomonda tekshiriladi.
            </div>
          </div>
        </div>
      </section>
    </main>
  );
}
