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
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-950/35 p-4 backdrop-blur-sm">
      <div
        role="dialog"
        aria-modal="true"
        aria-label={title}
        className={cn(
          "max-h-[88vh] w-full overflow-hidden rounded-2xl border border-border bg-white shadow-soft",
          wide ? "max-w-4xl" : "max-w-xl",
        )}
      >
        <header className="flex items-start justify-between gap-4 border-b border-border p-5">
          <div>
            <h2 className="text-lg font-bold text-slate-950">{title}</h2>
            {description ? (
              <p className="mt-1 text-sm text-slate-500">{description}</p>
            ) : null}
          </div>
          <Button variant="ghost" size="icon" onClick={() => onOpenChange(false)}>
            <X />
          </Button>
        </header>
        <div className="max-h-[62vh] overflow-y-auto p-5 edulab-scrollbar">
          {children}
        </div>
        {footer ? (
          <footer className="flex justify-end gap-3 border-t border-border p-5">
            {footer}
          </footer>
        ) : null}
      </div>
    </div>
  );
}
