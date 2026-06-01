import { notFound } from "next/navigation";
import { SettingsPage } from "@/features/settings/settings-page";
import { settingSections } from "@/lib/mock-data";
import type { SettingSection } from "@/lib/types";

export default async function Page({
  params,
}: {
  params: Promise<{ section: string }>;
}) {
  const { section } = await params;
  const isValid = settingSections.some((item) => item.id === section);
  if (!isValid) notFound();

  return <SettingsPage section={section as SettingSection} />;
}
