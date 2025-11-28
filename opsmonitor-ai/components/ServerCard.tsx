import React from 'react';
import { MonitoredServer, ServerStatus } from '../types';
import { Server, Activity, ShieldCheck, Clock, Trash2, BarChart3 } from 'lucide-react';

interface ServerCardProps {
  server: MonitoredServer;
  onDelete: (id: string) => void;
  onViewMetrics: (server: MonitoredServer) => void;
}

export const ServerCard: React.FC<ServerCardProps> = ({ server, onDelete, onViewMetrics }) => {
  const isConfiguring = server.status === ServerStatus.CONFIGURING;

  const handleDelete = () => {
    if (window.confirm(`Are you sure you want to remove server "${server.name}"? This action cannot be undone.`)) {
      onDelete(server.id);
    }
  };

  return (
    <div className={`bg-slate-800 rounded-xl border transition-all p-5 flex items-center justify-between group shadow-sm ${
      isConfiguring 
        ? 'border-blue-500/40 shadow-[0_0_15px_rgba(59,130,246,0.1)] animate-pulse' 
        : 'border-slate-700 hover:border-slate-600'
    }`}>
      <div className="flex items-center gap-5">
        {/* Status Icon */}
        <div className={`p-3 rounded-xl transition-colors ${
          server.status === ServerStatus.ONLINE ? 'bg-emerald-500/10 text-emerald-400' :
          server.status === ServerStatus.CONFIGURING ? 'bg-blue-500/10 text-blue-400' :
          'bg-red-500/10 text-red-400'
        }`}>
          {server.status === ServerStatus.ONLINE ? <Server className="w-6 h-6" /> : <Activity className="w-6 h-6" />}
        </div>

        {/* Server Info */}
        <div>
          <h3 className="font-bold text-slate-100 text-lg leading-tight tracking-tight">{server.name}</h3>
          <div className="flex items-center gap-3 text-sm text-slate-400 mt-1.5 font-mono">
            <span className="flex items-center gap-1.5">
               <span className="text-slate-500">HOST:</span>
               {server.ip}:{server.port}
            </span>
            <span className="w-1 h-1 rounded-full bg-slate-600"></span>
            <span className="flex items-center gap-1.5">
               <span className="text-slate-500">OS:</span>
               {server.os}
            </span>
          </div>
        </div>
      </div>

      {/* Status Badge & Actions */}
      <div className="flex items-center gap-6">
        <div className={`flex items-center gap-2 px-3 py-1.5 rounded-full text-sm font-medium border ${
          server.status === ServerStatus.ONLINE ? 'bg-emerald-500/5 text-emerald-400 border-emerald-500/20' :
          server.status === ServerStatus.CONFIGURING ? 'bg-blue-500/5 text-blue-400 border-blue-500/20' :
          'bg-red-500/5 text-red-400 border-red-500/20'
        }`}>
          {server.status === ServerStatus.ONLINE ? <ShieldCheck className="w-4 h-4" /> : <Clock className="w-4 h-4" />}
          <span>{server.status}</span>
        </div>

        <div className="h-8 w-px bg-slate-700 mx-1 hidden sm:block"></div>

        <div className="flex items-center gap-1">
            <button
                onClick={() => onViewMetrics(server)}
                disabled={isConfiguring}
                className="p-2 text-slate-400 hover:text-blue-400 hover:bg-blue-500/10 rounded-lg transition-all disabled:opacity-50 disabled:cursor-not-allowed"
                title="View Graphite Metrics"
            >
              <BarChart3 className="w-5 h-5" />
            </button>
            <button
                onClick={handleDelete}
                className="p-2 text-slate-500 hover:text-red-400 hover:bg-red-500/10 rounded-lg transition-all opacity-0 group-hover:opacity-100 focus:opacity-100"
                title="Delete Server"
            >
              <Trash2 className="w-5 h-5" />
            </button>
        </div>
      </div>
    </div>
  );
};