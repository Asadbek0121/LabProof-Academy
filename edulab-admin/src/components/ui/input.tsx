import * as React from "react";
import { cn } from "@/lib/utils";

export const Input = React.forwardRef<
  HTMLInputElement,
  React.InputHTMLAttributes<HTMLInputElement>
>(({ className, ...props }, ref) => (
  <input
    ref={ref}
    className={cn(
      "h-11 w-full rounded-lg border border-slate-200 bg-white px-3 text-sm text-foreground shadow-sm transition-all placeholder:text-slate-400 hover:border-slate-300 focus:border-primary focus:outline-none focus:ring-4 focus:ring-primary/10 dark:border-slate-800 dark:bg-slate-950/55 dark:text-slate-100 dark:placeholder:text-slate-500 dark:hover:border-slate-700",
      className,
    )}
    {...props}
  />
));
Input.displayName = "Input";

export const Textarea = React.forwardRef<
  HTMLTextAreaElement,
  React.TextareaHTMLAttributes<HTMLTextAreaElement>
>(({ className, ...props }, ref) => (
  <textarea
    ref={ref}
    className={cn(
      "min-h-28 w-full resize-none rounded-lg border border-slate-200 bg-white px-3 py-3 text-sm text-foreground shadow-sm transition-all placeholder:text-slate-400 hover:border-slate-300 focus:border-primary focus:outline-none focus:ring-4 focus:ring-primary/10 dark:border-slate-800 dark:bg-slate-950/55 dark:text-slate-100 dark:placeholder:text-slate-500 dark:hover:border-slate-700",
      className,
    )}
    {...props}
  />
));
Textarea.displayName = "Textarea";

export function Select({
  className,
  children,
  ...props
}: React.SelectHTMLAttributes<HTMLSelectElement>) {
  return (
    <select
      className={cn(
        "h-11 rounded-lg border border-slate-200 bg-white px-3 text-sm font-medium text-slate-700 shadow-sm transition-all hover:border-slate-300 focus:border-primary focus:outline-none focus:ring-4 focus:ring-primary/10 dark:border-slate-800 dark:bg-slate-950/55 dark:text-slate-100 dark:hover:border-slate-700",
        className,
      )}
      {...props}
    >
      {children}
    </select>
  );
}
