"use client";

import Link from "next/link";
import type * as React from "react";
import { useEffect, useMemo, useState, useTransition } from "react";
import { toast } from "sonner";
import {
  Activity,
  AlertTriangle,
  Bell,
  CheckCircle2,
  Cloud,
  CreditCard,
  Database,
  Download,
  FileText,
  Globe2,
  HardDrive,
  KeyRound,
  Lock,
  Mail,
  MonitorSmartphone,
  RefreshCcw,
  Save,
  ShieldCheck,
  UploadCloud,
  WalletCards,
} from "lucide-react";
import { PageHeader } from "@/components/layout/page-header";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Input, Select, Textarea } from "@/components/ui/input";
import { LineAreaChart } from "@/components/charts/line-area-chart";
import { settingSections } from "@/lib/mock-data";
import { cn } from "@/lib/utils";
import type { SettingSection } from "@/lib/types";

type SettingsPageProps = {
  section: SettingSection;
};

const sectionTitle: Record<SettingSection, string> = Object.fromEntries(
  settingSections.map((item) => [item.id, item.title]),
) as Record<SettingSection, string>;

export function SettingsPage({ section }: SettingsPageProps) {
  const [savedAt, setSavedAt] = useState("15.05.2026 14:25:30");
  const [isPending, startTransition] = useTransition();
  const active = useMemo(
    () => settingSections.find((item) => item.id === section) ?? settingSections[0],
    [section],
  );

  useEffect(() => {
    setSavedAt("Realtime tayyor");
  }, [section]);

  function realtimeSave(label = "Sozlama") {
    startTransition(() => {
      setSavedAt(new Date().toLocaleString("uz-UZ", { hour12: false }));
      toast.success(`${label} realtime saqlandi`);
    });
  }

  return (
    <>
      <PageHeader
        title={active.title}
        parent="Sozlamalar"
        current={active.title}
        action={
          <Button onClick={() => realtimeSave("Barcha o'zgarishlar")} disabled={isPending} className="flex gap-2 font-bold px-5 bg-violet-600 text-white hover:bg-violet-700 rounded-xl h-10 text-xs shadow-sm">
            <Save className="size-4" />
            Saqlash
          </Button>
        }
      />

      <div className="grid gap-6 xl:grid-cols-[340px_1fr] animate-in fade-in duration-200">
        <Card className="h-fit border border-border bg-white rounded-2xl shadow-soft">
          <CardContent className="flex flex-col gap-1.5 p-4.5">
            {settingSections.map((item) => {
              const isSelected = item.id === section;
              return (
                <Link
                  key={item.id}
                  href={`/settings/${item.id}`}
                  className={cn(
                    "flex items-center gap-3 rounded-xl p-3 transition duration-150 border border-transparent",
                    isSelected 
                      ? "bg-violet-50/60 border-violet-100 text-violet-700 shadow-sm" 
                      : "hover:bg-slate-50 text-slate-700",
                  )}
                >
                  <span className={cn(
                    "flex size-10 items-center justify-center rounded-xl transition-all duration-150", 
                    isSelected 
                      ? "bg-white text-violet-600 border border-violet-100" 
                      : "bg-slate-50 text-slate-500 border border-slate-100"
                  )}>
                    <item.icon className="size-5" />
                  </span>
                  <div>
                    <span className="block text-xs font-black tracking-tight leading-snug">{item.title}</span>
                    <span className="text-[10px] font-bold text-slate-400 mt-0.5 leading-none block">{item.subtitle}</span>
                  </div>
                </Link>
              );
            })}
          </CardContent>
        </Card>

        <div className="min-w-0">
          {section === "general" ? <GeneralSettings onSave={realtimeSave} /> : null}
          {section === "system" ? <SystemSettings onSave={realtimeSave} /> : null}
          {section === "localization" ? <LocalizationSettings onSave={realtimeSave} /> : null}
          {section === "backup" ? <BackupSettings onSave={realtimeSave} /> : null}
          {section === "security" ? <SecuritySettings onSave={realtimeSave} /> : null}
          {section === "email" ? <EmailSettings onSave={realtimeSave} /> : null}
          {section === "payments" ? <PaymentSettings onSave={realtimeSave} /> : null}
          {section === "integrations" ? <IntegrationSettings onSave={realtimeSave} /> : null}
          {section === "notifications" ? <NotificationSettings onSave={realtimeSave} /> : null}
          {section === "files" ? <FileSettings onSave={realtimeSave} /> : null}
          
          <div className="mt-5 flex items-center justify-between rounded-xl bg-violet-50/50 border border-violet-100 px-4 py-3 text-xs font-bold text-violet-850 shadow-sm">
            <span>{sectionTitle[section]} bo'yicha oxirgi saqlash: {savedAt}</span>
            <Button variant="ghost" size="sm" onClick={() => realtimeSave(sectionTitle[section])} className="h-7 hover:bg-violet-100/50 rounded-lg text-[10px] font-black uppercase text-violet-605 flex gap-1 bg-white border border-violet-200">
              <RefreshCcw className="size-3" />
              Yangilash
            </Button>
          </div>
        </div>
      </div>
    </>
  );
}

