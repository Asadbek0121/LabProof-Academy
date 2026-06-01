"use client";

import { Cell, Pie, PieChart, ResponsiveContainer, Tooltip } from "recharts";

const data = [
  { name: "Faol", value: 42, color: "#2563EB" },
  { name: "Jarayonda", value: 31, color: "#22C55E" },
  { name: "Kutmoqda", value: 18, color: "#F59E0B" },
  { name: "Boshlanmagan", value: 9, color: "#EF4444" },
];

export interface DonutData {
  name: string;
  value: number;
  color: string;
}

export function DonutChart({ label = "2,482", chartData }: { label?: string; chartData?: DonutData[] }) {
  const displayData = chartData || data;

  return (
    <div className="relative h-56">
      <ResponsiveContainer width="100%" height="100%">
        <PieChart>
          <Pie
            data={displayData}
            dataKey="value"
            nameKey="name"
            innerRadius={58}
            outerRadius={86}
            paddingAngle={2}
          >
            {displayData.map((entry) => (
              <Cell key={entry.name} fill={entry.color} />
            ))}
          </Pie>
          <Tooltip />
        </PieChart>
      </ResponsiveContainer>
      <div className="pointer-events-none absolute inset-0 flex items-center justify-center">
        <div className="text-center">
          <p className="text-xs font-semibold text-slate-500">Jami</p>
          <p className="text-xl font-extrabold text-slate-950">{label}</p>
        </div>
      </div>
    </div>
  );
}
