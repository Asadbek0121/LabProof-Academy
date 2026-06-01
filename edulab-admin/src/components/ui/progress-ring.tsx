"use client";

import { cn } from "@/lib/utils";

type ProgressRingProps = {
  value: number; // 0-100
  size?: number;
  strokeWidth?: number;
  className?: string;
  colorClass?: string;
  trackClass?: string;
  showLabel?: boolean;
  label?: string;
};

export function ProgressRing({
  value,
  size = 48,
  strokeWidth = 4,
  className,
  colorClass,
  trackClass = "text-slate-100",
  showLabel = true,
  label,
}: ProgressRingProps) {
  const radius = (size - strokeWidth) / 2;
  const circumference = 2 * Math.PI * radius;
  const offset = circumference - (Math.min(Math.max(value, 0), 100) / 100) * circumference;

  // Color based on value if no explicit class
  const color =
    colorClass ||
    (value >= 80
      ? "text-emerald-500"
      : value >= 50
        ? "text-amber-500"
        : "text-red-500");

  return (
    <div className={cn("relative inline-flex items-center justify-center", className)}>
      <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`} className="-rotate-90">
        {/* Track */}
        <circle
          cx={size / 2}
          cy={size / 2}
          r={radius}
          fill="none"
          stroke="currentColor"
          strokeWidth={strokeWidth}
          className={trackClass}
        />
        {/* Progress */}
        <circle
          cx={size / 2}
          cy={size / 2}
          r={radius}
          fill="none"
          stroke="currentColor"
          strokeWidth={strokeWidth}
          strokeDasharray={circumference}
          strokeDashoffset={offset}
          strokeLinecap="round"
          className={cn(color, "transition-all duration-700 ease-out")}
        />
      </svg>
      {showLabel && (
        <span className="absolute text-[10px] font-extrabold text-slate-700">
          {label ?? `${Math.round(value)}%`}
        </span>
      )}
    </div>
  );
}