function GeneralSettings({ onSave }: { onSave: (label?: string) => void }) {
  return (
    <SettingsCard title="Umumiy sozlamalar" description="Tizimning asosiy parametrlari va default ko'rinishini sozlang.">
      <SettingRow icon={ShieldCheck} title="Platforma nomi" description="Talaba va o'qituvchilarga ko'rinadi">
        <Input defaultValue="EduLab" onBlur={() => onSave("Platforma nomi")} className="h-10.5 rounded-xl border-slate-200 font-semibold" />
      </SettingRow>
      <SettingRow icon={UploadCloud} title="Platforma logotipi" description="SVG yoki PNG fayl">
        <div className="flex items-center gap-3.5 rounded-xl border border-slate-150 p-3.5 bg-slate-50/30">
          <span className="flex size-11 items-center justify-center rounded-xl bg-violet-50 text-violet-600 border border-violet-100">
            <Cloud className="size-5" />
          </span>
          <div className="flex-1 min-w-0">
            <p className="font-extrabold text-slate-800 text-xs">edulab-logo.svg</p>
            <p className="text-[10px] text-slate-400 font-bold mt-0.5">SVG - 24 KB</p>
          </div>
          <Button variant="secondary" onClick={() => onSave("Logotip")} className="border border-slate-200 rounded-lg hover:bg-slate-50 text-xs h-8 px-3 font-bold">O'zgartirish</Button>
        </div>
      </SettingRow>
      <SettingRow icon={Activity} title="Platforma tavsifi" description="Qisqacha matn">
        <Textarea defaultValue={"EduLab - zamonaviy online ta'lim platformasi.\nSifatli ta'lim, oson boshqaruv."} onBlur={() => onSave("Tavsif")} className="min-h-24 rounded-xl border-slate-200 text-xs font-semibold leading-relaxed" />
      </SettingRow>
      <SettingRow icon={Globe2} title="Vaqt mintaqasi" description="Tizim vaqti">
        <Select className="w-full h-10.5 rounded-xl border-slate-200 font-semibold text-slate-750" onChange={() => onSave("Vaqt mintaqasi")}>
          <option>(UTC+05:00) Tashkent</option>
          <option>(UTC+05:00) Samarkand</option>
        </Select>
      </SettingRow>
      <SettingRow icon={Bell} title="Xizmat holati" description="Maintenance rejimi">
        <Toggle label="O'chirilgan" onChange={() => onSave("Maintenance")} />
      </SettingRow>
    </SettingsCard>
  );
}

function SystemSettings({ onSave }: { onSave: (label?: string) => void }) {
  const facts = [
    ["Platforma nomi", "EduLab"],
    ["Joriy versiya", "v2.3.1"],
    ["Build raqami", "230515.1030"],
    ["Muhit", "Production"],
    ["Node.js versiyasi", "v20.11.1"],
    ["Ma'lumotlar bazasi", "PostgreSQL 15.2"],
    ["Oxirgi zaxira nusxa", "15.05.2026 02:30"],
    ["Vaqt mintaqasi", "(UTC+05:00) Tashkent"],
  ];
  return (
    <div className="space-y-5">
      <div className="grid gap-4 grid-cols-2 md:grid-cols-4">
        <Metric icon={Database} title="Server holati" value="Onlayn" tone="green" />
        <Metric icon={Cloud} title="Supabase holati" value="Onlayn" tone="green" />
        <Metric icon={HardDrive} title="Saqlash" value="12.4 GB" hint="/ 100 GB" tone="violet" />
        <Metric icon={Activity} title="API kechikishi" value="120 ms" tone="violet" />
      </div>
      <div className="grid gap-5 xl:grid-cols-[.9fr_1.1fr]">
        <Card className="border border-border bg-white rounded-2xl shadow-soft">
          <CardHeader className="border-b border-slate-100 pb-3"><CardTitle className="text-sm font-black text-slate-900 uppercase tracking-wide">Asosiy ma'lumotlar</CardTitle></CardHeader>
          <CardContent className="pt-2">
            <dl className="divide-y divide-slate-100">
              {facts.map(([label, value]) => (
                <div key={label} className="flex justify-between gap-4 py-3 text-xs">
                  <dt className="text-slate-450 font-bold">{label}</dt>
                  <dd className="font-extrabold text-slate-800">{value}</dd>
                </div>
              ))}
            </dl>
          </CardContent>
        </Card>
        
        <Card className="border border-border bg-white rounded-2xl shadow-soft">
          <CardHeader className="border-b border-slate-100 pb-3"><CardTitle className="text-sm font-black text-slate-900 uppercase tracking-wide">Tizim resurslari</CardTitle></CardHeader>
          <CardContent className="grid gap-5 md:grid-cols-[160px_1fr] pt-5">
            <div className="space-y-5">
              <Resource label="CPU yuklanishi" value="18%" />
              <Resource label="RAM ishlatilishi" value="42%" />
              <Resource label="Disk ishlatilishi" value="12%" />
            </div>
            <LineAreaChart secondary theme="purple" />
          </CardContent>
        </Card>
      </div>
      
      <Card className="border border-border bg-white rounded-2xl shadow-soft">
        <CardHeader className="border-b border-slate-100 pb-3.5 flex flex-row items-center justify-between">
          <CardTitle className="text-sm font-black text-slate-900 uppercase tracking-wide">Ulangan servislar</CardTitle>
          <Button variant="secondary" onClick={() => onSave("Servis statuslari")} className="border border-slate-200 rounded-lg hover:bg-slate-50 text-xs h-8 px-3 font-bold">Tekshirish</Button>
        </CardHeader>
        <CardContent className="grid gap-4 grid-cols-2 md:grid-cols-4 pt-5">
          {["Supabase Storage", "Resend", "Cloudinary", "Sentry"].map((name) => (
            <div key={name} className="rounded-xl border border-slate-150 p-4 bg-slate-50/20 text-center">
              <p className="font-extrabold text-xs text-slate-800">{name}</p>
              <Badge variant="success" className="mt-3">Ulangan</Badge>
            </div>
          ))}
        </CardContent>
      </Card>
    </div>
  );
}

