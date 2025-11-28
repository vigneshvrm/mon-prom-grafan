import React from 'react';
import { AreaChart, Area, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, Brush } from 'recharts';

interface MetricsChartProps {
  data: { timestamp: string; value: number }[];
  color: string;
  name: string;
  unit?: string;
  domain?: [number, number];
  timeLabel?: string;
}

const CustomTooltip = ({ active, payload, label, unit }: any) => {
  if (active && payload && payload.length) {
    return (
      <div className="bg-slate-800 border border-slate-700 p-3 rounded-lg shadow-xl backdrop-blur-sm bg-opacity-95">
        <p className="text-slate-400 text-xs mb-1 font-mono">{label}</p>
        <div className="flex items-baseline gap-1">
          <span className="text-slate-100 text-lg font-bold font-mono tracking-tight">
            {payload[0].value}
          </span>
          <span className="text-slate-500 text-xs font-medium uppercase">{unit}</span>
        </div>
        <p className="text-xs text-slate-500 mt-1" style={{ color: payload[0].color }}>
          {payload[0].name}
        </p>
      </div>
    );
  }
  return null;
};

export const MetricsChart: React.FC<MetricsChartProps> = ({ 
  data, 
  color, 
  name, 
  unit = '%',
  domain = [0, 100],
  timeLabel = 'Last 30 Mins'
}) => {
  return (
    <div className="h-72 w-full bg-slate-900/50 rounded-xl border border-slate-700/50 p-4">
      <div className="flex items-center justify-between mb-2">
        <h4 className="text-xs font-bold text-slate-400 uppercase tracking-wider">{name}</h4>
        <div className="flex items-center gap-2">
           <span className="w-2 h-2 rounded-full" style={{ backgroundColor: color }}></span>
           <span className="text-xs font-mono text-slate-500">{timeLabel}</span>
        </div>
      </div>
      <div className="h-56 w-full">
        <ResponsiveContainer width="100%" height="100%">
          <AreaChart data={data} margin={{ top: 10, right: 10, left: -20, bottom: 0 }}>
            <defs>
              <linearGradient id={`color${name.replace(/\s/g, '')}`} x1="0" y1="0" x2="0" y2="1">
                <stop offset="5%" stopColor={color} stopOpacity={0.3}/>
                <stop offset="95%" stopColor={color} stopOpacity={0}/>
              </linearGradient>
            </defs>
            <CartesianGrid strokeDasharray="3 3" stroke="#334155" vertical={false} opacity={0.5} />
            <XAxis 
              dataKey="timestamp" 
              hide={true} 
            />
            <YAxis 
              stroke="#64748b" 
              tick={{fill: '#64748b', fontSize: 10}}
              domain={domain}
              tickFormatter={(value) => `${value}`}
              width={35}
            />
            <Tooltip content={<CustomTooltip unit={unit} />} />
            <Area 
              type="monotone" 
              dataKey="value" 
              name={name}
              stroke={color} 
              fillOpacity={1} 
              fill={`url(#color${name.replace(/\s/g, '')})`} 
              strokeWidth={2}
              animationDuration={1500}
            />
            <Brush 
                dataKey="timestamp" 
                height={20} 
                stroke="#334155"
                fill="#0f172a"
                tickFormatter={() => ""}
                travellerWidth={6}
                alwaysShowText={false}
            />
          </AreaChart>
        </ResponsiveContainer>
      </div>
    </div>
  );
};