import * as React from "react";
import { cva, type VariantProps } from "class-variance-authority";
import { cn } from "@/lib/utils";

const buttonVariants = cva(
  "inline-flex items-center justify-center gap-2 rounded-xl text-sm font-semibold transition-all duration-200 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary/35 disabled:pointer-events-none disabled:opacity-50 [&_svg]:pointer-events-none [&_svg]:size-4 [&_svg]:shrink-0",
  {
    variants: {
      variant: {
        default:
          "bg-primary text-primary-foreground shadow-[0_12px_26px_rgba(37,99,235,0.28)] hover:bg-blue-700 hover:shadow-[0_16px_34px_rgba(37,99,235,0.34)]",
        secondary:
          "border border-border bg-white text-foreground shadow-sm hover:border-blue-200 hover:bg-blue-50 hover:text-primary",
        ghost: "text-muted-foreground hover:bg-secondary hover:text-foreground",
        destructive:
          "border border-red-200 bg-red-50 text-red-600 hover:bg-red-100",
        soft: "bg-blue-50 text-primary hover:bg-blue-100",
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