function LocalizationSettings({ onSave }: { onSave: (label?: string) => void }) {
  return (
    <SettingsCard title="Til va lokalizatsiya" description="uz, ru, en tillari va kelajakdagi RTL arxitekturasi.">
      <SettingRow icon={Globe2} title="Asosiy til" description="Admin panel default tili">
        <Select className="w-full h-10.5 rounded-xl border-slate-200 font-semibold" onChange={() => onSave("Asosiy til")}>
          <option>uz - O'zbek</option>
          <option>ru - Ruscha</option>
          <option>en - English</option>
        </Select>
      </SettingRow>
      <SettingRow icon={Globe2} title="Qo'llab-quvvatlanadigan tillar" description="Student app va bot">
        <div className="flex flex-wrap gap-2">
          {["uz", "ru", "en"].map((lang) => (
            <button key={lang} onClick={() => onSave(lang)} className="rounded-xl border border-violet-100 bg-violet-50 text-violet-650 px-4 py-2 text-xs font-black uppercase tracking-wider shadow-sm">
              {lang}
            </button>
          ))}
        </div>
      </SettingRow>
      <SettingRow icon={Globe2} title="RTL arxitektura" description="Arab/fors tillari uchun layout tayyorgarligi">
        <Toggle label="Tayyor, hozir o'chirilgan" onChange={() => onSave("RTL")} />
      </SettingRow>
      <SettingRow icon={CalendarIcon} title="Sana va vaqt" description="Mahalliy formatlar">
        <div className="grid gap-3 md:grid-cols-2">
          <Select onChange={() => onSave("Sana formati")} className="h-10.5 rounded-xl border-slate-200 font-semibold"><option>DD.MM.YYYY (15.05.2026)</option></Select>
          <Select onChange={() => onSave("Vaqt formati")} className="h-10.5 rounded-xl border-slate-200 font-semibold"><option>24 soat (14:30)</option></Select>
        </div>
      </SettingRow>
    </SettingsCard>
  );
}

function BackupSettings({ onSave }: { onSave: (label?: string) => void }) {
  return (
    <div className="space-y-5">
      <div className="grid gap-5 xl:grid-cols-[.9fr_1.1fr]">
        <Card className="border border-border bg-white rounded-2xl shadow-soft">
          <CardHeader className="border-b border-slate-100 pb-3.5">
            <CardTitle className="text-sm font-black text-slate-900 uppercase tracking-wide">Zaxira nusxa haqida</CardTitle>
            <CardDescription className="text-xs text-slate-400 mt-1 font-semibold">PostgreSQL, fayllar va sozlamalar shifrlangan holda saqlanadi.</CardDescription>
          </CardHeader>
          <CardContent className="space-y-4 pt-5">
            <InfoLine icon={ShieldCheck} title="Xavfsiz va shifrlangan" text="AES-256 bilan shifrlash" />
            <InfoLine icon={RefreshCcw} title="Avtomatik zaxira" text="Kundalik backup jadvali" />
            <InfoLine icon={Download} title="Osol tiklash" text="Rollback va restore nazorati" />
            <div className="rounded-xl border border-violet-100 bg-violet-50/50 p-3.5 text-xs font-bold text-violet-850 leading-relaxed shadow-sm">
              Oxirgi zaxira nusxa: 15.05.2026 02:30 - 2.45 GB
            </div>
          </CardContent>
        </Card>
        
        <Card className="border border-border bg-white rounded-2xl shadow-soft">
          <CardHeader className="border-b border-slate-100 pb-3.5"><CardTitle className="text-sm font-black text-slate-900 uppercase tracking-wide">Yangi zaxira nusxa yaratish</CardTitle></CardHeader>
          <CardContent className="space-y-4 pt-5">
            <div className="grid gap-3.5 grid-cols-2">
              <Choice active title="To'liq zaxira" subtitle="Barcha ma'lumotlar" />
              <Choice title="Faqat DB" subtitle="Faqat ma'lumotlar bazasi" />
            </div>
            <Input placeholder="Izoh kiriting (masalan: yangilashdan oldin)" className="h-10.5 rounded-xl border-slate-200 text-xs font-semibold" />
            <Button className="ml-auto flex gap-1.5 bg-violet-600 text-white hover:bg-violet-700 h-10 rounded-xl font-bold text-xs" onClick={() => onSave("Manual backup")}>
              <UploadCloud className="size-4" />
              Zaxira nusxa yaratish
            </Button>
          </CardContent>
        </Card>
      </div>
      
      <Card className="border border-border bg-white rounded-2xl shadow-soft">
        <CardHeader className="border-b border-slate-100 pb-3.5"><CardTitle className="text-sm font-black text-slate-900 uppercase tracking-wide">Zaxira nusxalar ro'yxati</CardTitle></CardHeader>
        <CardContent className="p-0">
          <DataTable
            headers={["Nomi", "Turi", "Hajmi", "Yaratilgan sana", "Holat", "Amallar"]}
            rows={[
              ["backup_2026_05_15_0230", "To'liq", "2.45 GB", "15.05.2026 02:30", "Muvaffaqiyatli", "Yuklash / Tiklash"],
              ["backup_2026_05_14_0230", "To'liq", "2.41 GB", "14.05.2026 02:30", "Muvaffaqiyatli", "Yuklash / Tiklash"],
              ["backup_2026_05_12_0230", "Faqat DB", "512 MB", "12.05.2026 02:30", "Muvaffaqiyatli", "Yuklash / Tiklash"],
            ]}
          />
        </CardContent>
      </Card>
    </div>
  );
}

