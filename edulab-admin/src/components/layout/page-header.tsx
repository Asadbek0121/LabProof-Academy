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
    <div className="mb-6 flex flex-col gap-4 border-b border-slate-200 pb-5 sm:flex-row sm:items-end sm:justify-between dark:border-slate-800">
      <div>
        <h1 className="text-2xl font-black tracking-tight text-slate-950 dark:text-slate-100">
          {title}
        </h1>
        <div className="mt-2 flex items-center gap-2 text-sm text-slate-500 dark:text-slate-500">
          <Link href="/students" className="hover:text-primary dark:hover:text-blue-300">
            Bosh sahifa
          </Link>
          <ChevronRight className="size-4" />
          {parent ? (
            <>
              <Link href="/settings" className="font-semibold hover:text-primary dark:hover:text-blue-300">
                {parent}
              </Link>
              <ChevronRight className="size-4" />
            </>
          ) : null}
          <span className="font-semibold text-primary dark:text-blue-300">{current}</span>
        </div>
      </div>
      {action}
    </div>
  );
}
