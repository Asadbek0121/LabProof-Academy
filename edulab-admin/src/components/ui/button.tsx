import * as React from "react";
import { cva, type VariantProps } from "class-variance-authority";
import { cn } from "@/lib/utils";

const buttonVariants = cva(
  "inline-flex items-center justify-center gap-2 rounded-lg text-sm font-semibold transition-all duration-200 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary/35 disabled:pointer-events-none disabled:opacity-50 [&_svg]:pointer-events-none [&_svg]:size-4 [&_svg]:shrink-0",
  {
    variants: {
      variant: {
        default:
          "bg-primary text-primary-foreground shadow-[0_10px_22px_rgba(37,99,235,0.22)] hover:bg-blue-700 hover:shadow-[0_14px_28px_rgba(37,99,235,0.28)]",
        secondary:
          "border border-border bg-white text-foreground shadow-sm hover:border-blue-200 hover:bg-blue-50 hover:text-primary dark:border-slate-800 dark:bg-slate-900 dark:text-slate-100 dark:hover:border-blue-900 dark:hover:bg-slate-800 dark:hover:text-blue-300",
        ghost: "text-muted-foreground hover:bg-secondary hover:text-foreground dark:text-slate-400 dark:hover:bg-slate-800 dark:hover:text-slate-100",
        destructive:
          "border border-red-200 bg-red-50 text-red-600 hover:bg-red-100 dark:border-red-500/20 dark:bg-red-500/12 dark:text-red-300 dark:hover:bg-red-500/18",
        soft: "bg-blue-50 text-primary hover:bg-blue-100 dark:bg-blue-500/12 dark:text-blue-300 dark:hover:bg-blue-500/18",
      },
      size: {
        sm: "h-9 px-3",
        md: "h-11 px-4",
        icon: "size-10 p-0",
      },
    },
    defaultVariants: {
      variant: "default",
      size: "md",
    },
  },
);

export interface ButtonProps
  extends React.ButtonHTMLAttributes<HTMLButtonElement>,
    VariantProps<typeof buttonVariants> {}

export const Button = React.forwardRef<HTMLButtonElement, ButtonProps>(
  ({ className, variant, size, ...props }, ref) => {
    return (
      <button
        ref={ref}
        className={cn(buttonVariants({ variant, size, className }))}
        {...props}
      />
    );
  },
);
Button.displayName = "Button";

export { buttonVariants };