function SecuritySettings({ onSave }: { onSave: (label?: string) => void }) {
  return (
    <div className="space-y-5">
      <div className="grid gap-4 grid-cols-2 md:grid-cols-5">
        <Metric icon={ShieldCheck} title="Xavfsizlik darajasi" value="98%" tone="green" />
        <Metric icon={MonitorSmartphone} title="Faol sessiyalar" value="15" tone="violet" />
        <Metric icon={Lock} title="2FA" value="ON" tone="green" />
        <Metric icon={ShieldCheck} title="Firewall" value="Himoyalangan" tone="green" />
        <Metric icon={AlertTriangle} title="Urinishlar" value="2" tone="red" />
      </div>
      <div className="grid gap-5 xl:grid-cols-[1.2fr_.9fr_.9fr]">
        <Card className="border border-border bg-white rounded-2xl shadow-soft">
          <CardHeader className="border-b border-slate-100 pb-3"><CardTitle className="text-sm font-black text-slate-900 uppercase tracking-wide">Kirish faolligi</CardTitle></CardHeader>
          <CardContent className="pt-5"><LineAreaChart theme="purple" /></CardContent>
        </Card>
        
        <Card className="border border-border bg-white rounded-2xl shadow-soft">
          <CardHeader className="border-b border-slate-100 pb-3"><CardTitle className="text-sm font-black text-slate-900 uppercase tracking-wide">Parol siyosati</CardTitle></CardHeader>
          <CardContent className="space-y-3 pt-5">
            {["Minimal uzunlik: 8 belgi", "Katta harf: yoqilgan", "Raqam: yoqilgan", "Maxsus belgi: yoqilgan", "Parol muddati: 90 kun"].map((item) => (
              <p key={item} className="flex items-center gap-2.5 text-xs font-bold text-slate-700">
                <CheckCircle2 className="size-4.5 text-emerald-500 shrink-0" /> {item}
              </p>
            ))}
          </CardContent>
        </Card>
        
        <Card className="border border-border bg-white rounded-2xl shadow-soft">
          <CardHeader className="border-b border-slate-100 pb-3"><CardTitle className="text-sm font-black text-slate-900 uppercase tracking-wide">Sessiya va JWT</CardTitle></CardHeader>
          <CardContent className="space-y-4 pt-5">
            <SettingMini label="Sessiya muddati">
              <Select onChange={() => onSave("JWT timeout")} className="h-10 rounded-xl border-slate-200 font-semibold"><option>30 daqiqa</option><option>60 daqiqa</option></Select>
            </SettingMini>
            <Toggle label="Avtomatik chiqish" onChange={() => onSave("Auto logout")} />
            <Toggle label="Biometrik kirish" onChange={() => onSave("Biometrik kirish")} />
            <Toggle label="Admin tasdiqlovi" onChange={() => onSave("Admin tasdiqlovi")} />
          </CardContent>
        </Card>
      </div>
      
      <Card className="border border-border bg-white rounded-2xl shadow-soft">
        <CardHeader className="border-b border-slate-100 pb-3.5"><CardTitle className="text-sm font-black text-slate-900 uppercase tracking-wide">Ishonchli qurilmalar</CardTitle></CardHeader>
        <CardContent className="p-0">
          <DataTable
            headers={["Qurilma", "Brauzer", "IP manzil", "Joylashuv", "Oxirgi faoliyat", "Amal"]}
            rows={[
              ["MacBook Pro 16", "Chrome 124", "192.168.1.10", "Toshkent, UZ", "15.05.2026 14:25", "Chiqish"],
              ["Windows PC", "Edge 124", "192.168.1.25", "Samarqand, UZ", "15.05.2026 12:10", "Chiqish"],
              ["iPhone 15 Pro", "Safari 17", "192.168.1.30", "Toshkent, UZ", "15.05.2026 11:45", "Chiqish"],
            ]}
          />
        </CardContent>
      </Card>
    </div>
  );
}

