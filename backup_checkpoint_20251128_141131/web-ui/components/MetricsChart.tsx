import React from 'react';
import { AreaChart, Area, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer } from 'recharts';

interface MetricsChartProps {
  data: { timestamp: string; value: number }[];
  color: string;
  name: string;
}

export const MetricsChart: React.FC<MetricsChartProps> = ({ data, color, name }) => {
  return (
    <div className="h-48 w-full">
      <h4 className="text-xs font-semibold text-slate-400 uppercase tracking-wider mb-2">{name} Usage</h4>
      <ResponsiveContainer width="100%" height="100%">
        <AreaChart data={data}>
          <defs>
            <linearGradient id={`color${name}`} x1="0" y1="0" x2="0" y2="1">
              <stop offset="5%" stopColor={color} stopOpacity={0.3}/>
              <stop offset="95%" stopColor={color} stopOpacity={0}/>
            </linearGradient>
          </defs>
          <CartesianGrid strokeDasharray="3 3" stroke="#334155" vertical={false} />
          <XAxis 
            dataKey="timestamp" 
            hide 
          />
          <YAxis 
            stroke="#64748b" 
            tick={{fill: '#64748b', fontSize: 10}}
            domain={[0, 100]}
          />
          <Tooltip 
            contentStyle={{ backgroundColor: '#1e293b', borderColor: '#475569', color: '#f1f5f9' }}
            itemStyle={{ color: color }}
          />
          <Area 
            type="monotone" 
            dataKey="value" 
            stroke={color} 
            fillOpacity={1} 
            fill={`url(#color${name})`} 
            strokeWidth={2}
          />
        </AreaChart>
      </ResponsiveContainer>
    </div>
  );
};