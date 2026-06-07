"use client";

import { X } from "lucide-react";
import { Button } from "@/components/ui/button";
import { cn } from "@/lib/utils";

type ModalProps = {
  open: boolean;
  title: string;
  description?: string;
  children: React.ReactNode;
  footer?: React.ReactNode;
  wide?: boolean;
  onOpenChange: (open: boolean) => void;
};

export function Modal({
  open,
  title,
  description,
  children,
  footer,
  wide,
  onOpenChange,
}: ModalProps) {
  if (!open) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-950/35 p-3 backdrop-blur-sm dark:bg-slate-950/65 xl:p-4">
      <div
        role="dialog"
        aria-modal="true"
        aria-label={title}
        className={cn(
          "max-h-[90vh] w-full overflow-hidden rounded-lg border border-border bg-white shadow-soft dark:border-slate-800 dark:bg-slate-900 xl:max-h-[88vh]",
          wide ? "max-w-[min(64rem,calc(100vw-1.5rem))] xl:max-w-4xl" : "max-w-xl",
        )}
      >
        <header className="flex items-start justify-between gap-4 border-b border-border p-4 dark:border-slate-800 xl:p-5">
          <div>
            <h2 className="text-lg font-bold text-slate-950 dark:text-slate-100">{title}</h2>
            {description ? (
              <p className="mt-1 text-sm text-slate-500 dark:text-slate-400">{description}</p>
            ) : null}
          </div>
          <Button variant="ghost" size="icon" onClick={() => onOpenChange(false)}>
            <X />
          </Button>
        </header>
        <div className="max-h-[66vh] overflow-y-auto p-4 edulab-scrollbar xl:max-h-[62vh] xl:p-5">
          {children}
        </div>
        {footer ? (
          <footer className="flex justify-end gap-3 border-t border-border p-4 dark:border-slate-800 xl:p-5">
            {footer}
          </footer>
        ) : null}
      </div>
    </div>
  );
}
