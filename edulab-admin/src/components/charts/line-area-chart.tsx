"use client";

import {
  Area,
  AreaChart,
  CartesianGrid,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts";
import { chartSeries } from "@/lib/mock-data";

export function LineAreaChart({
  secondary,
  compact,
  chartData,
  theme = "default",
}: {
  secondary?: boolean;
  compact?: boolean;
  chartData?: any[];
  theme?: "default" | "purple";
}) {
  const displayData = chartData || chartSeries;

  return (
    <div className={compact ? "h-32" : "h-72"}>
      <ResponsiveContainer width="100%" height="100%">
        <AreaChart data={displayData} margin={{ left: 0, right: 8, top: 12, bottom: 0 }}>
          <defs>
            <linearGradient id="blueFill" x1="0" x2="0" y1="0" y2="1">
              <stop offset="5%" stopColor="#2563EB" stopOpacity={0.28} />
              <stop offset="95%" stopColor="#2563EB" stopOpacity={0} />
            </linearGradient>
            <linearGradient id="greenFill" x1="0" x2="0" y1="0" y2="1">
              <stop offset="5%" stopColor="#22C55E" stopOpacity={0.24} />
              <stop offset="95%" stopColor="#22C55E" stopOpacity={0} />
            </linearGradient>
            <linearGradient id="violetFill" x1="0" x2="0" y1="0" y2="1">
              <stop offset="5%" stopColor="#7C3AED" stopOpacity={0.28} />
              <stop offset="95%" stopColor="#7C3AED" stopOpacity={0} />
            </linearGradient>
            <linearGradient id="indigoFill" x1="0" x2="0" y1="0" y2="1">
              <stop offset="5%" stopColor="#6366F1" stopOpacity={0.24} />
              <stop offset="95%" stopColor="#6366F1" stopOpacity={0} />
            </linearGradient>
          </defs>
          <CartesianGrid stroke="#E5E7EB" vertical={false} />
          <XAxis dataKey="name" tickLine={false} axisLine={false} tick={{ fontSize: 12, fill: "#475569" }} />
          <YAxis tickLine={false} axisLine={false} tick={{ fontSize: 12, fill: "#475569" }} />
          <Tooltip
            contentStyle={{
              borderRadius: 14,
              border: "1px solid #E5E7EB",
              boxShadow: "0 18px 45px rgba(15,23,42,.12)",
            }}
          />
          <Area
            type="monotone"
            dataKey="active"
            stroke={theme === "purple" ? "#7C3AED" : "#2563EB"}
            strokeWidth={3}
            fill={theme === "purple" ? "url(#violetFill)" : "url(#blueFill)"}
          />
          {secondary ? (
            <Area
              type="monotone"
              dataKey="newUsers"
              stroke={theme === "purple" ? "#6366F1" : "#22C55E"}
              strokeWidth={3}
              fill={theme === "purple" ? "url(#indigoFill)" : "url(#greenFill)"}
            />
          ) : null}
        </AreaChart>
      </ResponsiveContainer>
    </div>
  );
}
