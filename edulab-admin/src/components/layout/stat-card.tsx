import { ArrowUpRight } from "lucide-react";
import { Card } from "@/components/ui/card";
import { cn } from "@/lib/utils";
import type { StatCard as StatCardType } from "@/lib/types";

const toneClasses = {
  blue: "bg-blue-50 text-blue-600",
  green: "bg-emerald-50 text-emerald-600",
  orange: "bg-orange-50 text-orange-500",
  red: "bg-red-50 text-red-500",
  violet: "bg-violet-50 text-violet-600",
};

export function StatCard({ item }: { item: StatCardType }) {
  return (
    <Card className="p-5 transition duration-200 hover:-translate-y-0.5 hover:shadow-soft">
      <div className="flex items-center gap-4">
        <div
          className={cn(
            "flex size-14 items-center justify-center rounded-2xl",
            toneClasses[item.tone],
          )}
        >
          <item.icon className="size-6" />
        </div>
        <div>
          <p className="text-sm font-bold text-slate-700">{item.title}</p>
          <p className="mt-1 text-2xl font-extrabold text-slate-950">{item.value}</p>
          <p className={cn("mt-1 flex items-center gap-1 text-xs font-bold", toneClasses[item.tone].split(" ")[1])}>
            {item.hint}
            <ArrowUpRight className="size-3.5" />
          </p>
        </div>
      </div>
    </Card>
  );
}