function EmailSettings({ onSave }: { onSave: (label?: string) => void }) {
  return (
    <SettingsCard title="Email sozlamalari" description="SMTP, Resend va transactional email konfiguratsiyasi.">
      <SettingRow icon={Mail} title="Email provayder" description="SMTP yoki Resend">
        <Select className="w-full h-10.5 rounded-xl border-slate-200 font-semibold" onChange={() => onSave("Email provayder")}><option>Resend</option><option>SMTP</option></Select>
      </SettingRow>
      <SettingRow icon={Mail} title="SMTP host" description="Xabar yuborish serveri">
        <Input placeholder="smtp.example.com" onBlur={() => onSave("SMTP host")} className="h-10.5 rounded-xl border-slate-200 font-semibold" />
      </SettingRow>
      <SettingRow icon={KeyRound} title="API kalit" description="Server env orqali saqlanadi">
        <Input type="password" defaultValue="sk_live_****************" onBlur={() => onSave("Email API kalit")} className="h-10.5 rounded-xl border-slate-200 font-semibold" />
      </SettingRow>
      <SettingRow icon={Bell} title="Email shablonlari" description="Kirish, sertifikat, to'lov va ogohlantirishlar">
        <Button variant="secondary" onClick={() => onSave("Email shablonlari")} className="border border-slate-200 rounded-lg hover:bg-slate-50 text-xs h-9 px-4 font-bold">Shablonlarni boshqarish</Button>
      </SettingRow>
    </SettingsCard>
  );
}

function PaymentSettings({ onSave }: { onSave: (label?: string) => void }) {
  return (
    <div className="space-y-5">
      <div className="grid gap-4 grid-cols-2 md:grid-cols-5">
        <Metric icon={WalletCards} title="Oylik daromad" value="124,560,000" hint="so'm" tone="violet" />
        <Metric icon={CreditCard} title="Muvaffaqiyatli to'lovlar" value="2,453" tone="green" />
        <Metric icon={Activity} title="Faol obunalar" value="1,320" tone="violet" />
        <Metric icon={AlertTriangle} title="Muvaffaqiyatsiz to'lovlar" value="32" tone="red" />
        <Metric icon={WalletCards} title="Jami tushum" value="856,320,000" hint="so'm" tone="violet" />
      </div>
      <div className="grid gap-5 xl:grid-cols-[1.2fr_.8fr]">
        <Card className="border border-border bg-white rounded-2xl shadow-soft">
          <CardHeader className="border-b border-slate-100 pb-3.5 flex flex-row justify-between items-center">
            <CardTitle className="text-sm font-black text-slate-900 uppercase tracking-wide">Daromad statistikasi</CardTitle>
            <Select className="h-8.5 text-xs font-bold border-slate-200 rounded-lg w-36"><option>Oxirgi 12 oy</option></Select>
          </CardHeader>
          <CardContent className="pt-5"><LineAreaChart theme="purple" /></CardContent>
        </Card>
        
        <Card className="border border-border bg-white rounded-2xl shadow-soft">
          <CardHeader className="border-b border-slate-100 pb-3.5 flex flex-row items-center justify-between">
            <CardTitle className="text-sm font-black text-slate-900 uppercase tracking-wide">To'lov usullari</CardTitle>
            <Button variant="ghost" onClick={() => onSave("To'lov usullari")} className="text-xs text-violet-605 font-bold hover:bg-violet-50/50 h-8 rounded-lg">Tahrirlash</Button>
          </CardHeader>
          <CardContent className="space-y-3 pt-5">
            {["Click", "Payme", "Uzumbank", "Stripe", "PayPal"].map((method, index) => (
              <div key={method} className="flex items-center justify-between rounded-xl border border-slate-150 p-3 bg-slate-50/10 text-xs">
                <span className="font-extrabold text-slate-700">{method}</span>
                <Badge variant="success">Ulangan</Badge>
                <span className="font-black text-slate-800">{(1.5 + index * 0.4).toFixed(1)}%</span>
              </div>
            ))}
          </CardContent>
        </Card>
      </div>
      
      <div className="grid gap-5 xl:grid-cols-[.9fr_1.1fr]">
        <Card className="border border-border bg-white rounded-2xl shadow-soft">
          <CardHeader className="border-b border-slate-100 pb-3.5 flex flex-row items-center justify-between">
            <CardTitle className="text-sm font-black text-slate-900 uppercase tracking-wide">Obuna rejalari</CardTitle>
            <Button variant="ghost" className="text-xs text-violet-605 font-bold hover:bg-violet-50/50 h-8 rounded-lg">Yangi reja qo'shish</Button>
          </CardHeader>
          <CardContent className="grid gap-3 grid-cols-3 pt-5">
            {[
              ["Basic", "49,000", "monthly"],
              ["Premium", "99,000", "monthly"],
              ["VIP", "199,000", "yearly"],
            ].map(([name, price, mode], index) => {
              const isSelected = index === 1;
              return (
                <div key={name} className={cn(
                  "rounded-xl border p-4 text-center transition duration-150", 
                  isSelected 
                    ? "border-violet-250 bg-violet-50/40 shadow-sm" 
                    : "border-slate-150"
                )}>
                  <p className="font-black text-slate-800 text-xs uppercase tracking-wide">{name}</p>
                  <p className="mt-3.5 text-2xl font-black text-slate-900 leading-none">
                    {price}
                    <span className="text-[10px] text-slate-400 font-bold tracking-tight"> UZS</span>
                  </p>
                  <p className="mt-2 text-[10px] text-slate-400 font-bold leading-normal">{mode === "monthly" ? "Oyiga" : "Yiliga"}</p>
                  <Badge variant="success" className="mt-4">Faol</Badge>
                </div>
              );
            })}
          </CardContent>
        </Card>
        
        <Card className="border border-border bg-white rounded-2xl shadow-soft">
          <CardHeader className="border-b border-slate-100 pb-3.5"><CardTitle className="text-sm font-black text-slate-900 uppercase tracking-wide">So'nggi tranzaksiyalar</CardTitle></CardHeader>
          <CardContent className="p-0">
            <DataTable
              headers={["Talaba", "Summa", "Usul", "Status", "Sana"]}
              rows={[
                ["Alisher Usmanov", "99,000 so'm", "Payme", "Muvaffaqiyatli", "15.05.2026 14:25"],
                ["Madina Karimova", "49,000 so'm", "Click", "Muvaffaqiyatli", "15.05.2026 13:10"],
                ["Bobur Abdullayev", "199,000 so'm", "Stripe", "Kutilmoqda", "15.05.2026 12:45"],
              ]}
            />
          </CardContent>
        </Card>
      </div>
    </div>
  );
}

