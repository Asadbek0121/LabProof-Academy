import { ArrowRight, Construction } from "lucide-react";
import { PageHeader } from "@/components/layout/page-header";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";

export function PlaceholderPage({ title }: { title: string }) {
  return (
    <>
      <PageHeader title={title} current={title} />
      <Card>
        <CardContent className="grid min-h-[420px] place-items-center p-8 text-center">
          <div className="max-w-md">
            <span className="mx-auto flex size-16 items-center justify-center rounded-2xl bg-blue-50 text-primary">
              <Construction className="size-8" />
            </span>
            <h2 className="mt-5 text-2xl font-extrabold">{title}</h2>
            <p className="mt-2 text-sm leading-6 text-slate-500">
              Bu bo'lim admin panel shell, RBAC va umumiy layout bilan tayyor. Kontent boshqaruvi keyingi modul sifatida kengaytiriladi.
            </p>
            <Button className="mt-5">
              Ko'rib chiqish
              <ArrowRight />
            </Button>
          </div>
        </CardContent>
      </Card>
    </>
  );
}
