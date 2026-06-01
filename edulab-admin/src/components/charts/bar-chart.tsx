"use client";

import { Bar, BarChart, CartesianGrid, ResponsiveContainer, Tooltip, XAxis, YAxis } from "recharts";

const data = [
  { name: "Kirish", value: 95 },
  { name: "Biologiya", value: 92 },
  { name: "Mikrobiologiya", value: 88 },
  { name: "Gematologiya", value: 83 },
  { name: "Biokimyo", value: 76 },
  { name: "Immunologiya", value: 72 },
  { name: "Parazitologiya", value: 65 },
  { name: "Patologiya", value: 45 },
];

export function ModuleBarChart({ chartData }: { chartData?: { name: string; value: number }[] }) {
  const displayData = chartData || data;

  return (
    <div className="h-64">
      <ResponsiveContainer width="100%" height="100%">
        <BarChart data={displayData}>
          <CartesianGrid stroke="#E5E7EB" vertical={false} />
          <XAxis dataKey="name" tickLine={false} axisLine={false} tick={{ fontSize: 11, fill: "#475569" }} />
          <YAxis tickLine={false} axisLine={false} tick={{ fontSize: 11, fill: "#475569" }} />
          <Tooltip />
          <Bar dataKey="value" fill="#4F46E5" radius={[8, 8, 0, 0]} />
        </BarChart>
      </ResponsiveContainer>
    </div>
  );
}