function IntegrationSettings({ onSave }: { onSave: (label?: string) => void }) {
  const services = ["Telegram bot", "Cloudinary", "SMTP", "Payme", "Click", "Stripe", "Resend", "Google OAuth"];
  return (
    <div className="space-y-5">
      <div className="grid gap-4 grid-cols-2 md:grid-cols-5">
        <Metric icon={Cloud} title="Ulangan servislar" value="8" tone="violet" />
        <Metric icon={CheckCircle2} title="Faol integratsiyalar" value="6" tone="green" />
        <Metric icon={AlertTriangle} title="Kutilayotgan" value="1" tone="orange" />
        <Metric icon={AlertTriangle} title="Xatoliklar" value="1" tone="red" />
        <Metric icon={Activity} title="API so'rovlar" value="12,456" tone="violet" />
      </div>
      
      <div className="grid gap-5 xl:grid-cols-[1.25fr_.8fr_.65fr]">
        <Card className="border border-border bg-white rounded-2xl shadow-soft">
          <CardHeader className="border-b border-slate-100 pb-3"><CardTitle className="text-sm font-black text-slate-900 uppercase tracking-wide">Ulangan servislar</CardTitle></CardHeader>
          <CardContent className="space-y-2 pt-5">
            {services.map((service, index) => (
              <div key={service} className="grid grid-cols-[1fr_95px_125px_80px] items-center gap-3 rounded-xl border border-slate-150 p-3 text-xs">
                <span className="font-extrabold text-slate-700">{service}</span>
                <Badge variant={index === 7 ? "warning" : "success"}>{index === 7 ? "Kutilmoqda" : "Ulangan"}</Badge>
                <span className="text-[10px] text-slate-400 font-bold">15.05.2026 14:{25 - index}</span>
                <Button variant="secondary" size="sm" onClick={() => onSave(service)} className="border border-slate-200 rounded-lg hover:bg-slate-50 text-[10px] font-black uppercase h-7 px-2.5">Sozlash</Button>
              </div>
            ))}
          </CardContent>
        </Card>
        
        <Card className="border border-border bg-white rounded-2xl shadow-soft">
          <CardHeader className="border-b border-slate-100 pb-3"><CardTitle className="text-sm font-black text-slate-900 uppercase tracking-wide">Integratsiya tafsilotlari</CardTitle></CardHeader>
          <CardContent className="space-y-4 pt-5">
            <InfoLine icon={Cloud} title="Cloudinary" text="Signed upload, auto compression, thumbnail va transformation yoqilgan" />
            <InfoLine icon={Bell} title="Telegram" text="Webhook orqali chat style xabar almashish" />
            <InfoLine icon={Mail} title="Resend / SMTP" text="Transactional email yuborish" />
            <Button onClick={() => onSave("Test webhook")} className="w-full bg-violet-600 hover:bg-violet-700 text-white rounded-xl text-xs font-bold h-10 mt-2">Test yuborish</Button>
          </CardContent>
        </Card>
        
        <Card className="border border-border bg-white rounded-2xl shadow-soft">
          <CardHeader className="border-b border-slate-100 pb-3"><CardTitle className="text-sm font-black text-slate-900 uppercase tracking-wide">API kalitlar</CardTitle></CardHeader>
          <CardContent className="space-y-4 pt-5">
            {["Public API Key", "Secret API Key", "Webhook Secret"].map((key) => (
              <div key={key} className="rounded-xl border border-slate-150 p-3.5 bg-slate-50/20">
                <p className="text-[10px] font-black text-slate-400 uppercase tracking-wider">{key}</p>
                <p className="mt-1 truncate font-mono text-xs font-extrabold text-slate-700">pk_live_****************</p>
              </div>
            ))}
            <Button variant="secondary" className="w-full border border-slate-200 rounded-xl hover:bg-slate-50 text-xs font-bold h-11 mt-2" onClick={() => onSave("API kalit")}>Yangi API kalit yaratish</Button>
          </CardContent>
        </Card>
      </div>
    </div>
  );
}

