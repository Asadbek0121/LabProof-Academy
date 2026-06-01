import { FileSearch } from "lucide-react";
import { Card } from "@/components/ui/card";

export function EmptyState({
  title,
  message,
}: {
  title: string;
  message: string;
}) {
  return (
    <Card className="flex min-h-56 flex-col items-center justify-center gap-3 p-8 text-center">
      <div className="flex size-12 items-center justify-center rounded-2xl bg-blue-50 text-primary">
        <FileSearch className="size-5" />
      </div>
      <div>
        <h3 className="font-bold text-slate-950">{title}</h3>
        <p className="mt-1 max-w-md text-sm leading-6 text-slate-500">{message}</p>
      </div>
    </Card>
  );
}
