import Link from "next/link";
import { ChevronRight } from "lucide-react";

export function PageHeader({
  title,
  parent,
  current,
  action,
}: {
  title: string;
  parent?: string;
  current: string;
  action?: React.ReactNode;
}) {
  return (
    <div className="mb-6 flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
      <div>
        <h1 className="text-2xl font-extrabold tracking-tight text-slate-950">
          {title}
        </h1>
        <div className="mt-3 flex items-center gap-2 text-sm text-slate-500">
          <Link href="/students" className="hover:text-primary">
            Bosh sahifa
          </Link>
          <ChevronRight className="size-4" />
          {parent ? (
            <>
              <Link href="/settings" className="font-semibold hover:text-primary">
                {parent}
              </Link>
              <ChevronRight className="size-4" />
            </>
          ) : null}
          <span className="font-semibold text-primary">{current}</span>
        </div>
      </div>
      {action}
    </div>
  );
}