function NotificationSettings({ onSave }: { onSave: (label?: string) => void }) {
  return (
    <SettingsCard title="Bildirishnomalar" description="Admin panel, student ilova, Telegram bot va email xabarlari.">
      {["Telegram xabarlari", "Student app push", "Email xabarlari", "To'lov eslatmalari", "Sertifikat tayyor", "Xavfsizlik ogohlantirishlari"].map((item) => (
        <SettingRow key={item} icon={Bell} title={item} description="Realtime va unread count bilan ishlaydi">
          <Toggle label="Yoqilgan" onChange={() => onSave(item)} />
        </SettingRow>
      ))}
    </SettingsCard>
  );
}

function FileSettings({ onSave }: { onSave: (label?: string) => void }) {
  return (
    <SettingsCard title="Fayl sozlamalari" description="Rasm, video, round video, voice, PDF va hujjatlar uchun limitlar.">
      <SettingRow icon={HardDrive} title="Rasm limitlari" description="JPG, PNG, WEBP">
        <Input defaultValue="25 MB" onBlur={() => onSave("Rasm limit")} className="h-10.5 rounded-xl border-slate-200 font-semibold" />
      </SettingRow>
      <SettingRow icon={Activity} title="Video limitlari" description="Adaptive streaming va MP4 conversion">
        <Input defaultValue="2 GB" onBlur={() => onSave("Video limit")} className="h-10.5 rounded-xl border-slate-200 font-semibold" />
      </SettingRow>
      <SettingRow icon={FileText} title="PDF va hujjatlar" description="PDF, DOCX, XLSX, PPTX">
        <Input defaultValue="100 MB" onBlur={() => onSave("Hujjat limit")} className="h-10.5 rounded-xl border-slate-200 font-semibold" />
      </SettingRow>
      <SettingRow icon={Bell} title="Voice messages" description="Waveform preview va audio duration">
        <Input defaultValue="50 MB" onBlur={() => onSave("Voice limit")} className="h-10.5 rounded-xl border-slate-200 font-semibold" />
      </SettingRow>
      <SettingRow icon={Cloud} title="Cloudinary transformatsiyalar" description="Auto compression, preview generation, secure delivery">
        <Toggle label="Yoqilgan" onChange={() => onSave("Cloudinary transform")} />
      </SettingRow>
    </SettingsCard>
  );
}

function SettingsCard({
  title,
  description,
  children,
}: {
  title: string;
  description: string;
  children: React.ReactNode;
}) {
  return (
    <Card className="border border-border bg-white rounded-2xl shadow-soft">
      <CardHeader className="border-b border-slate-100 pb-3.5">
        <div>
          <CardTitle className="text-sm font-black text-slate-900 uppercase tracking-wide">{title}</CardTitle>
          <CardDescription className="text-xs text-slate-400 mt-1 font-semibold">{description}</CardDescription>
        </div>
      </CardHeader>
      <CardContent className="divide-y divide-slate-150 p-0">{children}</CardContent>
    </Card>
  );
}

function SettingRow({
  icon: Icon,
  title,
  description,
  children,
}: {
  icon: React.ComponentType<{ className?: string }>;
  title: string;
  description: string;
  children: React.ReactNode;
}) {
  return (
    <div className="grid gap-4 p-5 lg:grid-cols-[360px_1fr] hover:bg-slate-50/20 transition duration-150">
      <div className="flex gap-3.5">
        <span className="flex size-11 items-center justify-center rounded-xl bg-violet-50 text-violet-600 border border-violet-100 shrink-0">
          <Icon className="size-5" />
        </span>
        <div>
          <p className="font-extrabold text-slate-800 text-xs">{title}</p>
          <p className="text-xs text-slate-400 font-semibold mt-1 leading-normal">{description}</p>
        </div>
      </div>
      <div className="flex items-center min-w-0">{children}</div>
    </div>
  );
}

function Metric({
  icon: Icon,
  title,
  value,
  hint,
  tone,
}: {
  icon: React.ComponentType<{ className?: string }>;
  title: string;
  value: string;
  hint?: string;
  tone: "blue" | "green" | "violet" | "orange" | "red";
}) {
  const colors = {
    blue: "bg-indigo-50 text-indigo-600 border border-indigo-100/50",
    green: "bg-emerald-50 text-emerald-600 border border-emerald-100/50",
    violet: "bg-violet-50 text-violet-600 border border-violet-100/50",
    orange: "bg-amber-50 text-amber-600 border border-amber-100/50",
    red: "bg-rose-50 text-rose-600 border border-rose-100/50",
  };
  return (
    <Card className="border border-border bg-white rounded-2xl shadow-soft transition duration-300 hover:-translate-y-0.5 hover:shadow-md">
      <CardContent className="p-4.5">
        <div className="flex items-center gap-4">
          <span className={cn("flex size-12 items-center justify-center rounded-xl shrink-0", colors[tone])}>
            <Icon className="size-6" />
          </span>
          <div className="min-w-0">
            <p className="text-[10px] font-black text-slate-450 uppercase tracking-wider">{title}</p>
            <p className="mt-1.5 text-2xl font-black text-slate-850 leading-none">
              {value} {hint ? <span className="text-xs text-slate-400 font-bold">{hint}</span> : null}
            </p>
          </div>
        </div>
      </CardContent>
    </Card>
  );
}

function Toggle({ label, onChange }: { label: string; onChange: () => void }) {
  const [enabled, setEnabled] = useState(label !== "O'chirilgan");
  return (
    <button
      onClick={() => {
        setEnabled((value) => !value);
        onChange();
      }}
      className="flex items-center gap-3 text-xs font-extrabold text-slate-650"
    >
      <span className={cn("relative h-6.5 w-11 rounded-full transition duration-200 shadow-inner flex items-center", enabled ? "bg-violet-600" : "bg-slate-200")}>
        <span className={cn("absolute size-4.5 rounded-full bg-white shadow transition-all duration-200", enabled ? "left-5.5" : "left-1")} />
      </span>
      {label}
    </button>
  );
}

function InfoLine({
  icon: Icon,
  title,
  text,
}: {
  icon: React.ComponentType<{ className?: string }>;
  title: string;
  text: string;
}) {
  return (
    <div className="flex gap-3">
      <span className="flex size-10 items-center justify-center rounded-xl bg-violet-50 text-violet-600 border border-violet-100/50 shrink-0"><Icon className="size-5" /></span>
      <div className="min-w-0">
        <p className="font-extrabold text-slate-800 text-xs">{title}</p>
        <p className="text-xs text-slate-450 font-semibold mt-0.5 leading-normal">{text}</p>
      </div>
    </div>
  );
}

function Choice({ title, subtitle, active }: { title: string; subtitle: string; active?: boolean }) {
  return (
    <button className={cn(
      "rounded-xl border p-4 text-left transition duration-250 flex-1 min-w-0", 
      active 
        ? "border-violet-250 bg-violet-50/40 shadow-sm" 
        : "border-slate-150 hover:bg-slate-50/40"
    )}>
      <p className="font-extrabold text-xs text-slate-850 leading-snug">{title}</p>
      <p className="text-[10px] text-slate-400 font-bold mt-1 leading-normal">{subtitle}</p>
    </button>
  );
}

function Resource({ label, value }: { label: string; value: string }) {
  return (
    <div>
      <p className="text-[10px] font-black text-slate-400 uppercase tracking-wider">{label}</p>
      <p className="mt-1 text-3xl font-black text-slate-850 leading-none">{value}</p>
    </div>
  );
}

function SettingMini({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <label className="grid gap-2 text-xs font-bold text-slate-700">
      {label}
      {children}
    </label>
  );
}

function DataTable({ headers, rows }: { headers: string[]; rows: string[][] }) {
  return (
    <div className="overflow-x-auto edulab-scrollbar">
      <table className="w-full min-w-[720px] text-sm">
        <thead>
          <tr className="border-b border-border/50 text-left text-[10px] font-black uppercase tracking-wider text-slate-400 bg-slate-50/50">
            {headers.map((head) => <th key={head} className="px-4 py-3">{head}</th>)}
          </tr>
        </thead>
        <tbody className="divide-y divide-slate-100">
          {rows.map((row) => (
            <tr key={row.join("-")} className="group hover:bg-slate-50/30 transition duration-150">
              {row.map((cell, index) => {
                const isStatus = cell.includes("Muvaffaqiyatli");
                return (
                  <td key={`${cell}-${index}`} className="px-4 py-4 font-bold text-xs text-slate-700 h-14">
                    {isStatus ? <Badge variant="success">{cell}</Badge> : cell}
                  </td>
                );
              })}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

function CalendarIcon(props: { className?: string }) {
  return <Globe2 {...props} />;
}
